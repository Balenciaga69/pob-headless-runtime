-- Internal convenience facade for config-related calls.
local M = {}

-- Internal convenience facade. The formal public API is `api.init`.

local function getConfigService(session)
	-- Look up the config service from the bound session.
	local services = session and session:getServices() or nil
	return services and services.config or nil
end

local function requireConfigService(session)
	-- Fail fast when the config service is unavailable.
	local service = getConfigService(session)
	if not service then
		return nil, "config service not available"
	end
	return service
end

function M.set_config(session, params)
	-- Apply a config patch through the service layer.
	local service, err = requireConfigService(session)
	if not service then
		return nil, err
	end
	return service:apply_config(params)
end

function M.compare_config_stats(session, params, fields)
	-- Compare stats before and after a config change.
	local service, err = requireConfigService(session)
	if not service then
		return nil, err
	end
	return service:compare_config_stats(params, fields)
end

return M
