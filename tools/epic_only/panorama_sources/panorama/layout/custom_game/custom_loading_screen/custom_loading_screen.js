const LOADING_HUD = {
	CONTEXT: $.GetContextPanel(),
	PLAYERS_LIST: $("#LoadingPlayers_List"),
	BULLETS_ROOT: $("#LS_Tips_Bullets"),
	HINT_MOVIE: $("#LS_VideoHint"),
	MOVIE_CONTAINER: $("#LS_Tips_WebContainer"),
	LS_HINT_TIMER_HEADER: $("#LS_StartTimer_Header"),
	LS_HINT_TIMER_TEXT: $("#LS_StartTimer_Timer"),
	CHAT: FindDotaHudElementInLS("LoadingScreenChat"),
	OPTIONS_CONTAINER: $("#HostOptions"),
	BANNER_TOURNAMENT_FFA: $("#Banner_Tournament_FFA"),
};

const LOADING_STATES_DATA = {
	[DOTAConnectionState_t.DOTA_CONNECTION_STATE_CONNECTED]: "BState_Loaded",
	[DOTAConnectionState_t.DOTA_CONNECTION_STATE_ABANDONED]: "BState_Failed",
	[DOTAConnectionState_t.DOTA_CONNECTION_STATE_FAILED]: "BState_Failed",
};

const hints = [
	// ["tournament", 25],
	["orbs", 12],
	["progress", 7],
	["epic", 8],
	["collection", 11],
];
const additional_hints_config = {
	settings: { b_image: true, b_hide_desc: true, b_ignore_hover: true },
	tournament: {
		b_image: true,
		b_hide_desc: true,
		b_ignore_hover: true,
		click_callback: () => {
			$.DispatchEvent("ExternalBrowserGoToURL", "https://discord.gg/hZyjvskZvM");
		},
	},
};
let current_hint;
let auto_hint_schedule;
let players = {};

let players_in_lobby = 0;
let players_loaded = {};

let host_options_enabled = false;

function InitHints() {
	LOADING_HUD.BULLETS_ROOT.RemoveAndDeleteChildren();
	hints.forEach((hint_name, idx) => {
		const bullet = $.CreatePanel("Panel", LOADING_HUD.BULLETS_ROOT, `Bullet_${idx}`);
		bullet.BLoadLayoutSnippet("LS_Bullet");
	});
	current_hint = 0;
	SetHint(current_hint);
}

function CheckCurrentHint() {
	LOADING_HUD.CONTEXT.SetHasClass("BFirstHint", current_hint == 0);
	LOADING_HUD.CONTEXT.SetHasClass("BLastHint", current_hint == hints.length - 1);
}

