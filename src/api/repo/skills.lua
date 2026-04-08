-- Skill adapter that keeps active selection and calcs input aligned.
local M = {}
M.__index = M

function M.new(runtimeRepo)
    return setmetatable({
        runtime = runtimeRepo,
        pob = require("api.repo.pob_skills_adapter").new(),
    }, M)
end

local function getSelectedSkillEntry(group)
    local skillIndex = group and (group.mainActiveSkill or 1) or 1
    return group and group.displaySkillList and group.displaySkillList[skillIndex] or nil
end

function M:build_skill_snapshot(build, groupIndex, group)
    groupIndex = tonumber(groupIndex or self.pob:get_selected_group_index(build) or 1) or 1
    group = group or self.pob:get_group(build, groupIndex)
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
        calcsSkillNumber = self.pob:get_calcs_skill_number(build),
    }
end

function M:list_skills()
    local build, err =
        self.runtime:ensure_build_ready({ "skillsTab", "calcsTab" }, "skills not initialized")
    if not build then
        return nil, err
    end

    local groups = {}
    for groupIndex, group in ipairs(self.pob:get_socket_groups(build)) do
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
            isSelected = self.pob:get_selected_group_index(build) == groupIndex,
            skills = skills,
        }
    end

    return {
        mainSocketGroup = self.pob:get_selected_group_index(build),
        calcsSkillNumber = self.pob:get_calcs_skill_number(build),
        groups = groups,
    }
end

function M:get_selected_skill()
    local build, err =
        self.runtime:ensure_build_ready({ "skillsTab", "calcsTab" }, "skills not initialized")
    if not build then
        return nil, err
    end
    return self:build_skill_snapshot(build)
end

function M:apply_selection(params)
    local build, err =
        self.runtime:ensure_build_ready({ "skillsTab", "calcsTab" }, "skills not initialized")
    if not build then
        return nil, err
    end
    if type(params) ~= "table" then
        return nil, "params must be a table"
    end

    local groupIndex =
        tonumber(params.group or params.mainSocketGroup or self.pob:get_selected_group_index(build))
    local group = self.pob:get_group(build, groupIndex)
    if not group then
        return nil, "invalid skill group"
    end

    self.pob:set_selected_group_index(build, groupIndex)
    self.pob:set_calcs_skill_number(build, groupIndex)

    if params.skill ~= nil or params.mainActiveSkill ~= nil then
        local skillIndex = tonumber(params.skill or params.mainActiveSkill)
        if
            not skillIndex
            or not group.displaySkillList
            or not group.displaySkillList[skillIndex]
        then
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
