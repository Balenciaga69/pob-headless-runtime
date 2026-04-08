-- Internal API wiring that assembles repos and services by feature.
local buildRuntimeRepo = require("api.runtime.repo")
local statsOrchestrator = require("api.stats.orchestrator")
local skillsOrchestrator = require("api.skills.orchestrator")
local treeOrchestrator = require("api.tree.orchestrator")
local itemsOrchestrator = require("api.items.orchestrator")
local importOrchestrator = require("api.import.orchestrator")
local configOrchestrator = require("api.config.orchestrator")
local buildOrchestrator = require("api.build.orchestrator")
local fileUtil = require("util.file")

local M = {}

function M.createRepos(session)
    local runtime = buildRuntimeRepo.new(session)

    return {
        runtime = runtime,
    }
end

function M.createServices(session, repos)
    local services = {}
    services.stats = statsOrchestrator.new(repos)
    services.skills = skillsOrchestrator.new(repos)
    services.tree = treeOrchestrator.new(repos, services)
    services.items = itemsOrchestrator.new(repos, services)
    services.importer = importOrchestrator.new(repos, services)
    services.config = configOrchestrator.new(repos, services)
    services.build = buildOrchestrator.new(repos, services, session, fileUtil)
    return services
end

return M
