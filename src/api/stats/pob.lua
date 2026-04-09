-- Adapter that centralizes direct access to PoB skills tab state for stats summaries.
local skillContext = require("api.stats.skill_context")

local M = {}
M.__index = M

function M.new()
    return setmetatable({}, M)
end

local function getSkillContext(build)
    return skillContext.resolve(build)
end

function M:get_skill_context(build)
    return getSkillContext(build)
end

function M:get_main_skill_name(build)
    local skillContext = getSkillContext(build)
    return skillContext and skillContext.name or nil
end

return M
