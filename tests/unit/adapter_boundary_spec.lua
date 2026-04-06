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
	expect(type(repos.items.pob.render_tooltip) == "function", "expected items pob adapter")
	expect(type(repos.importer.pob.get_import_tab) == "function", "expected importer pob adapter")
	expect(type(repos.tree.pob.refresh_active_spec) == "function", "expected tree pob adapter")
	expect(type(repos.skills.pob.get_group) == "function", "expected skills pob adapter")
	expect(type(repos.config.pob.get_input) == "function", "expected config pob adapter")
	expect(type(repos.stats.pob.get_main_skill_name) == "function", "expected stats pob adapter")

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
