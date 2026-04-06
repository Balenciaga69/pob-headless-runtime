-- Access helpers for fragile object-graph lookups.
local M = {}

-- Extract the real main object from mainObject to avoid repeating long chains everywhere.
function M.getMainObjectMain(mainObject)
    -- Return the inner main object when the wrapper exists.
    return mainObject and mainObject.main or nil
end

-- Extract BUILD mode for use by demo/session.
function M.getBuildMode(mainObject)
    -- Return the BUILD mode object from the main runtime object.
    local main = M.getMainObjectMain(mainObject)
    return main and main.modes and main.modes["BUILD"] or nil
end

return M
