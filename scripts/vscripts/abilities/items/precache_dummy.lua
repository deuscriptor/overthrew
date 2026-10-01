item_precache_dummy = class({})

function item_precache_dummy:Precache(context)
	local precache_list = table.remove(_G.PRECACHE_RESOURCE_LISTS, 1)

	if not precache_list then return end

	for resource, resource_type in pairs(precache_list) do
		PrecacheResource(resource_type, resource, context)
	end
end
