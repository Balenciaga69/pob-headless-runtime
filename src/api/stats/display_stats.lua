local ipairs = ipairs
local string_format = string.format

local M = {}
M.__index = M

local function matchFlags(reqFlags, notFlags, flags)
    flags = flags or {}

    if type(reqFlags) == "string" then
        reqFlags = { reqFlags }
    end
    if reqFlags then
        for _, flag in ipairs(reqFlags) do
            if not flags[flag] then
                return false
            end
        end
    end

    if type(notFlags) == "string" then
        notFlags = { notFlags }
    end
    if notFlags then
        for _, flag in ipairs(notFlags) do
            if flags[flag] then
                return false
            end
        end
    end

    return true
end

local function stripColorCodes(text)
    if type(text) ~= "string" then
        return text
    end

    local stripped = text:gsub("%^x%x%x%x%x%x", "")
    stripped = stripped:gsub("%^.", "")
    return stripped
end

local function addThousandsSeparators(text)
    if type(text) ~= "string" then
        return text
    end

    local sign, whole, fraction = text:match("^([%+%-]?)(%d+)(.*)$")
    if not whole then
        return text
    end

    local reversed = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if reversed:sub(1, 1) == "," then
        reversed = reversed:sub(2)
    end
    return sign .. reversed .. (fraction or "")
end

local function normalizeValue(statData, statValue)
    if type(statValue) == "table" then
        return nil
    end

    local multiplier = ((statData.pc or statData.mod) and 100 or 1)
    local offset = statData.mod and 100 or 0
    return statValue * multiplier - offset
end

local function formatValue(statData, normalizedValue)
    if normalizedValue == nil then
        return nil
    end

    local formatted = string_format("%" .. statData.fmt, normalizedValue)
    local number, suffix = formatted:match("^([%+%-]?%d+%.%d+)(%D*)$")
    if number then
        formatted = number:gsub("0+$", ""):gsub("%.$", "") .. suffix
    end
    return addThousandsSeparators(formatted)
end

function M.new()
    return setmetatable({}, M)
end

function M:build_entries(build)
    if
        not build
        or not build.calcsTab
        or not build.calcsTab.mainEnv
        or not build.calcsTab.mainEnv.player
    then
        return {}
    end

    local actor = build.calcsTab.mainEnv.player
    local statList = build.displayStats or {}
    local entries = {}

    for _, statData in ipairs(statList) do
        if
            matchFlags(
                statData.flag,
                statData.notFlag,
                actor.mainSkill and actor.mainSkill.skillFlags
            )
        then
            if statData.stat then
                local statValue = actor.output and actor.output[statData.stat] or nil
                if statValue and statData.childStat then
                    statValue = statValue[statData.childStat]
                end

                local isVisible = statValue
                    and (
                        (statData.condFunc and statData.condFunc(statValue, actor.output))
                        or (not statData.condFunc and statValue ~= 0)
                    )

                if isVisible then
                    if statData.stat == "SkillDPS" and type(actor.output.SkillDPS) == "table" then
                        for _, skillData in ipairs(actor.output.SkillDPS) do
                            entries[#entries + 1] = {
                                type = "skill_dps",
                                key = "SkillDPS",
                                label = skillData.count
                                        and skillData.count >= 2
                                        and tostring(skillData.count) .. "x " .. skillData.name
                                    or skillData.name,
                                value = skillData.dps * (skillData.count or 1),
                                formatted = formatValue(
                                    { fmt = ".1f" },
                                    skillData.dps * (skillData.count or 1)
                                ),
                                trigger = skillData.trigger,
                                skillPart = skillData.skillPart,
                                source = skillData.source,
                            }
                        end
                    elseif not statData.hideStat then
                        local overCapValue = statData.overCapStat
                                and actor.output[statData.overCapStat]
                            or nil
                        local formatted = formatValue(statData, normalizeValue(statData, statValue))
                        if overCapValue and overCapValue > 0 then
                            formatted = formatted
                                .. " (+"
                                .. string_format("%d", overCapValue)
                                .. "%)"
                        end

                        entries[#entries + 1] = {
                            type = "stat",
                            key = statData.childStat
                                    and (statData.stat .. "." .. statData.childStat)
                                or statData.stat,
                            label = statData.label,
                            rawValue = statValue,
                            value = normalizeValue(statData, statValue),
                            formatted = formatted,
                            overCap = overCapValue,
                            format = statData.fmt,
                            colorHint = statData.label,
                        }
                    end
                end
            elseif statData.label and statData.condFunc and statData.condFunc(actor.output) then
                local baseValue = statData.labelStat and actor.output[statData.labelStat] or nil
                entries[#entries + 1] = {
                    type = "stat",
                    key = statData.labelStat or statData.label,
                    label = statData.label,
                    rawValue = baseValue,
                    value = baseValue,
                    formatted = tostring(baseValue) .. "% (" .. tostring(statData.val) .. ")",
                    colorHint = statData.label,
                }
            elseif #entries > 0 and entries[#entries].type ~= "separator" then
                entries[#entries + 1] = {
                    type = "separator",
                }
            end
        end
    end

    if entries[#entries] and entries[#entries].type == "separator" then
        entries[#entries] = nil
    end

    return entries
end

return M
