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
};

const LOADING_STATES_DATA = {
	[DOTAConnectionState_t.DOTA_CONNECTION_STATE_CONNECTED]: "BState_Loaded",
	[DOTAConnectionState_t.DOTA_CONNECTION_STATE_ABANDONED]: "BState_Failed",
	[DOTAConnectionState_t.DOTA_CONNECTION_STATE_FAILED]: "BState_Failed",
};

const hints = [
	["orbs", 12],
	["progress", 7],
	["epic", 8],
	["collection", 11],
];
const additional_hints_config = {
	settings: { b_image: true, b_hide_desc: true, b_ignore_hover: true },
};
let current_hint;
let matchRulesPageChanged;
let auto_hint_schedule;
let players = {};

let players_in_lobby = 0;
let players_loaded = {};

let host_options_enabled = false;

// Panorama keeps a panel's images in memory while the panel exists, and the loading screen stops updating as
// soon as the HUD replaces it, so its content is deleted while it still updates: when the locked rules arrive
// (the server ends setup half a second later), or at once for a player joining a match already past setup.
let loading_screen_released = false;
function ReleaseLoadingScreen(fade) {
	if (loading_screen_released) return;
	loading_screen_released = true;
	if (auto_hint_schedule) auto_hint_schedule = $.CancelScheduled(auto_hint_schedule);
	// The root stays: its black background is what the content fades to.
	LOADING_HUD.CONTEXT.Children().forEach((child) => {
		child.style.transitionProperty = "opacity";
		child.style.transitionDuration = "0.2s";
		child.style.opacity = "0";
	});
	$.Schedule(fade ? 0.2 : 0, () => LOADING_HUD.CONTEXT.RemoveAndDeleteChildren());
}

function IsMatchStarting() {
	const rules = CustomNetTables.GetTableValue("game_options", "match_rules");
	return (rules && rules.locked === 1) || Game.GameStateIsAfter(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP);
}

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
	if (loading_screen_released) return;
	if (auto_hint_schedule) auto_hint_schedule = $.CancelScheduled(auto_hint_schedule);
	idx = Math.clamp(idx, 0, hints.length - 1);

	const hint_name = hints[idx][0];
	const settings = LOADING_HUD.CONTEXT.FindChildTraverse("MatchRulesPanel");
	if (settings) settings.visible = hint_name === "settings";
	if (hint_name === "settings" && matchRulesPageChanged) matchRulesPageChanged(idx);
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
	if (loading_screen_released) return;
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
	LOADING_HUD.CONTEXT.AddClass(Game.GetMapInfo().map_display_name);

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
	if (loading_screen_released) return;
	if (IsMatchStarting()) return void ReleaseLoadingScreen(false);
	const player_info = Game.GetPlayerInfo(Game.GetLocalPlayerID());
	if (!player_info || player_info.player_connection_state != DOTAConnectionState_t.DOTA_CONNECTION_STATE_CONNECTED)
		return void $.Schedule(0.1, UpdateLoadingScreen);

	CreateLoadingPlayersPanel();
	UpdateTimer();
}

