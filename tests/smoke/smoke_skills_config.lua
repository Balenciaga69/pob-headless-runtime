local api = PoBHeadless
local smokekit = require("smokekit")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()
local selectedSnapshot

smokekit.runQueuedSmoke(api, xmlPath, function(_, summary)
    local skills, skillsErr = api.list_skills()
    if not skills then
        return false, skillsErr
    end
    testkit.expect(
        skills.groups and #skills.groups > 0,
        "skills_config: expected at least one skill group"
    )
    testkit.expect(summary.buildName ~= nil, "skills_config: expected build name in summary")

    if not selectedSnapshot then
        local snapshot, snapshotErr = api.get_selected_skill()
        if not snapshot then
            return false, snapshotErr
        end
        selectedSnapshot = snapshot

        local firstGroup = skills.groups and skills.groups[1]
        if firstGroup and firstGroup.skills and firstGroup.skills[1] then
            local _, selectErr = api.select_skill({
                group = firstGroup.index,
                skill = firstGroup.mainActiveSkill or firstGroup.skills[1].index or 1,
            })
            if selectErr then
                return false, selectErr
            end
        end

        local _, configErr = api.set_config({
            enemyLevel = 83,
            enemyIsBoss = "Pinnacle",
        })
        if configErr then
            return false, configErr
        end

        local restored, restoreErr = api.restore_skill_selection(selectedSnapshot)
        if not restored then
            return false, restoreErr
        end
    end

    local stats, statsErr = api.get_stats({ "Life", "FireResist", "TotalDPS" })
    if not stats then
        return false, statsErr
    end

    testkit.expect(
        stats._meta and stats._meta.mainSkill ~= nil,
        "skills_config: expected main skill meta"
    )
    testkit.expect(
        stats.Life ~= nil or stats.TotalDPS ~= nil,
        "skills_config: expected at least one stat value"
    )
    testkit.expect(selectedSnapshot ~= nil, "skills_config: expected selected skill snapshot")

    print("selectedGroup", skills.mainSocketGroup or 0)
    print(
        "selectedSkill",
        selectedSnapshot and selectedSnapshot.skill and selectedSnapshot.skill.name or ""
    )
    print("life", stats.Life or 0)
    print("fireRes", stats.FireResist or 0)
    print("dps", stats.TotalDPS or 0)
    return true
end)
