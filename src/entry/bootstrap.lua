-- Bootstrap that wires paths, shims, and Launch.lua startup.
local contextModule = require("entry.context")

local M = {}

-- Prefer reusing existing utf8 module; if not found, load compatibility version from compatibility directory.
local function loadUtf8Compat(context)
    -- Reuse the loaded utf8 module when possible, otherwise load the shim.
    local existing = package.loaded["lua-utf8"] or package.loaded["utf8"] or rawget(_G, "utf8")

    if type(existing) == "table" then
        package.loaded["utf8"] = existing
        package.loaded["lua-utf8"] = existing
        return existing
    end

    local utf8Path = contextModule.resolveCompatibilityPath(context, "lua-utf8.lua")
    local ok, result = pcall(dofile, utf8Path)
    if not ok then
        error("Failed to load utf8 compatibility module: " .. tostring(result))
    end
    if type(result) ~= "table" then
        error("utf8 compatibility module did not return a table")
    end

    package.loaded["utf8"] = result
    package.loaded["lua-utf8"] = result
    return result
end

-- First set up search paths, then load utf8 compatibility layer.
function M.prepareEnvironment(context)
    -- Prepare module search paths and utf8 compatibility before Launch.lua.
    contextModule.ensurePackagePaths(context)
    loadUtf8Compat(context)
end

-- Launch PoB, replacing GUI dependencies with headless stubs.
function M.launch(context, callbacks)
    -- Install stubs, run Launch.lua, and capture the resulting main object.
    require("compatibility.stubs").install(context, callbacks)
    dofile(contextModule.resolveSourcePath(context, "Launch.lua"))
    callbacks.mainObject.continuousIntegrationMode = os.getenv("CI")
    return callbacks.mainObject
end

return M
