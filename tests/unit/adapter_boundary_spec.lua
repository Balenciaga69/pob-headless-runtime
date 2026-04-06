local callbacksModule = require("runtime.callbacks")
local sessionModule = require("runtime.session")
local expect = require("testkit").expect

do
	local callbacks = callbacksModule.new()
	callbacks.setMainObject({
		main = {
			modes = {},
		},
	})

	local session = sessionModule.new({
		sourceDir = "src",
		runtimeDir = "runtime",
		repoRoot = ".",
		currentWorkDir = "src",
	}, callbacks)

	local repos = session:getRepos()
	expect(type(repos) == "table", "expected session repos table")
	expect(type(repos.runtime.ensure_build_ready) == "function", "expected runtime repo")
	expect(type(repos.tree.get_tree_state) == "function", "expected tree repo")
	expect(type(repos.items.parse_item) == "function", "expected items repo")
	expect(type(repos.skills.list_skills) == "function", "expected skills repo")
	expect(type(repos.importer.execute_remote_import) == "function", "expected importer repo")
	expect(type(repos.stats.get_output) == "function", "expected stats repo")
	expect(type(repos.config.apply_patch) == "function", "expected config repo")

	local services = session:getServices()
	expect(type(services) == "table", "expected session services table")
	expect(type(services.tree.simulate_node_delta) == "function", "expected tree service")
	expect(type(services.items.compare_item_stats) == "function", "expected items service")
	expect(type(services.importer.update_imported_build) == "function", "expected import service")
	expect(type(services.stats.get_summary) == "function", "expected stats service")
	expect(type(services.build.update_imported_build) == "function", "expected build service")

	local adapters = session:getAdapters()
	expect(type(adapters.runtime.ensure_build_ready) == "function", "expected adapter runtime repo")
	expect(type(adapters.tree.get_tree_state) == "function", "expected adapter tree repo")
	expect(type(adapters.importer.execute_remote_import) == "function", "expected adapter importer repo")
end
