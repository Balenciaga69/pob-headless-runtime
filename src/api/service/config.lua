-- Config service that applies and compares simulated changes.
local simulationUtil = require("util.simulation")
local tableUtil = require("util.table")

local M = {}
M.__index = M

function M.new(repos, services)
    -- Keep the config service thin and dependency-driven.
    return setmetatable({
        repos = repos,
        services = services,
    }, M)
end

function M:apply_config(params)
    -- Apply the config patch directly through the repo adapter.
    return self.repos.config:apply_patch(params)
end

function M:compare_config_stats(params, fields)
    -- Snapshot, apply, compare, and restore a config change.
    if fields ~= nil and type(fields) ~= "table" then
        return nil, "fields must be a table"
    end

    local snapshot, buildOrErr = self.repos.config:snapshot()
    if not snapshot then
        return nil, buildOrErr
    end
    local build = buildOrErr

    local beforeOutput = build.calcsTab.mainOutput
    if not beforeOutput then
        beforeOutput = self.repos.runtime:rebuild_config(build)
    end
    if not beforeOutput then
        return nil, "no output available"
    end

    local beforeStats = self.services.stats:pick_fields(beforeOutput, fields)
    beforeStats._meta = self.services.stats:build_meta(build)

    local appliedConfig, applyErr = self:apply_config(params)
    if not appliedConfig then
        self.repos.config:restore(snapshot)
        return nil, applyErr
    end

    local afterOutput = build.calcsTab.mainOutput
    local afterStats = self.services.stats:pick_fields(afterOutput, fields)
    afterStats._meta = self.services.stats:build_meta(build)

    local compared, compareErr = self.services.stats:compare_stats(beforeStats, afterStats, fields)
    self.repos.config:restore(snapshot)
    if not compared then
        return nil, compareErr
    end

    return simulationUtil.buildResult("config", compared, {
        restored = true,
        simulationMode = "snapshot_restore",
        config = tableUtil.shallowCopy(params),
    })
end

return M
