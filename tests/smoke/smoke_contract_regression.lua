local api = PoBHeadless
local smokekit = require("smokekit")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()

smokekit.runQueuedSmoke(api, xmlPath, function(_, summary)
    testkit.expect(summary.buildName ~= nil, "contract_regression: expected build name in summary")

    local stats, statsErr = api.get_stats({ "Life", "TotalDPS" })
    if not stats then
        return false, statsErr
    end
    testkit.expect(
        stats._meta and stats._meta.mainSkill ~= nil,
        "contract_regression: expected main skill meta"
    )
    testkit.expect(
        stats.Life ~= nil or stats.TotalDPS ~= nil,
        "contract_regression: expected at least one stat value"
    )

    local beforeEquipment, equipmentErr = api.list_equipment()
    if not beforeEquipment then
        return false, equipmentErr
    end
    testkit.expect(
        type(beforeEquipment.slots) == "table" and #beforeEquipment.slots > 0,
        "contract_regression: expected at least one equipment slot"
    )

    local config, configErr = api.set_config({
        enemyLevel = 84,
        enemyIsBoss = "Pinnacle",
    })
    if not config then
        return false, configErr
    end
    testkit.expect(config.enemyLevel == 84, "contract_regression: expected enemy level change")

    local _, invalidConfigErr = api.set_config({ invalidField = true })
    testkit.expect(
        invalidConfigErr ~= nil and invalidConfigErr:match("^unsupported config field:"),
        "contract_regression: expected unsupported field error"
    )

    local currentConfig, currentConfigErr = api.get_config()
    if not currentConfig then
        return false, currentConfigErr
    end
    testkit.expect(
        currentConfig.enemyIsBoss == "Pinnacle",
        "contract_regression: expected config readback"
    )

    local xmlText, xmlErr = api.save_build_xml()
    if not xmlText then
        return false, xmlErr
    end
    testkit.expect(#xmlText > 0, "contract_regression: expected exported xml text")

    print("buildName", summary.buildName or "")
    print("mainSkill", stats._meta and stats._meta.mainSkill or "")
    print("equipmentSlots", #beforeEquipment.slots)
    print("xmlSize", #xmlText)
    return true
end)
