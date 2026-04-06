local api = PoBHeadless
local testkit = require("testkit")

local xmlPath = arg[1]

if not xmlPath or xmlPath == "" then
	print("Missing build XML path.")
	os.exit(1)
end

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

local jewelItemText = [[
Rarity: Unique
Watcher's Eye
Prismatic Jewel
--------
Limited to: 1
--------
Item Level: 85
--------
6% increased maximum Energy Shield
4% increased maximum Life
6% increased maximum Mana
+6% Chance to Block Spell Damage while affected by Discipline
Unaffected by Chilled Ground while affected by Purity of Ice
--------
One by one, they stood their ground against a creature
they had no hope of understanding, let alone defeating,
and one by one, they became a part of it.
--------
Place into an allocated Jewel Socket on the Passive Skill Tree. Right click to remove from the Socket.
]]

local flow = testkit.newQueuedBuildFlow(api, xmlPath)

api.queue(function()
	if not flow.load() then
		return false
	end

	local summary, ready = flow.summary()
	if not ready then
		return false
	end

	local parsed, parseErr = api.parse_item(testItemText)
	if not parsed then
		error(parseErr, 0)
	end
	testkit.expect(parsed.type == "Ring", "item_tooltip: expected parsed ring item")
	testkit.expect(type(parsed.raw) == "string" and parsed.raw ~= "", "item_tooltip: expected parsed raw item text")

	local parsedJewel, parsedJewelErr = api.parse_item(jewelItemText)
	if not parsedJewel then
		error(parsedJewelErr, 0)
	end
	testkit.expect(parsedJewel.type == "Jewel", "item_tooltip: expected parsed jewel item")
	testkit.expect(parsedJewel.primarySlot == "Jewel", "item_tooltip: expected generic jewel primary slot")

	local tooltipWithoutSlot, tooltipWithoutSlotErr = api.render_item_tooltip(testItemText)
	if not tooltipWithoutSlot then
		error(tooltipWithoutSlotErr, 0)
	end
	testkit.expect(tooltipWithoutSlot.slot and tooltipWithoutSlot.slot.requested == nil, "item_tooltip: expected nil requested slot")
	testkit.expect(
		tooltipWithoutSlot.slot and type(tooltipWithoutSlot.slot.resolved) == "string" and tooltipWithoutSlot.slot.resolved:match("^Ring %d+$"),
		"item_tooltip: expected auto-resolved ring slot"
	)
	testkit.expect(tooltipWithoutSlot.slot and tooltipWithoutSlot.slot.autoResolved == true, "item_tooltip: expected auto-resolved ring slot flag")

	local jewelTooltip, jewelTooltipErr = api.render_item_tooltip(jewelItemText)
	if not jewelTooltip then
		error(jewelTooltipErr, 0)
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
		error(tooltipErr, 0)
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

	api.stop()
	return true
end)
