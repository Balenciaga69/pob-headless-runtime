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

    local services = session:getServices()
    expect(type(services) == "table", "expected session services table")
    expect(type(services.tree.simulate_node_delta) == "function", "expected tree service")
    expect(type(services.tree.pob.refresh_active_spec) == "function", "expected tree pob adapter")
    expect(type(services.items.compare_item_stats) == "function", "expected items service")
    expect(
        type(services.items.preview_item_display_stats) == "function",
        "expected items preview display stats service"
    )
    expect(type(services.items.list_items) == "function", "expected items list service")
    expect(type(services.items.pob.render_tooltip) == "function", "expected items pob adapter")
    expect(type(services.skills.list_skills) == "function", "expected skills service")
    expect(type(services.skills.select_skill) == "function", "expected skills select service")
    expect(type(services.skills.pob.get_group) == "function", "expected skills pob adapter")
    expect(type(services.importer.update_imported_build) == "function", "expected import service")
    expect(type(services.importer.pob.get_import_tab) == "function", "expected import pob adapter")
    expect(type(services.stats.get_summary) == "function", "expected stats service")
    expect(type(services.stats.pob.get_main_skill_name) == "function", "expected stats pob adapter")
    expect(type(services.build.update_imported_build) == "function", "expected build service")
    expect(type(services.config.apply_config) == "function", "expected config orchestrator")
    expect(type(services.config.pob.get_input) == "function", "expected config pob adapter")

    local adapters = session:getAdapters()
    expect(type(adapters.runtime.ensure_build_ready) == "function", "expected adapter runtime repo")
end
