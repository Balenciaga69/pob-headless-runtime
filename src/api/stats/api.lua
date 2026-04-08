-- Internal convenience facade for stats-related calls.
local M = {}

local function getStatsService(session)
    local services = session and session:getServices() or nil
    return services and services.stats or nil
end

local function requireStatsService(session)
    local service = getStatsService(session)
    if not service then
        return nil, "stats service not available"
    end
    return service
end

function M.get_stats(session, fields)
    local service, err = requireStatsService(session)
    if not service then
        return nil, err
    end
    return service:get_stats(fields)
end

function M.get_summary(session)
    local service, err = requireStatsService(session)
    if not service then
        return nil, err
    end
    return service:get_summary()
end

function M.compare_stats(session, beforeStats, afterStats, fields)
    local service, err = requireStatsService(session)
    if not service then
        return nil, err
    end
    return service:compare_stats(beforeStats, afterStats, fields)
end

return M
