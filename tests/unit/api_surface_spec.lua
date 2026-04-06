local apiModule = require("api.init")
local expect = require("testkit").expect

do
	local api = apiModule.create({})

	expect(type(api.load_build_xml) == "function", "expected load_build_xml export")
	expect(type(api.load_build_code) == "function", "expected load_build_code export")
	expect(type(api.compare_item_stats) == "function", "expected compare_item_stats export")
	expect(type(api.get_summary) == "function", "expected get_summary export")
	expect(type(api.get_stats) == "function", "expected get_stats export")
	expect(type(api.simulate_node_delta) == "function", "expected simulate_node_delta export")
	expect(type(api.get_runtime_status) == "function", "expected get_runtime_status export")
	expect(type(api.health) == "function", "expected health export")
	expect(type(api.get_api_surface) == "function", "expected get_api_surface export")
	expect(type(api.experimental) == "table", "expected experimental namespace export")
	expect(type(api.update_imported_build) == "nil", "expected experimental method to stay off stable root")
	expect(type(api.experimental.update_imported_build) == "function", "expected experimental build export")
	expect(type(api.experimental.compare_config_stats) == "function", "expected experimental config export")
	expect(type(api.experimental.render_item_tooltip) == "function", "expected experimental item export")
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
	expect(stable.compare_item_stats == true, "expected compare_item_stats to be stable")
	expect(stable.health == true, "expected health to be stable")
	expect(experimental.update_imported_build == true, "expected update_imported_build to be experimental")
	expect(experimental.render_item_tooltip == true, "expected render_item_tooltip to be experimental")
	expect(experimental.select_skill == true, "expected select_skill to be experimental")
	expect(surface.namespaces.stable == "top_level", "expected stable namespace marker")
	expect(surface.namespaces.experimental == "experimental", "expected experimental namespace marker")
end
