assert(IsInToolsMode())
local hero=PlayerResource:GetSelectedHeroEntity(0)
assert(IsValidEntity(hero),'wait hero')
local bundle=CreateItem('item_madstone_bundle',hero,hero)
print('TURBO_BUNDLE '..tostring(bundle))
local shard=CreateItem('item_aghanims_shard',hero,hero)
print('TURBO_SHARD initial='..tostring(shard:GetAbilityKeyValues().ItemInitialStockTime)..' playerSpecific='..tostring(shard:GetAbilityKeyValues().PlayerSpecificCooldown))
UTIL_Remove(shard)
if bundle then UTIL_Remove(bundle) end
for _,team in ipairs(TEAMS_LAYOUTS[GetMapName()].teamlist) do print('TURBO_STOCK before',team,GameRules:GetItemStockCount(team,'item_aghanims_shard',-1)) GameRules:IncreaseItemStock(team,'item_aghanims_shard',1,-1) print('TURBO_STOCK after',team,GameRules:GetItemStockCount(team,'item_aghanims_shard',-1)) end
