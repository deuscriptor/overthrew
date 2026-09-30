-- Unit-scoped modifier events (server only).
-- A modifier that declares a global event (MODIFIER_EVENT_ON_MODIFIER_ADDED, MODIFIER_EVENT_ON_TAKEDAMAGE, ...) is
-- called for every such event on any unit, once per modifier instance. Every hero and each of its illusions carries
-- the same upgrade modifiers, so with many illusions every event fanned out to all of them (issue #24).
-- modifier_event_proxy, a single instance on the overboss, is the only listener of those events and hands each one
-- to the modifiers registered on the unit it concerns. Modifiers on heroes and illusions register here instead of
-- declaring the event.
UnitEvents = UnitEvents or {}


--- Calls modifier[handler_name](modifier, event) for events of the modifier's parent.
function UnitEvents:Register(modifier, handler_name)
	local parent = modifier:GetParent()
	if not parent then return end
	parent.unit_event_handlers = parent.unit_event_handlers or {}
	parent.unit_event_handlers[handler_name] = parent.unit_event_handlers[handler_name] or {}
	parent.unit_event_handlers[handler_name][modifier] = true
end


--- Stops every handler of the modifier.
function UnitEvents:Unregister(modifier)
	local parent = modifier:GetParent()
	local handlers = parent and parent.unit_event_handlers
	if not handlers then return end
	for _, modifiers in pairs(handlers) do modifiers[modifier] = nil end
end


function UnitEvents:Notify(unit, handler_name, event)
	local handlers = unit and unit.unit_event_handlers
	local modifiers = handlers and handlers[handler_name]
	if not modifiers then return end
	-- handlers may add modifiers to the unit, which registers new handlers while this runs
	local current = {}
	for modifier in pairs(modifiers) do table.insert(current, modifier) end
	for _, modifier in ipairs(current) do
		if modifier:IsNull() then
			modifiers[modifier] = nil
		elseif modifiers[modifier] then
			ErrorTracking.Try(modifier[handler_name], modifier, event)
		end
	end
end
