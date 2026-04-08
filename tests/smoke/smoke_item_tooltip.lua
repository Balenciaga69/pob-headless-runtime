local api = PoBHeadless
local smokekit = require("smokekit")
local smokeItems = require("smoke_items")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()
local testItemText = smokeItems.dread_loop
local jewelItemText = smokeItems.watchers_eye

smokekit.runQueuedSmoke(api, xmlPath, function(_, summary)
	local parsed, parseErr = api.parse_item(testItemText)
	if not parsed then
		return false, parseErr
	end
	testkit.expect(parsed.type == "Ring", "item_tooltip: expected parsed ring item")
	testkit.expect(type(parsed.raw) == "string" and parsed.raw ~= "", "item_tooltip: expected parsed raw item text")

	local parsedJewel, parsedJewelErr = api.parse_item(jewelItemText)
	if not parsedJewel then
		return false, parsedJewelErr
	end
	testkit.expect(parsedJewel.type == "Jewel", "item_tooltip: expected parsed jewel item")
	testkit.expect(parsedJewel.primarySlot == "Jewel", "item_tooltip: expected generic jewel primary slot")

	local tooltipWithoutSlot, tooltipWithoutSlotErr = api.render_item_tooltip(testItemText)
	if not tooltipWithoutSlot then
		return false, tooltipWithoutSlotErr
	end
	testkit.expect(tooltipWithoutSlot.slot and tooltipWithoutSlot.slot.requested == nil, "item_tooltip: expected nil requested slot")
	testkit.expect(
		tooltipWithoutSlot.slot and type(tooltipWithoutSlot.slot.resolved) == "string" and tooltipWithoutSlot.slot.resolved:match("^Ring %d+$"),
		"item_tooltip: expected auto-resolved ring slot"
	)
	testkit.expect(tooltipWithoutSlot.slot and tooltipWithoutSlot.slot.autoResolved == true, "item_tooltip: expected auto-resolved ring slot flag")

	local jewelTooltip, jewelTooltipErr = api.render_item_tooltip(jewelItemText)
	if not jewelTooltip then
		return false, jewelTooltipErr
	end
	testkit.expect(jewelTooltip.slot and jewelTooltip.slot.requested == nil, "item_tooltip: expected nil requested jewel slot")
	testkit.expect(
		jewelTooltip.slot and type(jewelTooltip.slot.resolved) == "string" and jewelTooltip.slot.resolved:match("^Jewel %d+$"),
		"item_tooltip: expected auto-resolved jewel slot"
	)
	testkit.expect(jewelTooltip.slot and jewelTooltip.slot.nodeId ~= nil, "item_tooltip: expected jewel node id metadata")
	testkit.expect(jewelTooltip.slot and jewelTooltip.slot.autoResolved == true, "item_tooltip: expected auto-resolved jewel slot flag")

	local tooltip, tooltipErr = api.render_item_tooltip(testItemText, "Ring 1")
	if not tooltip then
		return false, tooltipErr
	end
	testkit.expect(type(tooltip.text) == "string" and tooltip.text ~= "", "item_tooltip: expected tooltip text")
	testkit.expect(tooltip.slot and tooltip.slot.resolved == "Ring 1", "item_tooltip: expected tooltip slot metadata")
	testkit.expect(type(tooltip.plainLines) == "table" and #tooltip.plainLines > 0, "item_tooltip: expected plain tooltip lines")
	testkit.expect(type(tooltip.separatorCount) == "number" and tooltip.separatorCount > 0, "item_tooltip: expected tooltip separators")

	local _, invalidSlotErr = api.render_item_tooltip(testItemText, "Fake Slot")
	testkit.expect(invalidSlotErr == "invalid item slot", "item_tooltip: expected invalid slot error")

	local _, invalidItemErr = api.parse_item("not an item")
	testkit.expect(
		invalidItemErr == "failed to parse item" or (type(invalidItemErr) == "string" and invalidItemErr:match("^invalid item text:")),
		"item_tooltip: expected invalid item error"
	)

	print("itemName", parsed.name or parsed.baseName or "")
	print("tooltipLines", #(tooltip.lines or {}))
	print("summaryBuild", summary.buildName or "")
	return true
end)
