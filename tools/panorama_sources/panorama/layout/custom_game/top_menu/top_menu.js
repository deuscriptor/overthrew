function HideDefaultButtons() {
	const menu = FindDotaHudElement("MenuButtons");
	for (const b of menu.Children()) b.visible = false;
}

(() => {
	HideDefaultButtons();
})();
