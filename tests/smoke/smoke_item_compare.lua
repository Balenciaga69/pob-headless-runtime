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

	local baselineSummary, ready = flow.summary()
	if not ready then
		return false
	end

	local compared, compareErr = api.compare_item_stats(testItemText, "Ring 1", { "Life", "FireResist", "ColdResist" })
	if not compared then
		error(compareErr, 0)
	end

	testkit.expect(compared.slot and compared.slot.resolved == "Ring 1", "item_compare: expected compare slot")
	testkit.expect(compared.currentItem ~= nil, "item_compare: expected current equipped item")
	testkit.expect(compared.candidateItem ~= nil, "item_compare: expected candidate item")
	testkit.expect(compared.kind == "item", "item_compare: expected item simulation kind")
	testkit.expect(compared.restored == true, "item_compare: expected item simulation restore flag")
	testkit.expect(compared.simulationMode == "calculator", "item_compare: expected item simulation mode")
	testkit.expect(type(compared.comparison) == "table", "item_compare: expected comparison payload")
	testkit.expect(type(compared.comparison.delta) == "table", "item_compare: expected comparison delta")
	testkit.expect(type(compared.comparison.fields) == "table" and #compared.comparison.fields == 3, "item_compare: expected requested compare fields")
	testkit.expect(type(compared.comparison.changedFields) == "table", "item_compare: expected changed fields")
	testkit.expect(compared.comparison._meta and compared.comparison._meta.before, "item_compare: expected before meta")
	testkit.expect(type(compared.delta) == "table", "item_compare: expected top-level delta table")
	testkit.expect(type(compared.changedFields) == "table", "item_compare: expected top-level changed fields table")

	testkit.expectDeltaMatches(
		compared.before,
		compared.after,
		compared.delta,
		{ "Life", "FireResist", "ColdResist" },
		"item_compare"
	)

	local afterCompareSummary, afterCompareErr = api.get_summary()
	if not afterCompareSummary then
		error(afterCompareErr, 0)
	end
	testkit.expectSummaryUnchanged(
		baselineSummary,
		afterCompareSummary,
		{ "Life", "FireResist", "ColdResist", "EnergyShield", "CombinedDPS" },
		"item_compare"
	)

	local autoCompared, autoCompareErr = api.compare_item_stats(testItemText)
	if not autoCompared then
		error(autoCompareErr, 0)
	end
	testkit.expect(autoCompared.slot and autoCompared.slot.autoResolved == true, "item_compare: expected auto-resolved slot")
	testkit.expect(type(autoCompared.delta.Life) == "number", "item_compare: expected auto compare life delta")

	local _, invalidSlotErr = api.compare_item_stats(testItemText, "Weapon 1", { "Life" })
	testkit.expect(invalidSlotErr == "item cannot be equipped in slot Weapon 1", "item_compare: expected invalid compare slot error")

	local _, invalidFieldsErr = api.compare_item_stats(testItemText, "Ring 1", "Life")
	testkit.expect(invalidFieldsErr == "fields must be a table", "item_compare: expected invalid compare fields error")

	local parsed, parseErr = api.parse_item(testItemText)
	if not parsed then
		error(parseErr, 0)
	end

	local tested, testErr = api.test_item(testItemText, "Ring 1")
	if not tested then
		error(testErr, 0)
	end
	testkit.expect(tested.slot and tested.slot.resolved == "Ring 1", "item_compare: expected test slot")
	testkit.expect(type(tested.compareFields) == "table" and #tested.compareFields > 0, "item_compare: expected compare fields")
	testkit.expect(type(tested.delta) == "table", "item_compare: expected delta table")
	testkit.expect(tested.testedItem and tested.testedItem.raw == parsed.raw, "item_compare: expected tested item raw to match parsed item")

	local equipped, equipErr = api.equip_item(testItemText, "Ring 1")
	if not equipped then
		error(equipErr, 0)
	end
	testkit.expect(equipped.slot and equipped.slot.resolved == "Ring 1", "item_compare: expected equip slot")
	testkit.expect(equipped.previousItem ~= nil, "item_compare: expected previous item summary")
	testkit.expect(equipped.item and equipped.item.raw == parsed.raw, "item_compare: expected equipped item raw to match parsed item")

	local afterEquipSummary, afterEquipErr = api.get_summary()
	if not afterEquipSummary then
		error(afterEquipErr, 0)
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
		error(testedJewelErr, 0)
	end
	testkit.expect(
		testedJewel.slot and type(testedJewel.slot.resolved) == "string" and testedJewel.slot.resolved:match("^Jewel %d+$"),
		"item_compare: expected auto-resolved jewel test slot"
	)
	testkit.expect(testedJewel.slot and testedJewel.slot.nodeId ~= nil, "item_compare: expected jewel test node id")

	local equippedJewel, equipJewelErr = api.equip_item(jewelItemText)
	if not equippedJewel then
		error(equipJewelErr, 0)
	end
	testkit.expect(equippedJewel.slot and equippedJewel.slot.resolved == testedJewel.slot.resolved, "item_compare: expected jewel equip to use tested slot")
	testkit.expect(equippedJewel.previousItem == nil or equippedJewel.previousItem.type == "Jewel", "item_compare: expected prior jewel metadata when replacing")

	local afterJewelSummary, afterJewelSummaryErr = api.get_summary()
	if not afterJewelSummary then
		error(afterJewelSummaryErr, 0)
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

	api.stop()
	return true
end)
