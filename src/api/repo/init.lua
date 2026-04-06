-- Repo bundle that wires the low-level adapters together.
local buildRuntimeRepo = require("api.repo.build_runtime")
local buildRepo = require("api.repo.build")
local statsRepo = require("api.repo.stats")
local skillsRepo = require("api.repo.skills")
local treeRepo = require("api.repo.tree")
local itemsRepo = require("api.repo.items")
local importRepo = require("api.repo.import")
local configRepo = require("api.repo.config")

local M = {}

function M.create(session)
	local runtime = buildRuntimeRepo.new(session)
	local stats = statsRepo.new(runtime)
	local skills = skillsRepo.new(runtime)

	return {
		runtime = runtime,
		build = buildRepo,
		stats = stats,
		skills = skills,
		tree = treeRepo.new(runtime, stats),
		items = itemsRepo.new(runtime),
		importer = importRepo.new(runtime),
		config = configRepo.new(runtime),
	}
end

return M
