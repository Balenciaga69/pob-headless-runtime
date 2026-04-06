-- Skill adapter that keeps active selection and calcs input aligned.
local M = {}
M.__index = M

function M.new(runtimeRepo)
	return setmetatable({
		runtime = runtimeRepo,
	}, M)
end

local function getSkillGroup(build, groupIndex)
	return build and build.skillsTab and build.skillsTab.socketGroupList and build.skillsTab.socketGroupList[groupIndex] or nil
end

local function getSelectedSkillEntry(group)
	local skillIndex = group and (group.mainActiveSkill or 1) or 1
	return group and group.displaySkillList and group.displaySkillList[skillIndex] or nil
end

function M:build_skill_snapshot(build, groupIndex, group)
	groupIndex = tonumber(groupIndex or build.mainSocketGroup or 1) or 1
	group = group or getSkillGroup(build, groupIndex)
	if not group then
		return nil, "selected skill group not found"
	end

	local skillIndex = tonumber(group.mainActiveSkill or 1) or 1
	local skill = getSelectedSkillEntry(group)
	local activeEffect = skill and skill.activeEffect
	local granted = activeEffect and activeEffect.grantedEffect
	local src = activeEffect and activeEffect.srcInstance
	local partIndex = src and src.skillPart or nil
	local part = granted and granted.parts and partIndex and granted.parts[partIndex] or nil

	return {
		group = {
			index = groupIndex,
			label = group.label,
			displayLabel = group.displayLabel or group.label,
			slot = group.slot,
		},
		skill = {
			index = skillIndex,
			name = granted and granted.name or nil,
		},
		part = {
			index = partIndex,
			name = part and part.name or nil,
		},
		calcsSkillNumber = build.calcsTab and build.calcsTab.input and build.calcsTab.input.skill_number or nil,
	}
end

function M:list_skills()
	local build, err = self.runtime:ensure_build_ready({ "skillsTab", "calcsTab" }, "skills not initialized")
	if not build then
		return nil, err
	end

	local groups = {}
	for groupIndex, group in ipairs(build.skillsTab.socketGroupList or {}) do
		local skills = {}
		for skillIndex, entry in ipairs(group.displaySkillList or {}) do
			local activeEffect = entry and entry.activeEffect
			local granted = activeEffect and activeEffect.grantedEffect
			local src = activeEffect and activeEffect.srcInstance
			skills[#skills + 1] = {
				index = skillIndex,
				name = granted and granted.name or nil,
				skillPart = src and src.skillPart or nil,
			}
		end

		groups[#groups + 1] = {
			index = groupIndex,
			label = group.label,
			displayLabel = group.displayLabel or group.label,
			slot = group.slot,
			mainActiveSkill = group.mainActiveSkill,
			isSelected = build.mainSocketGroup == groupIndex,
			skills = skills,
		}
	end

	return {
		mainSocketGroup = build.mainSocketGroup,
		calcsSkillNumber = build.calcsTab.input and build.calcsTab.input.skill_number or nil,
		groups = groups,
	}
end

function M:get_selected_skill()
	local build, err = self.runtime:ensure_build_ready({ "skillsTab", "calcsTab" }, "skills not initialized")
	if not build then
		return nil, err
	end
	return self:build_skill_snapshot(build)
end

function M:apply_selection(params)
	local build, err = self.runtime:ensure_build_ready({ "skillsTab", "calcsTab" }, "skills not initialized")
	if not build then
		return nil, err
	end
	if type(params) ~= "table" then
		return nil, "params must be a table"
	end

	local groupIndex = tonumber(params.group or params.mainSocketGroup or build.mainSocketGroup)
	local group = build.skillsTab.socketGroupList and build.skillsTab.socketGroupList[groupIndex]
	if not group then
		return nil, "invalid skill group"
	end

	local input = build.calcsTab.input or {}
	build.calcsTab.input = input
	build.mainSocketGroup = groupIndex
	input.skill_number = groupIndex

	if params.skill ~= nil or params.mainActiveSkill ~= nil then
		local skillIndex = tonumber(params.skill or params.mainActiveSkill)
		if not skillIndex or not group.displaySkillList or not group.displaySkillList[skillIndex] then
			return nil, "invalid skill index"
		end
		group.mainActiveSkill = skillIndex
	end

	if params.part ~= nil or params.skillPart ~= nil then
		local skillIndex = group.mainActiveSkill or 1
		local skill = group.displaySkillList and group.displaySkillList[skillIndex]
		local src = skill and skill.activeEffect and skill.activeEffect.srcInstance
		if not src then
			return nil, "selected skill does not expose skillPart"
		end
		src.skillPart = tonumber(params.part or params.skillPart)
	end

	return self:build_skill_snapshot(build, groupIndex, group)
end

return M
