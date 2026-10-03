-- Run only in a disposable Tools-mode draft: script_reload_code single_draft_random_smoke
assert(IsInToolsMode() and IsSingleDraftMap())
assert(GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION)
assert(not PlayerResource:HasSelectedHero(0))
GameLoop:PickRandomHero(0)
local selected = PlayerResource:GetSelectedHeroName(0)
local legal = false
for _, hero in ipairs(SingleDraft.offers[0]) do if hero.name == selected then legal = true end end
assert(legal, "Random selected a hero outside the four offers")
print("SINGLE_DRAFT_RANDOM PASS hero=" .. selected)
