// Behavioral checks for progress channels and the variant's shared map identity.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { sources } = require("./panorama_resources");
const scripts = path.join(sources, "panorama/layout/custom_game");

const utils = fs.readFileSync(path.join(scripts, "scripts/utils.js"), "utf8");
const declarations = utils.slice(0, utils.indexOf("Object.defineProperties"));
for (const map of ["ot3_necropolis_ffa", "ot3_ffa_epic", "ot3_ffa_epic_draft", "ot3_ffa_draft", "ot3_gardens_duo", "ot3_demo"]) {
	const context = vm.createContext({ Game: {
		GetLocalPlayerID: () => 0,
		GetLocalPlayerInfo: () => ({ player_steamid: "0" }),
		GetMapInfo: () => ({ map_display_name: map }),
	} });
	vm.runInContext(declarations, context);
	const epic = map === "ot3_ffa_epic" || map === "ot3_ffa_epic_draft";
	const singleDraft = map === "ot3_ffa_epic_draft" || map === "ot3_ffa_draft";
	assert.equal(vm.runInContext("IS_SINGLE_DRAFT_MAP", context), singleDraft);
	assert.equal(vm.runInContext("MAP_NAME", context), map);
	assert.equal(vm.runInContext("IS_EPIC_ONLY_MAP", context), epic);
	assert.equal(vm.runInContext("MAP_BASE_NAME", context), epic || singleDraft ? "ot3_necropolis_ffa" : map);
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
{
	const root = new Panel("Loading");
	let data;
	let listener;
	const requests = [];
	const waitingFrames = [];
	const pagesRequested = [];
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
		$: {CreatePanel: (type, parent, id) => new Panel(id, type, parent), Localize: value => value,
			Schedule: (delay, callback) => { if (delay === 0.6) waitingFrames.push(callback); }},
		Game: {GetLocalPlayerID: () => 0},
		GameEvents: {SendToServerEnsured: (name, args) => requests.push({name, args})},
		CustomNetTables: {GetTableValue: () => data, SubscribeNetTableListener: (table, fn) => { listener = fn; }},
	});
	vm.runInContext(initRules + "InitMatchRules();", context);
	assert.equal(root.children.length, 1, "wait for rules before constructing controls");
	const logo = new Panel("Logo", "Image", root, ["LS_Tips_Logo"]);
	const discord = new Panel("Discord", "Button", root, ["LS_DiscordButton"]);
	data = {host_id: 0, locked: 0, single_draft: 1, epic_orbs: 0, turbo: 1, longer_wards: 1};
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
	const tabs = ["core", "other", "items"].map(id => root.FindChildTraverse("MatchRulesTab_" + id));
	assert.equal(tabs[1].caption.style.color, "#dfc58b", "unvisited tab glows");
	tabs[1].events.onactivate();
	assert.deepEqual(pagesRequested, [1], "tabs open their settings page");
	const knob = name => root.FindChildTraverse("Rule_" + name).children[2].children[0].children[0];
	assert.match(knob("single_draft").style.transform, /18px/, "enabled option shows switch on");
	assert.match(knob("epic_orbs").style.transform, /\(0px/, "disabled option shows switch off");
	assert.equal(root.FindChildTraverse("KillGoalTime").text, "#host_rules_time_limit 33:20");
	vm.runInContext("matchRulesPageChanged(1)", context);
	assert.equal(tabs[1].caption.style.color, "#f3dfae", "active tab highlighted");
	assert.equal(tabs[0].caption.style.color, "#7f95a6", "visited tab no longer glows");
	assert.equal(tabs[2].caption.style.color, "#dfc58b");
	assert.equal(root.FindChildTraverse("MatchRules_core").visible, false);
	assert.equal(root.FindChildTraverse("MatchRules_other").visible, true);
	assert.equal(arrowLeft.enabled, true, "both arrows available on a middle page");
	assert.equal(arrowLeft.style.border, "1px solid #dfc58b", "untouched previous arrow glows once available");
	assert.deepEqual(bullets().map(b => b.style.width), ["8px", "22px", "8px"]);
	assert.equal(bullets()[0].style.backgroundColor, "#7f95a6", "visited page bullet stops glowing");
	assert.equal(bullets()[2].style.backgroundColor, "#dfc58b");
	vm.runInContext("matchRulesPageChanged(2)", context);
	assert.equal(root.FindChildTraverse("MatchRules_items").visible, true);
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
	assert.equal(waiting.text, "#host_rules_waiting.");
	for (const dots of ["..", "...", "."]) {
		waitingFrames.shift()();
		assert.equal(waiting.text, "#host_rules_waiting" + dots);
	}
	assert.equal(root.FindChildTraverse("Rule_single_draft").enabled, false);
	assert.equal(goal.enabled, false);
	data.host_id = 0;
	data.locked = 1;
	listener("game_options", "match_rules");
	assert.equal(start.enabled, false, "locked settings cannot be edited");
	assert.equal(waiting.visible, false, "no waiting message after start");
}
console.log("PASS: independent rule flags, delayed settings arrival, host controls and atomic Apply payload");

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
console.log("PASS: real map identity, FFA inheritance, separate time/kill progress, epic presentation and original-map behavior");

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
		MAP_BASE_NAME: "ot3_necropolis_ffa",
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
