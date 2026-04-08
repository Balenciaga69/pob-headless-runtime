-- Config orchestrator that applies and compares simulated changes.
local configSpecs = require("api.config.helpers.spec")
local configPob = require("api.config.pob")
local simulationUtil = require("util.simulation")
local tableUtil = require("util.table")

local M = {}
M.__index = M

function M.new(repos, services)
    return setmetatable({
        runtime = repos.runtime,
        stats = services.stats,
        pob = configPob.new(),
    }, M)
end

function M:snapshot()
    -- Capture the current config input state for restore flows.
    local build, err =
        self.runtime:ensure_build_ready({ "configTab", "calcsTab" }, "build/config not initialized")
    if not build then
        return nil, err
    end
    return self.pob:copy_snapshot(build), build
end

function M:restore(snapshot)
    -- Restore config input state from a snapshot and rebuild output.
    local build, err =
        self.runtime:ensure_build_ready({ "configTab", "calcsTab" }, "build/config not initialized")
    if not build then
        return nil, err
    end
    self.pob:restore_snapshot(build, snapshot)
    self.runtime:rebuild_config(build)
    return true
end

function M:apply_config(params)
    -- Apply a validated config patch and return the effective summary.
    local build, err =
        self.runtime:ensure_build_ready({ "configTab", "calcsTab" }, "build/config not initialized")
    if not build then
        return nil, err
    end
    if type(params) ~= "table" then
        return nil, "config must be a table"
    end

    local input = self.pob:get_input(build)
    for key in pairs(params) do
        if not configSpecs[key] then
            return nil, "unsupported config field: " .. tostring(key)
        end
    end
    for key, spec in pairs(configSpecs) do
        local value = params[key]
        if value ~= nil then
            spec.apply(build, input, value, self.pob)
        end
    end

    self.runtime:rebuild_config(build)
    self.runtime:run_frames_if_idle(1)

    return {
        bandit = input.bandit or build.bandit,
        pantheonMajorGod = input.pantheonMajorGod or build.pantheonMajorGod,
        pantheonMinorGod = input.pantheonMinorGod or build.pantheonMinorGod,
        enemyLevel = self.pob:get_enemy_level(build),
    }
end

function M:get_config()
    -- Read the supported writable config surface back as a normalized payload.
    local build, err =
        self.runtime:ensure_build_ready({ "configTab", "calcsTab" }, "build/config not initialized")
    if not build then
        return nil, err
    end

    local input = self.pob:get_input(build)
    local result = {}
    for key, spec in pairs(configSpecs) do
        if type(spec.read) == "function" then
            result[key] = spec.read(build, input, self.pob)
        end
    end
    return result
end

function M:compare_config_stats(params, fields)
    -- Snapshot, apply, compare, and restore a config change.
    if fields ~= nil and type(fields) ~= "table" then
        return nil, "fields must be a table"
    end

    local snapshot, buildOrErr = self:snapshot()
    if not snapshot then
        return nil, buildOrErr
    end
    local build = buildOrErr

    local beforeOutput = build.calcsTab.mainOutput
    if not beforeOutput then
        beforeOutput = self.runtime:rebuild_config(build)
    end
    if not beforeOutput then
        return nil, "no output available"
    end

    local beforeStats = self.stats:pick_fields(beforeOutput, fields)
    beforeStats._meta = self.stats:build_meta(build)

    local appliedConfig, applyErr = self:apply_config(params)
    if not appliedConfig then
        self:restore(snapshot)
        return nil, applyErr
    end

    local afterOutput = build.calcsTab.mainOutput
    local afterStats = self.stats:pick_fields(afterOutput, fields)
    afterStats._meta = self.stats:build_meta(build)

    local compared, compareErr = self.stats:compare_stats(beforeStats, afterStats, fields)
    self:restore(snapshot)
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
