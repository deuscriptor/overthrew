-- Run from the addon root: lua tools/test_log_noise.lua
-- Issue #35: code that runs during normal play writes nothing to the console, and match events are not polled.
-- Production Lua runs against engine mocks; print and DeepPrintTable record what would reach the console.
local say = print
local printed = {}
print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	table.insert(printed, table.concat(parts, " "))
end
DeepPrintTable = function() table.insert(printed, "DeepPrintTable") end
local function silent(path)
	assert(#printed == 0, path .. " printed: " .. tostring(printed[1]))
end

-- Valve's class() copies the base class into the new one.
class = function(base) local c = {} for k, v in pairs(base or {}) do c[k] = v end return c end
IsInToolsMode = function() return false end
IsValidEntity = function(entity) return entity ~= nil and not entity.null end
ErrorTracking = {Try = function(callback, ...) return callback(...) end}
local unique = 0
DoUniqueString = function(prefix) unique = unique + 1 return prefix .. unique end
local entities = {}
EntIndexToHScript = function(index) return entities[index] end
local game_time = 0
GameRules = {GetGameTime = function() return game_time end, Script_GetMatchID = function() return 1 end}
local timers = {}
-- CreateTimer(delay, callback) or CreateTimer({endTime = ..., callback = ...})
Timers = {CreateTimer = function(_, delay, callback) table.insert(timers, callback or delay.callback) return #timers end, RemoveTimer = function() end}
local client_listeners = {}
CustomGameEventManager = {
	RegisterListener = function(_, name, callback) client_listeners[name] = callback return name end,
	UnregisterListener = function() end,
	Send_ServerToPlayer = function() end,
}
CCustomGameEventManager = CustomGameEventManager
CustomNetTables = {SetTableValue = function() end}
local player = {}
local hero = {IsIllusion = function() return false end, GetClones = function() return {} end}
PlayerResource = {
	GetPlayer = function() return player end,
	GetSelectedHeroEntity = function() return hero end,
	IsValidPlayerID = function(_, id) return id == 0 end,
	GetSteamID = function() return 76561198000000000 end,
}
DOTA_UNIT_ORDER_MOVE_TO_POSITION, DOTA_UNIT_ORDER_CAST_POSITION, DOTA_UNIT_ORDER_CAST_TARGET = 1, 3, 4
DOTA_UNIT_ORDER_PURCHASE_ITEM, DOTA_UNIT_ORDER_PICKUP_ITEM, DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION = 16, 15, 30
DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP, DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 2, 8

-- Server events: dispatching one that nobody listens to is normal.
dofile("scripts/vscripts/libraries/event_driver.lua")
EventDriver:Dispatch("GameMode:init_finished", {})
local heard
EventDriver:Listen("Test:event", function(data) heard = data.value end)
EventDriver:Dispatch("Test:event", {value = 1})
assert(heard == 1, "listeners still receive their events")
silent("an event without listeners")

-- Client events: every accepted event records a token, which expires after 15 seconds.
dofile("scripts/vscripts/libraries/event_stream.lua")
local purge = timers[#timers]
entities[1] = player
local rerolls = 0
EventStream:Listen("Upgrades:reroll", function() rerolls = rerolls + 1 end)
client_listeners["Upgrades:reroll"](1, {_id = "token_1", PlayerID = 0})
game_time = 20
purge()
assert(rerolls == 1 and EventStream.accepted_events.token_1 == nil, "the event runs and its token expires")
silent("a client event and its token expiry")

-- Item changes: heroes and illusions (whose items arrive before they count as illusions) gain items constantly.
Events = {}
local inventory_checks, assembly_checks = 0, 0
HostItems = {
	QueueInventoryCheck = function() inventory_checks = inventory_checks + 1 end,
	CheckAssembly = function() assembly_checks = assembly_checks + 1 end,
	IsDisabled = function() return false end,
}
entities[2], entities[3], entities[4] = hero, {IsIllusion = function() return true end}, {}
dofile("scripts/vscripts/events/inventory_item_change.lua")
for _, holder in ipairs({2, 3}) do
	Events:OnInventoryItemChange({item_entindex = 4, hero_entindex = holder, removed = false, dropped = false})
end
Events:OnInventoryItemChange({item_entindex = 4, hero_entindex = 2, removed = true, dropped = false})
assert(inventory_checks == 3 and assembly_checks == 2, "item changes still check the hero's inventory")
silent("item changes")

-- Orders: the fountain cast filter runs on every targeted cast of a listed spell.
Filters = {}
Vector = function(x, y, z) return {x = x, y = y, z = z} end
DisableHelp = {ExecuteOrderFilter = function() end}
BackpackItems = {FilterOrder = function() end}
local errors = {}
DisplayError = function(_, message) table.insert(errors, message) end
dofile("scripts/vscripts/filters/order.lua")
local on_fountain = false
hero.GetTeamNumber = function() return 2 end
hero.HasModifier = function(_, name) return on_fountain and name == "modifier_fountain_rejuvenation_effect_lua" end
entities[5] = {GetAbilityName = function() return "pudge_meat_hook" end}
entities[6] = {GetTeamNumber = function() return 3 end}
local function hook()
	return Filters:ExecuteOrderFilter({order_type = DOTA_UNIT_ORDER_CAST_TARGET, issuer_player_id_const = 0, queue = 0,
		entindex_target = 6, entindex_ability = 5, position_x = 0, position_y = 0, position_z = 0, units = {["0"] = 2}})
end
assert(hook() == true, "a hook away from the fountain goes through")
on_fountain = true
assert(hook() == false and errors[1] == "#dota_hud_error_cant_cast_this_on_fountain", "a hook from the fountain is refused")
silent("cast orders")

-- Upgrade data loads when a hero first spawns.
require = function() end
GenericUpgrades = {generic_upgrades_data = {}}
UpgradesUtilities = {ParseUpgrade = function() end}
UPGRADE_TYPE = {ABILITY = 2}
GetMapName = function() return "ot3_necropolis_ffa" end
LoadKeyValues = function(path)
	if path:find("/overrides/") then return {pudge_meat_hook = {damage = {value = 2}}} end
	return {pudge_meat_hook = {damage = {value = 1}, range = {value = 1}}}
end
dofile("scripts/vscripts/game/upgrades/upgrades.lua")
Upgrades:LoadUpgradesData("npc_dota_hero_pudge")
assert(Upgrades.upgrades_kv.npc_dota_hero_pudge.pudge_meat_hook.damage.value == 2, "the map override still applies")
silent("loading a hero's upgrades")

-- Modifier property getters run whenever the engine reads the property.
modifier_base_generic_upgrade = {}
dofile("scripts/vscripts/game/upgrades/generic_upgrades/modifier_generic_attack_projectile_speed_upgrade.lua")
local projectile_speed = setmetatable({bonus = 75}, {__index = modifier_generic_attack_projectile_speed_upgrade})
assert(projectile_speed:GetModifierProjectileSpeedBonus() == 75)
silent("the projectile speed upgrade")

-- Cosmetics: equipped on every hero spawn, and their effects play on kills.
dofile("scripts/vscripts/libraries/webapi/declarations.lua")
ITEM_DEFINITIONS.test_aura = {slot = INVENTORY_SLOTS.AURA, particles = {{path = "aura.vpcf", attach_type = 1}}, model_path = "aura.vmdl"}
ITEM_DEFINITIONS.test_kill_effect = {slot = INVENTORY_SLOTS.KILL_EFFECT,
	particles = {{path = "kill.vpcf", attach_type = 1, persists = false}}, particle_variants = {{path = "variant.vpcf", attach_type = 1}}}
WebInventory = {HasItem = function() return true end}
PrecacheManager = {PrecacheResourceListAsync = function(_, _, callback) callback() end}
local particles = 0
ParticleManager = {CreateParticle = function() particles = particles + 1 return particles end, ReleaseParticleIndex = function() end}
dofile("scripts/vscripts/libraries/webapi/inventory/equipment.lua")
Equipment:AssignEquippedItems(0, {[INVENTORY_SLOTS.AURA] = "test_aura"})
Equipment:ApplyEquippedItems(0)
Equipment:PlayItemEffects(0, "test_kill_effect", hero, 1)
assert(Equipment:GetEquippedItems(0)[INVENTORY_SLOTS.AURA] == "test_aura" and particles == 3, "cosmetics still equip and play")
silent("equipping and playing cosmetics")

-- Match start: the before-match request goes out once, and nothing polls the backend afterwards.
GetDedicatedServerKeyV2 = function() return "key" end
GetDedicatedServerKeyV3 = GetDedicatedServerKeyV2
CreateHTTPRequest = function(_, url) error("Unexpected backend request to " .. url) end
DebugMessage = function() end
dofile("scripts/vscripts/libraries/webapi/webapi.lua")
local before_match = 0
WebApi.RequestBeforeMatch = function() before_match = before_match + 1 end
local scheduled = #timers
for _, state in ipairs({DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP, DOTA_GAMERULES_STATE_GAME_IN_PROGRESS}) do
	EventDriver:Dispatch("Events:state_changed", {state = state})
end
assert(before_match == 1 and #timers == scheduled, "only the before-match request is sent, and no poll is scheduled")
dofile("scripts/vscripts/libraries/webapi/mail.lua")
dofile("scripts/vscripts/libraries/webapi/payments.lua")
assert(MatchEvents == nil, "mail and payments load without a match-event registry")
silent("the match start")

say("PASS log noise: silent event dispatch, client events, item changes, cast orders, upgrade loading, projectile speed, cosmetics; no match-event polling")
