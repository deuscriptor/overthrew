assert(IsInToolsMode() and UsesHostRules())
if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
    for id, callback in pairs(EventDriver.serverside_events['Events:npc_spawned'] or {}) do
        if callback[1] == OT3Demo.OnNPCSpawned then EventDriver:CancelListener('Events:npc_spawned', id) end
    end
    PlayerDC.CheckEndGame = function() end
    GameRules:SetPreGameTime(600)
    assert(HostOptions:ApplyRules({PlayerID=0, epic_orbs=0, single_draft=0, turbo=0, kill_goal=30}))
    print('SWAP_PROBE_SETUP')
    return
end
local a = PlayerResource:GetSelectedHeroEntity(0)
assert(IsValidEntity(a), 'Select own hero first')
if not _G.swap_probe_bot then
    local team = PlayerResource:GetTeam(0) == DOTA_TEAM_BADGUYS and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
    _G.swap_probe_bot = GameRules:AddBotPlayerWithEntityScript('npc_dota_hero_lina', 'Swap probe', team, '', false)
    print('SWAP_PROBE_BOT', _G.swap_probe_bot)
    return
end
local b = _G.swap_probe_bot
local p = b:GetPlayerOwnerID()
local player_a, player_b = PlayerResource:GetPlayer(0), PlayerResource:GetPlayer(p)
print('SWAP_BEFORE', PlayerResource:GetSelectedHeroName(0), PlayerResource:GetSelectedHeroName(p))
player_a:SetAssignedHeroEntity(b)
player_b:SetAssignedHeroEntity(a)
print('SWAP_ASSIGNED', PlayerResource:GetSelectedHeroName(0), PlayerResource:GetSelectedHeroName(p), PlayerResource:GetSelectedHeroEntity(0):GetUnitName(), PlayerResource:GetSelectedHeroEntity(p):GetUnitName())
print('SWAP_OWNERS', a:GetPlayerOwnerID(), b:GetPlayerOwnerID(), a:GetTeam(), b:GetTeam(), PlayerResource:GetTeam(0), PlayerResource:GetTeam(p))
