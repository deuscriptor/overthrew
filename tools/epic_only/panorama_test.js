// Behavioral checks for progress channels and the variant's shared map identity.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { sources } = require("./panorama_resources");
const scripts = path.join(sources, "panorama/layout/custom_game");

const utils = fs.readFileSync(path.join(scripts, "scripts/utils.js"), "utf8");
const declarations = utils.slice(0, utils.indexOf("Object.defineProperties"));
for (const map of ["ot3_necropolis_ffa", "ot3_necropolis_ffa_epic_only", "ot3_necropolis_ffa_epic_only_single_draft", "ot3_gardens_duo", "ot3_demo"]) {
	const context = vm.createContext({ Game: {
		GetLocalPlayerID: () => 0,
		GetLocalPlayerInfo: () => ({ player_steamid: "0" }),
		GetMapInfo: () => ({ map_display_name: map }),
	} });
	vm.runInContext(declarations, context);
	const epic = map === "ot3_necropolis_ffa_epic_only" || map === "ot3_necropolis_ffa_epic_only_single_draft";
	assert.equal(vm.runInContext("IS_SINGLE_DRAFT_MAP", context), map === "ot3_necropolis_ffa_epic_only_single_draft");
	assert.equal(vm.runInContext("MAP_NAME", context), map);
	assert.equal(vm.runInContext("IS_EPIC_ONLY_MAP", context), epic);
	assert.equal(vm.runInContext("MAP_BASE_NAME", context), epic ? "ot3_necropolis_ffa" : map);
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
}

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
		$: dollar, IS_EPIC_ONLY_MAP: epic,
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
