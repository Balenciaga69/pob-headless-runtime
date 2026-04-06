-- Stats adapter that snapshots and reads current build state.
local M = {}
M.__index = M

local DEFAULT_STATS_FIELDS = {"TotalDPS", "CombinedDPS", "Life", "EnergyShield", "Mana", "Ward", "Armour", "Evasion",
	"FireResist", "ColdResist", "LightningResist", "ChaosResist", "SpellSuppressionChance",
	"BlockChance", "SpellBlockChance", "EffectiveMovementSpeedMod", "TotalEHP"}

function M.new(runtimeRepo)
	return setmetatable({
		runtime = runtimeRepo,
	}, M)
end

function M:get_default_stat_fields()
	return DEFAULT_STATS_FIELDS
end

function M:get_main_skill_name(build)
	if not build or not build.skillsTab then
		return nil
	end
	local group = build.skillsTab.socketGroupList and build.skillsTab.socketGroupList[build.mainSocketGroup or 1]
	if not group then
		return nil
	end
	local skillIndex = group.mainActiveSkill or 1
	local skill = group.displaySkillList and group.displaySkillList[skillIndex]
	local granted = skill and skill.activeEffect and skill.activeEffect.grantedEffect
	return granted and granted.name or nil
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
