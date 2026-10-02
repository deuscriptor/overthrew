// Behavioral checks for the Panorama logic, with mocked panels.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { sources } = require("./panorama_resources");
const scripts = path.join(sources, "panorama/layout/custom_game");

const utils = fs.readFileSync(path.join(scripts, "scripts/utils.js"), "utf8");
const declarations = utils.slice(0, utils.indexOf("Object.defineProperties"));
{
	// Before the match rules arrive, both rule flags are off.
	const context = vm.createContext({ Game: {
		GetLocalPlayerID: () => 0,
		GetLocalPlayerInfo: () => ({ player_steamid: "0" }),
		GetMapInfo: () => ({ map_display_name: "ot3_necropolis_ffa" }),
	} });
	vm.runInContext(declarations, context);
	assert.equal(vm.runInContext("MAP_NAME", context), "ot3_necropolis_ffa");
	assert.equal(vm.runInContext("IS_SINGLE_DRAFT_MAP", context), false);
	assert.equal(vm.runInContext("IS_EPIC_ONLY_MAP", context), false);
}

class Panel {
	constructor(id, paneltype = "Panel", parent = null, classes = []) {
		this.id = id;
		this.paneltype = paneltype;
		this.parent = parent;
		this.classes = classes;
		this.children = [];
		this.style = {};
		this.events = {};
		this.vars = {};
		this.visible = true;
		if (parent) parent.children.push(this);
	}
	GetParent() { return this.parent; }
	SetParent(parent) {
		if (this.parent) this.parent.children = this.parent.children.filter(child => child !== this);
		this.parent = parent;
		parent.children.push(this);
	}
	Children() { return this.children; }
	GetChild(index) { return this.children[index] || null; }
	FindChildTraverse(id) {
		if (this.id === id) return this;
		for (const child of this.children) {
			const found = child.FindChildTraverse(id);
			if (found) return found;
		}
		return null;
	}
	FindChildrenWithClassTraverse(name) {
		return this.children.flatMap(child => [
			...(child.classes.includes(name) ? [child] : []),
			...child.FindChildrenWithClassTraverse(name),
		]);
	}
	SetPanelEvent(name, handler) { this.events[name] = handler; }
	SetDialogVariable(name, value) { this.vars[name] = value; }
	SetImage(image) { this.image = image; }
	SetSelected(value) { this.selected = value; }
	IsSelected() { return !!this.selected; }
	IsValid() { return true; }
	RemoveAndDeleteChildren() { this.children = []; }
	ClearPropertyFromCode(name) { (this.cleared = this.cleared || []).push(name); }
}

{
	const container = new Panel("CustomUIContainer_Hud");
	const contextPanel = new Panel("TopBar", "Panel", container);
	let data = {open: 1, players: {0: {hero: "npc_dota_hero_axe", busy: 0}, 1: {hero: "npc_dota_hero_lina", busy: 0}}, requests: {}};
	let listener;
	const events = {}, sent = [];
	const dollar = {GetContextPanel: () => contextPanel, CreatePanel: (type, parent, id) => new Panel(id, type, parent), Localize: text => text};
	const context = vm.createContext({$: dollar, Game: {
		GetLocalPlayerID: () => 0, GetLocalPlayerInfo: () => null,
		GetPlayerInfo: id => ({player_name: "Player " + id}),
		GetMapInfo: () => ({map_display_name: "ot3_necropolis_ffa"}),
		GameStateIsAfter: () => true,
	}, GameEvents: {
		NewProtectedFrame: () => ({SubscribeProtected: (name, fn) => {events[name] = fn;}}),
		Subscribe: (name, fn) => {events[name] = fn;},
		SendToServerEnsured: (name, payload) => sent.push({name, payload}),
	}, GameUI: {GetTeamColor: team => ({2: "#3dd296;", 3: "#F3C909;"})[team]}, Players: {GetTeam: id => id + 2},
	DOTA_GameState: {DOTA_GAMERULES_STATE_PRE_GAME: 8}, CustomNetTables: {
		GetTableValue: () => data,
		SubscribeNetTableListener: (table, fn) => {listener = fn;},
	}});
	vm.runInContext(declarations + "\nCreateHeroSwapPanel();", context);
	const root = container.FindChildTraverse("HeroSwaps");
	assert.equal(root.parent, container, "Menu must avoid the clipped top-bar panel");
	assert.ok(root.visible);
	container.FindChildTraverse("RequestSwap_1").events.onactivate();
	assert.equal(sent[0].name, "HeroSwaps:request");
	assert.equal(sent[0].payload.target, 1);
	// Host-settings styling: green primary action, player-colour strip under the portrait.
	assert.equal(container.FindChildTraverse("RequestSwap_1").style.border, "1px solid #9cc07f");
	const swapRow = container.FindChildTraverse("HeroSwapPlayer_1");
	assert.equal(swapRow.children[1].style.borderBottom, "3px solid #F3C909");
	assert.equal(swapRow.children[1].image, "file://{images}/heroes/npc_dota_hero_lina.png");
	data.requests = {5: {id: 5, from: 1, to: 0}};
	listener("game_options", "hero_swaps", data);
	const swapBody = container.FindChildTraverse("HeroSwapsBody");
	const swapToggle = container.FindChildTraverse("HeroSwapsToggle");
	const swapBadge = container.FindChildTraverse("HeroSwapRequestBadge");
	assert.equal(swapBody.visible, false, "Incoming request must not open the menu");
	assert.equal(swapBadge.visible, true);
	assert.equal(swapBadge.children[0].text, "1", "count label centred inside the badge circle");
	assert.ok(!swapBody.children.some(panel => panel.text === "#hero_swaps_hint"), "Explanatory description removed");
	swapToggle.events.onactivate();
	assert.equal(swapBody.visible, true, "Player can open request controls");
	swapToggle.events.onactivate();
	events["HeroSwaps:status"]({status: "accepted"});
	assert.equal(swapBody.visible, false, "Status updates must not force the menu open");
	container.FindChildTraverse("AcceptSwap_1").events.onactivate();
	assert.equal(sent[1].name, "HeroSwaps:accept");
	assert.equal(sent[1].payload.request_id, 5);
	assert.equal(container.FindChildTraverse("AcceptSwap_1").style.border, "1px solid #9cc07f");
	assert.equal(container.FindChildTraverse("DeclineSwap_1").style.border, "1px solid #d66b62");
	assert.equal(container.FindChildTraverse("HeroSwapPlayer_1").children[0].style.backgroundColor, "#d4bb86",
		"incoming request marked with the gold accent");
	container.FindChildTraverse("DeclineSwap_1").events.onactivate();
	assert.equal(sent[2].name, "HeroSwaps:decline");
	data.requests = {6: {id: 6, from: 0, to: 1}};
	listener("game_options", "hero_swaps", data);
	assert.equal(swapBadge.visible, false, "Clear badge when no incoming requests remain");
	container.FindChildTraverse("CancelSwap_1").events.onactivate();
	assert.equal(sent[3].name, "HeroSwaps:cancel");
	data.requests = {};
	data.players[0].busy = 1;
	listener("game_options", "hero_swaps", data);
	assert.equal(container.FindChildTraverse("RequestSwap_1"), null, "Accepted swap blocks new requests");
	data.open = 0;
	listener("game_options", "hero_swaps", data);
	assert.equal(root.visible, false);
	data.open = 1;
	delete data.players[0];
	listener("game_options", "hero_swaps", data);
	assert.equal(root.visible, false, "Spectators and unpicked players cannot send swaps");
	console.log("PASS hero swap UI: requests, incoming consent, decline, cancellation, busy state, phase closure and spectators");
}

