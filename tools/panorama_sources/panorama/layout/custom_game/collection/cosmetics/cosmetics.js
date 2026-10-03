const CONTEXT = $.GetContextPanel();
const TABS_ROOT = $("#CC_Tabs");
const CONTENT_ROOT = $("#CC_ContentRoot");
const SORT_SELECTOR = $("#CC_SortingOptions");

GameUI.Cosmetics = {};

// Every cosmetic is free: the only action is equipping or taking it off.
function ToggleEquipped(item) {
	if (HUD.CONTEXT.BHasClass("EquipCooldown")) return;
	HUD.CONTEXT.AddClass("EquipCooldown");
	$.Schedule(0.15, () => {
		HUD.CONTEXT.RemoveClass("EquipCooldown");
	});

	if (item.BHasClass("BEquipped")) GameUI.Inventory.UnequipItem(item.item_name);
	else GameUI.Inventory.EquipItem(item.item_name);
}

function UpdateActionButtonForItem(item) {
	const button = item.FindChild("CI_ActionButton");
	const equipped = item.BHasClass("BEquipped");
	item.AddClass("BAvailable");
	item.AddClass(item.type_name);
	button.GetChild(2).text = $.Localize(`#action_${item.type_name}${equipped ? "_TAKE_OFF" : ""}`);
	button.SetPanelEvent("onactivate", () => ToggleEquipped(item));
}

const ITEM_PANELS = [];
function FillCosmeticItems(items) {
	const types_names_by_enum = Object.fromEntries(
		Object.entries(GameUI.Inventory.GetTypesDefinition()).map((a) => a.reverse()),
	);
	Object.entries(items).forEach(([name, definition]) => {
		const slot_name = GameUI.Inventory.GetItemSlotName(name);
		if (!slot_name) return;

		const root_for_item = $(`#CC_Content_${slot_name}`);
		if (!root_for_item) return;

		const item = $.CreatePanel("Panel", root_for_item, `Cosmetic_Item_${name}`);
		item.BLoadLayoutSnippet("Cosmetic_Item");
		item.AddClass(name);
		item.AddClass(slot_name);

		const loc_name = LocalizeItemName(name);
		item.loc_name = loc_name;

		item.SetDialogVariable("item_name", loc_name);
		item.SetDialogVariableInt("item_count", 0);

		item.SetHasClass("BEquipable", definition.type == GameUI.Inventory.GetTypesDefinition().EQUIPMENT);
		item.type_name = types_names_by_enum[definition.type];

		if (definition.is_hidden != undefined) item.SetHasClass("BHidden", definition.is_hidden == 1);

		item.slot = definition.slot;
		item.slot_name = slot_name;
		item.rarity = definition.rarity;
		item.rarity_name = GameUI.Inventory.GetRarityName(definition.rarity);
		item.image_path = GameUI.Inventory.GetItemImagePath(name);
		item.item_name = name;

		item.AddClass(item.rarity_name);

		const item_image = item.FindChildTraverse("CI_Image");
		item_image.SetImage(item.image_path);

		UpdateActionButtonForItem(item);
		ITEM_PANELS.push(item);

		item.SetPanelEvent("onmouseover", () => {
			item.RemoveClass("HighlightFocus");
			$.DispatchEvent(
				"UIShowCustomLayoutParametersTooltip",
				item_image,
				"CustomItem_Tooltip",
				"file://{resources}/layout/custom_game/collection/item_tooltip/item_tooltip.xml",
				BuildTooltipParams({
					items: { [name]: GameUI.Inventory.GetItemCount(name) },
				}),
			);
		});

		item.SetPanelEvent("onmouseout", () => {
			$.DispatchEvent("UIHideCustomLayoutTooltip", item, "CustomItem_Tooltip");
		});
	});
	SortItems("default");
}
GameUI.Cosmetics.OpenTab = {};
function InitTabs() {
	TABS_ROOT.RemoveAndDeleteChildren();
	CONTENT_ROOT.RemoveAndDeleteChildren();
	let cosmetic_tabs = Object.keys(GameUI.Inventory.GetSlotsDefinition());
	let b_first_tab = true;
	cosmetic_tabs.forEach((tab_name) => {
		const tab = $.CreatePanel("Button", TABS_ROOT, `CC_Tab_${tab_name}`);
		tab.BLoadLayoutSnippet("Cosmetic_Tab");
		tab.SetDialogVariableLocString("tab_name", tab_name);

		const content = $.CreatePanel("Panel", CONTENT_ROOT, `CC_Content_${tab_name}`);
		content.BLoadLayoutSnippet("Cosmetic_Content");
		content.AddClass(tab_name);

		const activate_content = () => {
			if (tab.BHasClass("BActive")) return;

			Game.EmitSound("General.ButtonClick");

			GameUI.ToggleSingleClassInParent(TABS_ROOT, tab, "BActive");
			GameUI.ToggleSingleClassInParent(CONTENT_ROOT, content, "BActive");
		};
		if (b_first_tab) activate_content();
		b_first_tab = false;

		GameUI.Cosmetics.OpenTab[tab_name] = activate_content;
		tab.SetPanelEvent("onactivate", activate_content);
	});
}

function ClearItems(func) {
	ITEM_PANELS.forEach((item_panel) => {
		func(item_panel);
		UpdateActionButtonForItem(item_panel);
	});
}

function UpdateOwnedItems(items) {
	ClearItems((item) => {
		item.RemoveClass("BOwned");
		item.SetDialogVariableInt("item_count", 0);
	});
	Object.entries(items).forEach(([item_name, item_data]) => {
		const item_panel = $(`#Cosmetic_Item_${item_name}`);
		if (!item_panel || item_data.count <= 0) return;
		item_panel.AddClass("BOwned");
		item_panel.SetDialogVariableInt("item_count", item_data.count);
	});
}
function UpdateEquippedItems(items) {
	ClearItems((item) => {
		item.RemoveClass("BEquipped");
	});

	Object.values(items).forEach((item_name) => {
		const item_panel = $(`#Cosmetic_Item_${item_name}`);
		if (!item_panel) return;
		item_panel.AddClass("BEquipped");
		UpdateActionButtonForItem(item_panel);
	});
}

function SortItems(sort_name) {
	CONTENT_ROOT.Children().forEach((items_root) => {
		for (const item of items_root.Children().sort(SORT_FUNCTIONS[sort_name])) {
			items_root.MoveChildBefore(item, items_root.GetChild(0));
		}
	});
	$.DispatchEvent("DropInputFocus");
	SORT_SELECTOR.SetSelected("sort_" + sort_name);
}

GameUI.Cosmetics.OpenSpecificCollectionTab = (tab_name, item_focus = "NONE") => {
	GameUI.Collection.OpenSpecificTab("cosmetics");
	GameUI.Cosmetics.OpenTab[tab_name]();

	const item_panel = $(`#Cosmetic_Item_${item_focus}`);
	if (!item_panel) return;

	ClearItems((item) => {
		item.RemoveClass("HighlightFocus");
	});

	item_panel.AddClass("HighlightFocus");
};

(() => {
	InitTabs();

	GameUI.Inventory.RegisterForDefinitionsChanges(FillCosmeticItems);
	GameUI.Inventory.RegisterForInventoryChanges(UpdateOwnedItems);
	GameUI.Inventory.RegisterForEquipmentChanges(UpdateEquippedItems);
})();
