dofile("scripts/vscripts/game/host_items.lua")
HostItems.QueueInventoryCheck = function() end -- Covered by test_host_settings.lua.
-- Run from the addon root: lua tools/test_orbs.lua
-- Executes production Lua; only engine/services and the upgrade rendering boundary
-- are mocked. This does not replace a Dota playtest of particles or compiled maps.
local real_print = print
local epic_orbs = false
local observations = {}
local entities = {}
local heroes = {}
local paused = false
local passed = 0

local function noop() end
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, callback)
    callback()
    passed = passed + 1
    real_print("PASS " .. name)
end

DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS, DOTA_TEAM_NEUTRALS = 2, 3, 4
for i = 1, 8 do _G["DOTA_TEAM_CUSTOM_" .. i] = 5 + i end
DOTA_UNIT_ORDER_CAST_TARGET, DOTA_UNIT_ORDER_CAST_POSITION = 5, 6
DOTA_UNIT_ORDER_PURCHASE_ITEM, DOTA_UNIT_ORDER_PICKUP_ITEM = 16, 17
DOTA_ModifyGold_PurchaseConsumable, PATTACH_ABSORIGIN_FOLLOW = 1, 1
LUA_MODIFIER_MOTION_NONE = 0

GetMapName = function() return "ot3_necropolis_ffa" end
IsInToolsMode = function() return false end
IsServer = function() return true end
IsValidEntity = function(entity) return type(entity) == "table" and not entity.removed end
IsValidPlayerID = function(id) return type(id) == "number" and id >= 0 end
Vector = function(x, y, z) return { x = x or 0, y = y or 0, z = z or 0 } end
class = function(value) return value or {} end
LinkLuaModifier, EmitGlobalSound = noop, noop
DeepPrintTable = noop
print = noop
RollPercentage = function(chance) observations.roll_chance = chance; return chance > 0 end
EntIndexToHScript = function(index) return entities[index] end
UTIL_Remove = function(entity) entity.removed = true end
GetGroundPosition = function(position) return position end

CustomNetTables = { SetTableValue = function(_, name, key, data)
    observations.net = observations.net or {}
    observations.net[name .. "/" .. key] = data
end }
EventStream = { Listen = noop }
EventDriver = { Listen = noop, Dispatch = function(_, name, data)
    observations.event_name, observations.event_data = name, data
end }
CustomGameEventManager = { Send_ServerToPlayer = function(_, player, name, data)
    observations.client_event = data
end }
HostOptions = { GetOption = function(_, name) return name == "epic_orbs" and epic_orbs end }
GameRules = { IsGamePaused = function() return paused end }
GenericUpgrades = { generic_upgrades_data = {} }
PlayerResource = {
    GetPlayer = function(_, id) return heroes[id] end,
    GetSelectedHeroEntity = function(_, id) return heroes[id] end,
    GetTeam = function(_, id) return heroes[id].team end,
}
CustomChat = {
    MessageToTeam = function(_, id, team, message) observations.chat = message end,
    MessageToAll = function(_, id, message) observations.chat = message end,
}
MVPController = { AddOrbCaptureScore = function(_, id, score) observations.mvp = score end }
EmitAnnouncerSoundForTeam = function(sound) observations.announcer = sound end
DisableHelp = { ExecuteOrderFilter = function() return true end }
BackpackItems = { FilterOrder = function() end } -- Covered by test_backpack_items.lua.
ParticleManager = {
    CreateParticle = function(_, name) observations.particle = name; return 1 end,
    SetParticleControl = noop,
}
CreateUnitByName = function()
    local unit = {
        SetOrigin = function(self, point) self.origin = point end,
        GetOrigin = function(self) return self.origin end,
        AddNewModifier = function(self, caster, ability, name, data)
            self.modifier_name, self.modifier_data = name, data
        end,
    }
    return unit
end

-- Skip unrelated modules required by production entrypoints; the modules under
-- test and rarity declarations are loaded explicitly, without rewriting code.
require = function() return true end
GameMode, Filters = {}, {}
dofile("scripts/vscripts/core_declarations.lua")
dofile("scripts/vscripts/game/upgrades/declarations.lua")
dofile("scripts/vscripts/game/upgrades/upgrades.lua")
dofile("scripts/vscripts/game/upgrades/rerolls.lua")
dofile("scripts/vscripts/game/game_loop.lua")
dofile("scripts/vscripts/game/end_game_stats.lua")
dofile("scripts/vscripts/game/capture_points/capture_points.lua")
dofile("scripts/vscripts/game/capture_points/capture_point_area.lua")
dofile("scripts/vscripts/filters/item.lua")
dofile("scripts/vscripts/filters/order.lua")

-- The selection UI/upgrade rolling is downstream of the behavior under test.
Upgrades.ShowSelection = function(self, hero, rarity, id)
    observations.shown_count = (observations.shown_count or 0) + 1
    observations.shown_rarity = rarity
    self.pending_selection[id] = { upgrade_rarity = rarity }
