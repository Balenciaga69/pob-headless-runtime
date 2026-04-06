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

-- Bind session to all public APIs, creating a unified entry point for helper scripts and transports.
function M.create(session)
    -- Expose the stable public API surface for external callers.
    return {
        load_build_file = bind(session, "build", "load_build_file"),
        load_build_xml = bind(session, "build", "load_build_xml"),
        load_build_code = bind(session, "build", "load_build_code"),
        save_build_xml = bind(session, "build", "save_build_xml"),
        save_build_code = bind(session, "build", "save_build_code"),
        save_build_file = bind(session, "build", "save_build_file"),
        update_imported_build = bind(session, "build", "update_imported_build"),
        get_stats = bind(session, "stats", "get_stats"),
        get_summary = bind(session, "stats", "get_summary"),
        compare_stats = bind(session, "stats", "compare_stats"),
        list_skills = bind(session, "skills", "list_skills"),
        select_skill = bind(session, "skills", "select_skill"),
        get_selected_skill = bind(session, "skills", "get_selected_skill"),
        restore_skill_selection = bind(session, "skills", "restore_skill_selection"),
        set_config = bind(session, "config", "apply_config"),
        compare_config_stats = bind(session, "config", "compare_config_stats"),
        parse_item = bind(session, "items", "parse_item"),
        test_item = bind(session, "items", "test_item"),
        compare_item_stats = bind(session, "items", "compare_item_stats"),
        simulate_mod = bind(session, "items", "simulate_mod"),
        render_item_tooltip = bind(session, "items", "render_item_tooltip"),
        equip_item = bind(session, "items", "equip_item"),
        get_tree = bind(session, "tree", "get_tree"),
        get_tree_node = bind(session, "tree", "get_tree_node"),
        search_tree_nodes = bind(session, "tree", "search_tree_nodes"),
        create_tree_snapshot = bind(session, "tree", "create_tree_snapshot"),
        restore_tree_snapshot = bind(session, "tree", "restore_tree_snapshot"),
        simulate_node_delta = bind(session, "tree", "simulate_node_delta"),
        get_runtime_status = function()
            return runtimeApi.get_runtime_status(session)
        end,
        health = function()
            return runtimeApi.health(session)
        end,
        get_api_surface = function()
            return runtimeApi.get_api_surface()
        end,
        get_stub_capabilities = function()
            return runtimeApi.get_stub_capabilities()
        end
    }
end

return M
