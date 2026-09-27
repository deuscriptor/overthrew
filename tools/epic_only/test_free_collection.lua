LOCAL_FREE_COLLECTION = true
IsInToolsMode = function() return true end
EventStream = {Listen = function() end}
EventDriver = {Listen = function() end, Dispatch = function() end}
PlayerResource = {GetPlayer = function() return {} end, IsValidPlayerID = function(_, id) return id == 0 end}
IsValidEntity = function(v) return v ~= nil end
local sent = {}
CustomGameEventManager = {Send_ServerToPlayer = function(_, _, event, data) sent[event] = data end}
CreateHTTPRequest = function() error("Unexpected backend request") end
local originalRequire = require
require = function() end
ITEM_TYPES = {EQUIPMENT=1, CONSUMABLE=2}
ITEM_DEFINITIONS = {
    hat={slot="2", type=1, rarity=1, unlocked_with={currency=500}},
    treat={slot="99", type=2, rarity=1},
}
BattlePass = {ApplyItemFilters = function() end}
dofile("scripts/vscripts/libraries/webapi/webapi.lua")
dofile("scripts/vscripts/libraries/webapi/player.lua")
dofile("scripts/vscripts/libraries/webapi/inventory/inventory.lua")
WebPlayer.players_data[0] = {currency=7, subscription={tier=0}}
assert(WebPlayer:GetSubscriptionTier(0) == 2 and WebPlayer:GetSubscriptionTier(1) == 2)
WebPlayer:UpdateClient(0)
assert(sent["WebPlayer:update"].player_data.subscription.tier == 2)
assert(WebPlayer.players_data[0].subscription.tier == 0, "Backend entitlement must not be overwritten")
assert(WebInventory:HasItem(0, "hat") and not WebInventory:HasItem(0, "unknown"))
assert(WebInventory:GetItemCost("hat") == 0)
WebInventory:PurchaseItem(0, "hat", 500, 1)
assert(sent["WebInventory:update"].items.hat.count == 1)
local used = false
WebInventory:ConsumeItem(0, "treat", 1, function() used = true end)
assert(used and WebInventory:GetItemCount(0,"treat") == 999)
-- The GG token is refused (before it is consumed) while the host has fixed the kill goal.
ITEM_DEFINITIONS.bp_gg_token = {type=1, rarity=1, on_consume=function(player_id) used = player_id end}
GetMapName = function() return "ot3_necropolis_ffa" end
local fixed, errors = true, {}
GameLoop = {HasFixedKillGoal = function() return fixed end}
DisplayError = function(player_id, message) table.insert(errors, {player_id, message}) end
ErrorTracking = {Try = function(fn, ...) return fn(...) end}
used = false
WebInventory:ItemConsumeEvent({PlayerID=0, item_name="bp_gg_token"})
assert(not used and errors[1][1] == 0 and errors[1][2] == "#dota_hud_error_gg_token_fixed_kill_goal")
fixed = false
WebInventory:ItemConsumeEvent({PlayerID=0, item_name="bp_gg_token"})
assert(used == 0 and #errors == 1, "other maps keep the GG token")
WebInventory:SetPlayerItems(0, {})
assert(WebInventory:HasItem(0,"hat"), "Backend refresh must not remove local access")
WebPlayer:UseCurrency(0, 500, function() end)
WebPlayer:AddBackendCurrency(0, 500)
assert(WebPlayer:GetCurrency(0) == 7)
for _, path in ipairs({"inventory/purchase_item", "inventory/set_equipped_items", "payments/get_payment_url", "match/after", "match/add_currency", "match/spend_currency"}) do
    WebApi:Send("api/lua/" .. path, {}, function() error("Must not report backend success") end)
end
Timers = {CreateTimer = function() error("Equipment must not schedule backend writes") end}
INVENTORY_SLOTS = {PET="5", SPRAY="1", COSMETIC_SKILL="6"}
dofile("scripts/vscripts/libraries/webapi/inventory/equipment.lua")
MatchEvents = {event_handlers = {}}
dofile("scripts/vscripts/libraries/webapi/payments.lua")
require = originalRequire
print("PASS free collection: local premium, all items, zero cost, reusable consumables, unchanged account data and blocked backend writes")
