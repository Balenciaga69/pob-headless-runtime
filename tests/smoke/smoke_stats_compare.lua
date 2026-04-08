local api = PoBHeadless
local smokekit = require("smokekit")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()

local testItemText = [[
Rarity: Rare
Dread Loop
Ruby Ring
--------
Item Level: 86
--------
+70 to maximum Life
+35% to Fire Resistance
+31% to Cold Resistance
]]

smokekit.runQueuedSmoke(api, xmlPath, function()
    local beforeStats, beforeErr =
        api.get_stats({ "Life", "FireResist", "ColdResist", "EnergyShield", "CombinedDPS" })
    if not beforeStats then
        return false, beforeErr
    end

    local _, equipErr = api.equip_item(testItemText, "Ring 1")
    if equipErr then
        return false, equipErr
    end

    local afterStats, afterErr =
        api.get_stats({ "Life", "FireResist", "ColdResist", "EnergyShield", "CombinedDPS" })
    if not afterStats then
        return false, afterErr
    end

    local compared, compareErr = api.compare_stats(
        beforeStats,
        afterStats,
        { "Life", "FireResist", "ColdResist", "CombinedDPS" }
    )
    if not compared then
        return false, compareErr
    end

    testkit.expect(
        type(compared.fields) == "table" and #compared.fields == 4,
        "stats_compare: expected compare fields"
    )
    testkit.expect(type(compared.before) == "table", "stats_compare: expected before stats table")
    testkit.expect(type(compared.after) == "table", "stats_compare: expected after stats table")
    testkit.expect(type(compared.delta) == "table", "stats_compare: expected delta stats table")
    testkit.expect(
        type(compared.changedFields) == "table",
        "stats_compare: expected changed fields"
    )
    testkit.expect(
        compared._meta and compared._meta.before and compared._meta.after,
        "stats_compare: expected compare meta"
    )

    testkit.expectDeltaMatches(
        compared.before,
        compared.after,
        compared.delta,
        { "Life", "FireResist", "ColdResist", "CombinedDPS" },
        "stats_compare"
    )

    testkit.expect(
        compared.changedFields[1] == "Life" or #compared.changedFields >= 1,
        "stats_compare: expected at least one changed field"
    )

    local autoCompared, autoCompareErr = api.compare_stats(beforeStats, afterStats)
    if not autoCompared then
        return false, autoCompareErr
    end
    testkit.expect(
        type(autoCompared.delta.Life) == "number",
        "stats_compare: expected auto compare life delta"
    )

    local emptyCompared, emptyCompareErr = api.compare_stats(beforeStats, afterStats, {})
    if not emptyCompared then
        return false, emptyCompareErr
    end
    testkit.expect(
        type(emptyCompared.delta.Life) == "number",
        "stats_compare: expected empty-field compare to infer numeric fields"
    )

    local _, invalidBeforeErr = api.compare_stats(nil, afterStats, { "Life" })
    testkit.expect(
        invalidBeforeErr == "before stats must be a table",
        "stats_compare: expected invalid before stats error"
    )

    local _, invalidFieldsErr = api.compare_stats(beforeStats, afterStats, "Life")
    testkit.expect(
        invalidFieldsErr == "fields must be a table",
        "stats_compare: expected invalid fields error"
    )

    print("compareLife", testkit.normalizeNumber(compared.delta.Life))
    print("compareFire", testkit.normalizeNumber(compared.delta.FireResist))
    print("compareChanged", #compared.changedFields)
    return true
end)
