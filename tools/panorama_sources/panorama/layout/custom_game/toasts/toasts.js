const CONTEXT = $.GetContextPanel();

let current_toasts_schedules = {};
let current_toast_id = 0;

function RemoveToast(toast, id) {
	if (current_toasts_schedules[id]) {
		current_toasts_schedules[id] = $.CancelScheduled(current_toasts_schedules[id]);
	}
	tip_toasts = tip_toasts.filter((tip) => tip.id != id);
	if (toast && toast.IsValid()) {
		toast.SetHasClass("Active", false);
		toast.DeleteAsync(0.35);
	}
}

const TIP_TOAST_DURATION = 6;
// older tip toasts leave early so a burst of tips never fills the screen
const MAX_TIP_TOASTS = 3;
let tip_toasts = [];

function SetTipPlayer(container, player_id, player_info) {
	const hero_image = container.GetChild(0);
	hero_image.SetImage(GetPortraitImage(player_id, player_info.player_selected_hero));
	// player colour strip under the portrait, like the top bar and scoreboard
	const color = /#[0-9a-f]{6}/i.exec(GameUI.GetTeamColor(Players.GetTeam(player_id)) || "");
	if (color) hero_image.style.borderBottom = `3px solid ${color[0]}`;

	const user_name = container.GetChild(1);
	if (player_info.player_steamid && player_info.player_steamid != "0") {
		user_name.steamid = player_info.player_steamid;
		return;
	}
	// no Steam account (bots): DOTAUserName would stay empty
	user_name.style.visibility = "collapse";
	$.CreatePanel("Label", container, "", { class: "TipPlayerName", text: player_info.player_name });
}

function PreparePlayerTipToast(toast, data, toast_id) {
	Game.EmitSound("General.Coins");
	toast.SetDialogVariableInt("value", data.currency);

	const source_player_info = Game.GetPlayerInfo(data.source_player_id);
	const target_player_info = Game.GetPlayerInfo(data.target_player_id);
	if (source_player_info) SetTipPlayer(toast.GetChild(0), data.source_player_id, source_player_info);
	if (target_player_info) SetTipPlayer(toast.GetChild(2), data.target_player_id, target_player_info);

	// the tipped player gets a gold frame (toasts.css) and a second chime
	if (data.target_player_id == Game.GetLocalPlayerID()) {
		toast.AddClass("TipToLocalPlayer");
		Game.EmitSound("Loot_Drop_Sfx_Minor");
	}

	tip_toasts.push({ toast: toast, id: toast_id });
	while (tip_toasts.length > MAX_TIP_TOASTS) {
		const oldest = tip_toasts[0];
		RemoveToast(oldest.toast, oldest.id);
	}
}

// Player tips are the only toasts the server sends.
function NewToast(event) {
	if (event.toast_type != "player_tip") return;

	const toast = $.CreatePanel("Panel", CONTEXT, `${current_toast_id}`);
	toast.BLoadLayoutSnippet("player_tip");

	// bind to local variable so that anon function later can capture it in current state
	// otherwise it will use future ongoing id instead of this one
	const toast_id = current_toast_id;
	PreparePlayerTipToast(toast, event.data, toast_id);

	toast.SetHasClass("Active", true);
	toast.AddClass(event.toast_type);
	current_toasts_schedules[toast_id] = $.Schedule(TIP_TOAST_DURATION, () => {
		RemoveToast(toast, toast_id);
	});

	current_toast_id++;
}

(() => {
	const frame = GameEvents.NewProtectedFrame("toast_notifications");
	frame.SubscribeProtected("Toasts:new", NewToast);

	CONTEXT.RemoveAndDeleteChildren();
})();
