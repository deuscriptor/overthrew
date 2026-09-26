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
	Children() { return this.children; }
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
	}, DOTA_GameState: {DOTA_GAMERULES_STATE_PRE_GAME: 8}, CustomNetTables: {
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
	data.requests = {5: {id: 5, from: 1, to: 0}};
	listener("game_options", "hero_swaps", data);
	const swapBody = container.FindChildTraverse("HeroSwapsBody");
	const swapToggle = container.FindChildTraverse("HeroSwapsToggle");
	const swapBadge = container.FindChildTraverse("HeroSwapRequestBadge");
	assert.equal(swapBody.visible, false, "Incoming request must not open the menu");
	assert.equal(swapBadge.visible, true);
	assert.equal(swapBadge.text, "1");
	assert.ok(!swapBody.children.some(panel => panel.text === "#hero_swaps_hint"), "Explanatory description removed");
	swapToggle.events.onactivate();
	assert.equal(swapBody.visible, true, "Player can open request controls");
	swapToggle.events.onactivate();
	events["HeroSwaps:status"]({status: "accepted"});
	assert.equal(swapBody.visible, false, "Status updates must not force the menu open");
	container.FindChildTraverse("AcceptSwap_1").events.onactivate();
	assert.equal(sent[1].name, "HeroSwaps:accept");
	assert.equal(sent[1].payload.request_id, 5);
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
	const context = vm.createContext({LOADING_HUD: {CONTEXT: root, MOVIE_CONTAINER: root}, hints: [], InitHints: () => {},
		SetHint: index => pagesRequested.push(index),
		$: {CreatePanel: (type, parent, id) => new Panel(id, type, parent), Localize: value => value,
			Schedule: (delay, callback) => { if (delay === 0.6) waitingFrames.push(callback); }},
		Game: {GetLocalPlayerID: () => 0},
		GameEvents: {SendToServerEnsured: (name, args) => requests.push({name, args})},
		CustomNetTables: {GetTableValue: () => data, SubscribeNetTableListener: (table, fn) => { listener = fn; }},
	});
	vm.runInContext(initRules + "InitMatchRules();", context);
	assert.equal(root.children.length, 0, "wait for rules before constructing controls");
	const logo = new Panel("Logo", "Image", root, ["LS_Tips_Logo"]);
	const discord = new Panel("Discord", "Button", root, ["LS_DiscordButton"]);
	data = {host_id: 0, locked: 0, single_draft: 1, epic_orbs: 0, turbo: 1, longer_wards: 1};
	vm.runInContext("InitMatchRules(); InitMatchRules();", context);
	assert.equal(root.children.length, 3, "initialize only once");
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
	vm.runInContext("matchRulesPageChanged(2)", context);
	assert.equal(root.FindChildTraverse("MatchRules_items").visible, true);
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
