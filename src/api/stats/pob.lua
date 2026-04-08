-- Adapter that centralizes direct access to PoB skills tab state for stats summaries.
local M = {}
M.__index = M

function M.new()
    return setmetatable({}, M)
end

local function getSkillContext(build)
    if not build or not build.skillsTab then
        return nil
    end

    local skillNumber = build.calcsTab
            and build.calcsTab.input
            and tonumber(build.calcsTab.input.skill_number)
        or build.mainSocketGroup
        or 1
    local groups = build.skillsTab.socketGroupList or {}
    local group = groups[skillNumber]
    if not group then
        return nil
    end

    local usesCalcsSelection = group.displaySkillListCalcs ~= nil
    local displayList = group.displaySkillListCalcs or group.displaySkillList
    local skillIndex = usesCalcsSelection and (group.mainActiveSkillCalcs or 1)
        or (group.mainActiveSkill or 1)
    local skill = displayList and displayList[skillIndex]
    local granted = skill and skill.activeEffect and skill.activeEffect.grantedEffect
    local srcInstance = skill and skill.activeEffect and skill.activeEffect.srcInstance or nil
    local skillPartIndex = srcInstance and (srcInstance.skillPartCalcs or srcInstance.skillPart) or nil
    local skillParts = skill and skill.activeEffect and skill.activeEffect.grantedEffect and skill.activeEffect.grantedEffect.parts
        or nil
    local skillPartName = skillParts and skillPartIndex and skillParts[skillPartIndex]
        or skill and skill.skillPartName
        or nil
    if type(skillPartName) == "table" then
        skillPartName = skillPartName.name or skillPartName.label or nil
    end

    return {
        socketGroupIndex = skillNumber,
        socketGroupLabel = group.displayLabel or group.label or nil,
        skillIndex = skillIndex,
        skillPartIndex = skillPartIndex,
        skillPartName = skillPartName,
        name = granted and granted.name or nil,
        selectionSource = usesCalcsSelection and "calcs" or "main",
    }
end

function M:get_skill_context(build)
    return getSkillContext(build)
end

function M:get_main_skill_name(build)
    local skillContext = getSkillContext(build)
    return skillContext and skillContext.name or nil
end

return M
