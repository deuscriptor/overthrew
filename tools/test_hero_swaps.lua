local output = print
DOTA_GAMERULES_STATE_HERO_SELECTION = 4
DOTA_GAMERULES_STATE_PRE_GAME = 8
DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 10
DOTA_CONNECTION_STATE_CONNECTED = 2
DOTA_MAX_TEAM_PLAYERS = 8
local state, now, ban = 4, 0, false
local players, callbacks, notifications, published, executed = {}, {}, {}, {}, {}
for id = 0, 3 do
	players[id] = {id = id, team = id + 2, connected = 2, hero = "hero_" .. id}
	players[id].GetPlayerID = function(self) return self.id end
end
function IsValidEntity(entity) return entity ~= nil end
function EntIndexToHScript(index) return players[index - 100] end
function table.deepcopy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = table.deepcopy(item) end
	return result
end
GameRules = {
	State_Get = function() return state end,
	GetGameTime = function() return now end,
	IsInBanPhase = function() return ban end,
	GetGameModeEntity = function() return {SetContextThink=function() end} end,
}
GameLoop = {current_layout = {teamlist = {2, 3, 4}}}
PlayerResource = {
	IsValidPlayerID = function(_, id) return players[id] ~= nil end,
	GetPlayer = function(_, id) return players[id] end,
	GetConnectionState = function(_, id) return players[id].connected end,
	GetTeam = function(_, id) return players[id].team end,
	GetSelectedHeroName = function(_, id) return players[id].hero end,
}
EventStream = {Listen = function(_, name, fn) callbacks[name] = fn end}
CustomGameEventManager = {Send_ServerToPlayer = function(_, player, name, data) table.insert(notifications, {player.id, name, data}) end}
CustomNetTables = {SetTableValue = function(_, tbl, key, value) published[key] = value end}
dofile("scripts/vscripts/game/hero_swaps.lua")
local real_execute = HeroSwaps.Execute
local spawned = false
HeroSwaps.Execute = function(_, request)
	if not spawned then return false end
	table.insert(executed, request)
	players[request.from].hero, players[request.to].hero = players[request.to].hero, players[request.from].hero
	return true
end
local function reset()
	now, state, ban, spawned = 0, 4, false, false
	for id, player in pairs(players) do player.hero, player.connected = "hero_" .. id, 2 end
	HeroSwaps:Init()
	executed = {}
end
local function request(a, b)
	assert(HeroSwaps:Handle("request", a, {target=b}))
	return HeroSwaps.next_id
