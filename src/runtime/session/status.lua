-- Session status helpers that report readiness and final build state.
local accessUtil = require("util.access")
local runtimeStateUtil = require("runtime.runtime_state")

local M = {}

function M.isInsideCallback(session)
	-- Treat nested callback execution as unsafe for frame advancement.
	return (session.callbacks.activeDepth or 0) > 0 or session.executingPendingActions == true
end

function M.getStatus(session)
	-- Capture the runtime readiness snapshot used by settle loops and callers.
	local main = accessUtil.getMainObjectMain(session.callbacks.mainObject)
	local build = session:getBuild()
	local promptMsg = runtimeStateUtil.getPromptMessage(session.callbacks)

	local calcsTab = build and build.calcsTab or nil
	local output = calcsTab and calcsTab.mainOutput or nil

	return {
		initDispatched = session.initDispatched == true,
		mainReady = main ~= nil,
		buildReady = build ~= nil,
		calcsReady = calcsTab ~= nil,
		outputReady = output ~= nil,
		pendingActionCount = #session.pendingActions,
		executingPendingActions = session.executingPendingActions == true,
		insideCallback = session:isInsideCallback(),
		activeDepth = session.callbacks.activeDepth or 0,
		headlessDone = session.callbacks.headlessDone == true,
		promptMsg = promptMsg,
		stopRequested = runtimeStateUtil.shouldStop(session.callbacks),
	}
end

function M.finalizeBuild(session)
	-- Publish the final build only after prompt blockers are cleared.
	local promptMsg = runtimeStateUtil.getPromptMessage(session.callbacks)
	if promptMsg then
		return nil, promptMsg
	end

	local build = session:getBuild()
	_G.build = build
	return build, nil
end

return M