function SetHint(idx) {
	if (auto_hint_schedule) auto_hint_schedule = $.CancelScheduled(auto_hint_schedule);
	idx = Math.clamp(idx, 0, hints.length - 1);

	const hint_name = hints[idx][0];
	const settings = LOADING_HUD.CONTEXT.FindChildTraverse("MatchRulesPanel");
	if (settings) settings.visible = hint_name === "settings";
	const hint_config = additional_hints_config[hint_name];
	const b_image = !!hint_config && hint_config.b_image;
	const b_hide_desc = !!hint_config && hint_config.b_hide_desc;
	const b_ignore_hover = !!hint_config && hint_config.b_ignore_hover;
	const click_callback = !!hint_config && hint_config.click_callback;

	LOADING_HUD.MOVIE_CONTAINER.SetHasClass("BImage", b_image);
	LOADING_HUD.MOVIE_CONTAINER.SetHasClass("BHideDescription", b_hide_desc);
	LOADING_HUD.MOVIE_CONTAINER.SetHasClass("BIgnoreHover", b_ignore_hover);
	LOADING_HUD.MOVIE_CONTAINER.ClearPanelEvent("onactivate");
	LOADING_HUD.MOVIE_CONTAINER.SetHasClass("BClickable", click_callback != undefined);
	if (click_callback) LOADING_HUD.MOVIE_CONTAINER.SetPanelEvent("onactivate", click_callback);

	LOADING_HUD.HINT_MOVIE.SetMovie(b_image ? "" : `file://{resources}/videos/custom_game/${hint_name}.webm`);
	LOADING_HUD.MOVIE_CONTAINER.SwitchClass("content", `Content_${b_image ? hint_name : "none"}`);

	$(`#Bullet_${current_hint}`).RemoveClass("Active");
	$(`#Bullet_${idx}`).AddClass("Active");

	LOADING_HUD.CONTEXT.SetDialogVariable(
		"hint_desc_header",
		$.Localize(`#ls_hint_desc_${hint_name}_header`),
		LOADING_HUD.CONTEXT,
	);
	LOADING_HUD.CONTEXT.SetDialogVariable(
		"hint_desc_text",
		$.Localize(`#ls_hint_desc_${hint_name}`),
		LOADING_HUD.CONTEXT,
	);

	current_hint = idx;
	CheckCurrentHint();
	// Settings pages never advance automatically while the host is editing.
	if (hint_name === "settings") return;
	auto_hint_schedule = $.Schedule(hints[idx][1], () => {
		auto_hint_schedule = undefined;
		if (idx < hints.length - 1) NextHint();
		else SetHint(0);
	});
}

function NextHint() {
	SetHint(current_hint + 1);
}

function PrevHint() {
	SetHint(current_hint - 1);
}

function UpdatePlayersLoadState() {
	Object.entries(players).forEach(([player_id, panel]) => {
		const player_info = Game.GetPlayerInfo(parseInt(player_id));
		panel.SwitchClass("loading_state", LOADING_STATES_DATA[player_info.player_connection_state] || "BState_None");

		players_loaded[player_id] =
			player_info.player_connection_state == DOTAConnectionState_t.DOTA_CONNECTION_STATE_CONNECTED || null;
	});

	const player_loaded_count = Object.values(players_loaded).filter((v) => v).length;

	LOADING_HUD.CONTEXT.SetDialogVariableInt("players_loaded", player_loaded_count);

	$.Schedule(0.1, () => {
		if (player_loaded_count < players_in_lobby) UpdatePlayersLoadState();
		else LOADING_HUD.CONTEXT.RemoveClass("BLoadingState");
	});
}

function CreateLoadingPlayersPanel() {
	LOADING_HUD.CONTEXT.SetHasClass("BLoadingState", true);
	// The loading screen runs before the shared HUD utilities are included.
	const map_name = Game.GetMapInfo().map_display_name;
	LOADING_HUD.CONTEXT.AddClass(["ot3_ffa_epic", "ot3_ffa_epic_draft", "ot3_ffa_draft"].includes(map_name) ? "ot3_necropolis_ffa" : map_name);

	LOADING_HUD.PLAYERS_LIST.RemoveAndDeleteChildren();

	for (let player_id = 0; player_id < DOTALimits_t.DOTA_MAX_TEAM_PLAYERS; player_id++) {
		const player_info = Game.GetPlayerInfo(player_id);
		if (!player_info) continue;

		players_in_lobby++;

		const player_panel = $.CreatePanel("Panel", LOADING_HUD.PLAYERS_LIST, `LS_PlayerLoading_${player_id}`);
		player_panel.BLoadLayoutSnippet("LS_Player");
		player_panel.SetHasClass("BLocalPlayer", player_id == Game.GetLocalPlayerID());
		players[player_id] = player_panel;

		const player_root_info = player_panel.FindChild("LS_PlayerInfo");
		player_root_info.GetChild(0).steamid = player_info.player_steamid;
		player_root_info.GetChild(1).steamid = player_info.player_steamid;
	}
	LOADING_HUD.CONTEXT.SetDialogVariableInt("players_total", players_in_lobby);

	UpdatePlayersLoadState();
}

