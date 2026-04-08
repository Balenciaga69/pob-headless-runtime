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

    local xmlText, xmlErr = api.save_build_xml()
    if not xmlText then
        return false, xmlErr
    end
    testkit.expect(#xmlText > 0, "min_api: expected exported xml text")

    print("buildName", summary.buildName or "")
    print("mainSkill", stats._meta and stats._meta.mainSkill or "")
    print("equipmentSlots", #equipment.slots)
    print("enemyLevel", updatedConfig.enemyLevel or 0)
    print("xmlSize", #xmlText)
    return true
end)
