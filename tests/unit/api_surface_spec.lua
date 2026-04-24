local apiModule = require("api.init")
local expect = require("testkit").expect

do
    local api = apiModule.create({})

    expect(type(api.load_build_xml) == "function", "expected load_build_xml export")
    expect(type(api.load_build_code) == "function", "expected load_build_code export")
    expect(type(api.load_build_file) == "function", "expected load_build_file export")
    expect(type(api.save_build_xml) == "function", "expected save_build_xml export")
    expect(type(api.save_build_code) == "function", "expected save_build_code export")
    expect(type(api.save_build_file) == "function", "expected save_build_file export")
    expect(type(api.get_summary) == "function", "expected get_summary export")
    expect(type(api.get_stats) == "function", "expected get_stats export")
    expect(type(api.get_display_stats) == "function", "expected get_display_stats export")
    expect(
        type(api.preview_item_display_stats) == "function",
        "expected preview_item_display_stats export"
    )
    expect(type(api.equip_item) == "function", "expected equip_item export")
    expect(type(api.list_equipment) == "function", "expected list_equipment export")
    expect(type(api.list_items) == "function", "expected list_items export")
    expect(type(api.list_skills) == "function", "expected list_skills export")
    expect(type(api.select_skill) == "function", "expected select_skill export")
    expect(type(api.get_selected_skill) == "function", "expected get_selected_skill export")
    expect(type(api.set_config) == "function", "expected set_config export")
    expect(type(api.get_config) == "function", "expected get_config export")
    expect(type(api.get_runtime_status) == "function", "expected get_runtime_status export")
    expect(type(api.health) == "function", "expected health export")
    expect(type(api.get_api_surface) == "function", "expected get_api_surface export")
    expect(type(api.experimental) == "table", "expected experimental namespace export")
    expect(
        type(api.compare_item_stats) == "nil",
        "expected experimental method to stay off stable root"
    )
    expect(
        type(api.experimental.compare_item_stats) == "function",
        "expected experimental item export"
    )
    expect(
        type(api.experimental.compare_config_stats) == "function",
        "expected experimental config export"
    )
    expect(
        type(api.experimental.simulate_node_delta) == "function",
        "expected experimental tree export"
    )
end

do
    local api = apiModule.create({})
    local result, err = api.get_stats()
    expect(result == nil, "expected missing stats service to fail cleanly")
    expect(err == "stats service not available", "expected explicit service guard error")
end

do
    local api = apiModule.create({})
    local surface = api.get_api_surface()

    expect(type(surface) == "table", "expected api surface table")
    expect(type(surface.stable) == "table", "expected stable api tier")
    expect(type(surface.experimental) == "table", "expected experimental api tier")
    expect(type(surface.namespaces) == "table", "expected namespace model")

    local stable = {}
    for _, name in ipairs(surface.stable) do
        stable[name] = true
    end
    local experimental = {}
    for _, name in ipairs(surface.experimental) do
        experimental[name] = true
    end

    expect(stable.load_build_xml == true, "expected load_build_xml to be stable")
    expect(stable.get_summary == true, "expected get_summary to be stable")
    expect(stable.get_display_stats == true, "expected get_display_stats to be stable")
    expect(
        stable.preview_item_display_stats == true,
        "expected preview_item_display_stats to be stable"
    )
    expect(stable.load_build_file == true, "expected load_build_file to be stable")
    expect(stable.save_build_xml == true, "expected save_build_xml to be stable")
    expect(stable.equip_item == true, "expected equip_item to be stable")
    expect(stable.list_equipment == true, "expected list_equipment to be stable")
    expect(stable.list_items == true, "expected list_items to be stable")
    expect(stable.list_skills == true, "expected list_skills to be stable")
    expect(stable.select_skill == true, "expected select_skill to be stable")
    expect(stable.get_selected_skill == true, "expected get_selected_skill to be stable")
    expect(stable.set_config == true, "expected set_config to be stable")
    expect(stable.get_config == true, "expected get_config to be stable")
    expect(stable.health == true, "expected health to be stable")
    expect(
        experimental.compare_item_stats == true,
        "expected compare_item_stats to be experimental"
    )
    expect(
        experimental.simulate_node_delta == true,
        "expected simulate_node_delta to be experimental"
    )
    expect(experimental.select_skill == true, "expected select_skill to be experimental")
    expect(experimental.list_skills == true, "expected list_skills to stay experimental")
    expect(
        experimental.get_selected_skill == true,
        "expected get_selected_skill to stay experimental"
    )
    expect(surface.namespaces.stable == "top_level", "expected stable namespace marker")
    expect(
        surface.namespaces.experimental == "experimental",
        "expected experimental namespace marker"
    )
end