function UpdateLoadingScreen() {
	const player_info = Game.GetPlayerInfo(Game.GetLocalPlayerID());
	if (!player_info || player_info.player_connection_state != DOTAConnectionState_t.DOTA_CONNECTION_STATE_CONNECTED)
		return void $.Schedule(0.1, UpdateLoadingScreen);

	CreateLoadingPlayersPanel();
	UpdateTimer();
}

function UpdateTimer() {
	var game_time = Game.GetGameTime();
	var transition_time = Game.GetStateTransitionTime();
	if (transition_time >= 0)
		LOADING_HUD.CONTEXT.SetDialogVariable(
			"ls_hints_timer",
			FormatSeconds(Math.max(transition_time - game_time, 0)),
		);

	LOADING_HUD.CONTEXT.SetHasClass("BGameLaunch", transition_time >= 0);
	LOADING_HUD.CONTEXT.SetHasClass(
		"BGameLoading",
		Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD),
	);

	if (Game.GameStateIsAfter(DOTA_GameState.DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD))
		LOADING_HUD.LS_HINT_TIMER_HEADER.text = $.Localize("#ls_hint_text_header_game_start");

	if (LOADING_HUD.CHAT.BHasClass("ChatExpanded") && !LOADING_HUD.CHAT.b_custom_change_color) {
		FindDotaHudElementInLS("ChatLinesContainer").style.backgroundColor = "rgba(0,0,0,0.85)";
		LOADING_HUD.CHAT.b_custom_change_color = true;
	}
	if (Game.GameStateIsAfter(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP)) return;
	$.Schedule(0.1, UpdateTimer);
}

function UpdateChatStyle() {
	FindDotaHudElementInLS("ChatLinesOverlay").visible = false;
	const is_4x3 = dotaLoadingScreen.BHasClass("AspectRatio4x3");
	const is_16x10 = dotaLoadingScreen.BHasClass("AspectRatio16x10");

	let chat_width = 600;
	if (is_4x3) chat_width = 282;
	else if (is_16x10) chat_width = 450;

	LOADING_HUD.CHAT.style.width = `${chat_width}px`;
	LOADING_HUD.CHAT.style.margin = "0 30px 582px 0px";
	FindDotaHudElementInLS("ChatLinesContainer").style.height = "130px";
	LOADING_HUD.CHAT.style.horizontalAlign = "right";
}

