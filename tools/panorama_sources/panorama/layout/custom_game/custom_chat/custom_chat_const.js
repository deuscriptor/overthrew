const NON_BREAKING_SPACE = "\u00A0";
const BASE_MESSAGE_INDENT = "<child id='CustomChatFiller'>\u00A0";
const CONTEXT = $.GetContextPanel();
const FILLER_LENGTH = 72;

const GUILD_TAG_COLORS = {
	[DOTATeam_t.DOTA_TEAM_GOODGUYS]: ["#3375FF", "#66FFBF", "#BF00BF", "#F3F00B", "#FF6B00"],
	[DOTATeam_t.DOTA_TEAM_BADGUYS]: ["#FE86C2", "#A1B447", "#65D9F7", "#008321", "#A46900"],
};
const DEFAULT_GUILD_TAG_COLOR = "#ffffff";

const rank_classes = ["BronzeTier", "SilverTier", "GoldTier", "PlatinumTier", "MasterTier", "GrandmasterTier"];

const C_CHAT_ENUM = {
	PLAYER_NAME: 0,
	PLAYER_COLOR: 1,
	HERO_NAME: 2,
	PLAYER_COLOR_READABLE: 3,
};
const PLAYER_COLOR_MAPS = ["dota", "dota_tournament", "aa_map_5v5", "aa_map_3v3"];
// dark player colours (FFA brown, blue, purple) are lifted towards white to stay readable on the chat background
const MIN_CHAT_COLOR_LUMINANCE = 0.45;
function ReadableChatColor(color) {
	const match = /#([0-9a-f]{6})/i.exec(color || "");
	if (!match) return color;

	const rgb = [0, 2, 4].map((i) => parseInt(match[1].substr(i, 2), 16));
	const luminance = (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]) / 255;
	if (luminance >= MIN_CHAT_COLOR_LUMINANCE) return `#${match[1]}`;

	const mix = (MIN_CHAT_COLOR_LUMINANCE - luminance) / (1 - luminance);
	return `#${rgb.map((c) => Math.round(c + (255 - c) * mix).toString(16).padStart(2, "0")).join("")}`;
}
const C_CHAT_ACTIONS = {
	[C_CHAT_ENUM.PLAYER_NAME]: (player_id) => {
		return Players.GetPlayerName(player_id);
	},
	[C_CHAT_ENUM.PLAYER_COLOR]: (player_id) => {
		if (PLAYER_COLOR_MAPS.includes(MAP_NAME)) return GetHEXPlayerColor(player_id);
		else return GameUI.GetTeamColor(Players.GetTeam(player_id));
	},
	[C_CHAT_ENUM.PLAYER_COLOR_READABLE]: (player_id) => {
		return ReadableChatColor(C_CHAT_ACTIONS[C_CHAT_ENUM.PLAYER_COLOR](player_id));
	},
	[C_CHAT_ENUM.HERO_NAME]: (player_id) => {
		const hero_id = Players.GetPlayerHeroEntityIndex(player_id);
		if (!hero_id) return "";

		return $.Localize(Entities.GetUnitName(hero_id));
	},
};
const MAX_CHAT_SIZE = 15;