for (let draft = 0; draft < 2; draft++) for (let epic = 0; epic < 2; epic++) {
	let data;
	let listener;
	const context = vm.createContext({Game: {
		GetLocalPlayerID: () => 0, GetLocalPlayerInfo: () => null,
		GetMapInfo: () => ({map_display_name: "ot3_necropolis_ffa"}),
	}, CustomNetTables: {
		GetTableValue: () => data,
		SubscribeNetTableListener: (table, fn) => {listener = fn;},
	}});
	vm.runInContext(declarations, context);
	data = {single_draft: draft, epic_orbs: epic};
	listener("game_options", "match_rules");
	assert.equal(vm.runInContext("IS_SINGLE_DRAFT_MAP", context), !!draft);
	assert.equal(vm.runInContext("IS_EPIC_ONLY_MAP", context), !!epic);
	assert.equal(vm.runInContext("IS_FLAT_REROLL_MAP", context), !!epic);
}

const loading = fs.readFileSync(path.join(scripts, "custom_loading_screen/custom_loading_screen.js"), "utf8");
const initRules = loading.slice(loading.indexOf("function InitMatchRules()"), loading.indexOf("function ToggleHostOption"));
const releaseLoading = loading.slice(loading.indexOf("let loading_screen_released"), loading.indexOf("function InitHints()"));
{
	const root = new Panel("Loading");
	let data;
	let listener;
	const requests = [];
	const waitingFrames = [];
	const claimTimers = [];
	const pagesRequested = [];
	const releaseTimers = [];
	let gameState = 2;
	// The loading screen's own pager: arrows with a chevron image, and the bullets container.
	const tipsRoot = new Panel("LS_Tips_Root", "Panel", root);
	const arrowLeft = new Panel("LS_Tips_Left", "Button", tipsRoot, ["LS_Tips_Arrow"]);
	new Panel("", "Image", arrowLeft);
	const bulletsRoot = new Panel("LS_Tips_Bullets", "Panel", tipsRoot);
	const arrowRight = new Panel("LS_Tips_Right", "Button", tipsRoot, ["LS_Tips_Arrow"]);
	new Panel("", "Image", arrowRight);
	const initHints = () => {
		bulletsRoot.children = [];
		for (let i = 0; i < 3; i++) {
			const bullet = new Panel("Bullet_" + i, "Panel", bulletsRoot, ["LS_Bullet"]);
			new Panel("", "Image", bullet, ["Bullet_BG"]);
			new Panel("", "Image", bullet, ["Bullet_Active"]);
		}
	};
	const context = vm.createContext({LOADING_HUD: {CONTEXT: root, MOVIE_CONTAINER: root, BULLETS_ROOT: bulletsRoot}, hints: [], InitHints: initHints,
		SetHint: index => pagesRequested.push(index),
		$: {CreatePanel: (type, parent, id) => new Panel(id, type, parent), Localize: value => value, DispatchEvent: () => {},
			Schedule: (delay, callback) => { if (delay === 0.3) waitingFrames.push(callback); if (delay === 2) claimTimers.push(callback); if (delay === 0.2) releaseTimers.push(callback); }},
		Game: {GetLocalPlayerID: () => 0, GetPlayerInfo: id => ({player_name: "Player " + id}), GameStateIsAfter: state => gameState > state},
		DOTA_GameState: {DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP: 2}, auto_hint_schedule: undefined,
		GameEvents: {SendToServerEnsured: (name, args) => requests.push({name, args})},
		CustomNetTables: {GetTableValue: () => data, SubscribeNetTableListener: (table, fn) => { listener = fn; }},
	});
	vm.runInContext(releaseLoading + initRules + "InitMatchRules();", context);
	assert.equal(root.children.length, 1, "wait for rules before constructing controls");
	const logo = new Panel("Logo", "Image", root, ["LS_Tips_Logo"]);
	const discord = new Panel("Discord", "Button", root, ["LS_DiscordButton"]);
	data = {host_id: -1, locked: 0, ready: 0, single_draft: 1, epic_orbs: 0, turbo: 1, longer_wards: 1};
	vm.runInContext("InitMatchRules();", context);
	assert.equal(root.children.length, 3, "settings stay hidden until every player has loaded");
	assert.equal(logo.visible, true, "loading tips stay until then");
	data = {host_id: 0, locked: 0, ready: 1, single_draft: 1, epic_orbs: 0, turbo: 1, longer_wards: 1};
	vm.runInContext("InitMatchRules(); InitMatchRules();", context);
	assert.equal(root.children.length, 4, "initialize only once");
	// Pager: arrows and bullets grouped into one row, styled like the settings.
	const pager = root.FindChildTraverse("MatchRulesPager");
	assert.equal(pager.parent, tipsRoot);
	assert.deepEqual(pager.children.map(p => p.id), ["LS_Tips_Left", "LS_Tips_Bullets", "LS_Tips_Right"]);
	assert.equal(tipsRoot.style.backgroundImage, "none", "frame art with the notch removed");
	const bullets = () => bulletsRoot.children;
	assert.ok(bullets()[0].children.every(art => art.visible === false), "bullet images replaced by styled dots");
	assert.equal(arrowLeft.enabled, false, "no previous page on the first page");
	assert.equal(arrowLeft.style.opacity, "0.35");
	assert.equal(arrowLeft.style.visibility, "visible", "dimmed, not collapsed, so the row does not shift");
	assert.equal(arrowRight.enabled, true);
	assert.equal(arrowRight.children[0].style.washColor, "#d4bb86");
	assert.equal(arrowRight.children[0].hittest, false, "hover and clicks reach the arrow, not its icon");
	assert.deepEqual(bullets().map(b => b.style.width), ["22px", "8px", "8px"], "current page is a gold pill");
	assert.equal(bullets()[0].style.backgroundColor, "#d4bb86");
	assert.equal(arrowRight.style.border, "1px solid #dfc58b", "arrow glows until noticed");
	assert.match(arrowRight.style.boxShadow, /^#c59a48cc/);
	assert.equal(bullets()[1].style.backgroundColor, "#dfc58b", "unvisited page bullet glows like its tab");
	arrowRight.events.onmouseover();
	assert.equal(arrowRight.style.border, "1px solid #d4bb86", "arrow hover");
	arrowRight.events.onmouseout();
	assert.equal(arrowRight.style.border, "1px solid #415465", "no glow once hovered");
	assert.doesNotMatch(arrowRight.style.boxShadow, /c59a48/);
	bullets()[2].events.onactivate();
	assert.equal(pagesRequested[pagesRequested.length - 1], 2, "bullets open their page");
	pagesRequested.length = 0;
	assert.equal(logo.visible, false);
	assert.equal(discord.visible, false);
	assert.equal(root.FindChildTraverse("Rule_flat_rerolls"), null);
	assert.deepEqual(root.FindChildTraverse("MatchRules_core").children.filter(p => p.paneltype === "ToggleButton").map(p => p.id), ["Rule_single_draft", "Rule_turbo", "Rule_epic_orbs", "Rule_backpack_items"]);
	assert.equal(vm.runInContext("hints.length", context), 3, "one settings page per category");
	assert.equal(root.FindChildTraverse("MatchRules_core").visible, true);
	assert.equal(root.FindChildTraverse("MatchRules_other").visible, false);
	assert.deepEqual(root.FindChildTraverse("MatchRules_other").children.filter(p => p.paneltype === "ToggleButton").map(p => p.id), ["Rule_all_vision", "Rule_infinite_rerolls", "Rule_longer_wards", "Rule_invincible_wards"]);
	assert.deepEqual(root.FindChildTraverse("MatchRulesTabs").children.map(p => p.id), ["MatchRulesTab_core", "MatchRulesTab_items", "MatchRulesTab_other"], "tab order: Core, Items, Other");
	const tabs = ["core", "items", "other"].map(id => root.FindChildTraverse("MatchRulesTab_" + id));
	assert.equal(tabs[1].caption.style.color, "#dfc58b", "unvisited tab glows");
	tabs[1].events.onactivate();
	assert.deepEqual(pagesRequested, [1], "tabs open their settings page");
	const knob = name => root.FindChildTraverse("Rule_" + name).children[2].children[0].children[0];
	const track = name => root.FindChildTraverse("Rule_" + name).children[2];
	assert.equal(track("single_draft").style.saturation, "1", "the host sees coloured switches");
	assert.equal(track("epic_orbs").style.opacity, "1");
	assert.match(knob("single_draft").style.transform, /18px/, "enabled option shows switch on");
	assert.match(knob("epic_orbs").style.transform, /\(0px/, "disabled option shows switch off");
	assert.equal(root.FindChildTraverse("KillGoalTime").text, "#host_rules_time_limit 33:20");
	vm.runInContext("matchRulesPageChanged(1)", context);
	assert.equal(tabs[1].caption.style.color, "#f3dfae", "active tab highlighted");
	assert.equal(tabs[0].caption.style.color, "#7f95a6", "visited tab no longer glows");
	assert.equal(tabs[2].caption.style.color, "#dfc58b");
	assert.equal(root.FindChildTraverse("MatchRules_core").visible, false);
	assert.equal(root.FindChildTraverse("MatchRules_items").visible, true);
	assert.equal(arrowLeft.enabled, true, "both arrows available on a middle page");
	assert.equal(arrowLeft.style.border, "1px solid #dfc58b", "untouched previous arrow glows once available");
	assert.deepEqual(bullets().map(b => b.style.width), ["8px", "22px", "8px"]);
	assert.equal(bullets()[0].style.backgroundColor, "#7f95a6", "visited page bullet stops glowing");
	assert.equal(bullets()[2].style.backgroundColor, "#dfc58b");
	vm.runInContext("matchRulesPageChanged(2)", context);
	assert.equal(root.FindChildTraverse("MatchRules_other").visible, true);
	assert.equal(arrowRight.enabled, false, "no next page on the last page");
	assert.equal(vm.runInContext("hints[0][0]", context), "settings");
	const start = root.FindChildTraverse("ApplyMatchRules");
	const waiting = root.FindChildTraverse("WaitingForHost");
	assert.equal(waiting.visible, false);
	assert.equal(start.enabled, true);
	start.events.onactivate();
	assert.deepEqual(JSON.parse(JSON.stringify(requests[0])), {name:"HostOptions:apply_rules", args:{single_draft:1,epic_orbs:0,turbo:1,backpack_items:0,kill_goal:50,infinite_rerolls:0,all_vision:0,invincible_wards:0,longer_wards:1,divine_rapier:0,dagon:0}});
	const goal = root.FindChildTraverse("KillGoalInput");
	assert.equal(goal.text, "50");
	goal.text = "";
	goal.events.ontextentrychange();
	listener("game_options", "match_rules");
	assert.equal(goal.text, "", "refresh overwrote active edit");
	assert.equal(start.enabled, false);
	goal.text = "45";
	goal.events.ontextentrychange();
	start.events.onactivate();
	assert.equal(requests[requests.length - 1].args.kill_goal, 45);
	assert.equal(root.FindChildTraverse("KillGoalTime").text, "#host_rules_time_limit 30:00");
	data.host_id = 1;
	listener("game_options", "match_rules");
	assert.equal(start.visible, false, "non-host cannot start");
	assert.equal(waiting.visible, true);
	// Status card in Apply & Start's footprint (42px + 12px margin), so the five rows still fit.
	assert.equal(waiting.style.height, start.style.height);
	assert.equal(waiting.style.marginTop, start.style.marginTop);
	const waitingLabels = waiting.children[1].children.map(p => p.text);
	assert.deepEqual(waitingLabels, ["#host_rules_waiting", "#host_rules_waiting_detail"], "no dots appended to the text");
	const litDots = () => root.FindChildTraverse("WaitingForHostDots").children.map(dot => dot.style.opacity === "1");
	assert.deepEqual(litDots(), [true, false, false]);
	assert.equal(root.FindChildTraverse("WaitingForHostDots").style.padding, "6px", "room for the lifted dot's glow, not clipped");
	for (const lit of [[false, true, false], [false, false, true], [true, false, false]]) {
		waitingFrames.shift()();
		assert.deepEqual(litDots(), lit, "gold dots pulse in turn");
	}
	assert.equal(root.FindChildTraverse("Rule_single_draft").enabled, false);
	assert.equal(goal.enabled, false);
	for (const name of ["single_draft", "epic_orbs"]) {
		assert.equal(track(name).style.saturation, "0", "waiting players see greyed-out switches");
		assert.equal(track(name).style.opacity, "0.5");
	}
	assert.equal(waiting.children[1].children[1].vars.host_name, "Player 1", "waiting card names the host");
	const claim = root.FindChildTraverse("ClaimHost");
	assert.equal(claim.visible, false, "no claim while someone is host");
	data.host_id = -1;
	listener("game_options", "match_rules");
	assert.equal(claim.visible, true, "anyone can claim a free host role");
	assert.equal(waiting.visible, false);
	assert.equal(start.visible, false);
	assert.equal(root.FindChildTraverse("Rule_single_draft").enabled, false, "no edits before claiming");
	// Same footprint as Apply & Start and the waiting card, lit like unvisited tabs.
	assert.equal(claim.style.height, start.style.height);
	assert.equal(claim.style.marginTop, start.style.marginTop);
	assert.equal(claim.style.border, "1px solid #dfc58b");
	assert.match(claim.style.boxShadow, /^#c59a48cc/);
	assert.deepEqual(claim.children[1].children.map(p => p.text), ["#host_rules_claim", "#host_rules_claim_detail"]);
	claim.events.onmouseover();
	assert.equal(claim.style.border, "1px solid #d4bb86", "claim hover");
	claim.events.onmouseout();
	const sent = requests.length;
	claim.events.onactivate();
	claim.events.onactivate();
	assert.equal(requests.length, sent + 1, "one claim request at a time");
	assert.deepEqual(JSON.parse(JSON.stringify(requests[requests.length - 1])), {name: "HostOptions:claim_host", args: {}});
	assert.equal(claim.enabled, false);
	claimTimers.shift()();
	assert.equal(claim.enabled, true, "claim can be retried if it was not granted");
	data.host_id = 0;
	listener("game_options", "match_rules");
	assert.equal(claim.visible, false);
	assert.equal(start.visible, true, "the claimer gets Apply & Start");
	assert.equal(track("single_draft").style.saturation, "1", "switches regain colour for the new host");
	data.locked = 1;
	listener("game_options", "match_rules");
	assert.equal(start.enabled, false, "locked settings cannot be edited");
	assert.equal(waiting.visible, false, "no waiting message after start");
	assert.equal(claim.visible, false, "no claim after start");
	// The loading screen stops updating once the HUD takes over, so the locked rules release it: the content fades
	// to the black root and is deleted, freeing its art, before the server ends setup.
	assert.equal(vm.runInContext("IsMatchStarting()", context), true, "locked rules start the match");
	data.locked = 0;
	assert.equal(vm.runInContext("IsMatchStarting()", context), false);
	gameState = 4;
	assert.equal(vm.runInContext("IsMatchStarting()", context), true, "a player joining after setup");
	data.locked = 1;
	const content = root.children.slice();
	vm.runInContext("ReleaseLoadingScreen(true); ReleaseLoadingScreen(true);", context);
	assert.ok(content.every(child => child.style.opacity === "0" && child.style.transitionProperty === "opacity"), "content fades out");
	assert.equal(releaseTimers.length, 1, "released once");
	releaseTimers.shift()();
	assert.equal(root.children.length, 0, "content deleted, freeing its art");
	listener("game_options", "match_rules");
	vm.runInContext("InitMatchRules();", context);
	assert.equal(root.children.length, 0, "settings are not rebuilt after release");
}
console.log("PASS: independent rule flags, settings hidden until everyone loads, Claim Host, host controls and atomic Apply payload; locked rules release the loading screen");

const source = fs.readFileSync(path.join(scripts, "top_bar/orbs_progress.js"), "utf8");
for (const epic of [false, true]) {
	const root = new Panel("TopBar_TeamsList");
	const team = new Panel("TopBar_Team_2", "Panel", root);
	const bars = {};
	for (const name of ["Common", "Rare"]) {
		const container = new Panel("Container" + name, "Panel", team);
		const parent = new Panel("Parent" + name, "Panel", container);
		const bar = new Panel("OrbsProgress_Bar_" + name, "ProgressBar", parent);
		const fill = new Panel("Fill" + name, "Panel", bar, ["ProgressBarLeft"]);
		new Panel("Scene" + name, "DOTAScenePanel", fill);
		new Panel("Icon" + name, "Image", container);
		bars[name] = bar;
	}
	const events = [];
	let listener;
	const dollar = () => root;
	dollar.Localize = key => key;
	dollar.DispatchEvent = (...args) => events.push(args);
	const context = vm.createContext({
		$: dollar,
		Game: { GetLocalPlayerInfo: () => ({ player_team_id: 2 }) },
		IsSpectating: () => false,
		IS_EPIC_ONLY_MAP: epic,
		CustomNetTables: {
			GetTableValue: () => null,
			SubscribeNetTableListener: (_name, handler) => { listener = handler; },
		},
		TriggerClassBySchedule: () => {},
	});
	vm.runInContext(source, context);
	listener("orbs", "current_progress_2", { team: 2, orb_type: 1, reward_rarity: epic ? 4 : 1, current: 250, max: 1000 });
	listener("orbs", "current_progress_2", { team: 2, orb_type: 2, reward_rarity: epic ? 4 : 2, current: 1, max: 2 });
	assert.equal(bars.Common.value, 0.25);
	assert.equal(bars.Common.GetParent().vars.value, 25);
	assert.equal(bars.Rare.value, 0.5);
	assert.equal(bars.Rare.GetParent().vars.current, 1);
	assert.equal(bars.Rare.GetParent().vars.max, 2);
	for (const name of ["Common", "Rare"]) {
		assert.equal(root.FindChildTraverse("Scene" + name).visible, !epic);
		if (epic) {
			assert.equal(root.FindChildTraverse("Fill" + name).style.backgroundColor, "rgb(234, 0, 255)");
			const icon = root.FindChildTraverse("Icon" + name);
			assert.ok(icon.image.endsWith("orb_epic.png"));
			icon.events.onmouseover();
			assert.equal(events.at(-1)[2], `#orbs_hint_${name.toLowerCase()}_epic_only`);
		} else {
			assert.equal(root.FindChildTraverse("Fill" + name).style.backgroundColor, undefined);
			assert.equal(root.FindChildTraverse("Icon" + name).image, undefined);
		}
	}
}
console.log("PASS: separate time/kill progress, epic presentation with Epic-Only orbs and normal presentation without");

// Exercise the real selection and reroll handlers with empty rendered choices.
const upgradesSource = fs.readFileSync(path.join(scripts, "upgrades_panel/upgrades_panel.js"), "utf8");
for (const epic of [false, true]) {
	const panels = new Map();
	const panel = id => {
		if (!panels.has(id)) panels.set(id, {
			classes: new Set(), events: {},
			BHasClass(name) { return this.classes.has(name); },
			SetHasClass(name, value) { value ? this.classes.add(name) : this.classes.delete(name); },
			SetPanelEvent(name, handler) { this.events[name] = handler; },
			FindChildTraverse: child => panel(child),
			SetDialogVariableInt() {}, RemoveAndDeleteChildren() {}, SwitchClass() {},
		});
		return panels.get(id);
	};
	const events = [], requests = [];
	const dollar = panel;
	dollar.GetContextPanel = () => panel("root");
	dollar.Localize = key => key;
	dollar.Schedule = () => {};
	dollar.DispatchEvent = (...args) => events.push(args);
	const context = vm.createContext({
		$: dollar, IS_EPIC_ONLY_MAP: epic, IS_FLAT_REROLL_MAP: epic,
		FindDotaHudElement: panel,
		Game: { EmitSound() {} },
		GameEvents: { SendToServerEnsured: name => requests.push(name) },
		GameUI: { Collection: { Show() {}, OpenSubPanel() {} } },
	});
	vm.runInContext(upgradesSource.slice(0, upgradesSource.lastIndexOf("(function () {")), context);
	for (const balance of [0, 1, 2, 3, 4, 30]) {
		vm.runInContext(`current_reroll_count = ${balance}; ShowUpgrades({upgrades: {
			selection_id: "balance_${balance}", upgrade_rarity: 4,
			reroll_price: ${epic ? 1 : 4}, choices: {}
		}});`, context);
		const allowed = balance >= (epic ? 1 : 4);
		panel("#RerollButton").events.onmouseover();
		assert.equal(events.at(-1)[2], allowed ? (epic ? "#reroll_tooltip_epic_only" : "#reroll_tooltip") : "#reroll_buy_in_shop_hint");
		const before = requests.length;
		vm.runInContext("Reroll(); Reroll();", context);
		assert.equal(requests.length - before, allowed ? 1 : 0, `epic=${epic}, balance=${balance}`);
	}
}
console.log("PASS: server-supplied reroll price, final 1–3 rerolls, empty balance, duplicate-click guard and normal-map pricing");

// Scoreboard Tip button: greyed out during the cooldown and once the per-game cap is used.
{
	const scoreboardSource = fs.readFileSync(path.join(scripts, "scoreboard/scoreboard.js"), "utf8");
	const hudClasses = new Set();
	let now = 0;
	const dollar = id => new Panel(id);
	dollar.GetContextPanel = () => new Panel("Scoreboard");
	dollar.Schedule = () => {};
	const context = vm.createContext({
		$: dollar,
		dotaHud: { SetHasClass: (name, value) => (value ? hudClasses.add(name) : hudClasses.delete(name)), BHasClass: name => hudClasses.has(name) },
		Game: { GetGameTime: () => now },
		GameUI: {},
	});
	vm.runInContext(scoreboardSource.slice(0, scoreboardSource.lastIndexOf("(function () {")), context);
	const tick = () => vm.runInContext("Object.values(interval_funcs).forEach((func) => func())", context);
	now = 110;
	context.UpdateTips({ max_this_game: 3, used_this_game: 1, cooldown: 100, cooldown_duration: 30 });
	assert.ok(hudClasses.has("TipsBlock"), "blocked during cooldown");
	now = 130;
	tick();
	assert.ok(!hudClasses.has("TipsBlock"), "unblocked after cooldown");
	now = 140;
	context.UpdateTips({ max_this_game: 3, used_this_game: 3, cooldown: 140, cooldown_duration: 30 });
	now = 1000;
	tick();
	assert.ok(hudClasses.has("TipsBlock"), "cap keeps the button blocked after the cooldown");
	context.UpdateTips({ max_this_game: 3, used_this_game: 0, cooldown: -10000, cooldown_duration: 30 });
	assert.ok(!hudClasses.has("TipsBlock"), "fresh player can tip");
	console.log("PASS scoreboard tips: cooldown, per-game cap survives cooldown, fresh state");
}

// End screen: tips-received badge sits before the MVP crown and only shows when tipped.
{
	const endScreenSource = fs.readFileSync(path.join(scripts, "end_screen/end_screen.js"), "utf8");
	const start = endScreenSource.indexOf("function CreateTipsBadge");
	const badgeSource = endScreenSource.slice(start, endScreenSource.indexOf("\nfunction ", start + 1));
	class EndPanel extends Panel {
		constructor(id, type, parent, props = {}) { super(id, type, parent); Object.assign(this, props); }
		SetDialogVariableInt(name, value) { this.vars[name] = value; }
		MoveChildBefore(child, before) {
			this.children.splice(this.children.indexOf(child), 1);
			this.children.splice(this.children.indexOf(before), 0, child);
		}
	}
	const dispatched = [];
	const dollar = {
		CreatePanel: (type, parent, id, props) => new EndPanel(id, type, parent, props),
		Localize: (key, panel) => `${key}:${panel.vars.tips_received}`,
		DispatchEvent: (...args) => dispatched.push(args),
	};
	const context = vm.createContext({ $: dollar });
	vm.runInContext(badgeSource, context);
	const basic = new EndPanel("BasicPlayerRoot_0");
	new EndPanel("EG_HeroIcon", "Image", basic);
	new EndPanel("EG_PSB_MVP_Icon", "Panel", basic);
	context.CreateTipsBadge(basic, { tips_received: 0 });
	context.CreateTipsBadge(basic, undefined);
	assert.equal(basic.FindChildTraverse("EG_PSB_Tips"), null, "no badge without tips");
	context.CreateTipsBadge(basic, { tips_received: 4 });
	const badge = basic.FindChildTraverse("EG_PSB_Tips");
	assert.deepEqual(basic.children.map(child => child.id), ["EG_HeroIcon", "EG_PSB_Tips", "EG_PSB_MVP_Icon"]);
	assert.equal(badge.children[1].text, "4");
	badge.events.onmouseover();
	assert.deepEqual(dispatched[0], ["DOTAShowTextTooltip", badge, "#end_screen_tips_received:4"]);
	console.log("PASS end screen tips: badge only when tipped, placed before MVP crown, localized tooltip");
}

// Chat: dark FFA team colours are lifted to a readable luminance, bright ones stay exact.
{
	const chatConst = fs.readFileSync(path.join(scripts, "custom_chat/custom_chat_const.js"), "utf8");
	const teams = { 2: "#3dd296;", 3: "#F3C909;", 8: "#815336;", 9: "#8c2af4;", 10: "#3455FF;" };
	const context = vm.createContext({
		$: { GetContextPanel: () => new Panel("Chat") },
		DOTATeam_t: { DOTA_TEAM_GOODGUYS: 2, DOTA_TEAM_BADGUYS: 3 },
		MAP_NAME: "ot3_necropolis_ffa",
		GameUI: { GetTeamColor: team => teams[team] },
		Players: { GetTeam: id => id },
	});
	vm.runInContext(chatConst, context);
	const luminance = hex => {
		const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.substr(i, 2), 16));
		return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
	};
	const readable = id => vm.runInContext(`C_CHAT_ACTIONS[C_CHAT_ENUM.PLAYER_COLOR_READABLE](${id})`, context);
	assert.equal(readable(2), "#3dd296", "bright teal unchanged");
	assert.equal(readable(3), "#F3C909", "bright yellow unchanged");
	for (const id of [8, 9, 10]) {
		const color = readable(id);
		assert.match(color, /^#[0-9a-f]{6}$/);
		assert.ok(Math.abs(luminance(color) - 0.45) < 0.01, `team ${id} lifted to the readable minimum`);
	}
	const [r, g, b] = [1, 3, 5].map(i => parseInt(readable(9).substr(i, 2), 16));
	assert.ok(b > r && r > g, "purple keeps its hue order");
	assert.equal(vm.runInContext("ReadableChatColor('')", context), "");
	console.log("PASS chat tip colours: dark team colours readable, bright colours exact, hue kept");
}

// Chat: native lines move to the custom area when they arrive, not from a per-frame loop.
{
	const chatSource = fs.readFileSync(path.join(scripts, "custom_chat/custom_chat.js"), "utf8");
	class ChatPanel extends Panel {
		GetChildCount() { return this.children.length; }
		DeleteAsync() { this.deleted = true; this.parent.children = this.parent.children.filter(child => child !== this); }
		AddClass(name) { this.classes.push(name); }
	}
	const wrapper = new ChatPanel("ChatLinesWrapper");
	const native = new ChatPanel("ChatLinesPanel", "Panel", wrapper);
	const stale = new ChatPanel("ChatLinesPanel", "Panel", wrapper);
	stale.custom_area = true;
	let scheduled = [];
	const handlers = [];
	const dollar = {
		CreatePanel: (type, parent, id) => new ChatPanel(id, type, parent),
		Schedule: (delay, fn) => scheduled.push({ delay, fn }),
		RegisterEventHandler: (name, panel, fn) => handlers.push({ name, panel, fn }),
	};
	const context = vm.createContext({
		$: dollar, MAX_CHAT_SIZE: 15,
		FindDotaHudElement: id => wrapper.FindChildTraverse(id),
		GameEvents: { SendEventClientSide: () => {} },
	});
	vm.runInContext(chatSource.slice(0, chatSource.lastIndexOf("(function () {")) + "InitCustomChatOverrideArea();", context);
	const custom = wrapper.children.find(child => child.custom_area && child !== stale);
	assert.ok(stale.deleted, "the previous load's custom area is removed");
	assert.deepEqual(handlers.map(h => [h.name, h.panel]), [["PanelLayoutInvalidated", native]]);
	assert.deepEqual(scheduled.map(s => s.delay), [5], "only the 5 s buffer trim keeps running");
	const invalidate = () => handlers[0].fn(native);
	scheduled = [];
	invalidate();
	assert.equal(scheduled.length, 0, "nothing to move: no redirect");
	const filler = new ChatPanel("", "Panel", native);
	const line = new ChatPanel("", "Label", native);
	for (let i = 0; i < 4; i++) invalidate();
	assert.deepEqual(scheduled.map(s => s.delay), [0], "one redirect per arrival, however many events the line raises");
	scheduled.shift().fn();
	assert.deepEqual(native.children, [], "native area emptied");
	assert.ok(filler.deleted, "native spacer panels are dropped");
	assert.deepEqual(custom.children, [line], "the line moved to the custom area");
	assert.deepEqual(scheduled.map(s => s.delay), [7], "only the line's expiry is scheduled");
	scheduled.shift().fn();
	assert.ok(line.classes.includes("Expired"));
	new ChatPanel("", "Label", native);
	invalidate();
	assert.deepEqual(scheduled.map(s => s.delay), [0], "the next line schedules a new redirect");
	console.log("PASS chat redirect: native lines move when they arrive, once per arrival, no per-frame loop");
}

// Fountain range indicator: range checks every 0.1 s, controls sent only on change, per-frame target updates only
// inside a ring.
{
	const fountainSource = fs.readFileSync(path.join(scripts, "scripts/fountain_range.js"), "utf8");
	const units = { 1: { team: 3, pos: [1000, 0, 400] }, 2: { team: 4, pos: [-1000, 0, 400] }, 3: { team: 2, pos: [0, 1000, 400] },
		10: { pos: [0, -3000, 400] }, 11: { pos: [0, -3000, 400] } };
	let scheduled = [];
	let calls = [];
	let next_particle = 100;
	let portrait = 10;
	let alt = false;
	const context = vm.createContext({
		$: { Schedule: (delay, fn) => scheduled.push({ delay, fn }) },
		Game: {
			GameStateIsBefore: () => false,
			GetLocalPlayerInfo: () => ({ player_id: 0, player_team_id: 2 }),
		},
		DOTA_GameState: { DOTA_GAMERULES_STATE_PRE_GAME: 8 },
		Entities: {
			GetAllEntitiesByClassname: () => [1, 2, 3],
			GetTeamNumber: id => units[id].team,
			GetAbsOrigin: id => units[id].pos.slice(),
			GetAttackRange: () => 600,
		},
		Players: { GetLocalPlayerPortraitUnit: () => portrait },
		GameUI: { IsAltDown: () => alt, CustomUIConfig: () => ({ team_colors_rgb: {} }) },
		Vector: {
			sub: (a, b) => a.map((v, i) => v - b[i]),
			len: v => Math.hypot(v[0], v[1], v[2]),
		},
		ParticleAttachment_t: { PATTACH_WORLDORIGIN: 0, PATTACH_ABSORIGIN_FOLLOW: 1 },
		Particles: {
			CreateParticle: () => { calls.push(["create"]); return next_particle++; },
			SetParticleControl: (p, cp, value) => calls.push(["cp", p, cp, value]),
			SetParticleControlEnt: (p, cp, unit, attach) => calls.push(["ent", p, cp, unit, attach]),
			SetParticleAlwaysSimulate: p => calls.push(["always", p]),
		},
	});
	vm.runInContext(fountainSource, context);
	assert.equal(calls.filter(c => c[0] === "create").length, 2, "enemy fountains only");
	assert.ok(!calls.some(c => c[0] === "always"), "the indicators are not simulated off-screen");
	const [a, b] = [100, 101];
	const plain = value => JSON.parse(JSON.stringify(value)); // arrays made in the context fail deepStrictEqual
	const initial = Object.fromEntries(plain(calls).filter(c => c[0] === "cp" && c[1] === a).map(c => [c[2], c[3]]));
	assert.deepEqual(initial[7], [1000, 0, 117], "target starts on the fountain, at the indicator height");
	assert.deepEqual(initial[13], [0, 0, 2], "danger level set from the start");
	// runs the pending update; returns the controls it sent and the delay of the next one
	const tick = () => {
		calls = [];
		assert.equal(scheduled.length, 1, "one update loop");
		const loop = scheduled.pop();
		loop.fn();
		return [plain(calls), scheduled[0].delay];
	};
	assert.deepEqual(scheduled.map(s => s.delay), [0.1]);
	assert.deepEqual(tick(), [[], 0.1], "far from every fountain: no control updates, checks every 0.1 s");
	assert.deepEqual(tick(), [[], 0.1]);
	units[10].pos = [1000, 900, 400]; // 943 from fountain a: inside range + 450, outside attack range
	assert.deepEqual(tick(), [[["cp", a, 6, [1, 0, 0]], ["cp", a, 7, [1000, 900, 400]]], 0], "ring shown, target on the unit");
	units[10].pos = [1000, 850, 400];
	assert.deepEqual(tick(), [[["cp", a, 7, [1000, 850, 400]]], 0], "inside a ring the target follows the unit every frame");
	assert.deepEqual(tick(), [[], 0], "a unit standing still sends nothing");
	units[10].pos = [1000, 500, 400];
	assert.deepEqual(tick(), [[["cp", a, 7, [1000, 500, 400]], ["cp", a, 13, [1, 1, 2]]], 0], "targeted");
	portrait = 11;
	units[11].pos = [1000, 300, 400];
	assert.deepEqual(tick(), [[["cp", a, 7, [1000, 300, 400]]], 0], "a newly selected unit takes the target");
	alt = true;
	assert.deepEqual(tick(), [[["cp", a, 7, [1000, 0, 117]], ["cp", b, 6, [1, 0, 0]], ["cp", b, 13, [1, 1, 2]]], 0.1],
		"Alt shows every ring with the target on its fountain");
	alt = false;
	units[11].pos = [0, -3000, 400];
	assert.deepEqual(tick(), [[["cp", a, 6, [0, 0, 0]], ["cp", a, 13, [0, 0, 2]], ["cp", b, 6, [0, 0, 0]], ["cp", b, 13, [0, 0, 2]]], 0.1],
		"leaving hides the rings; the target already rests on the fountain");
	portrait = -1;
	assert.deepEqual(tick(), [[], 0.1], "no portrait unit: nothing to update");
	console.log("PASS fountain range: 0.1 s checks, controls only on change, per-frame target only inside a ring, Alt, no forced off-screen simulation");
}

// Top bar: the Tip buttons follow Alt from a 0.1 s check, not a per-frame loop. The collection tracks no keys: its
// key classes only lit quantity hints in purchase dialogs, which the free collection never opens.
{
	const topBarSource = fs.readFileSync(path.join(scripts, "top_bar/top_bar.js"), "utf8");
	const [altSource] = topBarSource.match(/(let alt_pressed.*\n)?function CheckAltPress\(\) \{[\s\S]*?\n\}\n/);
	let alt = false;
	let scheduled = [];
	const classes = [];
	const context = vm.createContext({
		$: { Schedule: (delay, fn) => scheduled.push({ delay, fn }) },
		GameUI: { IsAltDown: () => alt },
		HUD: { CONTEXT: { SetHasClass: (name, value) => classes.push([name, value]) } },
	});
	vm.runInContext(altSource + "CheckAltPress();", context);
	const tick = () => {
		assert.deepEqual(scheduled.map(s => s.delay), [0.1], "one check every 0.1 s");
		scheduled.pop().fn();
	};
	assert.deepEqual(classes, [], "Alt up: no class change");
	alt = true;
	tick();
	tick();
	assert.deepEqual(classes, [["BAltPressed", true]], "set once when Alt goes down");
	alt = false;
	tick();
	assert.deepEqual(classes, [["BAltPressed", true], ["BAltPressed", false]], "cleared once when Alt goes up");
	const collectionSource = fs.readFileSync(path.join(scripts, "collection/collection.js"), "utf8");
	assert.doesNotMatch(collectionSource, /GameUI\.Is(Shift|Alt|Control)Down/, "the collection tracks no modifier keys");
	console.log("PASS top bar Alt: 0.1 s check, class only on change; the collection tracks no keys");
}

// Tip toast: player strips, bot name fallback, highlight for the tipped player, coin pop, at most three at once.
{
	const toastsSource = fs.readFileSync(path.join(scripts, "toasts/toasts.js"), "utf8");
	class ToastPanel extends Panel {
		constructor(id, type, parent, props = {}) { super(id, type, parent); Object.assign(this, props); this.valid = true; }
		SetDialogVariableInt(name, value) { this.vars[name] = value; }
		AddClass(name) { this.classes.push(name); }
		SetHasClass(name, value) { if (value) this.classes.push(name); else this.classes = this.classes.filter(c => c !== name); }
		GetChild(index) { return this.children[index]; }
		FindChild(id) { return this.children.find(child => child.id === id) || null; }
		IsValid() { return this.valid; }
		DeleteAsync() { this.valid = false; this.parent.children = this.parent.children.filter(child => child !== this); }
		BLoadLayoutSnippet(name) {
			this.snippet = name;
			const player = () => { const c = new ToastPanel("", "Panel", this, {}); new ToastPanel("", "Image", c); new ToastPanel("", "DOTAUserName", c); return c; };
			player();
			const value = new ToastPanel("", "Panel", this);
			value.classes.push("TipValueContainer");
			new ToastPanel("", "Label", value);
			new ToastPanel("", "Panel", value).classes.push("TipCurrencyContainer");
			player();
		}
	}
	const root = new ToastPanel("toast_notifications");
	let scheduled = [];
	const sounds = [];
	const dollar = {
		GetContextPanel: () => root,
		CreatePanel: (type, parent, id, props) => new ToastPanel(id, type, parent, props),
		Localize: key => key,
		Schedule: (delay, fn) => { scheduled.push({ delay, fn }); return scheduled.length; },
		CancelScheduled: () => undefined,
	};
	const infos = {
		0: { player_name: "Me", player_steamid: "76561190000000000", player_selected_hero: "npc_dota_hero_sven" },
		1: { player_name: "Tip Bot 1", player_steamid: "0", player_selected_hero: "npc_dota_hero_pudge" },
		2: { player_name: "Tip Bot 2", player_steamid: "0", player_selected_hero: "npc_dota_hero_techies" },
	};
	const context = vm.createContext({
		$: dollar,
		Game: { EmitSound: name => sounds.push(name), GetPlayerInfo: id => infos[id], GetLocalPlayerID: () => 0 },
		GameUI: { GetTeamColor: team => ({ 2: "#3dd296;", 8: "#815336;" })[team] },
		Players: { GetTeam: id => (id === 0 ? 8 : 2) },
		GetPortraitImage: (id, hero) => `portrait:${hero}`,
	});
	vm.runInContext(toastsSource.slice(0, toastsSource.lastIndexOf("(() => {")), context);
	const tip = (source, target) => context.NewToast({ toast_type: "player_tip", data: { source_player_id: source, target_player_id: target, currency: 50 } });

	tip(1, 0);
	const first = root.children[0];
	assert.equal(first.snippet, "player_tip");
	assert.equal(first.vars.value, 50);
	const [source, value, target] = first.children;
	assert.equal(source.children[0].image, "portrait:npc_dota_hero_pudge");
	assert.equal(source.children[0].style.borderBottom, "3px solid #3dd296");
	assert.equal(target.children[0].style.borderBottom, "3px solid #815336");
	assert.equal(source.children[1].style.visibility, "collapse", "empty DOTAUserName hidden for bots");
	assert.equal(source.children[2].text, "Tip Bot 1", "bot name shown as a label");
	assert.equal(source.children[2].class, "TipPlayerName", "bot name styled by toasts.css");
	assert.equal(target.children[1].steamid, "76561190000000000", "real players keep DOTAUserName");
	assert.equal(target.children.length, 2);
	assert.ok(first.classes.includes("TipToLocalPlayer"), "tipped local player gets the gold frame class");
	assert.deepEqual(sounds, ["General.Coins", "Loot_Drop_Sfx_Minor"]);
	assert.deepEqual(value.children[1].style, {}, "coin pop is a toasts.css animation");
	assert.ok(scheduled.some(s => s.delay === 6), "tip toast lasts 6 seconds");

	sounds.length = 0;
	tip(0, 2);
	assert.ok(!root.children[1].classes.includes("TipToLocalPlayer"), "no frame when someone else is tipped");
	assert.deepEqual(sounds, ["General.Coins"]);
	tip(2, 1);
	tip(1, 2);
	assert.equal(root.children.length, 3, "at most three tip toasts on screen");
	assert.ok(!first.valid, "oldest tip toast removed first");

	// each expiry removes its own toast (it used to pass the newest id instead)
	const expiries = scheduled.filter(s => s.delay === 6);
	const [second, third, fourth] = root.children;
	expiries[1].fn();
	assert.ok(!second.valid && third.valid && fourth.valid);
	assert.equal(vm.runInContext("tip_toasts.length", context), 2, "expired toast leaves the cap list");
	tip(0, 1);
	assert.ok(third.valid && fourth.valid, "a new tip under the cap removes nothing");
	console.log("PASS tip toast: colour strips, bot names, tipped-player class and chime, three-toast cap");
}

{
	// Hidden layouts park their art: Panorama loads the images of every panel that exists, even hidden ones.
	const park = utils.slice(utils.indexOf("function ParkImages"), utils.indexOf("const FindDotaHudElement"));
	const context = vm.createContext({});
	vm.runInContext(park, context);
	const root = new Panel("Root");
	const frame = new Panel("Frame", "Panel", root);
	const glow = new Panel("Glow", "Image", frame);
	const restore = context.ParkImages(root, [[glow, "s2r://panorama/images/custom_game/collection/glow_png.vtex"]]);
	assert.deepEqual([root, frame, glow].map(p => p.style.backgroundImage), ["none", "none", "none"], "stylesheet art overridden");
	assert.equal(glow.image, "", "Image source emptied");
	restore();
	assert.deepEqual([root, frame, glow].map(p => p.cleared), [["background-image"], ["background-image"], ["background-image"]],
		"the CSS property name clears the override; camelCase leaves it in place");
	assert.equal(glow.image, "s2r://panorama/images/custom_game/collection/glow_png.vtex");
	console.log("PASS parked art: stylesheet images and Image sources held back until restored");
}
{
	const textures = require("./panorama_textures");
	const image = { width: 3, height: 2, rgba: Buffer.from([255, 0, 0, 255, 0, 255, 0, 128, 0, 0, 255, 0, 10, 20, 30, 255, 40, 50, 60, 250, 70, 80, 90, 255]) };
	assert.deepEqual(textures.decodePng(textures.encodePng(image, true)).rgba, image.rgba, "RGBA PNG round trip");
	const opaque = textures.decodePng(textures.encodePng(image, false));
	assert.ok(opaque.rgba.every((v, i) => (i % 4 === 3 ? v === 255 : v === image.rgba[i])), "dropping alpha keeps the colours");
	assert.equal(textures.decodePng(textures.encodePng(image, true), 200), null, "alpha scan stops at the first see-through pixel");
	// A transparent pixel adds no colour to the average (no dark fringes) and alpha averages linearly.
	const half = textures.resize({ width: 2, height: 1, rgba: Buffer.from([255, 0, 0, 255, 0, 0, 0, 0]) }, 1, 1);
	assert.deepEqual([...half.rgba], [255, 0, 0, 128]);
	// Colour averages in linear light: black and white give sRGB 188, not 128.
	assert.equal(textures.resize({ width: 2, height: 1, rgba: Buffer.from([0, 0, 0, 255, 255, 255, 255, 255]) }, 1, 1).rgba[0], 188);
	assert.throws(() => textures.resize(image, 4, 4), /downscaled/);
	// DXT1 block: red and blue endpoints, indices 0..3 along the first row.
	const block = Buffer.from([0x00, 0xf8, 0x1f, 0x00, 0b11100100, 0, 0, 0]);
	const dxt = textures.decodeDxt(block, 4, 4, textures.FORMAT.DXT1);
	assert.deepEqual([...dxt.subarray(0, 16)], [255, 0, 0, 255, 0, 0, 255, 255, 170, 0, 85, 255, 85, 0, 170, 255]);
	console.log("PASS textures: PNG round trip, alpha scan, alpha-weighted linear downscale, DXT1 decode");
}
