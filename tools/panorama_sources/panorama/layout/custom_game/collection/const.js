const HUD = {
	CONTEXT: $.GetContextPanel(),
	TOP_BAR_BUTTONS_ROOT: $("#C_TopBar_ButtonsRoot"),
	TABS_ROOT: $("#C_Tabs"),
	CONTENT_ROOT: $("#C_Content"),
};
const GetC_Image = (extended_path) => {
	return `file://{images}/custom_game/collection/${extended_path}.png`;
};
const MAX_TIER_SUB = 3;
