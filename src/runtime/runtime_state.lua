-- Runtime state helpers for settle-loop flags.
local M = {}

-- Read whether the runtime is currently blocked by a prompt.
function M.getPromptMessage(callbacks)
	return callbacks and callbacks.mainObject and callbacks.mainObject.promptMsg or nil
end

-- Decide whether the runtime should stop advancing frames.
function M.shouldStop(callbacks)
	if not callbacks then
		return false
	end

	return callbacks.headlessDone or M.getPromptMessage(callbacks) ~= nil
end

return M
