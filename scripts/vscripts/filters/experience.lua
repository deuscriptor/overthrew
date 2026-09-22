function Filters:FilterModifyExperience(event)
	if TurboRewards and TurboRewards.experience then return true end
	if IsTurboMode() and GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME
		and event.experience and event.experience > 0 then
		event.experience = event.experience * 2
	end

	return true
end
