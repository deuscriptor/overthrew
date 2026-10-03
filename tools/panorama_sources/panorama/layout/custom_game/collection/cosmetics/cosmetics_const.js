const SORT_FUNCTIONS = {
	default: function (a, b) {
		return b.loc_name > a.loc_name ? 1 : b.loc_name == a.loc_name ? 0 : -1;
	},
	rarity_up: function (a, b) {
		return a.rarity - b.rarity || SORT_FUNCTIONS["default"](a, b);
	},
	rarity_down: function (a, b) {
		return b.rarity - a.rarity || SORT_FUNCTIONS["default"](a, b);
	},
};
