-- Stats adapter that snapshots and reads current build state.
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

function M.new(runtimeRepo)
    return setmetatable({
        runtime = runtimeRepo,
        pob = require("api.repo.pob_stats_adapter").new(),
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

return M
