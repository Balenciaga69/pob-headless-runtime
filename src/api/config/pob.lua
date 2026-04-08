-- Adapter that centralizes direct access to PoB config tab state.
local tableUtil = require("util.table")

local M = {}
M.__index = M

function M.new()
    return setmetatable({}, M)
end

function M:get_input(build)
    local input = build.configTab.input or {}
    build.configTab.input = input
    return input
end

function M:get_enemy_level(build)
    return build.configTab.enemyLevel
end

function M:set_enemy_level(build, value)
    build.configTab.enemyLevel = value
end

function M:copy_snapshot(build)
    return {
        input = tableUtil.shallowCopy(build.configTab.input or {}),
        enemyLevel = build.configTab.enemyLevel,
    }
end

function M:restore_snapshot(build, snapshot)
    build.configTab.input = tableUtil.shallowCopy(snapshot and snapshot.input or {})
    build.configTab.enemyLevel = snapshot and snapshot.enemyLevel or build.configTab.enemyLevel
end

return M
