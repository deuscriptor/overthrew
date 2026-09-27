const CONTEXT = $.GetContextPanel();
const DEFAULT_DURATION = 30;

// overrides for toast snippets
// for cases when specific snippet needs different panel
const TOAST_SNIPPETS_OVERRIDE = {
	player_tip: "player_tip",
	sub_trial_available: "sub_trial_available",
};

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

function PrepareToast(toast, event, toast_id) {
	const image = toast.FindChildTraverse("ToastImage");
	let duration = DEFAULT_DURATION;
	let toast_image_src;

	switch (event.toast_type) {
		case "mail_incoming": {
			toast.SetDialogVariable("topic", $.Localize(event.data.topic));
			toast.SetDialogVariable("source", $.Localize(event.data.source));

			Game.EmitSound("WeeklyQuest.StarGranted");

			toast.SetPanelEvent("onactivate", () => {
				GameUI.OpenMailWithId(event.data.id);
				RemoveToast(toast, toast_id);
			});
			toast_image_src = "file://{images}/custom_game/mail/mail_gold.png";
			break;
		}
		case "payment_success": {
			Game.EmitSound("WeeklyQuest.ClaimReward");
			const product_name = event.data.product_name;
			let product_name_localized = $.Localize(`#${product_name}`);
			if (event.data.quantity > 1) {
				product_name_localized = `${product_name_localized} - x${event.data.quantity}`;
			}
			if (event.data.gift_codes) {
				const gift_code_prefix_localized = $.Localize("#toast_gift_code_prefix");
				product_name_localized = `${gift_code_prefix_localized} ${product_name_localized}`;
			}
			toast.SetDialogVariable("product_name", product_name_localized);
			toast_image_src = GameUI.GetProductIcon(product_name);
			toast.SetPanelEvent("onactivate", () => {
				GameUI.Collection.OpenSpecificTab("gift_codes");
				RemoveToast(toast, toast_id);
			});
			break;
		}
		case "payment_fail": {
			const product_name = event.data.product_name;
			toast.SetDialogVariable("product_name", $.Localize(`#${product_name}`));
			toast.SetPanelEvent("onactivate", () => {
				$.DispatchEvent("ExternalBrowserGoToURL", event.data.hosted_invoice_url);
				RemoveToast(toast, toast_id);
			});
			toast_image_src = GameUI.GetProductIcon(product_name);
			break;
		}
		case "player_tip": {
			PreparePlayerTipToast(toast, event.data, toast_id);

			// override max duration to avoid screen clutter
			duration = TIP_TOAST_DURATION;
			break;
		}
		case "gift_code_sent": {
			Game.EmitSound("WeeklyQuest.ClaimReward");

			const product_name = event.data.gift_code.product_name;
			toast.SetDialogVariable("product_name", $.Localize(`#${product_name}`));

			const gifter = Game.GetPlayerInfo(event.data.gifter);
			toast.SetDialogVariable("gifter_name", gifter.player_name);

			toast_image_src = GameUI.GetProductIcon(product_name);

			toast.SetPanelEvent("onactivate", () => {
				GameUI.Collection.OpenSpecificTab("cosmetics");
				RemoveToast(toast, toast_id);
			});
			break;
		}
		case "sub_trial_available": {
			toast_image_src = GameUI.Inventory.GetItemImagePath("bp_sub_tier_2_consumable");

			const accept_button = toast.FindChildTraverse("AcceptButton");
			const decline_button = toast.FindChildTraverse("DeclineButton");

			accept_button.SetPanelEvent("onactivate", () => {
				GameUI.Inventory.ConsumeItem("bp_sub_tier_2_consumable");
				RemoveToast(toast, toast_id);
			});

			decline_button.SetPanelEvent("onactivate", () => {
				RemoveToast(toast, toast_id);
			});

			break;
		}
		case "sub_trial_started": {
			toast_image_src = GameUI.Inventory.GetItemImagePath("bp_sub_tier_2_consumable");

			toast.SetPanelEvent("onactivate", () => {
				GameUI.Collection.OpenSpecificTab("subscription");
				RemoveToast(toast, toast_id);
			});
			break;
		}
		case "promo_claim_available": {
			toast_image_src = "file://{images}/custom_game/promo_events/button_with_bg.png";

			toast.SetPanelEvent("onactivate", () => {
				GameUI.ToggleCustomPromoEvents(true);
			});
			break;
		}
	}

	if (image) {
		image.SetImage(toast_image_src);
	}

	toast.SetDialogVariable("toast_header", $.Localize(`#toast_${event.toast_type}`, toast));
	toast.SetDialogVariable("toast_description", $.Localize(`#toast_${event.toast_type}_description`, toast));

	toast.SetHasClass("Active", true);
	toast.AddClass(event.toast_type);

	current_toasts_schedules[toast_id] = $.Schedule(duration, () => {
		RemoveToast(toast, toast_id);
	});
}

function GetToastSnippet(toast_type) {
	const snippet_override = TOAST_SNIPPETS_OVERRIDE[toast_type];
	return snippet_override ? snippet_override : "toast";
}

function NewToast(event) {
	// $.Msg("NewToast");
	// JSON.print(event);
	if (!event.toast_type) return;

	const toast = $.CreatePanel("Panel", CONTEXT, `${current_toast_id}`);
	toast.BLoadLayoutSnippet(GetToastSnippet(event.toast_type));

	// bind to local variable so that anon function later can capture it in current state
	// otherwise it will use future ongoing id instead of this one
	let toast_id = current_toast_id;

	const close_button = toast.FindChild("CloseButton");
	if (close_button) {
		close_button.SetPanelEvent("onactivate", () => {
			RemoveToast(toast, toast_id);
		});
	}

	PrepareToast(toast, event, current_toast_id);

	current_toast_id++;
}

(() => {
	const frame = GameEvents.NewProtectedFrame("toast_notifications");
	frame.SubscribeProtected("Toasts:new", NewToast);

	CONTEXT.RemoveAndDeleteChildren();
})();
