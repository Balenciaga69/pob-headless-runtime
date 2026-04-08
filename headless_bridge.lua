-- Legacy headless entry bridge that keeps upstream Launch.lua untouched.
-- The early bootstrap must stay self-contained because local modules are not on package.path yet.
local function bootstrapLocalLuaPath()
    local wrapperPath = (arg and arg[0]) or "headless_bridge.lua"

    -- Read the current OS path separator.
    local pathSeparator = package.config:sub(1, 1)

    -- Normalize the wrapper path to the active platform convention.
    if pathSeparator == "\\" then
        wrapperPath = wrapperPath:gsub("/", "\\")
    else
        wrapperPath = wrapperPath:gsub("\\", "/")
    end

    -- Resolve the directory that contains this bridge file.
    local toolDir = wrapperPath:match("^(.*)[/\\][^/\\]+$") or "."

    -- Build the Lua module search paths under src and tests/helpers.
    local moduleRoot = toolDir .. pathSeparator .. "src"
    local modulePattern = moduleRoot .. pathSeparator .. "?.lua"
    local moduleInitPattern = moduleRoot .. pathSeparator .. "?" .. pathSeparator .. "init.lua"
    local helperRoot = toolDir .. pathSeparator .. "tests" .. pathSeparator .. "helpers"
    local helperPattern = helperRoot .. pathSeparator .. "?.lua"
    local helperInitPattern = helperRoot .. pathSeparator .. "?" .. pathSeparator .. "init.lua"

    -- Prepend each search pattern only once.
    if not package.path:find(modulePattern, 1, true) then
        package.path = modulePattern .. ";" .. package.path
    end
    if not package.path:find(moduleInitPattern, 1, true) then
        package.path = moduleInitPattern .. ";" .. package.path
    end
    if not package.path:find(helperPattern, 1, true) then
        package.path = helperPattern .. ";" .. package.path
    end
    if not package.path:find(helperInitPattern, 1, true) then
        package.path = helperInitPattern .. ";" .. package.path
    end
end

-- Initialize the Lua search path before any local require runs.
bootstrapLocalLuaPath()

-- Normalize argv so arg and varargs share one table.
local argv = {
    [0] = arg and arg[0],
}
for index = 1, select("#", ...) do
    argv[index] = select(index, ...)
end

-- Derive the execution context from arg[0].
local context = require("entry.context").fromArg0(argv[0])

-- Load the environment bootstrap helper.
local bootstrap = require("entry.bootstrap")

-- Create the callback bridge for PoB lifecycle hooks.
local callbacks = require("runtime.callbacks").new()

-- Create the runtime session that owns lifecycle orchestration.
local session = require("runtime.session").new(context, callbacks)

-- Prepare the Lua runtime environment for headless execution.
bootstrap.prepareEnvironment(context)

-- Run Launch.lua and initialize the main object.
bootstrap.launch(context, callbacks)

-- Install the legacy helper surface expected by older scripts.
session:installLegacyHelpers()

-- Load an optional automation script from POB_HEADLESS_TEST_SCRIPT.
session:loadHeadlessScript(argv)

-- Drive PoB until it settles, using configurable safety bounds.
local _, settleErr = session:runUntilSettled({
    maxFrames = tonumber(os.getenv("POB_HEADLESS_MAX_FRAMES")) or 200,
    maxSeconds = tonumber(os.getenv("POB_HEADLESS_MAX_SECONDS")) or 5,
})

-- Finalize the build object after the runtime settles.
local _, err = session:finalizeBuild()

-- Exit with failure if settling or finalization reported an error.
if settleErr or err then
    io.stderr:write((settleErr or err) .. "\n")
    os.exit(1)
end
