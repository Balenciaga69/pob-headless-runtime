-- Internal convenience facade for item-related calls.
local M = {}

-- Internal convenience facade. The formal public API is `api.init`.

local function getItemsService(session)
	local services = session and session:getServices() or nil
	return services and services.items or nil
end

local function requireItemsService(session)
	local service = getItemsService(session)
	if not service then
		return nil, "items service not available"
	end
	return service
end

function M.parse_item(session, itemText)
	local service, err = requireItemsService(session)
	if not service then
		return nil, err
	end
	return service:parse_item(itemText)
end

function M.test_item(session, itemText, slot)
	local service, err = requireItemsService(session)
	if not service then
		return nil, err
	end
	return service:test_item(itemText, slot)
end

function M.compare_item_stats(session, itemText, slot, fields)
	local service, err = requireItemsService(session)
	if not service then
		return nil, err
	end
	return service:compare_item_stats(itemText, slot, fields)
end

function M.simulate_mod(session, modLine, slot, fields)
	local service, err = requireItemsService(session)
	if not service then
		return nil, err
	end
	return service:simulate_mod(modLine, slot, fields)
end

function M.render_item_tooltip(session, itemText, slot)
	local service, err = requireItemsService(session)
	if not service then
		return nil, err
	end
	return service:render_item_tooltip(itemText, slot)
end

function M.equip_item(session, itemText, slot)
	local service, err = requireItemsService(session)
	if not service then
		return nil, err
	end
	return service:equip_item(itemText, slot)
end

return M
