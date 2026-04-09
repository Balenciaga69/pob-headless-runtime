-- Runtime status and capability exposure for headless callers.
local stubs = require("compatibility.stubs")
local surface = require("api.surface")

local M = {}

-- Expose current session/runtime status for external tools or smoke tests to check readiness.
function M.get_runtime_status(session)
    -- Return the current session readiness snapshot.
    return session:getStatus()
end

-- Stable alias for callers that want a generic worker readiness probe.
function M.health(session)
    return M.get_runtime_status(session)
end

-- Expose the formal API tiers. Stable is maintained; experimental is compatibility-only.
function M.get_api_surface()
    return {
        stable = { unpack(surface.stable_names) },
        experimental = { unpack(surface.experimental_names) },
        namespaces = surface.namespaces,
    }
end

-- Expose headless stub capability matrix to prevent callers from using unsupported APIs.
function M.get_stub_capabilities()
    -- Return the capability matrix for the compatibility layer.
    return stubs.getCapabilityMatrix()
end

return M
