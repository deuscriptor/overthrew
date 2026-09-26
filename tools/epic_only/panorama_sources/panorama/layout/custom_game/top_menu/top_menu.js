const HUD = {
	CONTEXT: $.GetContextPanel(),
	LINES: $("#CTM_Lines"),
};

function HideDefaultButtons() {
	const menu = FindDotaHudElement("MenuButtons");
	for (const b of menu.Children()) b.visible = false;
}
const REMOVED_BUTTONS = ["CTM_CustomSettings", "CTM_Mail", "CTM_Leaderboard", "CTM_Feedback", "CTM_Promo"];
function HideRemovedButtons() {
	for (const id of REMOVED_BUTTONS) {
		const button = $(`#${id}`);
		if (button) button.visible = false;
	}
}
function CloseTopBanner(name) {
	HUD.CONTEXT.AddClass(`BClose_${name}`);

	if (name == "NewMail") dotaHud.SetHasClass("BHasCustomNewMails", false);
}
function OpenTopBanner(name) {
	if (name == "NewMail") return; // The mail button is removed; its banner would point at nothing.
	HUD.CONTEXT.RemoveClass(`BClose_${name}`);

	if (name == "NewMail") dotaHud.SetHasClass("BHasCustomNewMails", true);
}
function CloseChatWheelBanner() {
	CloseTopBanner("ChatWheelNewPromo");
}
function OpenChatWheelTab() {
	GameUI.Collection.OpenSpecificTab("chat_wheel");
	CloseChatWheelBanner();
}

function CloseMailBanner() {
	CloseTopBanner("NewMail");
}
GameUI.OpenTopBanner = OpenTopBanner;
GameUI.CloseTopBanner = CloseTopBanner;

(() => {
	CloseTopBanner("NewMail");
	CloseTopBanner("ChatWheelNewPromo");
	HideDefaultButtons();
	HideRemovedButtons();
})();
