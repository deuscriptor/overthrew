modifier_event_proxy = class({})

function modifier_event_proxy:IsHidden() return false end
function modifier_event_proxy:IsPurgable() return false end
function modifier_event_proxy:RemoveOnDeath() return false end


if not IsServer() then return end


-- The only listener of these global events: unit-scoped ones go to the modifiers of the unit concerned
-- (libraries/unit_events.lua).
function modifier_event_proxy:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_HERO_KILLED,
		MODIFIER_EVENT_ON_MODIFIER_ADDED,
		MODIFIER_EVENT_ON_TAKEDAMAGE_KILLCREDIT,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_EVENT_ON_SPELL_TARGET_READY,
	}
end


function modifier_event_proxy:OnHeroKilled(event)
	EventDriver:Dispatch("Events:hero_killed", {
		killed = event.target,
		killer = event.attacker,
		last_hit_unit = event.unit,
		inflictor = event.inflictor,
	})
end


function modifier_event_proxy:OnModifierAdded(event)
	local unit = event.unit
	local buff = event.added_buff
	if not IsValidEntity(unit) or not buff or buff:IsNull() then return end

	local event_data = {
		unit = unit,
		modifier = buff,
	}
	UnitEvents:Notify(unit, "OnModifierAdded", event_data)
	EventDriver:Dispatch("Events:modifier_added", event_data)
end


-- to the attacker's modifiers
function modifier_event_proxy:OnTakeDamage(event)
	UnitEvents:Notify(event.attacker, "OnTakeDamage", event)
end


-- to the caster's modifiers
function modifier_event_proxy:OnSpellTargetReady(event)
	UnitEvents:Notify(event.unit, "OnSpellTargetReady", event)
end


function modifier_event_proxy:OnTakeDamageKillCredit(event)
	local damage = event.damage
	local target = event.target
	local attacker = event.attacker

	if not IsValidEntity(target) or not IsValidEntity(attacker) or not damage or not target:IsRealHero() then return end
	if attacker == target then return end -- self damage not calculated

	local attacker_player_id = attacker:GetPlayerOwnerID()
	if not IsValidPlayerID(attacker_player_id) then return end

	local hero = GameLoop.hero_by_player_id[attacker_player_id]
	-- if attacker is different from assigner hero for this player, then damage is done by some other controlled unit (summon or whatnot)
	local is_summon_damage = IsValidEntity(hero) and attacker:GetEntityIndex() ~= hero:GetEntityIndex() or false

	EndGameStats:Add_HeroDamage(attacker_player_id, event.damage, is_summon_damage)
end
