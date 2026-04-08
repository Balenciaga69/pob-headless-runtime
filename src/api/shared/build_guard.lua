-- Guards for partially initialized build objects.
local M = {}

local function hasRequiredTabs(build, requiredTabs)
    for _, tabName in ipairs(requiredTabs or {}) do
        if not build[tabName] then
            return false
        end
    end
    return true
end

-- Centralize the common build/tab checks used by repo adapters.
function M.getBuildWithTabs(session, requiredTabs, errorMessage)
    local build = session:getBuild()
    if not build then
        return nil, errorMessage or "build not initialized"
    end
    if not hasRequiredTabs(build, requiredTabs) then
        return nil, errorMessage or "build not initialized"
    end
    return build
end

-- Keep repo callers readable by moving the build lookup into a callback wrapper.
function M.withBuild(session, requiredTabs, errorMessage, callback)
    local build, err = M.getBuildWithTabs(session, requiredTabs, errorMessage)
    if not build then
        return nil, err
    end
    return callback(build)
end

return M
