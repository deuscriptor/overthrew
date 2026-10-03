const CONTEXT = $.GetContextPanel();
const _rarities = GameUI.Inventory.GetRaritiesDefinition();
const TIERS_COLORS = {
	[_rarities.COMMON]: "#a7b2ce",
	[_rarities.UNCOMMON]: "#5a92cd",
	[_rarities.RARE]: "#4867f1",
	[_rarities.MYTHICAL]: "#834af5",
	[_rarities.LEGENDARY]: "#d033e2",
	[_rarities.IMMORTAL]: "#cc9e35",
	[_rarities.ARCANA]: "#a3d857",
	[_rarities.UNIQUE]: "#d80f00",
};

// The collection's tooltip for one cosmetic: name, rarity and description.
function UpdateTooltip() {
	if (!CONTEXT.arrow_color_updated) {
		const parent = CONTEXT.GetParent().GetParent();
		const set_color = (name) => {
			parent.FindChildTraverse(name).style.washColor = "#131627";
		};
		set_color("TopArrow");
		set_color("RightArrow");
		set_color("BottomArrow");
		set_color("LeftArrow");
		CONTEXT.arrow_color_updated = true;
	}

	let items = CONTEXT.GetAttributeString(`items`, undefined);
	const items_parsed = items != undefined && items != "undefined" && items != "" ? JSON.parse(items) : undefined;
	const first_item = items_parsed ? Object.entries(items_parsed)[0] : undefined;

	const item_name = first_item ? first_item[0] : "no_item";
	const item_count = first_item ? first_item[1] : 0;
	CONTEXT.SetDialogVariableInt("count", GameUI.Inventory.GetItemCount(item_name) || 0);

	const item_rarity = GameUI.Inventory.GetItemRarity(item_name) || 1;
	const rarity_color = TIERS_COLORS[item_rarity];

	CONTEXT.SetDialogVariable("item_name", LocalizeItemName(item_name));

	const unique_desc_key = `#${item_name}_description`;
	let description = $.Localize(unique_desc_key, CONTEXT);
	if (unique_desc_key == `#${description}`) {
		const slot = GameUI.Inventory.GetItemSlot(item_name);
		const default_desc_key = slot != undefined ? GameUI.Inventory.GetItemSlotName(item_name) : "none";
		description = $.Localize(`#default_item_description_${default_desc_key}`, CONTEXT);
	}

	CONTEXT.SetDialogVariable("item_description", description);
	CONTEXT.SetHasClass("BManyItems", item_count > 0);

	$(`#CI_Name`).style.backgroundColor =
		`gradient(linear, 0% 0%, 100% 0%, ` + `from(${rarity_color}33), to (${rarity_color}03))`;
	$(`#CI_RarityOverlay`).style.backgroundColor =
		`gradient(linear, 0% 0%, 100% 0%, ` +
		`from(${rarity_color}14), color-stop(0.25, ${rarity_color}), color-stop(0.75, ${rarity_color}), to(transparent));`;
	$("#CI_MainInfo").style.backgroundColor =
		`gradient(linear, 0% 0%, 80% 250%, ` + `from(${rarity_color}26), to(${rarity_color}03))`;

	const rarity_name = GameUI.Inventory.GetRarityName(item_rarity);
	$("#CI_RarityName").text = $.Localize("#item_tooltip_rarity").replace(
		"##rarity_name##",
		`<font color='${rarity_color}'>${$.Localize(`#rarity_${rarity_name}`)}</font>`,
	);
}
