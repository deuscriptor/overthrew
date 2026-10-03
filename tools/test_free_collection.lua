-- Run from the addon root: lua tools/test_free_collection.lua
-- The collection is local: premium tier 2 and every cosmetic for everyone, settings per match, no backend.
EventStream = {Listen = function() end}
PlayerResource = {GetPlayer = function() return {} end, IsValidPlayerID = function(_, id) return id == 0 or id == 1 end}
IsValidPlayerID = function(id) return id == 0 or id == 1 end
IsValidEntity = function(v) return v ~= nil end
local sent = {}
CustomGameEventManager = {Send_ServerToPlayer = function(_, _, event, data) sent[event] = data end}
CreateHTTPRequest = function() error("Unexpected backend request") end
local errors = {}
DisplayError = function(player_id, message) table.insert(errors, {player_id, message}) end
toboolean = function(value) return value == true or value == 1 or value == "1" or value == "true" end
local originalRequire = require
require = function() end
dofile("scripts/vscripts/libraries/webapi/declarations.lua")
dofile("scripts/vscripts/libraries/webapi/player.lua")
dofile("scripts/vscripts/libraries/webapi/settings.lua")

-- Every definition shipped with the addon is a free cosmetic: equipment in one of the slots, with no price,
-- treasure or subscription requirement left.
for _, file in ipairs({"kill_effects", "auras", "pets", "hero_effects", "sprays", "cosmetic_skills", "high_fives"}) do
    dofile("scripts/vscripts/libraries/webapi/item_definitions/" .. file .. ".lua")
end
local slots, count = {}, 0
for _, slot in pairs(INVENTORY_SLOTS) do slots[slot] = true end
for name, definition in pairs(ITEM_DEFINITIONS) do
    assert(definition.type == ITEM_TYPES.EQUIPMENT and slots[definition.slot] and definition.rarity, name .. " is a cosmetic")
    assert(definition.unlocked_with == nil and definition.on_use == nil and definition.on_consume == nil, name .. " has no unlock or use")
    count = count + 1
end
assert(count >= 100, "the collection is loaded")
dofile("scripts/vscripts/libraries/webapi/inventory/inventory.lua")

assert(WebPlayer:GetSubscriptionTier(0) == 2 and WebPlayer:GetSubscriptionTier(1) == 2)
WebPlayer:UpdateClient(0)
assert(sent["WebPlayer:update"].player_data.subscription.tier == 2)

for name in pairs(ITEM_DEFINITIONS) do assert(WebInventory:HasItem(0, name)) end
assert(not WebInventory:HasItem(0, "bp_reroll") and not WebInventory:HasItem(0, "unknown"))
WebInventory:UpdateClient(0)
local client_count = 0
for name, item in pairs(sent["WebInventory:update"].items) do
    assert(ITEM_DEFINITIONS[name] and item.count == 1)
    client_count = client_count + 1
end
assert(client_count == count, "the client gets every item")

ITEM_DEFINITIONS.broken = {slot = INVENTORY_SLOTS.AURA, rarity = 1}
assert(not pcall(WebInventory.ValidateDefinitions, WebInventory), "a definition without a type is refused")
ITEM_DEFINITIONS.broken = nil

-- Settings toggled in the upgrades panel last for the match and reach the client with the player data.
WebSettings:SetSettingValueEvent({PlayerID = 0, setting_name = "generic_from_subscription", setting_value = 1})
assert(WebSettings:GetSettingValue(0, "generic_from_subscription") == true, "0/1 become booleans")
assert(sent["WebPlayer:update"].player_data.settings.generic_from_subscription == true)
WebSettings:SetSettingValueEvent({PlayerID = 0, setting_name = "auto_select_favorites_delay", setting_value = 6})
assert(WebSettings:GetSettingValue(0, "auto_select_favorites_delay") == 6)
WebSettings:SetSettingValueEvent({PlayerID = 0, setting_name = "auto_select_favorites", setting_value = 0})
assert(WebSettings:GetSettingValue(0, "auto_select_favorites") == false)
WebSettings:SetSettingValueEvent({PlayerID = 0, setting_name = "hide_streaks", setting_value = 1})
assert(WebSettings:GetSettingValue(0, "hide_streaks") == nil and errors[1][2] == "#dota_hud_error_invalid_setting", "unknown settings are refused")
assert(WebSettings:GetSettingValue(1, "generic_from_subscription", false) == false, "settings are per player")
require = originalRequire
print("PASS free collection: local premium, every cosmetic owned and free, settings per match, no backend")
