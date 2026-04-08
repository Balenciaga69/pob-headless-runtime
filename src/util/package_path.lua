-- Package path helpers for local modules.
local pathUtil = require("util.path")

local M = {}

-- Insert into package.path only when the entry is missing.
function M.prependIfMissing(entry)
    local pathValue = package.path or ""
    if pathValue:find(entry, 1, true) then
        return false
    end

    package.path = entry .. ";" .. pathValue
    return true
end

-- Add both Lua module search patterns for a directory.
function M.prependLuaModuleDir(dir)
    local normalizedDir = pathUtil.trimTrailingSeparator(dir)
    local sep = pathUtil.getPathSeparator()

    M.prependIfMissing(normalizedDir .. sep .. "?" .. sep .. "init.lua")
    M.prependIfMissing(normalizedDir .. sep .. "?.lua")
end

return M
