const ORBS_TYPE_COMMON = 1;
const ORBS_TYPE_RARE = 2;
const ORBS_TYPE_EPIC = 4;

const TOPBAR = {
	TEAMS_ROOT: $("#TopBar_TeamsList"),
};

const BARS = {
	[ORBS_TYPE_COMMON]: "OrbsProgress_Bar_Common",
	[ORBS_TYPE_RARE]: "OrbsProgress_Bar_Rare",
};

function ApplyEpicRewardPresentation(bar, orb_type) {
	if (bar.epic_reward_presentation) return;
	bar.epic_reward_presentation = true;
	const container = bar.GetParent().GetParent();
	const tooltip = orb_type === ORBS_TYPE_COMMON ? "#orbs_hint_common_epic_only" : "#orbs_hint_rare_epic_only";
	const showTooltip = (panel) => {
		panel.SetPanelEvent("onmouseover", () => $.DispatchEvent("DOTAShowTextTooltip", panel, $.Localize(tooltip)));
		panel.SetPanelEvent("onmouseout", () => $.DispatchEvent("DOTAHideTextTooltip", panel));
	};
	showTooltip(container);
	showTooltip(bar);
	for (const fill of bar.FindChildrenWithClassTraverse("ProgressBarLeft")) {
		fill.style.backgroundColor = "rgb(234, 0, 255)";
	}
	const updateChildren = (panel) => {
		for (const child of panel.Children()) {
			// The old scene contains the common/rare colored fire. Use the epic fill here.
			if (child.paneltype === "DOTAScenePanel") child.visible = false;
			// Replace the information icon and its old reward tooltip, if present.
			if (child.paneltype === "Image") {
				child.SetImage("file://{images}/custom_game/upgrades/orb_epic.png");
				showTooltip(child);
			}
			updateChildren(child);
		}
	};
	updateChildren(container);
}

function ListenToOrbNetTable(_tableName, _key, data) {
	if (IsSpectating()) {
		for (var teamId of Game.GetAllTeamIDs()) {
			UpdateOrbsProgress({}, teamId);
		}
	} else {
		UpdateOrbsProgress(data, data.team);
	}
}
let schedule_orb_progression_animation_common;
let schedule_orb_progression_animation_rare;
function UpdateOrbsProgress(data, team) {
	if (!team && Game.GetLocalPlayerInfo() && Game.GetLocalPlayerInfo().player_team_id)
		team = Game.GetLocalPlayerInfo().player_team_id;
	if (!data || typeof data != "object" || Object.keys(data).length === 0)
		data = CustomNetTables.GetTableValue("orbs", "current_progress_" + team);
	if (!data) return;
	const orb_type = data.orb_type;
	if (!orb_type) return;
	if (!TOPBAR) return;
	if (!TOPBAR.TEAMS_ROOT) return;
	if (!TOPBAR.TEAMS_ROOT.FindChildTraverse("TopBar_Team_" + team)) return;
	const bar = TOPBAR.TEAMS_ROOT.FindChildTraverse("TopBar_Team_" + team).FindChildTraverse(BARS[orb_type]);
	if (!bar) return;
	// orb_type is the progress source, so time and kill progress stay separate.
	const reward_rarity = data.reward_rarity || (IS_EPIC_ONLY_MAP ? ORBS_TYPE_EPIC : orb_type);
	if (reward_rarity === ORBS_TYPE_EPIC) ApplyEpicRewardPresentation(bar, orb_type);

	const current = data.current || 0;
	const max = data.max || 1000;

	const pct_value = current / max;
	bar.value = pct_value;
	const bar_parent = bar.GetParent();
	if (orb_type == ORBS_TYPE_COMMON) {
		if (pct_value > 0.99)
			TriggerClassBySchedule(schedule_orb_progression_animation_common, "OrbProgressionGoalShake_Common");

		bar_parent.SetDialogVariable("value", Math.round(Math.abs(bar.value) * 100));
	} else if (orb_type == ORBS_TYPE_RARE) {
		if (current == 0)
			TriggerClassBySchedule(schedule_orb_progression_animation_rare, "OrbProgressionGoalShake_Rare");

		bar_parent.SetDialogVariable("current", current);
		bar_parent.SetDialogVariable("max", max);
	}
}
function ToggleBarsVisibility() {
	$.GetContextPanel().ToggleClass("HideBars");
}
function InitUI(iTeamNumber) {
	UpdateOrbsProgress(
		{
			orb_type: ORBS_TYPE_COMMON,
			current: 0,
		},
		iTeamNumber,
	);

	UpdateOrbsProgress(
		{
			orb_type: ORBS_TYPE_RARE,
			current: 0,
			max: 2,
		},
		iTeamNumber,
	);
}
(function () {
	if (IsSpectating()) {
		for (var teamId of Game.GetAllTeamIDs()) {
			InitUI(teamId);
		}
	} else {
		InitUI(Game.GetLocalPlayerInfo().player_team_id);
	}

	CustomNetTables.SubscribeNetTableListener("orbs", ListenToOrbNetTable);
})();
