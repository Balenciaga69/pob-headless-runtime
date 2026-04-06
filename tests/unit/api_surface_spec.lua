local apiModule = require("api.init")
local expect = require("testkit").expect

do
	local api = apiModule.create({})

	expect(type(api.load_build_file) == "function", "expected load_build_file export")
	expect(type(api.load_build_code) == "function", "expected load_build_code export")
	expect(type(api.update_imported_build) == "function", "expected update_imported_build export")
	expect(type(api.compare_config_stats) == "function", "expected compare_config_stats export")
	expect(type(api.compare_item_stats) == "function", "expected compare_item_stats export")
	expect(type(api.simulate_mod) == "function", "expected simulate_mod export")
	expect(type(api.get_tree) == "function", "expected get_tree export")
	expect(type(api.get_tree_node) == "function", "expected get_tree_node export")
	expect(type(api.search_tree_nodes) == "function", "expected search_tree_nodes export")
	expect(type(api.create_tree_snapshot) == "function", "expected create_tree_snapshot export")
	expect(type(api.restore_tree_snapshot) == "function", "expected restore_tree_snapshot export")
	expect(type(api.simulate_node_delta) == "function", "expected simulate_node_delta export")
	expect(type(api.save_build_code) == "function", "expected save_build_code export")
	expect(type(api.get_runtime_status) == "function", "expected get_runtime_status export")
end

do
	local api = apiModule.create({})
	local result, err = api.get_stats()
	expect(result == nil, "expected missing stats service to fail cleanly")
	expect(err == "stats service not available", "expected explicit service guard error")
end
