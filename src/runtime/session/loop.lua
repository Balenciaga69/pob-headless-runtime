-- Session loop helpers that control frame stepping and settle behavior.
local accessUtil = require("util.access")
local runtimeStateUtil = require("runtime.runtime_state")

local M = {}

local function formatBool(value)
    -- Render booleans in timeout messages as stable text.
    return value and "true" or "false"
end

local function buildTimeoutMessage(status, maxFrames, maxSeconds)
    -- Include every readiness flag so callers can see why settling failed.
    return string.format(
        "headless runtime did not settle within %d frame(s) / %.2f second(s) (pending=%d, mainReady=%s, buildReady=%s, calcsReady=%s, outputReady=%s)",
        maxFrames,
        maxSeconds,
        status.pendingActionCount or 0,
        formatBool(status.mainReady),
        formatBool(status.buildReady),
        formatBool(status.calcsReady),
        formatBool(status.outputReady)
    )
end

function M.ensureMainReady(session)
    -- Try the current frame first, then give PoB one extra frame to initialize.
    local main = accessUtil.getMainObjectMain(session.callbacks.mainObject)
    if main then
        return main
    end

    session:runFramesIfIdle(1)
    main = accessUtil.getMainObjectMain(session.callbacks.mainObject)
    if main then
        return main
    end

    return nil
end

function M.runFramesIfIdle(session, frameCount)
    -- Avoid advancing the runtime while a callback is already on the stack.
    if session:isInsideCallback() then
        session:getBuild()
        return
    end

    session:runFrames(frameCount)
end

function M.runFrames(session, frameCount)
    -- Dispatch OnInit once, then step frames until the runtime asks us to stop.
    if not session.initDispatched then
        session.callbacks.runCallback("OnInit")
        session.initDispatched = true
    end

    for _ = 1, frameCount or 10 do
        if runtimeStateUtil.shouldStop(session.callbacks) then
            break
        end

        session.callbacks.runCallback("OnFrame")
        session:getBuild()
        session:runPendingActions()
        session:getBuild()

        if runtimeStateUtil.shouldStop(session.callbacks) then
            break
        end
    end
end

function M.runUntilSettled(session, options)
    -- Keep stepping until readiness settles, a predicate passes, or a timeout hits.
    if session:isInsideCallback() then
        return nil, "runUntilSettled() cannot be called from inside callbacks"
    end

    options = options or {}
    local maxFrames = math.max(1, tonumber(options.maxFrames) or 200)
    local maxSeconds = tonumber(options.maxSeconds) or 5
    local startClock = os.clock()
    local predicate = options["until"]

    local function isSettled(status)
        if type(predicate) == "function" then
            return predicate(status, session) == true
        end

        return status.initDispatched and status.mainReady and status.pendingActionCount == 0
    end

    local frames = 0
    while true do
        local status = session:getStatus()
        if status.stopRequested then
            return status, nil
        end
        if isSettled(status) then
            return status, nil
        end
        if frames >= maxFrames then
            return nil, buildTimeoutMessage(status, maxFrames, maxSeconds)
        end
        if maxSeconds >= 0 and (os.clock() - startClock) >= maxSeconds then
            return nil, buildTimeoutMessage(status, maxFrames, maxSeconds)
        end

        session:runFrames(1)
        frames = frames + 1
    end
end

return M
