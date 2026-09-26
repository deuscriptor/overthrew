-- Run twice in a disposable local Tools session with a synthetic player 1.
-- First run sends a request to the human; accept it using the actual UI.
assert(IsInToolsMode() and UsesHostRules() and HeroSwaps:IsOpen())
if not _G.hero_swaps_ui_check then
	local state = {get_connection = PlayerResource.GetConnectionState,
		a = PlayerResource:GetSelectedHeroEntity(0), b = PlayerResource:GetSelectedHeroEntity(1)}
	assert(IsValidEntity(state.a) and IsValidEntity(state.b))
	_G.hero_swaps_ui_check = state
	PlayerResource.GetConnectionState = function(self, id)
		if id == 1 then return DOTA_CONNECTION_STATE_CONNECTED end
		return state.get_connection(self, id)
	end
	assert(HeroSwaps:Handle("request", 1, {target=0}))
	print("HERO_SWAPS_UI_REQUEST_SENT")
	return
end
local state = _G.hero_swaps_ui_check
assert(PlayerResource:GetSelectedHeroEntity(0) == state.b and PlayerResource:GetSelectedHeroEntity(1) == state.a,
	"Accept the request in the UI first")
PlayerResource.GetConnectionState = state.get_connection
_G.hero_swaps_ui_check = nil
print("HERO_SWAPS_UI_PASS authenticated client acceptance completed the cross-team swap")
