-- Session helpers for legacy compatibility and optional helper script loading.
local fileUtil = require("util.file")
local legacyAdapter = require("runtime.session.legacy_adapter")

local M = {}

function M.loadHeadlessScript(session, argv)
    -- Load an optional helper script after the runtime has been prepared.
    local scriptPath = os.getenv("POB_HEADLESS_TEST_SCRIPT")
    if not scriptPath or scriptPath == "" then
        return
    end

    local scriptText, err = fileUtil.readAll(scriptPath, "headless helper")
    if not scriptText then
        error(err)
    end

    local scriptFunc, compileErr = load(scriptText, "@" .. scriptPath)
    if not scriptFunc then
        error("Failed to compile headless helper " .. scriptPath .. ": " .. tostring(compileErr))
    end

    local previousArg = rawget(_G, "arg")
    _G.arg = argv or {}
    scriptFunc(unpack(argv or {}))
    _G.arg = previousArg
end

function M.installLegacyHelpers(session)
    -- Keep the historical helper surface available for older scripts.
    legacyAdapter.install(session)
end

function M.getAdapters(session)
    -- Preserve the deprecated alias without expanding the public API surface.
    return session.repos
end

function M.getRepos(session)
    return session.repos
end

function M.getServices(session)
    return session.services
end

return M