function InitMatchRules() {
	// Loading panels can initialize before map information and net tables arrive.
	if (!CustomNetTables.GetTableValue("game_options", "match_rules")) return;
	if (LOADING_HUD.CONTEXT.FindChildTraverse("MatchRulesPanel")) return;
	["LS_Tips_Logo", "LS_DiscordButton"].forEach(function(className) {
		LOADING_HUD.CONTEXT.FindChildrenWithClassTraverse(className).forEach(function(element) { element.visible = false; });
	});
	const panel = $.CreatePanel("Panel", LOADING_HUD.MOVIE_CONTAINER, "MatchRulesPanel");
	panel.style.width = "100%";
	panel.style.height = "100%";
	panel.style.flowChildren = "down";
	panel.style.horizontalAlign = "center";
	panel.style.verticalAlign = "top";
	panel.style.backgroundColor = "gradient(linear, 0% 0%, 100% 100%, from(#172330), to(#0c141e))";
	panel.style.padding = "20px 30px";
	panel.style.border = "1px solid #415465";
	panel.style.zIndex = "100";
	function label(parent, text) {
		const p = $.CreatePanel("Label", parent, "");
		p.text = $.Localize(text);
		p.style.color = "#eeeeee";
		p.style.fontSize = "18px";
		p.style.marginBottom = "4px";
		return p;
	}
	const controls = {};
	let killGoal, goalDirty = false, syncingGoal = false, canEditRules = false;
	function validKillGoal() {
		return /^\d+$/.test(killGoal.text) && Number(killGoal.text) >= 1 && Number(killGoal.text) <= 2147483647;
	}
	const categories = [{ id: "core", options: ["epic_orbs", "turbo", "single_draft", "kill_goal"] }];
	const body = $.CreatePanel("Panel", panel, "MatchRulesCategories");
	body.style.width = "100%";
	body.style.height = "fill-parent-flow(1.0)";
	body.style.flowChildren = "down";
	body.style.overflow = "squish scroll";
	categories.forEach(function(category) {
		const group = $.CreatePanel("Panel", body, "MatchRules_" + category.id);
		group.style.width = "100%";
		group.style.flowChildren = "down";
		group.style.marginBottom = "12px";
		const heading = label(group, "#host_rules_category_" + category.id);
		heading.style.color = "#d4bb86";
		heading.style.fontSize = "20px";
		heading.style.fontWeight = "semi-bold";
		heading.style.letterSpacing = "1px";
		heading.style.marginBottom = "12px";
		category.options.forEach(function(name) {
			const row = $.CreatePanel(name === "kill_goal" ? "Panel" : "ToggleButton", group, "Rule_" + name);
			row.style.width = "100%";
			row.style.height = "42px";
			row.style.padding = "6px 14px";
			row.style.marginBottom = "4px";
			row.style.backgroundColor = "#1b2b3b";
			row.style.border = "1px solid #304456";
			const caption = label(row, "#host_rules_" + name);
			caption.style.marginBottom = "0px";
			caption.style.verticalAlign = "center";
			if (name === "kill_goal") {
				killGoal = $.CreatePanel("TextEntry", row, "KillGoalInput");
				killGoal.style.horizontalAlign = "right";
				killGoal.style.verticalAlign = "center";
				killGoal.style.width = "100px";
				killGoal.style.height = "30px";
				killGoal.style.fontSize = "18px";
				killGoal.style.textAlign = "right";
				killGoal.style.color = "#eeeeee";
				killGoal.style.backgroundColor = "#0c141e";
				killGoal.style.border = "1px solid #607988";
				killGoal.maxchars = 10;
				killGoal.text = "30";
				return;
			}
			controls[name] = row;
			row.SetPanelEvent("onactivate", function() {
				GameEvents.SendToServerEnsured("HostOptions:set_option_state", {name: name, state: row.IsSelected()});
			});
		});
	});
	const start = $.CreatePanel("Button", panel, "ApplyMatchRules");
	start.style.horizontalAlign = "right";
	start.style.marginTop = "16px";
	start.style.backgroundColor = "gradient(linear, 0% 0%, 0% 100%, from(#527647), to(#344e30))";
	start.style.border = "1px solid #789364";
	start.style.padding = "10px 26px";
	label(start, "#host_rules_start").style.marginBottom = "0px";
	start.SetPanelEvent("onactivate", function() {
		if (!canEditRules || !validKillGoal()) return;
		const event = {kill_goal: Number(killGoal.text)};
		Object.keys(controls).forEach(function(name) { event[name] = controls[name].IsSelected() ? 1 : 0; });
		GameEvents.SendToServerEnsured("HostOptions:apply_rules", event);
	});
	killGoal.SetPanelEvent("ontextentrychange", function() {
		if (syncingGoal || !canEditRules) return;
		goalDirty = true;
		const valid = validKillGoal();
		killGoal.style.border = valid ? "1px solid #607988" : "1px solid #d66b62";
		start.enabled = valid;
		if (valid) GameEvents.SendToServerEnsured("HostOptions:set_option_state", {name: "kill_goal", state: Number(killGoal.text)});
	});
	function refresh() {
		const rules = CustomNetTables.GetTableValue("game_options", "match_rules") || {};
		const canEdit = rules.host_id === Game.GetLocalPlayerID() && rules.locked === 0;
		canEditRules = canEdit;
		killGoal.enabled = canEdit;
		if (!canEdit || !goalDirty) {
			syncingGoal = true;
			killGoal.text = String(rules.kill_goal === undefined ? 30 : rules.kill_goal);
			syncingGoal = false;
			goalDirty = false;
			killGoal.style.border = "1px solid #607988";
		}
		Object.keys(controls).forEach(function(name) {
			controls[name].enabled = canEdit;
			controls[name].SetSelected(rules[name] === 1);
		});
		start.enabled = canEdit && validKillGoal();
		start.visible = canEdit;
	}
	CustomNetTables.SubscribeNetTableListener("game_options", function(table, key) { if (key === "match_rules") refresh(); });
	refresh();
	hints.splice(0, hints.length, ["settings", 0]);
	InitHints();
}