end
reset()
callbacks["HeroSwaps:request"]({PlayerID=1, target=0}, 100)
assert(not next(HeroSwaps.requests), "Forged PlayerID must be rejected")
callbacks["HeroSwaps:request"]({PlayerID=0, target=1}, 100)
assert(HeroSwaps.requests[1], "Authenticated request should succeed")
assert(not HeroSwaps:Handle("accept", 0, {request_id=1}))
assert(not HeroSwaps:Handle("accept", 2, {request_id=1}))
assert(HeroSwaps:Handle("accept", 1, {request_id=1}))
assert(HeroSwaps:IsBusy(0) and HeroSwaps:IsBusy(1))
assert(not HeroSwaps:Handle("request", 2, {target=1}))
assert(not HeroSwaps:Handle("accept", 1, {request_id=1}))
spawned, state = true, 8
HeroSwaps:Tick()
assert(#executed == 1 and not HeroSwaps:IsBusy(0))
HeroSwaps:Tick()
assert(#executed == 1 and players[0].hero == "hero_1" and players[1].hero == "hero_0")
assert(players[0].team == 2 and players[1].team == 3)

reset()
for _, target in ipairs({0, 3, -1, 99, 1.5, "1"}) do assert(not HeroSwaps:Handle("request", 0, {target=target})) end
players[1].hero = ""
assert(not HeroSwaps:Handle("request", 0, {target=1}))
players[1].hero = players[0].hero
assert(not HeroSwaps:Handle("request", 0, {target=1}))
players[1].hero, players[1].connected = "hero_1", 3
assert(not HeroSwaps:Handle("request", 0, {target=1}))
players[1].connected = 2
local id = request(0, 1)
assert(not HeroSwaps:Handle("request", 0, {target=2}), "Cooldown must limit request spam")
assert(not HeroSwaps:Handle("decline", 0, {request_id=id}))
assert(HeroSwaps:Handle("decline", 1, {request_id=id}))
now = 3
id = request(0, 1)
assert(not HeroSwaps:Handle("cancel", 1, {request_id=id}))
assert(HeroSwaps:Handle("cancel", 0, {request_id=id}))
now = 6
id = request(0, 1)
now = 37
assert(not HeroSwaps:Handle("accept", 1, {request_id=id}))
HeroSwaps:Tick()
assert(not next(HeroSwaps.requests))

reset()
id = request(0, 1)
players[1].hero = "changed_hero"
assert(not HeroSwaps:Handle("accept", 1, {request_id=id}))
HeroSwaps:Tick()
assert(not next(HeroSwaps.requests))
reset()
id = request(0, 1)
request(2, 1)
assert(HeroSwaps:Handle("accept", 1, {request_id=id}))
assert(not next(HeroSwaps.requests), "Other requests involving either participant must be invalidated")
players[1].connected = 3
HeroSwaps:Tick()
assert(not next(HeroSwaps.accepted), "Disconnect cancels accepted swaps before spawn")
reset()
for _, phase in ipairs({4, 5, 6, 7, 8, 9}) do state = phase; assert(HeroSwaps:IsOpen()) end
for _, phase in ipairs({3, 10, 11}) do state = phase; assert(not HeroSwaps:IsOpen()) end
state, ban = 4, true
assert(not HeroSwaps:IsOpen())
reset()
id = request(0, 1)
assert(HeroSwaps:Handle("accept", 1, {request_id=id}))
state, spawned = 10, true
HeroSwaps:Tick()
assert(#executed == 0 and not next(HeroSwaps.accepted) and published.hero_swaps.open == 0)
assert(not HeroSwaps:Handle("request", 0, {target=1}))

reset()
local hero = {GetPlayerOwnerID = function() return 0 end, upgrades = {generic={account_bonus={count=2}}}}
HeroSwaps:CaptureBaseUpgrades(hero)
hero.upgrades.generic.account_bonus.count = 9
assert(HeroSwaps.base_generics[0].account_bonus.count == 2, "Baseline must not alias live upgrades")
for _, rarity in ipairs({1, 2, 4, 4}) do HeroSwaps:RecordOrbSelection(hero, {upgrade_rarity=rarity}) end
HeroSwaps:RecordOrbSelection(hero, {upgrade_rarity=2})
assert(#HeroSwaps.spent_orbs[0] == 5 and HeroSwaps.spent_orbs[0][5].rarity == 2)
state = 10
HeroSwaps:RecordOrbSelection(hero, {upgrade_rarity=4})
assert(#HeroSwaps.spent_orbs[0] == 5, "Only pre-match orbs need a refund ledger")
HeroSwaps.Execute = real_execute
-- Refund into the player's existing queue without granting new starting bonuses. Repeating a swap must not duplicate refunded rewards.
state = 8
local sent_queue
Upgrades = {disabled_upgrades_per_player={}, pending_selection={[0]={old=true}},
	favorites_upgrades={[0]={old_hero={foo=1}, generic={keep=1}}}, queued_selection={[0]={{rarity=1}}},
	SetGenericUpgrade=function(_, unit, name, count) unit.upgrades.generic = unit.upgrades.generic or {}; unit.upgrades.generic[name] = {count=count} end,
	SendUpgradesData=function() end, SendPendingFavorites=function() end,
	ShowSelection=function(_, unit, rarity, player_id) sent_queue = {unit, rarity, player_id} end,
}
local new_hero = {upgrades={}, FindModifierByName=function() return nil end}
HeroSwaps:RefreshPlayer(0, new_hero)
assert(#Upgrades.queued_selection[0] == 6 and sent_queue[1] == new_hero and sent_queue[2] == 1)
for index, rarity in ipairs({1, 1, 2, 4, 4, 2}) do assert(Upgrades.queued_selection[0][index].rarity == rarity) end
assert(not Upgrades.pending_selection[0] and not next(HeroSwaps.spent_orbs[0]))
assert(not Upgrades.favorites_upgrades[0].old_hero and Upgrades.favorites_upgrades[0].generic.keep == 1)
assert(new_hero.upgrades.generic.account_bonus.count == 2)
HeroSwaps:RefreshPlayer(0, new_hero)
assert(#Upgrades.queued_selection[0] == 6, "Second swap must not duplicate refunds")
-- A swapped hero's pre-game stun is re-created under its new team with the time it had left
-- (the old one would be suppressed by the new fountain's debuff immunity).
local stun = {remaining = 7.5}
function stun:GetRemainingTime() return self.remaining end
function stun:Destroy() self.destroyed = true end
local added = nil
local swapped = {modifiers = {modifier_pregame_stunned = stun}}
for _, method in ipairs({"SetOwner", "SetPlayerID", "SetControllableByPlayer", "SetRespawnPosition"}) do
	swapped[method] = function() end
end
function swapped:SetTeam(team) self.team = team end
function swapped:FindModifierByName(name) return self.modifiers[name] end
function swapped:AddNewModifier(caster, ability, name, data)
	added = {caster = caster, name = name, duration = data.duration, team = self.team}
end
players[1].SetAssignedHeroEntity = function() end
FindClearSpaceForUnit = function() end
GameLoop.hero_by_player_id = {}
GetDummyInventory = function() end
HeroSwaps:Assign(swapped, 1, {x = 0})
assert(stun.destroyed and added.name == "modifier_pregame_stunned" and added.caster == swapped)
assert(added.duration == 7.5 and added.team == 3, "stun re-created after the team change, same remaining time")
local unstunned = {}
for key, value in pairs(swapped) do unstunned[key] = value end
unstunned.modifiers, added = {}, nil
HeroSwaps:Assign(unstunned, 1, {x = 0})
assert(added == nil, "no stun added after the horn")
-- Issue #26: before the swap, each hero is precached with its new owner's cosmetics, and the swap waits for both.
local precached = {}
PrecacheUnitByNameAsync = function(name, callback, player_id) table.insert(precached, {name, callback, player_id}) end
local sven = {initialized = true, GetUnitName = function() return "npc_dota_hero_sven" end, GetAbsOrigin = function() return {} end}
local warden = {initialized = true, GetUnitName = function() return "npc_dota_hero_arc_warden" end, GetAbsOrigin = function() return {} end}
PlayerResource.GetSelectedHeroEntity = function(_, id) return id == 0 and sven or id == 1 and warden or nil end
HeroSwaps.GetOwnedUnits = function() error("past the precache gate") end
HeroSwaps.precached = {}
local swap = {id = 7, from = 0, to = 1}
assert(HeroSwaps:Execute(swap) == false and HeroSwaps:Execute(swap) == false, "the swap waits for the precache")
assert(#precached == 2, "each hero is precached once")
assert(precached[1][1] == "npc_dota_hero_arc_warden" and precached[1][3] == 0, "Arc Warden is precached for its new owner")
assert(precached[2][1] == "npc_dota_hero_sven" and precached[2][3] == 1, "and Sven for its new owner")
precached[1][2]()
assert(HeroSwaps:Execute(swap) == false, "both precaches must finish")
precached[2][2]()
local passed, gate_error = pcall(HeroSwaps.Execute, HeroSwaps, swap)
assert(not passed and tostring(gate_error):find("past the precache gate"), "then the swap runs")
-- precached once per match: swapping the same heroes between the same players again doesn't wait
passed, gate_error = pcall(HeroSwaps.Execute, HeroSwaps, {id = 8, from = 0, to = 1})
assert(not passed and tostring(gate_error):find("past the precache gate") and #precached == 2, "a known pair is not precached again")
assert(HeroSwaps:PrecacheHeroFor("npc_dota_hero_sven", 0) == false and #precached == 3, "another player's copy is precached separately")
output("PASS hero swaps: sender authentication, recipient consent, cross-team requests, phase limits, expiry, cancellation, disconnects, stale heroes, concurrent requests, deferred execution, exact orb ledger, precache for new owners")
