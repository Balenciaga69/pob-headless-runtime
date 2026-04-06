-- Public API binding layer for headless callers.
local runtimeApi = require("api.runtime")

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
    -- Keep the top-level session API intentionally small; non-stable helpers live under api.experimental.
    local api = bindMap(session, {
        load_build_xml = { service = "build", method = "load_build_xml" },
        load_build_code = { service = "build", method = "load_build_code" },
        get_stats = { service = "stats", method = "get_stats" },
        get_summary = { service = "stats", method = "get_summary" },
        compare_item_stats = { service = "items", method = "compare_item_stats" },
        simulate_node_delta = { service = "tree", method = "simulate_node_delta" },
    })

    -- Experimental capabilities stay available for refactors and legacy scripts without polluting the stable root surface.
    api.experimental = bindMap(session, {
        load_build_file = { service = "build", method = "load_build_file" },
        save_build_xml = { service = "build", method = "save_build_xml" },
        save_build_code = { service = "build", method = "save_build_code" },
        save_build_file = { service = "build", method = "save_build_file" },
        update_imported_build = { service = "build", method = "update_imported_build" },
        compare_stats = { service = "stats", method = "compare_stats" },
        list_skills = { service = "skills", method = "list_skills" },
        select_skill = { service = "skills", method = "select_skill" },
        get_selected_skill = { service = "skills", method = "get_selected_skill" },
        restore_skill_selection = { service = "skills", method = "restore_skill_selection" },
        set_config = { service = "config", method = "apply_config" },
        compare_config_stats = { service = "config", method = "compare_config_stats" },
        parse_item = { service = "items", method = "parse_item" },
        test_item = { service = "items", method = "test_item" },
        simulate_mod = { service = "items", method = "simulate_mod" },
        render_item_tooltip = { service = "items", method = "render_item_tooltip" },
        equip_item = { service = "items", method = "equip_item" },
        get_tree = { service = "tree", method = "get_tree" },
        get_tree_node = { service = "tree", method = "get_tree_node" },
        search_tree_nodes = { service = "tree", method = "search_tree_nodes" },
        create_tree_snapshot = { service = "tree", method = "create_tree_snapshot" },
        restore_tree_snapshot = { service = "tree", method = "restore_tree_snapshot" },
    })

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
