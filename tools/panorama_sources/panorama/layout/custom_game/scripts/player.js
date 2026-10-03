let PLAYER_DATA = {};
let PLAYER_DATA_CHANGED_LISTENERS = [];

function _UpdatePlayerData(event) {
	if (!event || !event.player_data) return;
	PLAYER_DATA = event.player_data;

	_Notify(PLAYER_DATA_CHANGED_LISTENERS, PLAYER_DATA);
}

GameUI.Player = {};

/**
 * Returns local player subscription tier (premium benefits are local: every player has tier 2).
 *
 * If local player data is not loaded (or missing), returns 0.
 * @returns {Number}
 */
GameUI.Player.GetSubscriptionTier = function () {
	return PLAYER_DATA.subscription ? PLAYER_DATA.subscription.tier : 0;
};

/**
 * Returns table with local player settings, with setting name being the key.
 * @returns {Object}
 */
GameUI.Player.GetSettings = function () {
	return PLAYER_DATA.settings ? PLAYER_DATA.settings : {};
};

/**
 * Returns settings value under passed `setting_name`.
 * @param {String} setting_name
 * @returns
 */
GameUI.Player.GetSettingValue = function (setting_name) {
	return GameUI.Player.GetSettings()[setting_name];
};

/**
 * Sets setting value under `name` to `value` for the rest of the match.
 * @param {String} name
 * @param {any} value
 */
GameUI.Player.SetSettingValue = function (name, value) {
	PLAYER_DATA.settings = PLAYER_DATA.settings || {};

	PLAYER_DATA.settings[name] = value;

	GameEvents.SendToServerEnsured("WebSettings:set_setting_value", {
		setting_name: name,
		setting_value: value,
	});
};

/**
 * Register a `callback` to be called whenever local player data changes.
 * @param {CallableFunction} callback
 */
GameUI.Player.RegisterForPlayerDataChanges = function (callback) {
	PLAYER_DATA_CHANGED_LISTENERS.push(callback);
	if (Object.keys(PLAYER_DATA).length > 0) callback(PLAYER_DATA);
};

PLAYER_DATA_REQUESTED = false;

(() => {
	GameEvents.SubscribeProtected("WebPlayer:update", _UpdatePlayerData);

	GameEvents.Subscribe("game_rules_state_change", () => {
		// request once we reach hero selection (or later, if reconnected), but only once in client lifetime
		if (Game.GameStateIsBefore(DOTA_GameState.DOTA_GAMERULES_STATE_HERO_SELECTION)) return;
		if (PLAYER_DATA_REQUESTED) return;
		PLAYER_DATA_REQUESTED = true;
		GameEvents.SendToServerEnsured("WebPlayer:get_data", {});
	});
})();