end

local function reset(epic)
    epic_orbs = epic
    observations, entities, heroes = {}, {}, {}
    paused = false
    Upgrades.queued_selection, Upgrades.pending_selection = {}, {}
    EndGameStats.orbs_collected = {}
    GameLoop.current_layout = TEAMS_LAYOUTS.ot3_necropolis_ffa
    GameLoop.current_kill_order = { [2] = 1 }
    GameLoop.heroes_by_team = {}
    GameLoop.common_upgrades_progress = { [2] = 0 }
    GameLoop.rare_upgrades_progress = { [2] = 0 }
    GameLoop.rare_upgrades_requirement = { [2] = GameLoop.current_layout.rare_upgrade_basic_requirement }
    GameLoop.rare_upgrades_filled_times = { [2] = 0 }
    for id = 0, 1 do
        local hero = {
            id = id, team = 2 + id,
            GetPlayerOwnerID = function(self) return self.id end,
            GetPlayerID = function(self) return self.id end,
            GetTeam = function(self) return self.team end,
            IsAlive = function() return true end,
            PassivesDisabled = function() return false end,
            FindModifierByName = function() return nil end,
            IsCourier = function() return false end,
            IsIllusion = function() return false end,
            SpendGold = function(self, amount) self.spent = (self.spent or 0) + amount end,
        }
        heroes[id] = hero
        GameLoop.heroes_by_team[hero.team] = { hero }
    end
end
local function queue_count(id) return #(Upgrades.queued_selection[id or 0] or {}) end
local function assert_queue(rarity, count, id)
    id = id or 0
    equal(queue_count(id), count, "selection count")
    for _, selection in ipairs(Upgrades.queued_selection[id] or {}) do equal(selection.rarity, rarity, "queued rarity") end
end

test("normal orbs retain all reward rarities and physical orb visuals", function()
    for _, rarity in ipairs({ 1, 2, 4 }) do
        reset(false)
        equal(ResolveOrbRarity(rarity), rarity)
        Upgrades:QueueSelection(heroes[0], rarity)
        assert_queue(rarity, 1)
        local orb = GameMode:SpawnOrbDrop(Vector(0, 0, 0), rarity, true)
        equal(orb.modifier_data.orb_type, rarity)
        equal(observations.particle, "particles/orb_" .. RARITY_ENUM_TO_TEXT[rarity] .. ".vpcf")
    end
end)

test("hero upgrade overrides load from the FFA map folder", function()
    reset(false)
    local loaded = {}
    LoadKeyValues = function(path)
        table.insert(loaded, path)
        return {}
    end
    Upgrades:LoadUpgradesData("npc_dota_hero_axe")
    equal(loaded[1], "scripts/upgrades/heroes/npc_dota_hero_axe.txt")
    equal(loaded[2], "scripts/upgrades/overrides/ot3_necropolis_ffa/npc_dota_hero_axe.txt")
end)

test("epic rewards queue a single epic selection", function()
    for _, rarity in ipairs({ 1, 2, 4 }) do
        reset(true)
        Upgrades:QueueSelection(heroes[0], rarity)
        assert_queue(4, 1)
        equal(observations.shown_rarity, 4)
    end
end)

test("physical epic capture keeps the source orb type and publishes epic stats/event", function()
    reset(true)
    local orb = GameMode:SpawnOrbDrop(Vector(12, 34, 0), 1, true)
    equal(orb.modifier_data.orb_type, 4)
    equal(orb.modifier_data.source_orb_type, 1)
    equal(orb.modifier_data.should_launch, true)
    equal(observations.particle, "particles/orb_epic.vpcf")
    local modifier = setmetatable({
        orb_type = orb.modifier_data.orb_type,
        source_orb_type = orb.modifier_data.source_orb_type,
        GetParent = function() return orb end,
        StopPoint = function() observations.stopped = true end,
    }, { __index = capture_point_area })
    modifier:AddRewardForTeam(2)
    modifier:AddRewardForTeam(2)
    assert_queue(4, 1)
    equal(EndGameStats.orbs_collected[2][ORB_CAPTURE_TYPE.DROP], 4)
    equal(observations.event_name, "GameLoop:orb_captured")
    equal(observations.event_data.rarity, 4)
    equal(observations.stopped, true)
    assert_queue(4, 0, 1)
end)

