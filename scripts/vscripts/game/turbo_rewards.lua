-- Scripted grants can bypass the engine's economy filters. Route them through
-- the same policy and suppress a second scaling if the engine also filters one.
TurboRewards = TurboRewards or {}

local function invoke(kind, native, ...)
	TurboRewards[kind] = true
	local ok, result = pcall(native, ...)
	TurboRewards[kind] = nil
	if not ok then error(result, 2) end
	return result
end

if not TurboRewards.native_hero_gold then
	TurboRewards.native_hero_gold = CDOTA_BaseNPC_Hero.ModifyGold
	function CDOTA_BaseNPC_Hero:ModifyGold(amount, reliable, reason)
		if not IsTurboMode() or TurboRewards.gold then
			return TurboRewards.native_hero_gold(self, amount, reliable, reason)
		end
		local event = {gold=amount, reason_const=reason}
		Filters:ModifyGoldFilter(event)
		return invoke("gold", TurboRewards.native_hero_gold, self, event.gold, reliable, reason)
	end

	TurboRewards.native_player_gold = CDOTA_PlayerResource.ModifyGold
	function CDOTA_PlayerResource:ModifyGold(player_id, amount, reliable, reason)
		if not IsTurboMode() or TurboRewards.gold then
			return TurboRewards.native_player_gold(self, player_id, amount, reliable, reason)
		end
		local event = {gold=amount, reason_const=reason, player_id_const=player_id}
		Filters:ModifyGoldFilter(event)
		return invoke("gold", TurboRewards.native_player_gold, self, player_id, event.gold, reliable, reason)
	end

	TurboRewards.native_experience = CDOTA_BaseNPC_Hero.AddExperience
	function CDOTA_BaseNPC_Hero:AddExperience(amount, reason, apply_bot_difficulty, increment_total)
		if not IsTurboMode() or TurboRewards.experience then
			return TurboRewards.native_experience(self, amount, reason, apply_bot_difficulty, increment_total)
		end
		local event = {experience=amount}
		Filters:FilterModifyExperience(event)
		return invoke("experience", TurboRewards.native_experience, self, event.experience, reason, apply_bot_difficulty, increment_total)
	end
end