function UpdateTimer() {
	if (loading_screen_released) return;
	if (IsMatchStarting()) return void ReleaseLoadingScreen(true);
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
	if (loading_screen_released) return;
	// Loading panels can initialize before map information and net tables arrive. The settings stay
	// hidden (the usual tips show instead) until every player has loaded.
	const initialRules = CustomNetTables.GetTableValue("game_options", "match_rules");
	if (!initialRules || (initialRules.ready !== 1 && initialRules.locked !== 1)) return;
	if (LOADING_HUD.CONTEXT.FindChildTraverse("MatchRulesPanel")) return;
	["LS_Tips_Logo", "LS_DiscordButton"].forEach(function(className) {
		LOADING_HUD.CONTEXT.FindChildrenWithClassTraverse(className).forEach(function(element) { element.visible = false; });
	});
	const GOLD = "#d4bb86";
	const panel = $.CreatePanel("Panel", LOADING_HUD.MOVIE_CONTAINER, "MatchRulesPanel");
	css(panel, {
		width: "100%", height: "100%", flowChildren: "down", horizontalAlign: "center", verticalAlign: "top",
		backgroundColor: "gradient(linear, 0% 0%, 100% 100%, from(#1a2835), to(#0b121a))",
		padding: "14px 28px 16px 28px", border: "1px solid #415465", zIndex: "100",
		boxShadow: "inset #00000088 0px 0px 24px 0px",
	});
	function css(target, styles) {
		for (const key in styles) target.style[key] = styles[key];
	}
	function label(parent, text) {
		const p = $.CreatePanel("Label", parent, "");
		p.text = $.Localize(text);
		p.style.color = "#eeeeee";
		p.style.fontSize = "18px";
		p.style.marginBottom = "4px";
		return p;
	}
	function tooltip(target, text) {
		target.SetPanelEvent("onmouseout", function() { $.DispatchEvent("DOTAHideTextTooltip", target); });
		return function() { $.DispatchEvent("DOTAShowTextTooltip", target, $.Localize(text)); };
	}
	function formatTime(seconds) {
		const minutes = Math.floor(seconds / 60);
		const rest = Math.round(seconds % 60);
		return minutes + ":" + (rest < 10 ? "0" : "") + rest;
	}
	const controls = {};
	const rowStyles = {};
	let killGoal, killGoalFrame, killGoalMeasure, killGoalTime, goalDirty = false, syncingGoal = false, canEditRules = false;
	function alignKillGoal() {
		if (!killGoal.IsValid() || !killGoalMeasure.IsValid()) return;
		killGoalMeasure.text = killGoal.text;
		// TextEntry ignores text-align in the current Dota client. Measure the
		// actual font and right-anchor the editor inside a full-width clickable box.
		$.Schedule(0.03, function() {
			if (!killGoal.IsValid() || !killGoalMeasure.IsValid()) return;
			const scale = killGoalMeasure.actualuiscale_x || 1;
			const textWidth = killGoalMeasure.actuallayoutwidth / scale;
			if (killGoal.text && textWidth === 0) {
				$.Schedule(0.1, alignKillGoal);
				return;
			}
			killGoal.style.width = Math.min(98, Math.max(22, textWidth + 18)) + "px";
		});
	}
	function validKillGoal() {
		return /^\d+$/.test(killGoal.text) && Number(killGoal.text) >= 1 && Number(killGoal.text) <= 2147483647;
	}
	// Mirrors HostOptions:ApplyRules: base match length is 1200 seconds per 30 kills.
	function updateGoalTime() {
		const valid = validKillGoal() && Number(killGoal.text) <= 99999;
		killGoalTime.text = valid ? $.Localize("#host_rules_time_limit") + " " + formatTime(Number(killGoal.text) * 40) : "";
	}
	const categories = [
		{ id: "core", options: ["single_draft", "turbo", "epic_orbs", "backpack_items", "kill_goal"] },
		{ id: "items", options: ["divine_rapier", "dagon"] },
		{ id: "other", options: ["all_vision", "infinite_rerolls", "longer_wards", "invincible_wards"] },
	];
	// Category tabs replace the per-page heading; unvisited pages glow until opened.
	const tabBar = $.CreatePanel("Panel", panel, "MatchRulesTabs");
	css(tabBar, {width: "100%", height: "32px", flowChildren: "right"});
	const divider = $.CreatePanel("Panel", panel, "MatchRulesDivider");
	css(divider, {width: "100%", height: "1px", marginBottom: "10px",
		backgroundColor: "gradient(linear, 0% 0%, 100% 0%, from(#d4bb8699), to(#d4bb8600))"});
	const body = $.CreatePanel("Panel", panel, "MatchRulesCategories");
	body.style.width = "100%";
	body.style.height = "fill-parent-flow(1.0)";
	body.style.flowChildren = "down";
	body.style.overflow = "squish scroll";
	const groups = [];
	const tabs = [];
	const visited = {};
	let currentPage = 0;
	function styleTab(tab, index, hovered) {
		const active = index === currentPage;
		const unseen = !active && !visited[index];
		tab.caption.style.color = active ? "#f3dfae" : unseen ? "#dfc58b" : hovered ? "#c9d6e0" : "#7f95a6";
		tab.caption.style.textShadow = unseen ? "0px 0px 6px 1.0 #c59a48aa" : "0px 1px 2px 1.0 #000000aa";
		tab.underline.style.backgroundColor = active ? GOLD : hovered ? "#d4bb8655" : "transparent";
	}
	categories.forEach(function(category, index) {
		const tab = $.CreatePanel("Button", tabBar, "MatchRulesTab_" + category.id);
		css(tab, {height: "100%", padding: "0px 12px", marginRight: "2px"});
		tab.caption = label(tab, "#host_rules_category_" + category.id);
		css(tab.caption, {fontSize: "17px", fontWeight: "bold", letterSpacing: "1.5px", textTransform: "uppercase",
			marginBottom: "0px", verticalAlign: "center"});
		tab.underline = $.CreatePanel("Panel", tab, "");
		css(tab.underline, {width: "100%", height: "2px", verticalAlign: "bottom"});
		tab.SetPanelEvent("onactivate", function() { if (typeof SetHint === "function") SetHint(index); });
		tab.SetPanelEvent("onmouseover", function() { styleTab(tab, index, true); });
		tab.SetPanelEvent("onmouseout", function() { styleTab(tab, index, false); });
		tabs.push(tab);
		const group = $.CreatePanel("Panel", body, "MatchRules_" + category.id);
		group.style.width = "100%";
		group.style.flowChildren = "down";
		group.style.marginBottom = "0px"; // one category is shown per page
		groups.push(group);
		category.options.forEach(function(name) {
			const row = $.CreatePanel(name === "kill_goal" ? "Panel" : "ToggleButton", group, "Rule_" + name);
			// A code-created ToggleButton brings its own tick box; the switch below replaces it.
			row.Children().forEach(function(child) { child.visible = false; });
			css(row, {
				width: "100%",
				// Sized so five rows fit the fixed-height settings page without scrolling.
				height: "36px", padding: "0px 12px 0px 0px", marginBottom: "4px",
				transitionProperty: "background-color, border", transitionDuration: "0.12s",
			});
			const accent = $.CreatePanel("Panel", row, "");
			css(accent, {width: "3px", height: "100%", transitionProperty: "background-color", transitionDuration: "0.12s"});
			const caption = label(row, "#host_rules_" + name);
			css(caption, {marginBottom: "0px", marginLeft: "14px", verticalAlign: "center",
				transitionProperty: "color", transitionDuration: "0.12s"});
			const showTooltip = tooltip(row, "#host_rules_" + name + "_tip");
			if (name === "kill_goal") {
				css(row, {backgroundColor: "#16222e", border: "1px solid #26394a"});
				accent.style.backgroundColor = GOLD;
				row.SetPanelEvent("onmouseover", showTooltip);
				killGoalTime = $.CreatePanel("Label", row, "KillGoalTime");
				css(killGoalTime, {horizontalAlign: "right", verticalAlign: "center", marginRight: "112px",
					fontSize: "15px", color: "#8da6b5"});
				killGoalTime.hittest = false;
				killGoalFrame = $.CreatePanel("Panel", row, "KillGoalField");
				killGoalFrame.style.horizontalAlign = "right";
				killGoalFrame.style.verticalAlign = "center";
				killGoalFrame.style.width = "100px";
				killGoalFrame.style.height = "28px";
				killGoalFrame.style.backgroundColor = "#0a1017";
				killGoalFrame.style.border = "1px solid #607988";
				killGoal = $.CreatePanel("TextEntry", killGoalFrame, "KillGoalInput");
				killGoal.style.horizontalAlign = "right";
				killGoal.style.verticalAlign = "center";
				killGoal.style.width = "100px";
				killGoal.style.height = "28px";
				killGoal.style.fontSize = "18px";
				killGoal.style.fontFamily = "Radiance";
				killGoal.style.fontWeight = "normal";
				killGoal.style.padding = "3px 6px";
				killGoal.style.color = "#eeeeee";
				killGoal.style.backgroundColor = "transparent";
				killGoal.style.border = "0px";
				killGoalFrame.SetPanelEvent("onactivate", function() { if (canEditRules) killGoal.SetFocus(); });
				killGoal.maxchars = 10;
				killGoal.text = "50";
				killGoalMeasure = $.CreatePanel("Label", row, "KillGoalTextMeasure");
				killGoalMeasure.style.width = "fit-children";
				killGoalMeasure.style.fontFamily = "Radiance";
				killGoalMeasure.style.fontSize = "18px";
				killGoalMeasure.style.fontWeight = "normal";
				killGoalMeasure.style.padding = "0px";
				killGoalMeasure.style.color = "#00000000";
				killGoalMeasure.hittest = false;
				alignKillGoal();
				return;
			}
			// Panorama draws rounded borders without anti-aliasing, so the outline is an
			// outer rounded background showing 1px around the inner fill. Oversized radii are
			// clamped to half the height, keeping semicircular ends at any UI scale.
			const track = $.CreatePanel("Panel", row, "");
			css(track, {width: "40px", height: "22px", horizontalAlign: "right", verticalAlign: "center",
				borderRadius: "999px", transitionProperty: "background-color, box-shadow, saturation, opacity", transitionDuration: "0.12s"});
			const trackFill = $.CreatePanel("Panel", track, "");
			css(trackFill, {width: "38px", height: "20px", margin: "1px", borderRadius: "999px",
				transitionProperty: "background-color", transitionDuration: "0.12s"});
			const knob = $.CreatePanel("Panel", trackFill, "");
			css(knob, {width: "16px", height: "16px", margin: "2px", verticalAlign: "center", borderRadius: "50%",
				boxShadow: "#00000099 0px 1px 2px 0px", transitionProperty: "transform, background-color", transitionDuration: "0.12s"});
			let hovered = false;
			rowStyles[name] = function() {
				const on = row.IsSelected();
				const hot = hovered && canEditRules;
				css(row, {
					backgroundColor: on ? (hot ? "#2a4058" : "#213347") : (hot ? "#1f2f3f" : "#16222e"),
					border: "1px solid " + (hot ? "#5b7a95" : on ? "#3d5770" : "#26394a"),
				});
				accent.style.backgroundColor = on ? GOLD : "transparent";
				caption.style.color = on ? "#f4f6f8" : "#9aabb8";
				track.style.backgroundColor = on ? "#9cc07f" : "#415465";
				// A faint glow in the outline colour softens the edge pixels.
				track.style.boxShadow = (on ? "#9cc07f66" : "#41546566") + " 0px 0px 2px 0px";
				trackFill.style.backgroundColor = on ? "gradient(linear, 0% 0%, 0% 100%, from(#6f9f5c), to(#4a7340))" : "#0a1017";
				// Read-only viewers (waiting for or before a host, or after the start) get greyed-out switches.
				css(track, {saturation: canEditRules ? "1" : "0", opacity: canEditRules ? "1" : "0.5"});
				css(knob, {backgroundColor: on ? "#ffffff" : "#6d7f8e", transform: on ? "translate3d(18px, 0px, 0px)" : "translate3d(0px, 0px, 0px)"});
			};
			controls[name] = row;
			row.SetPanelEvent("onmouseover", function() { hovered = true; rowStyles[name](); showTooltip(); });
			row.SetPanelEvent("onmouseout", function() {
				hovered = false;
				rowStyles[name]();
				$.DispatchEvent("DOTAHideTextTooltip", row);
			});
			row.SetPanelEvent("onactivate", function() {
				rowStyles[name]();
				GameEvents.SendToServerEnsured("HostOptions:set_option_state", {name: name, state: row.IsSelected()});
			});
		});
	});
	const start = $.CreatePanel("Button", panel, "ApplyMatchRules");
	css(start, {horizontalAlign: "center", marginTop: "12px", minWidth: "220px", height: "42px", padding: "0px 28px",
		backgroundColor: "gradient(linear, 0% 0%, 0% 100%, from(#5e8f4f), to(#335230))",
		border: "1px solid #9cc07f", borderRadius: "3px", boxShadow: "#000000aa 0px 2px 8px 0px",
		transitionProperty: "brightness, saturation, opacity", transitionDuration: "0.12s"});
	const startCaption = label(start, "#host_rules_start");
	css(startCaption, {marginBottom: "0px", horizontalAlign: "center", verticalAlign: "center", fontSize: "18px",
		fontWeight: "bold", letterSpacing: "1.5px", color: "#ffffff", textShadow: "0px 1px 3px 1.0 #000000cc"});
	let startHovered = false;
	function styleStart() {
		const ready = start.enabled;
		css(start, {
			brightness: ready && startHovered ? "1.25" : "1",
			saturation: ready ? "1" : "0.15",
			opacity: ready ? "1" : "0.6",
		});
	}
	start.SetPanelEvent("onmouseover", function() { startHovered = true; styleStart(); });
	start.SetPanelEvent("onmouseout", function() { startHovered = false; styleStart(); });
	// Non-hosts get a status card in Apply & Start's place and footprint, so the five rows still fit.
	const waiting = $.CreatePanel("Panel", panel, "WaitingForHost");
	css(waiting, {horizontalAlign: "center", marginTop: "12px", minWidth: "220px", height: "42px", padding: "0px 22px 0px 12px",
		flowChildren: "right", backgroundColor: "gradient(linear, 0% 0%, 100% 100%, from(#1a2835), to(#0b121a))",
		border: "1px solid #415465", borderRadius: "3px", boxShadow: "#000000aa 0px 2px 8px 0px"});
	waiting.hittest = false;
	// Gold dots pulse in turn, like the pager's current-page pill. Panels clip their children, so the
	// padding leaves room for the lifted dot and its glow.
	const waitingDots = $.CreatePanel("Panel", waiting, "WaitingForHostDots");
	css(waitingDots, {flowChildren: "right", verticalAlign: "center", padding: "6px", marginRight: "8px"});
	for (let i = 0; i < 3; i++) {
		css($.CreatePanel("Panel", waitingDots, ""), {width: "8px", height: "8px", marginLeft: i ? "5px" : "0px", borderRadius: "4px",
			backgroundColor: GOLD, transitionProperty: "opacity, box-shadow, transform", transitionDuration: "0.25s"});
	}
	const waitingText = $.CreatePanel("Panel", waiting, "");
	css(waitingText, {flowChildren: "down", verticalAlign: "center"});
	css(label(waitingText, "#host_rules_waiting"), {marginBottom: "0px", fontSize: "15px", fontWeight: "bold",
		letterSpacing: "1.5px", textTransform: "uppercase", color: "#f3dfae", textShadow: "0px 1px 2px 1.0 #000000aa"});
	const waitingDetail = label(waitingText, "");
	css(waitingDetail, {marginBottom: "0px", fontSize: "13px", color: "#8da6b5"});
	// With no host yet, anyone can claim the role: the same card, lit gold like unvisited tabs.
	const claim = $.CreatePanel("Button", panel, "ClaimHost");
	css(claim, {horizontalAlign: "center", marginTop: "12px", minWidth: "220px", height: "42px", padding: "0px 22px 0px 16px",
		flowChildren: "right", backgroundColor: "gradient(linear, 0% 0%, 100% 100%, from(#1a2835), to(#0b121a))",
		borderRadius: "3px", transitionProperty: "border, box-shadow, brightness, opacity", transitionDuration: "0.12s"});
	const claimMark = $.CreatePanel("Panel", claim, "");
	css(claimMark, {width: "9px", height: "9px", verticalAlign: "center", marginRight: "14px", backgroundColor: GOLD,
		transform: "rotateZ(45deg)", boxShadow: "#d4bb8699 0px 0px 6px 0px"});
	const claimText = $.CreatePanel("Panel", claim, "");
	css(claimText, {flowChildren: "down", verticalAlign: "center"});
	css(label(claimText, "#host_rules_claim"), {marginBottom: "0px", fontSize: "15px", fontWeight: "bold",
		letterSpacing: "1.5px", textTransform: "uppercase", color: "#f3dfae", textShadow: "0px 1px 2px 1.0 #000000aa"});
	css(label(claimText, "#host_rules_claim_detail"), {marginBottom: "0px", fontSize: "13px", color: "#8da6b5"});
	claimText.Children().forEach(function(child) { child.hittest = false; });
	let claimHovered = false, claimPending = false;
	function styleClaim() {
		const ready = claim.enabled;
		css(claim, {
			border: "1px solid " + (ready && claimHovered ? GOLD : "#dfc58b"),
			boxShadow: ready && claimHovered ? "#d4bb8666 0px 0px 6px 0px" : "#c59a48cc 0px 0px 8px 1px",
			brightness: ready && claimHovered ? "1.25" : "1",
			opacity: ready ? "1" : "0.6",
		});
	}
	const showClaimTooltip = tooltip(claim, "#host_rules_claim_tip");
	claim.SetPanelEvent("onmouseover", function() { claimHovered = true; styleClaim(); showClaimTooltip(); });
	claim.SetPanelEvent("onmouseout", function() {
		claimHovered = false;
		styleClaim();
		$.DispatchEvent("DOTAHideTextTooltip", claim);
	});
	claim.SetPanelEvent("onactivate", function() {
		if (!claim.enabled) return;
		// One request at a time; the rules update shows who got the role.
		claimPending = true;
		refresh();
		GameEvents.SendToServerEnsured("HostOptions:claim_host", {});
		$.Schedule(2, function() { claimPending = false; if (claim.IsValid()) refresh(); });
	});
	let waitingStep = 0;
	function animateWaiting() {
		if (!waiting.IsValid()) return;
		waitingDots.Children().forEach(function(dot, index) {
			const lit = index === waitingStep;
			css(dot, {opacity: lit ? "1" : "0.3", boxShadow: lit ? "#d4bb8699 0px 0px 6px 0px" : "#00000000 0px 0px 0px 0px",
				transform: lit ? "translate3d(0px, -2px, 0px)" : "translate3d(0px, 0px, 0px)"});
		});
		waitingStep = (waitingStep + 1) % 3;
		$.Schedule(0.3, animateWaiting);
	}
	animateWaiting();
	start.SetPanelEvent("onactivate", function() {
		if (!canEditRules || !validKillGoal()) return;
		const event = {kill_goal: Number(killGoal.text)};
		Object.keys(controls).forEach(function(name) { event[name] = controls[name].IsSelected() ? 1 : 0; });
		GameEvents.SendToServerEnsured("HostOptions:apply_rules", event);
	});
	killGoal.SetPanelEvent("ontextentrychange", function() {
		alignKillGoal();
		updateGoalTime();
		if (syncingGoal || !canEditRules) return;
		goalDirty = true;
		const valid = validKillGoal();
		killGoalFrame.style.border = valid ? "1px solid #607988" : "1px solid #d66b62";
		start.enabled = valid;
		styleStart();
		if (valid) GameEvents.SendToServerEnsured("HostOptions:set_option_state", {name: "kill_goal", state: Number(killGoal.text)});
	});
	function refresh() {
		if (loading_screen_released) return;
		const rules = CustomNetTables.GetTableValue("game_options", "match_rules") || {};
		const canEdit = rules.host_id === Game.GetLocalPlayerID() && rules.locked === 0;
		canEditRules = canEdit;
		killGoal.enabled = canEdit;
		if (!canEdit || !goalDirty) {
			syncingGoal = true;
			killGoal.text = String(rules.kill_goal === undefined ? 50 : rules.kill_goal);
			alignKillGoal();
			updateGoalTime();
			syncingGoal = false;
			goalDirty = false;
			killGoalFrame.style.border = "1px solid #607988";
		}
		Object.keys(controls).forEach(function(name) {
			controls[name].enabled = canEdit;
			controls[name].SetSelected(rules[name] === 1);
			rowStyles[name]();
		});
		start.enabled = canEdit && validKillGoal();
		styleStart();
		start.visible = canEdit;
		const open = rules.locked !== 1;
		const hasHost = rules.host_id !== undefined && rules.host_id >= 0;
		claim.visible = open && !hasHost;
		claim.enabled = claim.visible && !claimPending;
		styleClaim();
		waiting.visible = open && hasHost && !canEdit;
		if (waiting.visible) {
			const host = Game.GetPlayerInfo(rules.host_id);
			waitingDetail.SetDialogVariable("host_name", host ? host.player_name : "");
			waitingDetail.text = $.Localize("#host_rules_waiting_detail", waitingDetail);
		}
	}
	CustomNetTables.SubscribeNetTableListener("game_options", function(table, key) { if (key === "match_rules") refresh(); });
	refresh();
	// Page switching reuses the loading screen's hint arrows and bullets. They are restyled like the
	// settings (slate buttons, gold current page) and grouped into one row under the panel.
	let pager;
	function stylePager() {
		const bullets = LOADING_HUD.BULLETS_ROOT;
		const left = LOADING_HUD.CONTEXT.FindChildTraverse("LS_Tips_Left");
		const right = LOADING_HUD.CONTEXT.FindChildTraverse("LS_Tips_Right");
		if (!bullets || !left || !right) return;
		const tipsRoot = bullets.GetParent();
		tipsRoot.style.backgroundImage = "none"; // frame art with the notch under the bullets
		pager = $.CreatePanel("Panel", tipsRoot, "MatchRulesPager");
		css(pager, {flowChildren: "right", horizontalAlign: "center", verticalAlign: "bottom", marginBottom: "32px"});
		[left, bullets, right].forEach(function(part) { part.SetParent(pager); });
		css(bullets, {margin: "0px 12px", padding: "0px", horizontalAlign: "left", verticalAlign: "center"});
		pager.arrows = [left, right];
		pager.arrows.forEach(function(arrow) {
			// Inline visibility overrides the stylesheet hiding the first/last arrow: the ends are dimmed
			// instead, so the row does not shift.
			css(arrow, {width: "30px", height: "30px", margin: "0px", horizontalAlign: "left", verticalAlign: "center",
				visibility: "visible", backgroundImage: "none", borderRadius: "3px",
				backgroundColor: "gradient(linear, 0% 0%, 100% 100%, from(#1a2835), to(#0b121a))",
				boxShadow: "#000000aa 0px 2px 6px 0px", transitionProperty: "border, opacity, brightness", transitionDuration: "0.12s"});
			const icon = arrow.GetChild(0);
			// The chevron art is orange; desaturate it so the gold wash takes.
			if (icon) {
				css(icon, {width: "11px", height: "16px", margin: "0px", horizontalAlign: "center", verticalAlign: "center",
					saturation: "0", washColor: GOLD, brightness: "1.3", transform: "none"});
				// Now centred in a small button, the icon would take the hover and click from it.
				icon.hittest = false;
			}
			arrow.SetPanelEvent("onmouseover", function() { arrow.hovered = arrow.noticed = true; refreshPager(); });
			arrow.SetPanelEvent("onmouseout", function() { arrow.hovered = false; refreshPager(); });
		});
		bullets.Children().forEach(function(bullet, index) {
			bullet.Children().forEach(function(art) { art.visible = false; });
			bullet.SetPanelEvent("onactivate", function() { if (typeof SetHint === "function") SetHint(index); });
			bullet.SetPanelEvent("onmouseover", function() { bullet.hovered = true; refreshPager(); });
			bullet.SetPanelEvent("onmouseout", function() { bullet.hovered = false; refreshPager(); });
		});
		refreshPager();
	}
	function refreshPager() {
		if (!pager) return;
		// Like unvisited category tabs, arrows glow until first hovered or pressed and bullets glow until
		// their page has been opened.
		pager.arrows.forEach(function(arrow, side) {
			const available = side === 0 ? currentPage > 0 : currentPage < categories.length - 1;
			const hot = available && arrow.hovered;
			const glow = available && !hot && !arrow.noticed;
			arrow.enabled = available;
			css(arrow, {opacity: available ? "1" : "0.35", brightness: hot ? "1.25" : "1",
				border: "1px solid " + (hot ? GOLD : glow ? "#dfc58b" : "#415465"),
				boxShadow: glow ? "#c59a48cc 0px 0px 8px 1px" : hot ? "#d4bb8666 0px 0px 6px 0px" : "#000000aa 0px 2px 6px 0px"});
		});
		LOADING_HUD.BULLETS_ROOT.Children().forEach(function(bullet, index) {
			const active = index === currentPage;
			const unseen = !active && !visited[index];
			css(bullet, {width: active ? "22px" : "8px", height: "8px", marginLeft: index ? "6px" : "0px", verticalAlign: "center",
				borderRadius: "4px",
				backgroundColor: active ? GOLD : bullet.hovered ? "#c9d6e0" : unseen ? "#dfc58b" : "#7f95a6",
				boxShadow: active ? "#d4bb8666 0px 0px 6px 0px" : unseen ? "#c59a48cc 0px 0px 6px 1px" : "#00000000 0px 0px 0px 0px"});
		});
	}
	matchRulesPageChanged = function(index) {
		visited[index] = true;
		currentPage = index;
		groups.forEach(function(group, i) { group.visible = i === index; });
		tabs.forEach(function(tab, i) { styleTab(tab, i, false); });
		refreshPager();
	};
	matchRulesPageChanged(0);
	hints.splice(0, hints.length);
	categories.forEach(function() { hints.push(["settings", 0]); });
	InitHints();
	stylePager();
}

function ToggleHostOption(name) {
	if (!host_options_enabled || loading_screen_released) return;

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
	if (loading_screen_released) return;
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

(() => {
	UpdateChatStyle();
	FindDotaHudElementInLS("SidebarAndBattleCupLayoutContainer").visible = false;
	if (IsMatchStarting()) return void ReleaseLoadingScreen(false);
	UpdateLoadingScreen();
	InitHints();

	GameEvents.Subscribe("HostOptions:show", ShowHostOptions);
	CustomNetTables.SubscribeNetTableListener("game_options", function(table, key) {
		if (key !== "match_rules") return;
		if (IsMatchStarting()) ReleaseLoadingScreen(true);
		else InitMatchRules();
	});
	InitMatchRules();
})();
