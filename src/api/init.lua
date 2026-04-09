-- Public API binding layer for headless callers.
local runtimeApi = require("api.runtime")
local surface = require("api.surface")

local M = {}

-- Formal public API surface for headless callers. Session binds this module to
-- `session.api`, and legacy helpers expose that bound table as `PoBHeadless`.

local function getServices(session)
    -- Resolve the service table from a live session.
    if type(session) ~= "table" or type(session.getServices) ~= "function" then
        return nil
    end
    return session:getServices()
end

-- Bind a session method to a service method, creating a closure that handles
-- service lookup and error reporting for the caller.
local function bind(session, serviceName, methodName)
    -- Create a thin wrapper around a service method with consistent error handling.
    return function(...)
        local services = getServices(session)
        local service = services and services[serviceName] or nil
        local method = service and service[methodName] or nil
        if not method then
            return nil, serviceName .. " service not available"
        end
        return method(service, ...)
    end
end

local function bindMap(session, descriptors)
    local surface = {}
    for exportName, descriptor in pairs(descriptors or {}) do
        surface[exportName] = bind(session, descriptor.service, descriptor.method)
    end
    return surface
end

-- Bind session to all public APIs, creating a unified entry point for helper scripts and transports.
function M.create(session)
    -- The stable root surface is the maintained product contract.
    local api = bindMap(session, surface.stable_bindings)

    -- Experimental capabilities remain as a compatibility sandbox only.
    api.experimental = bindMap(session, surface.experimental_bindings)

    api.get_runtime_status = function()
        return runtimeApi.get_runtime_status(session)
    end
    api.health = function()
        return runtimeApi.health(session)
    end
    api.get_api_surface = function()
        return runtimeApi.get_api_surface()
    end
    api.get_stub_capabilities = function()
        return runtimeApi.get_stub_capabilities()
    end

    return api
end

return M
