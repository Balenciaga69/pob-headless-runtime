local api = PoBHeadless
local smokekit = require("smokekit")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()

smokekit.runQueuedSmoke(api, xmlPath, function(_, summary)
    testkit.expect(summary.buildName ~= nil, "min_api: expected build name in summary")

    local stats, statsErr = api.get_stats({ "Life", "TotalDPS" })
    if not stats then
        return false, statsErr
    end
    testkit.expect(
        stats._meta and stats._meta.mainSkill ~= nil,
        "min_api: expected main skill meta"
    )
    testkit.expect(
        stats.Life ~= nil or stats.TotalDPS ~= nil,
        "min_api: expected at least one stat value"
    )

    local skills, skillsErr = api.list_skills()
    if not skills then
        return false, skillsErr
    end
    testkit.expect(type(skills.groups) == "table", "min_api: expected skill groups")

    local selectedSkill, selectedSkillErr = api.get_selected_skill()
    if not selectedSkill then
        return false, selectedSkillErr
    end
    testkit.expect(
        selectedSkill.skill and selectedSkill.skill.name ~= nil,
        "min_api: expected selected skill payload"
    )

    local configBefore, configBeforeErr = api.get_config()
    if not configBefore then
        return false, configBeforeErr
    end

    local updatedConfig, configErr = api.set_config({
        enemyLevel = 84,
        enemyIsBoss = "Pinnacle",
    })
    if not updatedConfig then
        return false, configErr
    end
    testkit.expect(updatedConfig.enemyLevel == 84, "min_api: expected updated enemy level")

    local _, invalidConfigErr = api.set_config({ invalidField = true })
    testkit.expect(
        invalidConfigErr ~= nil and invalidConfigErr:match("^unsupported config field:"),
        "min_api: expected unsupported field error"
    )

    local equipment, equipmentErr = api.list_equipment()
    if not equipment then
        return false, equipmentErr
    end
    testkit.expect(type(equipment.slots) == "table", "min_api: expected equipment slots")

    local items, itemsErr = api.list_items()
    if not items then
        return false, itemsErr
    end
    testkit.expect(type(items.items) == "table", "min_api: expected item list")

    local xmlText, xmlErr = api.save_build_xml()
    if not xmlText then
        return false, xmlErr
    end
    testkit.expect(#xmlText > 0, "min_api: expected exported xml text")

    print("buildName", summary.buildName or "")
    print("mainSkill", stats._meta and stats._meta.mainSkill or "")
    print("equipmentSlots", #equipment.slots)
    print("items", #items.items)
    print("enemyLevel", updatedConfig.enemyLevel or 0)
    print("xmlSize", #xmlText)
    return true
end)
