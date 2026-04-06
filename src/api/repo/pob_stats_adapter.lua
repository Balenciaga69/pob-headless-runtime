-- Adapter that centralizes direct access to PoB skills tab state for stats summaries.
local M = {}
M.__index = M

function M.new()
	return setmetatable({}, M)
end

function M:get_main_skill_name(build)
	if not build or not build.skillsTab then
		return nil
	end
	local groups = build.skillsTab.socketGroupList or {}
	local group = groups[build.mainSocketGroup or 1]
	if not group then
		return nil
	end
	local skillIndex = group.mainActiveSkill or 1
	local skill = group.displaySkillList and group.displaySkillList[skillIndex]
	local granted = skill and skill.activeEffect and skill.activeEffect.grantedEffect
	return granted and granted.name or nil
end

return M
