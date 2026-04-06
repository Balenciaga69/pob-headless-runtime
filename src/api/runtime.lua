-- Runtime status and capability exposure for headless callers.
local stubs = require("compatibility.stubs")

local M = {}

-- Expose current session/runtime status for external tools or smoke tests to check readiness.
function M.get_runtime_status(session)
	-- Return the current session readiness snapshot.
    return session:getStatus()
end

-- Expose headless stub capability matrix to prevent callers from using unsupported APIs.
function M.get_stub_capabilities()
	-- Return the capability matrix for the compatibility layer.
    return stubs.getCapabilityMatrix()
end

return M
