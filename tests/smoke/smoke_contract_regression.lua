local api = PoBHeadless
local smokekit = require("smokekit")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()

smokekit.runQueuedSmoke(api, xmlPath, function(_, summary)
    local skills, skillsErr = api.list_skills()
    if not skills then
        return false, skillsErr
    end
    testkit.expect(
        skills.groups and #skills.groups > 0,
        "contract_regression: expected at least one skill group"
    )
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

    local firstGroup = skills.groups[1]
    local firstSkill = firstGroup and firstGroup.skills and firstGroup.skills[1]
    if firstGroup and firstSkill then
        local selected, selectErr = api.select_skill({
            group = firstGroup.index,
            skill = firstGroup.mainActiveSkill or firstSkill.index or 1,
        })
        if not selected then
            return false, selectErr
        end
        testkit.expect(
            selected.mainSocketGroup == firstGroup.index,
            "contract_regression: selected group mismatch"
        )
    end

    local _, configErr = api.set_config({
        enemyLevel = 84,
        enemyIsBoss = "Pinnacle",
    })
    if configErr then
        return false, configErr
    end

    local _, invalidConfigErr = api.set_config({ invalidField = true })
    testkit.expect(
        invalidConfigErr ~= nil and invalidConfigErr:match("^unsupported config field:"),
        "contract_regression: expected unsupported field error"
    )

    local xmlText, xmlErr = api.save_build_xml()
    if not xmlText then
        return false, xmlErr
    end
    testkit.expect(#xmlText > 0, "contract_regression: expected exported xml text")

    print("buildName", summary.buildName or "")
    print("mainSkill", stats._meta and stats._meta.mainSkill or "")
    print("skillGroups", #skills.groups)
    print("xmlSize", #xmlText)
    return true
end)
