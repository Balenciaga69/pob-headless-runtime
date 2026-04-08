-- Service layer between the public API and repo adapters.
local statsService = require("api.service.stats")
local skillsService = require("api.service.skills")
local treeService = require("api.service.tree")
local itemsService = require("api.service.items")
local importService = require("api.service.import")
local configService = require("api.service.config")
local buildService = require("api.service.build")
local fileUtil = require("util.file")

local M = {}

function M.create(session, repos)
    -- Assemble the service layer from the repo adapters.
    local services = {}
    services.stats = statsService.new(repos)
    services.skills = skillsService.new(repos)
    services.tree = treeService.new(repos, services)
    services.items = itemsService.new(repos, services)
    services.importer = importService.new(repos, services)
    services.config = configService.new(repos, services)
    services.build = buildService.new(repos, services, session, fileUtil)
    return services
end

return M
