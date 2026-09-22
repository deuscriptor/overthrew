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
	const context = vm.createContext({LOADING_HUD: {CONTEXT: root, MOVIE_CONTAINER: root}, hints: [], InitHints: () => {},
		$: {CreatePanel: (type, parent, id) => new Panel(id, type, parent), Localize: value => value},
		Game: {GetLocalPlayerID: () => 0},
		GameEvents: {SendToServerEnsured: (name, args) => requests.push({name, args})},
		CustomNetTables: {GetTableValue: () => data, SubscribeNetTableListener: (table, fn) => { listener = fn; }},
	});
	vm.runInContext(initRules + "InitMatchRules();", context);
	assert.equal(root.children.length, 0, "wait for rules before constructing controls");
	const logo = new Panel("Logo", "Image", root, ["LS_Tips_Logo"]);
	const discord = new Panel("Discord", "Button", root, ["LS_DiscordButton"]);
	data = {host_id: 0, locked: 0, single_draft: 1, epic_orbs: 0, turbo: 1};
	vm.runInContext("InitMatchRules(); InitMatchRules();", context);
	assert.equal(root.children.length, 3, "initialize only once");
	assert.equal(logo.visible, false);
	assert.equal(discord.visible, false);
	assert.equal(root.FindChildTraverse("Rule_flat_rerolls"), null);
	assert.deepEqual(root.FindChildTraverse("MatchRules_core").children.filter(p => p.paneltype === "ToggleButton").map(p => p.id), ["Rule_epic_orbs", "Rule_turbo", "Rule_single_draft"]);
	assert.equal(vm.runInContext("hints.length", context), 1, "only settings page remains");
	assert.equal(vm.runInContext("hints[0][0]", context), "settings");
	const start = root.FindChildTraverse("ApplyMatchRules");
	assert.equal(start.enabled, true);
	start.events.onactivate();
	assert.deepEqual(JSON.parse(JSON.stringify(requests[0])), {name:"HostOptions:apply_rules", args:{single_draft:1,epic_orbs:0,turbo:1}});
	data.host_id = 1;
	listener("game_options", "match_rules");
	assert.equal(start.visible, false, "non-host cannot start");
	assert.equal(root.FindChildTraverse("Rule_single_draft").enabled, false);
	data.host_id = 0;
	data.locked = 1;
	listener("game_options", "match_rules");
	assert.equal(start.enabled, false, "locked settings cannot be edited");
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
