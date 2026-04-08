-- Runtime status and capability exposure for headless callers.
local stubs = require("compatibility.stubs")

local M = {}

local API_SURFACE = {
    stable = {
        "load_build_xml",
        "load_build_code",
        "load_build_file",
        "save_build_xml",
        "save_build_code",
        "save_build_file",
        "get_summary",
        "get_stats",
        "get_display_stats",
        "equip_item",
        "list_equipment",
        "set_config",
        "get_config",
        "get_runtime_status",
        "health",
    },
    experimental = {
        "update_imported_build",
        "compare_stats",
        "list_skills",
        "select_skill",
        "get_selected_skill",
        "restore_skill_selection",
        "compare_config_stats",
        "parse_item",
        "test_item",
        "simulate_mod",
        "render_item_tooltip",
        "compare_item_stats",
        "get_tree",
        "get_tree_node",
        "search_tree_nodes",
        "create_tree_snapshot",
        "restore_tree_snapshot",
        "simulate_node_delta",
    },
}

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
        stable = { unpack(API_SURFACE.stable) },
        experimental = { unpack(API_SURFACE.experimental) },
        namespaces = {
            stable = "top_level",
            experimental = "experimental",
            legacy = "flattened_globals",
        },
    }
end

-- Expose headless stub capability matrix to prevent callers from using unsupported APIs.
function M.get_stub_capabilities()
    -- Return the capability matrix for the compatibility layer.
    return stubs.getCapabilityMatrix()
end

return M
