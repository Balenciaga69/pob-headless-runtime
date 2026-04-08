-- Session action helpers that queue deferred work at safe frame boundaries.
local runtimeStateUtil = require("runtime.runtime_state")

local M = {}

function M.enqueueAction(session, action)
	-- Store work until the runtime reaches a safe execution boundary.
	session.pendingActions[#session.pendingActions + 1] = action
end

function M.runPendingActions(session)
	-- Run deferred actions under callback depth tracking so nested work stays visible.
	if #session.pendingActions == 0 then
		return
	end

	session.executingPendingActions = true
	session.callbacks.activeDepth = (session.callbacks.activeDepth or 0) + 1
	local remaining = {}

	for _, action in ipairs(session.pendingActions) do
		local ok, doneOrErr = pcall(action, session.api, session)
		if not ok then
			session.callbacks.activeDepth = session.callbacks.activeDepth - 1
			session.executingPendingActions = false
			error(doneOrErr)
		end
		if doneOrErr ~= true then
			remaining[#remaining + 1] = action
		end
		if runtimeStateUtil.shouldStop(session.callbacks) then
			break
		end
	end

	session.pendingActions = remaining
	session.callbacks.activeDepth = session.callbacks.activeDepth - 1
	session.executingPendingActions = false
end

return M
