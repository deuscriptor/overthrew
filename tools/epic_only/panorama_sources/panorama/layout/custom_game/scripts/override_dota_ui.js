function RemoveOT3Background() {
	var otBG = $.GetContextPanel().GetParent().GetParent().GetParent().FindChildTraverse("OT3BG");
	if (otBG) {
		otBG.DeleteAsync(0.1);
	}
}

function OverrideDotaNeutralItemsShop() {
	const shop_grid_1 = FindDotaHudElement("GridNeutralsCategory");
	if (!shop_grid_1) return;

	shop_grid_1.style.overflow = "squish scroll";

	shop_grid_1
		.FindChildTraverse("TeamNeutralItemsTierList")
		.Children()
		.forEach((panel) => {
			panel.FindChild("TierItemsList").style.flowChildren = "right-wrap";
		});
}

function MovePlayerPerformanceContainer() {
	const playerPerformanceContainer = FindDotaHudElement("player_performance_container");
	if (!playerPerformanceContainer) return;
	playerPerformanceContainer.style.marginTop = "13px";
}
function MoveMorphlingBar() {
	const player_info = Game.GetPlayerInfo(Game.GetLocalPlayerID());

	if (!player_info.player_selected_hero) return void $.Schedule(1, MoveMorphlingBar);
	if (player_info.player_selected_hero != "npc_dota_hero_morphling") return;

	const bar = FindDotaHudElement("MorphProgress");
	bar.style.marginLeft = "73px";
}

function UpdateFightRecap() {
	const fight_recap = FindDotaHudElement("FightRecap");
	fight_recap.style.marginTop = `${MAP_BASE_NAME == "ot3_necropolis_ffa" ? 75 : 50}px`;
}

function UpdateSidePanelPos() {
	const side_stats = FindDotaHudElement("stackable_side_panels");
	if (side_stats) side_stats.style.marginTop = "28px";
}

function CastBackpackItem(slot) {
	const unit = Players.GetLocalPlayerPortraitUnit();
	if (!Entities.IsControllableByPlayer(unit, Players.GetLocalPlayer())) return;
	const item = Entities.GetItemInSlot(unit, slot);
	// Starts native targeting; the server performs the cast from the backpack.
	if (item !== -1) Abilities.ExecuteAbility(item, unit, false);
}

function SetupBackpackItems() {
	const rules = CustomNetTables.GetTableValue("game_options", "match_rules");
	if (!rules || rules.locked !== 1) return void $.Schedule(0.5, SetupBackpackItems);
	if (rules.backpack_items !== 1) return;
	for (let slot = 6; slot <= 8; slot++) {
		const panel = FindDotaHudElement(`inventory_slot_${slot}`);
		if (!panel) return void $.Schedule(0.5, SetupBackpackItems);
		const button = panel.FindChildTraverse("AbilityButton") || panel;
		button.SetPanelEvent("onactivate", () => CastBackpackItem(slot));
	}
}

(function () {
	// OverrideDotaNeutralItemsShop();
	RemoveOT3Background();
	MovePlayerPerformanceContainer();
	MoveMorphlingBar();
	UpdateFightRecap();
	UpdateSidePanelPos();
	SetupBackpackItems();
})();