function ToggleHostOption(name) {
	if (!host_options_enabled) return;

	const checkbox = $(`#${name}`);
	const current_state = checkbox.selected || false;
	checkbox.selected = !current_state;
	checkbox.SetSelected(checkbox.selected);

	GameEvents.SendToServerEnsured("HostOptions:set_option_state", {
		name: name,
		state: checkbox.selected,
	});
}

function ShowHostOptions(event) {
	let data = event.event_data;
	host_options_enabled = true;
	LOADING_HUD.CONTEXT.SetHasClass("host_options_enabled", true);

	LOADING_HUD.OPTIONS_CONTAINER.Children().forEach((option) => {
		option.visible = data.available_options[option.id] === 1;
	});
}

GameUI.GetOption = (option_name) => {
	const table = CustomNetTables.GetTableValue("game_options", "host_options");
	return table ? table[option_name] || false : false;
};

function UdpateWeekendsDates(dates) {
	let weekends_event_info = CustomNetTables.GetTableValue("game_state", "weekends_event_info");
	if (!weekends_event_info) return;
	// weekends_event_info.is_event_active = 1;
	const is_event_active = weekends_event_info.is_event_active == 1;

	LOADING_HUD.CONTEXT.AddClass("BShowWeekendsEvent", is_event_active);
	LOADING_HUD.CONTEXT.SetHasClass("BWeekendsEventActive", is_event_active);
	const set_date = (_n) => {
		const date = weekends_event_info.dates[_n].replace(/-/g, ".");
		LOADING_HUD.CONTEXT.SetDialogVariable(`weekend_event_date_${_n}`, date);
	};
	LOADING_HUD.CONTEXT.SetDialogVariableLocString(
		"weekend_event_header",
		`ls_weekend_banner_header_event_${is_event_active ? "on" : "off"}`,
	);
	set_date(1);
	set_date(2);
}
CustomNetTables.SubscribeNetTableListener("game_state", UdpateWeekendsDates);

function UpdateTournamentDates() {
	LOADING_HUD.BANNER_TOURNAMENT_FFA.SetDialogVariableTime("t_ffa_signups_start", 1710583200);
	LOADING_HUD.BANNER_TOURNAMENT_FFA.SetDialogVariableTime("t_ffa_signups_end", 1711188000);
	LOADING_HUD.BANNER_TOURNAMENT_FFA.SetDialogVariableTime("t_ffa_start", 1711792800);
	LOADING_HUD.BANNER_TOURNAMENT_FFA.SetDialogVariableTime("t_ffa_end", 1711814400);
}
(() => {
	LOADING_HUD.CONTEXT.RemoveClass("BShowWeekendsEvent");
	UdpateWeekendsDates();
	UpdateLoadingScreen();
	InitHints();
	UpdateChatStyle();
	// UpdateTournamentDates();
	FindDotaHudElementInLS("SidebarAndBattleCupLayoutContainer").visible = false;

	GameEvents.Subscribe("HostOptions:show", ShowHostOptions);
	CustomNetTables.SubscribeNetTableListener("game_options", function(table, key) {
		if (key === "match_rules") InitMatchRules();
	});
	InitMatchRules();
})();
