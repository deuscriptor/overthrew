DEFAULT_MATCH_LENGTH = 1200

TEAM_COLORS = {
	[DOTA_TEAM_GOODGUYS] = { 61, 210, 150 },
	[DOTA_TEAM_BADGUYS]  = { 243, 201, 9 },
	[DOTA_TEAM_CUSTOM_1] = { 197, 77, 168 },
	[DOTA_TEAM_CUSTOM_2] = { 255, 108, 0 },
	[DOTA_TEAM_CUSTOM_3] = { 52, 85, 255 },
	[DOTA_TEAM_CUSTOM_4] = { 101, 212, 19 },
	[DOTA_TEAM_CUSTOM_5] = { 129, 83, 54 },
	[DOTA_TEAM_CUSTOM_6] = { 27, 192, 216 },
	[DOTA_TEAM_CUSTOM_7] = { 199, 228, 13 },
	[DOTA_TEAM_CUSTOM_8] = { 140, 42, 244 },
}

TEAMS_LAYOUTS = {
	["ot3_necropolis_ffa"] = {
		player_count = 1,
		teamlist = {
			DOTA_TEAM_GOODGUYS,
			DOTA_TEAM_BADGUYS,
			DOTA_TEAM_CUSTOM_1,
			DOTA_TEAM_CUSTOM_2,
			DOTA_TEAM_CUSTOM_3,
			DOTA_TEAM_CUSTOM_4,
			DOTA_TEAM_CUSTOM_5,
			DOTA_TEAM_CUSTOM_6,
		},
		-- these are ADDED to basic 960 / 720
		ring_bonuses = {
			gpm = 900,
			xpm = 1440,
		},
		ring_radius = 1100,
		overboss_throw_chance = 3, -- x2 on FFA map
		kill_goal = 30,
		abandon_kill_goal_reduction = 2,
		kills_by_vote = 1,
		time_by_vote = 30,
		game_base_duration = DEFAULT_MATCH_LENGTH,
		respawn_time = {
			11, 10, 9, 8, 7, 6, 5, 4
		},

		common_upgrade_progress = {
			6, 7.3, 8.9, 10.9, 13.2, 16.2, 19.7, 24
		},
		-- bar starts at 2 kills, incremented by 3 after every 1 orb granted
		rare_upgrade_basic_requirement = 2,
		rare_upgrade_requirement_increment = 3,
		rare_upgrade_requirement_step = 1,
		capture_point_time = 5,
		capture_point_radius = 250,
		flying_item_drop_time = 120, -- x2 on FFA map
		center_vision_reveal_radius = 1200,
		tower_attack_range = 1050,

		starting_drop_weights = {},

		gg_token_kill_goal_bonus = 10,
		rating_changes = {28, 20, 12, 4, -4, -12, -20, -28},
		stalemate_game_time_limit = 180,

		leader_overthrow_reward_min = 4,
		leader_overthrow_reward_max = 5,
		leader_overthrow_threshold = 5,

		min_connected_players = 2,
	},
}

PREGAME_TIME = 20

GAME_DURATION_OPTIONAL_EARLY_CONSUMABLES_TIME = 20

LEADER_KILL_GOLD_REWARD_PER_DIFFERENCE = 60
LEADER_KILLS_TO_DIFFERENCE = 2
GOLD_TO_EXP_RATIO = 1
NONLEADER_KILL_MULTIPLIER = 0.5

UPGRADE_RARITY_COMMON = 1
UPGRADE_RARITY_RARE = 2
UPGRADE_RARITY_EPIC = 4

function IsFlatRerollMap()
	return IsEpicOnlyMap()
end

function IsTurboMode()
	return HostOptions ~= nil and HostOptions.locked == true and HostOptions:GetOption("turbo")
end

function IsEpicOnlyMap()
	return HostOptions ~= nil and HostOptions:GetOption("epic_orbs")
end

function IsSingleDraftMap()
	return HostOptions ~= nil and HostOptions:GetOption("single_draft")
end

function ResolveOrbRarity(rarity)
	return IsEpicOnlyMap() and UPGRADE_RARITY_EPIC or rarity
end

-- TODO: revert
COMMON_UPGRADES_REQUIREMENT = 1000 -- (IsInToolsMode() and 50) or 1000

COURIER_PICKUP_BLACKLIST = {
	["item_gold_coin"] = true,
	["item_common_orb"] = true,
	["item_rare_orb"] = true,
	["item_epic_orb"] = true,
}

RING_RADIUS_MINIMUM = 300
-- sector-based orb random variables
RING_SECTOR_COUNT = 8
ADJACENT_SECTOR_FACTOR = 0.5 -- basically 50% of a total weight from dropped orb goes to immediate sector neighbors
RARITY_WEIGHT_MULTIPLIER = 4.0
INVERSED_WEIGHT_MULTIPLIER = 5.0 -- basically how much do we want random to bias towards least dropped epic spawn points
RING_RADIUS_PER_ORB = 200 -- radius is capped to value in per-map config
EPIC_ORB_WEIGHT = 40

OVERBOSS_ORB_THROW_MULTIPLIER_PCT = 150
OVERBOSS_ORB_THROW_MULTIPLIER_PCT_CHANGE_PER_MINUTE = -5
OVERBOSS_ORB_THROW_MULTIPLIER_MIN_CAP = 75
OVERBOSS_ORB_THROW_MULTIPLIER_MAX_CAP = 99999

OVERBOSS_ORB_THROW_RARE_PCT = 0
OVERBOSS_ORB_THROW_RARE_PCT_CHANGE_PER_MINUTE = 5
OVERBOSS_ORB_THROW_RARE_PCT_MAX_CAP = 50

OVERBOSS_ORB_THROW_EPIC_PCT = -25
OVERBOSS_ORB_THROW_EPIC_PCT_CHANGE_PER_MINUTE = 2.5
OVERBOSS_ORB_THROW_EPIC_PCT_MAX_CAP = 25

REROLL_PRICES = {
	[UPGRADE_RARITY_COMMON] = 1,
	[UPGRADE_RARITY_RARE] = 2,
	[UPGRADE_RARITY_EPIC] = 4
}

RANDOM_BONUS_ITEMS = { "item_faerie_fire", "item_enchanted_mango" }

MAX_NEUTRAL_ITEMS_PER_PLAYER = 1

PRINT_EXTENDED_DEBUG = false
DEV_BOTS_ENABLED = false
DEV_RANDOM_WINRATES = false
DEV_ENABLE_SPECTATOR_TEAM = false
DEV_ORB_DROP_PINGS = false

RATING_MULTIPLIER = 0.0125
RATING_CHANGE_CAP = 20

-- 10 minutes for simulated end game, makes sure we won't hog dedicated servers with neverending games
SIMULATED_END_GAME_DELAY = 600

DEVELOPERS = {
	["76561198132422587"] = true, -- Sanctus Animus
	["76561198064622537"] = true, -- Sheodar
	["76561198015161808"] = true, -- Cookies
    ["76561198007141460"] = true, -- Firetoad
    ["76561198188258659"] = true, -- Luminance
    ["76561199069138789"] = true, -- Dota 2 unofficial
    ["76561198054211176"] = true, -- Snoresville
    ["76561198040469212"] = true, -- Draze22
	["76561198007063562"] = true, -- Daser27
}


KNOWN_LOCALE_ALIASES = {
	eng = "english",
	en = "english",
	ru = "russian",
	fr = "french"
}

END_GAME_PLAYER_COUNT_CHECK_ENABLED = not IsInToolsMode()
