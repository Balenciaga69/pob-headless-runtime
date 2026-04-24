local api = PoBHeadless
local smokekit = require("smokekit")
local smokeItems = require("smoke_items")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()
local testItemText = smokeItems.dread_loop

smokekit.runQueuedSmoke(api, xmlPath, function(_, baselineSummary)
    local preview, previewErr = api.preview_item_display_stats(testItemText, "Ring 1")
    if not preview then
        return false, previewErr
    end

    testkit.expect(preview.kind == "item", "preview_item_display_stats: expected item kind")
    testkit.expect(preview.restored == true, "preview_item_display_stats: expected restored flag")
    testkit.expect(
        preview.simulationMode == "snapshot_restore",
        "preview_item_display_stats: expected snapshot restore mode"
    )
    testkit.expect(
        preview.slot and preview.slot.resolved == "Ring 1",
        "preview_item_display_stats: expected preview slot"
    )
    testkit.expect(
        preview.currentItem ~= nil,
        "preview_item_display_stats: expected current item summary"
    )
    testkit.expect(
        preview.candidateItem ~= nil,
        "preview_item_display_stats: expected candidate item summary"
    )
    testkit.expect(
        preview.displayStats and type(preview.displayStats.entries) == "table",
        "preview_item_display_stats: expected display stats entries"
    )
    testkit.expect(
        preview.displayStats._meta and type(preview.displayStats._meta.mainSkill) == "string",
        "preview_item_display_stats: expected display stats meta"
    )
    testkit.expect(
        #preview.displayStats.entries > 0,
        "preview_item_display_stats: expected non-empty display stats"
    )

    local afterPreviewSummary, afterPreviewErr = api.get_summary()
    if not afterPreviewSummary then
        return false, afterPreviewErr
    end
    testkit.expectSummaryUnchanged(
        baselineSummary,
        afterPreviewSummary,
        { "Life", "FireResist", "ColdResist", "EnergyShield", "CombinedDPS" },
        "preview_item_display_stats"
    )

    print("previewDisplayEntries", #preview.displayStats.entries)
    print("previewMainSkill", preview.displayStats._meta.mainSkill or "")
    return true
end)
