-- Canonical public API surface for stable and experimental bindings.
local M = {}

M.namespaces = {
    stable = "top_level",
    experimental = "experimental",
    legacy = "flattened_globals",
}

M.stable_names = {
    "load_build_xml",
    "load_build_code",
    "load_build_file",
    "save_build_xml",
    "save_build_code",
    "save_build_file",
    "get_summary",
    "get_stats",
    "get_display_stats",
    "preview_item_display_stats",
    "equip_item",
    "list_equipment",
    "list_items",
    "list_skills",
    "select_skill",
    "get_selected_skill",
    "set_config",
    "get_config",
    "get_runtime_status",
    "health",
}

M.experimental_names = {
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
}

M.stable_bindings = {
    load_build_xml = { service = "build", method = "load_build_xml" },
    load_build_code = { service = "build", method = "load_build_code" },
    load_build_file = { service = "build", method = "load_build_file" },
    save_build_xml = { service = "build", method = "save_build_xml" },
    save_build_code = { service = "build", method = "save_build_code" },
    save_build_file = { service = "build", method = "save_build_file" },
    get_stats = { service = "stats", method = "get_stats" },
    get_display_stats = { service = "stats", method = "get_display_stats" },
    preview_item_display_stats = { service = "items", method = "preview_item_display_stats" },
    get_summary = { service = "stats", method = "get_summary" },
    equip_item = { service = "items", method = "equip_item" },
    list_equipment = { service = "items", method = "list_equipment" },
    list_items = { service = "items", method = "list_items" },
    list_skills = { service = "skills", method = "list_skills" },
    select_skill = { service = "skills", method = "select_skill" },
    get_selected_skill = { service = "skills", method = "get_selected_skill" },
    set_config = { service = "config", method = "apply_config" },
    get_config = { service = "config", method = "get_config" },
}

M.experimental_bindings = {
    update_imported_build = { service = "build", method = "update_imported_build" },
    compare_stats = { service = "stats", method = "compare_stats" },
    list_skills = { service = "skills", method = "list_skills" },
    select_skill = { service = "skills", method = "select_skill" },
    get_selected_skill = { service = "skills", method = "get_selected_skill" },
    restore_skill_selection = { service = "skills", method = "restore_skill_selection" },
    compare_config_stats = { service = "config", method = "compare_config_stats" },
    parse_item = { service = "items", method = "parse_item" },
    test_item = { service = "items", method = "test_item" },
    simulate_mod = { service = "items", method = "simulate_mod" },
    render_item_tooltip = { service = "items", method = "render_item_tooltip" },
    compare_item_stats = { service = "items", method = "compare_item_stats" },
    get_tree = { service = "tree", method = "get_tree" },
    get_tree_node = { service = "tree", method = "get_tree_node" },
    search_tree_nodes = { service = "tree", method = "search_tree_nodes" },
    create_tree_snapshot = { service = "tree", method = "create_tree_snapshot" },
    restore_tree_snapshot = { service = "tree", method = "restore_tree_snapshot" },
    simulate_node_delta = { service = "tree", method = "simulate_node_delta" },
}

function M.to_lookup(names)
    local lookup = {}
    for _, name in ipairs(names or {}) do
        lookup[name] = true
    end
    return lookup
end

return M
