-- Stats orchestrator that normalizes field selection and reads.
local tableUtil = require("util.table")
local statsCompareUtil = require("util.stats_compare")

local M = {}
M.__index = M

local DEFAULT_STATS_FIELDS = {
    "TotalDPS",
    "CombinedDPS",
    "Life",
    "EnergyShield",
    "Mana",
    "Ward",
    "Armour",
    "Evasion",
    "FireResist",
    "ColdResist",
    "LightningResist",
    "ChaosResist",
    "SpellSuppressionChance",
    "BlockChance",
    "SpellBlockChance",
    "EffectiveMovementSpeedMod",
    "TotalEHP",
}

function M.new(repos)
    return setmetatable({
        runtime = repos.runtime,
        pob = require("api.stats.pob").new(),
    }, M)
end

function M:get_default_stat_fields()
    return DEFAULT_STATS_FIELDS
end

function M:get_main_skill_name(build)
    return self.pob:get_main_skill_name(build)
end

function M:get_output()
    local build, err = self.runtime:ensure_build_ready({ "calcsTab" }, "build not initialized")
    if not build then
        return nil, err
    end
    local output, outputErr = self.runtime:rebuild_output(build)
    if not output then
        return nil, outputErr
    end
    return output, build
end

function M:build_meta(build)
    return {
        buildName = build and build.buildName or nil,
        level = build and tonumber(build.characterLevel) or nil,
        treeVersion = build
                and (build.targetVersion or (build.spec and build.spec.treeVersion) or nil)
            or nil,
        mainSkill = self:get_main_skill_name(build),
    }
end

function M:build_summary(build, output)
    return {
        buildName = build and build.buildName or nil,
        level = build and tonumber(build.characterLevel) or nil,
        className = build and build.spec and build.spec.curClassName or nil,
        ascendClassName = build and build.spec and build.spec.curAscendClassName or nil,
        treeVersion = build
                and (build.targetVersion or (build.spec and build.spec.treeVersion) or nil)
            or nil,
        mainSkill = self:get_main_skill_name(build),
        stats = {
            TotalDPS = output and output.TotalDPS or nil,
            CombinedDPS = output and output.CombinedDPS or nil,
            Life = output and output.Life or nil,
            EnergyShield = output and output.EnergyShield or nil,
            FireResist = output and output.FireResist or nil,
            ColdResist = output and output.ColdResist or nil,
            LightningResist = output and output.LightningResist or nil,
            ChaosResist = output and output.ChaosResist or nil,
        },
    }
end

function M:pick_fields(output, fields)
    local result = {}
    for _, field in ipairs(fields or self:get_default_stat_fields()) do
        if output[field] ~= nil then
            result[field] = output[field]
        end
    end
    return result
end

function M:get_stats(fields)
    local output, build = self:get_output()
    if not output then
        return nil, build
    end

    local result = self:pick_fields(output, fields)
    result._meta = self:build_meta(build)
    return result
end

function M:get_summary()
    local output, build = self:get_output()
    if not output then
        return nil, build
    end
    return self:build_summary(build, output)
end

function M:normalize_compare_fields(beforeStats, afterStats, fields)
    if fields == nil then
        return tableUtil.copyArray(self:get_default_stat_fields())
    end
    if type(fields) ~= "table" then
        return nil, "fields must be a table"
    end

    local normalized = {}
    local seen = {}
    for _, field in ipairs(fields) do
        if type(field) ~= "string" or field == "" then
            return nil, "fields must contain non-empty strings"
        end
        if not seen[field] then
            seen[field] = true
            normalized[#normalized + 1] = field
        end
    end

    if #normalized == 0 then
        for key, _ in pairs(beforeStats or {}) do
            if
                type(key) == "string"
                and key ~= "_meta"
                and type((beforeStats or {})[key]) == "number"
            then
                normalized[#normalized + 1] = key
                seen[key] = true
            end
        end
        for key, _ in pairs(afterStats or {}) do
            if
                type(key) == "string"
                and key ~= "_meta"
                and type((afterStats or {})[key]) == "number"
                and not seen[key]
            then
                normalized[#normalized + 1] = key
                seen[key] = true
            end
        end
    end

    return normalized
end

function M:compare_stats(beforeStats, afterStats, fields)
    if type(beforeStats) ~= "table" then
        return nil, "before stats must be a table"
    end
    if type(afterStats) ~= "table" then
        return nil, "after stats must be a table"
    end

    local compareFields, err = self:normalize_compare_fields(beforeStats, afterStats, fields)
    if not compareFields then
        return nil, err
    end

    local beforePicked = statsCompareUtil.pickNumericFields(beforeStats, compareFields)
    local afterPicked = statsCompareUtil.pickNumericFields(afterStats, compareFields)
    local delta, changedFields =
        statsCompareUtil.numericDelta(beforeStats, afterStats, compareFields)

    return {
        fields = compareFields,
        before = beforePicked,
        after = afterPicked,
        delta = delta,
        changedFields = changedFields,
        _meta = {
            before = beforeStats._meta,
            after = afterStats._meta,
        },
    }
end

return M
