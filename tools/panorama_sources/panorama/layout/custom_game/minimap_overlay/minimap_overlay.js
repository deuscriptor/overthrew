const CONTEXT = $.GetContextPanel();
const MAP_OVERLAY = $("#MapOverlay");

let timeout = 0;
function UpdateMinimapOverlay() {
	const minimap_buttons = FindDotaHudElement("GlyphScanContainer");
	const glyph_button = FindDotaHudElement("GlyphButton");

	if ((!minimap_buttons || !glyph_button) && timeout++ < 30) $.Schedule(1, UpdateMinimapOverlay);

	if (IsSpectating()) minimap_buttons.visible = false;

	minimap_buttons.style.backgroundImage = `url('s2r://panorama/images/custom_game/minimap_side_container_bg.png');`;
	glyph_button.style.marginTop = "-1px";

	const roshan_button = FindDotaHudElement("RoshanTimer");
	if (roshan_button) roshan_button.visible = false;
}

function OpenCollection() {
	CONTEXT.AddClass("CollectionSeen");
	GameUI.Custom_ToggleCollection();
}

const DEFAULT_MAP_STYLES = {
	minimap_block: {
		width: ["244px", "280px"],
		height: ["244px", "280px"],
		backgroundImage: "url('s2r://panorama/images/hud/reborn/bg_minimap_psd.vtex')",
		verticalAlign: "bottom",
	},
	minimap: {
		width: ["260px", "296px"],
		height: ["260px", "296px"],
		verticalAlign: "middle",
		horizontalAlign: "center",
	},
	GlyphScanContainer: {
		marginLeft: ["244px", "280px"],
		height: "280px",
		width: "84px",
		verticalAlign: "bottom",
	},
};

function ResetMapStyleByDefault() {
	const is_large_map = FindDotaHudElement("Hud").BHasClass("MinimapExtraLarge");

	Object.entries(DEFAULT_MAP_STYLES).forEach(([element_name, json_style]) => {
		const reset_style_valid_check = () => {
			const element = FindDotaHudElement(element_name);
			if (!element || !element.IsValid()) return $.Schedule(1, reset_style_valid_check);

			Object.entries(json_style).forEach(([_name, _value]) => {
				let value = _value;
				if (typeof _value == "object") value = _value[is_large_map ? 1 : 0];

				element.style[_name] = value;
			});
		};
		reset_style_valid_check();
	});
}

(() => {
	UpdateMinimapOverlay();

	const remove_dota_hud_element = function (id) {
		const element = FindDotaHudElement(id);
		if (element) element.DeleteAsync(0);
	};
	remove_dota_hud_element("HUDSkinMinimap");
	remove_dota_hud_element("HUDSkinFXGlyph");
	remove_dota_hud_element("HUDSkinTopBarBG");

	ResetMapStyleByDefault();
	$.RegisterEventHandler("PanelStyleChanged", FindDotaHudElement("minimap_block"), ResetMapStyleByDefault);
	$.RegisterEventHandler("PanelStyleChanged", MAP_OVERLAY, ResetMapStyleByDefault);

	const ability_hud_skin = FindDotaHudElement("HUDSkinAbilityContainerBG");
	ability_hud_skin.style.width = "100%";
	ability_hud_skin.style.marginRight = "200px";

	FindDotaHudElement("RadarButton").visible = false;
	FindDotaHudElement("glyph").visible = false;
	FindDotaHudElement("TormentorTimerContainer").visible = false;
})();
