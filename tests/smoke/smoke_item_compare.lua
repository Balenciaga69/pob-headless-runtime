local api = PoBHeadless
local smokekit = require("smokekit")
local smokeItems = require("smoke_items")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()
local testItemText = smokeItems.dread_loop
local jewelItemText = smokeItems.watchers_eye

smokekit.runQueuedSmoke(api, xmlPath, function(_, baselineSummary)
    local compared, compareErr =
        api.compare_item_stats(testItemText, "Ring 1", { "Life", "FireResist", "ColdResist" })
    if not compared then
        return false, compareErr
    end

    testkit.expect(
        compared.slot and compared.slot.resolved == "Ring 1",
        "item_compare: expected compare slot"
    )
    testkit.expect(compared.currentItem ~= nil, "item_compare: expected current equipped item")
    testkit.expect(compared.candidateItem ~= nil, "item_compare: expected candidate item")
    testkit.expect(compared.kind == "item", "item_compare: expected item simulation kind")
    testkit.expect(compared.restored == true, "item_compare: expected item simulation restore flag")
    testkit.expect(
        compared.simulationMode == "calculator",
        "item_compare: expected item simulation mode"
    )
    testkit.expect(
        type(compared.comparison) == "table",
        "item_compare: expected comparison payload"
    )
    testkit.expect(
        type(compared.comparison.delta) == "table",
        "item_compare: expected comparison delta"
    )
    testkit.expect(
        type(compared.comparison.fields) == "table" and #compared.comparison.fields == 3,
        "item_compare: expected requested compare fields"
    )
    testkit.expect(
        type(compared.comparison.changedFields) == "table",
        "item_compare: expected changed fields"
    )
    testkit.expect(
        compared.comparison._meta and compared.comparison._meta.before,
        "item_compare: expected before meta"
    )
    testkit.expect(type(compared.delta) == "table", "item_compare: expected top-level delta table")
    testkit.expect(
        type(compared.changedFields) == "table",
        "item_compare: expected top-level changed fields table"
    )

    testkit.expectDeltaMatches(
        compared.before,
        compared.after,
        compared.delta,
        { "Life", "FireResist", "ColdResist" },
        "item_compare"
    )

    local afterCompareSummary, afterCompareErr = api.get_summary()
    if not afterCompareSummary then
        return false, afterCompareErr
    end
    testkit.expectSummaryUnchanged(
        baselineSummary,
        afterCompareSummary,
        { "Life", "FireResist", "ColdResist", "EnergyShield", "CombinedDPS" },
        "item_compare"
    )

    local autoCompared, autoCompareErr = api.compare_item_stats(testItemText)
    if not autoCompared then
        return false, autoCompareErr
    end
    testkit.expect(
        autoCompared.slot and autoCompared.slot.autoResolved == true,
        "item_compare: expected auto-resolved slot"
    )
    testkit.expect(
        type(autoCompared.delta.Life) == "number",
        "item_compare: expected auto compare life delta"
    )

    local _, invalidSlotErr = api.compare_item_stats(testItemText, "Weapon 1", { "Life" })
    testkit.expect(
        invalidSlotErr == "item cannot be equipped in slot Weapon 1",
        "item_compare: expected invalid compare slot error"
    )

    local _, invalidFieldsErr = api.compare_item_stats(testItemText, "Ring 1", "Life")
    testkit.expect(
        invalidFieldsErr == "fields must be a table",
        "item_compare: expected invalid compare fields error"
    )

    local parsed, parseErr = api.parse_item(testItemText)
    if not parsed then
        return false, parseErr
    end

    local tested, testErr = api.test_item(testItemText, "Ring 1")
    if not tested then
        return false, testErr
    end
    testkit.expect(
        tested.slot and tested.slot.resolved == "Ring 1",
        "item_compare: expected test slot"
    )
    testkit.expect(
        type(tested.compareFields) == "table" and #tested.compareFields > 0,
        "item_compare: expected compare fields"
    )
    testkit.expect(type(tested.delta) == "table", "item_compare: expected delta table")
    testkit.expect(
        tested.testedItem and tested.testedItem.raw == parsed.raw,
        "item_compare: expected tested item raw to match parsed item"
    )

    local equipped, equipErr = api.equip_item(testItemText, "Ring 1")
    if not equipped then
        return false, equipErr
    end
    testkit.expect(
        equipped.slot and equipped.slot.resolved == "Ring 1",
        "item_compare: expected equip slot"
    )
    testkit.expect(equipped.previousItem ~= nil, "item_compare: expected previous item summary")
    testkit.expect(
        equipped.item and equipped.item.raw == parsed.raw,
        "item_compare: expected equipped item raw to match parsed item"
    )

    local afterEquipSummary, afterEquipErr = api.get_summary()
    if not afterEquipSummary then
        return false, afterEquipErr
    end
    testkit.expectDeltaMatches(
        baselineSummary,
        afterEquipSummary,
        tested.delta,
        { "Life", "FireResist", "ColdResist" },
        "item_compare"
    )

    local testedJewel, testedJewelErr = api.test_item(jewelItemText)
    if not testedJewel then
        return false, testedJewelErr
    end
    testkit.expect(
        testedJewel.slot
            and type(testedJewel.slot.resolved) == "string"
            and testedJewel.slot.resolved:match("^Jewel %d+$"),
        "item_compare: expected auto-resolved jewel test slot"
    )
    testkit.expect(
        testedJewel.slot and testedJewel.slot.nodeId ~= nil,
        "item_compare: expected jewel test node id"
    )

    local equippedJewel, equipJewelErr = api.equip_item(jewelItemText)
    if not equippedJewel then
        return false, equipJewelErr
    end
    testkit.expect(
        equippedJewel.slot and equippedJewel.slot.resolved == testedJewel.slot.resolved,
        "item_compare: expected jewel equip to use tested slot"
    )
    testkit.expect(
        equippedJewel.previousItem == nil or equippedJewel.previousItem.type == "Jewel",
        "item_compare: expected prior jewel metadata when replacing"
    )

    local afterJewelSummary, afterJewelSummaryErr = api.get_summary()
    if not afterJewelSummary then
        return false, afterJewelSummaryErr
    end
    testkit.expectDeltaMatches(
        afterEquipSummary,
        afterJewelSummary,
        testedJewel.delta,
        { "Life" },
        "item_compare_jewel"
    )

    print("itemCompareLife", testkit.normalizeNumber(compared.delta.Life))
    print("itemCompareFire", testkit.normalizeNumber(compared.delta.FireResist))
    print("itemCompareChanged", #compared.changedFields)
    return true
end)
