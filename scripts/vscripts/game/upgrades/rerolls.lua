UpgradeRerolls = UpgradeRerolls or class({})


function UpgradeRerolls:Init()
	UpgradeRerolls.current_free_rerolls = {}
	UpgradeRerolls.free_rerolls = false -- IsInToolsMode()
end


function UpgradeRerolls:PreparePlayer(player_id)
	UpgradeRerolls.current_free_rerolls[player_id] = (HostOptions.locked and HostOptions:GetOption("infinite_rerolls")) and 999 or 30

	if UpgradeRerolls.free_rerolls then
		UpgradeRerolls.current_free_rerolls[player_id] = 99999
	end

	UpgradeRerolls:UpdateRerollCount(player_id)
end


function UpgradeRerolls:_ConsumeRerolls(player_id, rarity)
	local current_free_rerolls = UpgradeRerolls.current_free_rerolls[player_id] or 0

	if UpgradeRerolls.free_rerolls then
		current_free_rerolls = 99999
		rarity = 0
	end

	if current_free_rerolls >= rarity then
		UpgradeRerolls.current_free_rerolls[player_id] = current_free_rerolls - rarity
		return true
	end

	return false
end


function UpgradeRerolls:ConsumeRerolls(player_id, rarity)
	local reroll_allowed = UpgradeRerolls:_ConsumeRerolls(player_id, rarity)

	if reroll_allowed then
		UpgradeRerolls:UpdateRerollCount(player_id)
	end

	return reroll_allowed
end


function UpgradeRerolls:UpdateRerollCount(player_id)
	CustomNetTables:SetTableValue("rerolls", tostring(player_id), {
		count = UpgradeRerolls.current_free_rerolls[player_id] or 0
	})
end


UpgradeRerolls:Init()
