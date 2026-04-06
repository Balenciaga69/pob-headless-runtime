-- Internal convenience facade for stats-related calls.
local M = {}

-- Internal convenience facade. The formal public API is `api.init`.

-- Retrieves the stats service from the session, or returns nil if not available.
local function getStatsService(session)
	-- Resolve the stats service from the session.
	local services = session and session:getServices() or nil
	return services and services.stats or nil
end

-- Requires the stats service to be available, returning an error if not.
local function requireStatsService(session)
	-- Fail fast when the stats service is missing.
	local service = getStatsService(session)
	if not service then
		return nil, "stats service not available"
	end
	return service
end

-- Retrieves the current stats for the session, optionally filtering by specific fields.
function M.get_stats(session, fields)
	-- Return the current stat snapshot.
	local service, err = requireStatsService(session)
	if not service then
		return nil, err
	end
	return service:get_stats(fields)
end

-- Retrieves a summary of the current stats for the session.
function M.get_summary(session)
	-- Return the current stat summary.
	local service, err = requireStatsService(session)
	if not service then
		return nil, err
	end
	return service:get_summary()
end

-- Compares stats between two states (before and after) for the session, optionally filtering by specific fields.
function M.compare_stats(session, beforeStats, afterStats, fields)
	-- Compare two stat snapshots and return the delta.
	local service, err = requireStatsService(session)
	if not service then
		return nil, err
	end
	return service:compare_stats(beforeStats, afterStats, fields)
end

return M
