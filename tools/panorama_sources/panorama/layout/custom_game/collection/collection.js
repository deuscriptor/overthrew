GameUI.Collection = GameUI.Collection || {};
GameUI.ToggleSingleClassInParent = (parent, child, class_name) => {
	parent.Children().forEach((upgrade) => {
		upgrade.RemoveClass(class_name);
	});
	if (child) child.AddClass(class_name);
};

// The collection is free and local: cosmetics are its only tab.
const TABS = ["cosmetics"];

function InitFreeCollectionLabel() {
	HUD.TOP_BAR_BUTTONS_ROOT.RemoveAndDeleteChildren();
	const freeLabel = $.CreatePanel("Label", HUD.TOP_BAR_BUTTONS_ROOT, "LocalCollectionFree");
	freeLabel.text = $.Localize("#collection_local_free");
	freeLabel.style.color = "#e8e4d8";
	freeLabel.style.fontSize = "18px";
	freeLabel.style.verticalAlign = "center";
}

function InitContent() {
	HUD.TABS_ROOT.RemoveAndDeleteChildren();
	HUD.CONTENT_ROOT.RemoveAndDeleteChildren();

	let b_first_tab = true;
	TABS.forEach((tab_name) => {
		const tab = $.CreatePanel("Button", HUD.TABS_ROOT, `Tab_${tab_name}`);
		tab.BLoadLayoutSnippet("Tab");
		tab.SetDialogVariable(`tab_name`, $.Localize(`#tab_${tab_name}`, tab));
		tab.FindChildTraverse("Icon").SetImage(GetC_Image(`tab_icon_${tab_name}`));

		const content_panel = $.CreatePanel("Panel", HUD.CONTENT_ROOT, `CollectionContent_${tab_name}`);
		content_panel.BLoadLayout(
			`file://{resources}/layout/custom_game/collection/${tab_name}/${tab_name}.xml`,
			false,
			false,
		);

		const activate_content = () => {
			if (tab.BHasClass("BActive")) return;

			Game.EmitSound("Item.PickUpRecipeShop");
			GameUI.ToggleSingleClassInParent(HUD.TABS_ROOT, tab, "BActive");
			GameUI.ToggleSingleClassInParent(HUD.CONTENT_ROOT, content_panel, "BActive");
		};

		if (b_first_tab) activate_content();
		b_first_tab = false;

		tab.SetPanelEvent("onactivate", activate_content);
		tab.Open = activate_content;
	});
}

function UpdatePlayerData(player_data) {
	for (let tier = 0; tier <= MAX_TIER_SUB; tier++) HUD.CONTEXT.RemoveClass(`SubTier_${tier}`);
	if (!player_data.subscription || player_data.subscription.tier == undefined) return;

	const sub_tier = player_data.subscription.tier;
	for (let tier = 0; tier <= sub_tier; tier++) HUD.CONTEXT.AddClass(`SubTier_${tier}`);
	HUD.CONTEXT.SetDialogVariable("sub_state_text", $.Localize(`#sub_${sub_tier}`, HUD.CONTEXT));
}

function ToggleCollectionShow() {
	LoadCollection();
	HUD.CONTEXT.ToggleClass("Show");
	if (!HUD.CONTEXT.BHasClass("Show")) $.DispatchEvent("DropInputFocus");
}

GameUI.Collection.OpenSpecificTab = (tab_name, b_skip_open_collection) => {
	LoadCollection();
	const tab = $(`#Tab_${tab_name}`);
	if (!tab || !tab.Open) return;
	if (!b_skip_open_collection) HUD.CONTEXT.AddClass("Show");
	tab.Open();
};

GameUI.Collection.Show = () => {
	LoadCollection();
	HUD.CONTEXT.AddClass("Show");
};

// Panorama loads the images of every panel that exists, even hidden: the collection parks its art and builds its
// tabs, with all their item images, only when first opened.
let RestoreCollectionArt;
function LoadCollection() {
	if (!RestoreCollectionArt) return;
	RestoreCollectionArt();
	RestoreCollectionArt = undefined;
	InitContent();
}
function ForwardToCosmetics(name, owner) {
	const stub = (...args) => {
		LoadCollection();
		if (owner()[name] !== stub) owner()[name](...args);
	};
	return stub;
}

(() => {
	GameUI.Custom_ToggleCollection = ToggleCollectionShow;

	InitFreeCollectionLabel();
	RestoreCollectionArt = ParkImages(HUD.CONTEXT, [
		[HUD.CONTEXT.FindChildrenWithClassTraverse("C_Glow")[0], "s2r://panorama/images/custom_game/collection/glow_png.vtex"],
	]);
	// Other layouts call into the cosmetics tab before it exists; its script replaces these on load.
	GameUI.Cosmetics = { OpenSpecificCollectionTab: ForwardToCosmetics("OpenSpecificCollectionTab", () => GameUI.Cosmetics) };

	GameUI.Player.RegisterForPlayerDataChanges(UpdatePlayerData);
})();
