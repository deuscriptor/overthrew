-- custom attachment to indicate that particle is using status effect
-- which can only be created as a part of modifier
PATTACH_SPECIAL_STATUS_FX = "STATUS_FX"

-- equipment slots enum, shared with Panorama (INVENTORY_SLOT in scripts/inventory.js)
INVENTORY_SLOTS = {
	SPRAY = "1",
	AURA = "2",
	HERO_EFFECT = "3",
	KILL_EFFECT = "4",
	PET = "5",
	COSMETIC_SKILL = "6",
	HIGH_FIVE = "7",
}

-- item types, describes possible actions done to item
ITEM_TYPES = {
	EQUIPMENT = 1,
}

-- WARNING: integer values used must ascend, since some places are using rarity as a threshold
-- discarding lower or higher values
-- breaking the order WILL break the logic in said places
ITEM_RARITIES = {
	COMMON = 1,
	UNCOMMON = 2,
	RARE = 3,
	MYTHICAL = 4,
	LEGENDARY = 5,
	IMMORTAL = 6,
	ARCANA = 7,

	UNIQUE = 99,
}


-- equipment policies for item slots
EQUIPMENT_POLICY = {
	-- previously equipped item is unequipped automatically
	-- particles, modifiers and units returned from special callback (if any, otherwise from default creation) are saved and destroyed automatically
	-- allows exactly one equipped item per slot
	AUTO = 0,
	-- same as above, but skips default effect creation on equip
	-- this allows items with playable particles (such as kill effect / deny effect) to use default equip flow
	AUTO_SKIP_EFFECT_ON_EQUIP = 1,
	-- unequipping and assets lifetime should be managed manually in equip callback
	-- used if you want to have multiple equipped items in slot
	-- or some complex interaction with previous equipped items
	MANUAL = 10,
}

-- unspecified slots default to AUTO
SLOT_EQUIPMENT_POLICY = {
	-- all of these are using default flow, with particles being created externally (either triggered from events or from abilities)
	[INVENTORY_SLOTS.SPRAY] = EQUIPMENT_POLICY.AUTO_SKIP_EFFECT_ON_EQUIP,
	[INVENTORY_SLOTS.KILL_EFFECT] = EQUIPMENT_POLICY.AUTO_SKIP_EFFECT_ON_EQUIP,
	[INVENTORY_SLOTS.COSMETIC_SKILL] = EQUIPMENT_POLICY.AUTO_SKIP_EFFECT_ON_EQUIP,
	[INVENTORY_SLOTS.HIGH_FIVE] = EQUIPMENT_POLICY.AUTO_SKIP_EFFECT_ON_EQUIP,
}

ITEM_DEFINITIONS = {}


-- maximum amount of tips player can use in a single game
TIPS_PER_GAME_MAX = 3
-- currency amount announced per tip (display only - nothing is credited)
TIPS_CURRENCY_PER_TIP = 50
-- cooldown of tip per player (on the one who tips)
TIPS_COOLDOWN = 30
