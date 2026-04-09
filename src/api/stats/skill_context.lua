-- Skill context resolution for stats APIs.
local M = {}

local function get_actor_main_skill(build)
    local player = build
        and build.calcsTab
        and build.calcsTab.mainEnv
        and build.calcsTab.mainEnv.player
        or nil
    return player and player.mainSkill or nil
end

local function normalize_skill_part_name(skillPart)
    if type(skillPart) == "table" then
        return skillPart.name or skillPart.label or nil
    end
    return skillPart
end

local function get_socket_group_index(build, socketGroup)
    if not build or not build.skillsTab or not socketGroup then
        return nil
    end

    local groups = build.skillsTab.socketGroupList or {}
    for groupIndex, group in ipairs(groups) do
        if group == socketGroup then
            return groupIndex
        end
    end

    return nil
end

local function get_skill_index(displayList, skill)
    if type(displayList) ~= "table" or not skill then
        return nil
    end

    for skillIndex, entry in ipairs(displayList) do
        if entry == skill then
            return skillIndex
        end
    end

    return nil
end

function M.resolve(build)
    local mainSkill = get_actor_main_skill(build)
    if mainSkill then
        local socketGroup = mainSkill.socketGroup or nil
        local granted = mainSkill.activeEffect and mainSkill.activeEffect.grantedEffect or nil
        local srcInstance = mainSkill.activeEffect and mainSkill.activeEffect.srcInstance or nil
        local skillPartIndex = srcInstance and (srcInstance.skillPartCalcs or srcInstance.skillPart) or nil
        local skillParts = granted and granted.parts or nil
        local skillPart = skillParts and skillPartIndex and skillParts[skillPartIndex] or mainSkill.skillPartName
        local displayList = socketGroup and (socketGroup.displaySkillListCalcs or socketGroup.displaySkillList)
            or nil

        return {
            socketGroupIndex = get_socket_group_index(build, socketGroup)
                or (build and build.mainSocketGroup or nil),
            socketGroupLabel = socketGroup and (socketGroup.displayLabel or socketGroup.label) or nil,
            skillIndex = get_skill_index(displayList, mainSkill)
                or (socketGroup and (socketGroup.mainActiveSkillCalcs or socketGroup.mainActiveSkill or 1))
                or 1,
            skillPartIndex = skillPartIndex,
            skillPartName = normalize_skill_part_name(skillPart),
            name = granted and granted.name or nil,
            selectionSource = "calcs",
        }
    end

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
    local skillPartIndex = srcInstance and (srcInstance.skillPartCalcs or srcInstance.skillPart)
        or nil
    local skillParts = skill
            and skill.activeEffect
            and skill.activeEffect.grantedEffect
            and skill.activeEffect.grantedEffect.parts
        or nil
    local skillPartName = skillParts and skillPartIndex and skillParts[skillPartIndex]
        or skill and skill.skillPartName
        or nil

    return {
        socketGroupIndex = skillNumber,
        socketGroupLabel = group.displayLabel or group.label or nil,
        skillIndex = skillIndex,
        skillPartIndex = skillPartIndex,
        skillPartName = normalize_skill_part_name(skillPartName),
        name = granted and granted.name or nil,
        selectionSource = usesCalcsSelection and "calcs" or "main",
    }
end

return M