test("passive and kill meters preserve thresholds while granting/stating epics", function()
    reset(true)
    GameLoop.common_upgrades_progress[2] = 989
    GameLoop:CommonUpgradesTick()
    equal(GameLoop.common_upgrades_progress[2], 995)
    equal(queue_count(), 0)
    paused = true
    GameLoop:CommonUpgradesTick()
    equal(GameLoop.common_upgrades_progress[2], 995)
    paused = false
    GameLoop:CommonUpgradesTick()
    equal(GameLoop.common_upgrades_progress[2], 1)
    assert_queue(4, 1)
    equal(EndGameStats.orbs_collected[2][ORB_CAPTURE_TYPE.PASSIVE], 4)
    local meter = observations.net["orbs/current_progress_2"]
    equal(meter.orb_type, 1, "passive bar identity")
    equal(meter.reward_rarity, 4)
    GameLoop:ProcessRareUpgradeProgress(2)
    equal(queue_count(), 1)
    GameLoop:ProcessRareUpgradeProgress(2)
    assert_queue(4, 2)
    equal(GameLoop.rare_upgrades_requirement[2], 5)
    equal(GameLoop.rare_upgrades_progress[2], 0)
    equal(EndGameStats.orbs_collected[2][ORB_CAPTURE_TYPE.KILLS], 4)
    meter = observations.net["orbs/current_progress_2"]
    equal(meter.orb_type, 2, "kill bar identity")
    equal(meter.reward_rarity, 4)
end)

local function make_item(name, cost)
    return {
        GetName = function() return name end,
        GetPurchaser = function() return heroes[0] end,
        GetAbilityKeyValues = function() return { ItemCost = tostring(cost) } end,
    }
end
test("shop rewards keep source prices and announce/account for epic rewards", function()
    for _, source in ipairs({ { "common", 2000 }, { "rare", 4000 }, { "epic", 8000 } }) do
        reset(true)
        local item = make_item("item_" .. source[1] .. "_orb_ffa", source[2])
        local courier = { IsCourier = function() return true end }
        equal(Filters:OrbAddedToInventoryFilter(item, courier), true)
        assert_queue(4, 1)
        equal(heroes[0].consumed_orbs_cost, source[2])
        equal(heroes[0].spent, source[2])
        equal(observations.announcer, "custom.epic_orb")
        equal(observations.chat, "orb_purchased_chat_message_epic")
        equal(EndGameStats.orbs_collected[2][ORB_CAPTURE_TYPE.SHOP], 4)
        equal(observations.mvp, 20)
        equal(item.removed, true)
    end
end)

test("FFA shop orbs pass purchase orders and quickbuy under both orb rules", function()
    for _, epic in ipairs({ false, true }) do
        reset(epic)
        entities[1] = make_item("item_common_orb_ffa", 2000)
        entities[2] = heroes[0]
        local event = {
            order_type = DOTA_UNIT_ORDER_PURCHASE_ITEM, issuer_player_id_const = 0,
            entindex_target = 0, entindex_ability = 0, units = { ["0"] = 2 },
            shop_item_name = entities[1]:GetName(),
        }
        equal(Filters:ExecuteOrderFilter(event), true, "purchase order eligibility")
        equal(Filters:ItemAddedToInventoryFilter({ item_entindex_const = 1, inventory_parent_entindex_const = 2 }), true, "quickbuy eligibility")
        assert_queue(epic and 4 or 1, 1)
    end
end)

test("Epic Only spends all 30 rerolls at one each and rejects the 31st", function()
    reset(true)
    UpgradeRerolls:Init()
    UpgradeRerolls:PreparePlayer(0)
    equal(observations.net["rerolls/0"].count, 30)
    for _, rarity in ipairs({ 1, 2, 4 }) do equal(Upgrades:GetRerollPrice(rarity), 1) end
    Upgrades.pending_selection[0] = { upgrade_rarity = 4 }
    for used = 1, 30 do
        Upgrades:Reroll({ PlayerID = 0 })
        equal(observations.net["rerolls/0"].count, 30 - used)
        equal(observations.shown_count, used)
        equal(observations.shown_rarity, 4)
    end
    Upgrades:Reroll({ PlayerID = 0 })
    equal(observations.shown_count, 30)
    equal(UpgradeRerolls.current_free_rerolls[0], 0)
    Upgrades.favorites_upgrades = {}
    Upgrades:SendPendingSelection({ PlayerID = 0 })
    equal(observations.client_event.upgrades.reroll_price, 1)
end)

test("normal orbs retain rarity pricing and pending selection price", function()
    for _, rarity in ipairs({ 1, 2, 4 }) do
        reset(false)
        UpgradeRerolls:Init()
        UpgradeRerolls:PreparePlayer(0)
        Upgrades.pending_selection[0] = { upgrade_rarity = rarity }
        Upgrades:Reroll({ PlayerID = 0 })
        equal(observations.net["rerolls/0"].count, 30 - rarity)
        equal(observations.shown_count, 1)
        Upgrades:SendPendingSelection({ PlayerID = 0 })
        equal(observations.client_event.upgrades.reroll_price, rarity)
        UpgradeRerolls.current_free_rerolls[0] = rarity - 1
        Upgrades:Reroll({ PlayerID = 0 })
        equal(observations.shown_count, 1)
    end
end)

dofile("tools/test_single_draft.lua")
real_print(string.format("%d orb regression cases passed", passed))
