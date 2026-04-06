local api = PoBHeadless
local testkit = require("testkit")

local xmlPath = arg[1]

if not xmlPath or xmlPath == "" then
	print("Missing build XML path.")
	os.exit(1)
end

local shieldItemText = [[
Rarity: Rare
Gale Span
Pine Buckler
--------
Item Level: 86
--------
+40 to maximum Life
+20% to Cold Resistance
]]

local wandItemText = [[
Rarity: Rare
Storm Song
Driftwood Wand
--------
Item Level: 86
--------
Adds 1 to 2 Lightning Damage to Spells
10% increased Spell Damage
]]

local sceptreItemText = [[
Rarity: Rare
Rune Gnarl
Driftwood Sceptre
--------
Item Level: 86
--------
20% increased Spell Damage
]]

local bowItemText = [[
Rarity: Rare
Eagle Mark
Short Bow
--------
Item Level: 86
--------
Adds 1 to 2 Cold Damage
]]

local quiverItemText = [[
Rarity: Rare
Skirmish Keep
Two-Point Arrow Quiver
--------
Item Level: 86
--------
+30 to maximum Life
]]

local stygianBeltItemText = [[
Rarity: Rare
Gloom Tether
Stygian Vise
--------
Item Level: 86
--------
Has 1 Abyssal Socket
+80 to maximum Life
+35% to Fire Resistance
]]

local abyssJewelItemText = [[
Rarity: Rare
Grim Song
Murderous Eye Jewel
--------
Abyss
--------
Requirements:
Level: 30
--------
Item Level: 78
--------
+31 to maximum Life
Adds 11 to 19 Cold Damage to Staff Attacks
5% chance to gain Onslaught for 4 seconds on Kill
--------
Place into an Abyssal Socket on an Item or into an allocated Jewel Socket on the Passive Skill Tree. Right click to remove from the Socket.
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

	local _, invalidTestSlotErr = api.test_item(wandItemText, "Fake Slot")
	testkit.expect(invalidTestSlotErr == "invalid item slot" or invalidTestSlotErr == "item cannot be equipped in slot Fake Slot", "item_slot_rules: expected invalid slot error")

	local testedShield, testedShieldErr = api.test_item(shieldItemText, "Weapon 2")
	if not testedShield then
		error(testedShieldErr, 0)
	end
	testkit.expect(testedShield.slot and testedShield.slot.resolved == "Weapon 2", "item_slot_rules: expected shield to be valid in Weapon 2")

	local testedOffhandWand, testedOffhandWandErr = api.test_item(wandItemText, "Weapon 2")
	if not testedOffhandWand then
		error(testedOffhandWandErr, 0)
	end
	testkit.expect(testedOffhandWand.slot and testedOffhandWand.slot.resolved == "Weapon 2", "item_slot_rules: expected wand to be valid in Weapon 2")

	local _, invalidSceptreErr = api.test_item(sceptreItemText, "Weapon 2")
	testkit.expect(invalidSceptreErr == "item cannot be equipped in slot Weapon 2", "item_slot_rules: expected sceptre to be invalid in Weapon 2")

	local _, invalidBowOffhandErr = api.test_item(bowItemText, "Weapon 2")
	testkit.expect(invalidBowOffhandErr == "item cannot be equipped in slot Weapon 2", "item_slot_rules: expected bow to be invalid in Weapon 2")

	local _, invalidQuiverErr = api.test_item(quiverItemText, "Weapon 2")
	testkit.expect(invalidQuiverErr == "item cannot be equipped in slot Weapon 2", "item_slot_rules: expected quiver to be invalid without bow main hand")

	local testedBowMainhand, testedBowMainhandErr = api.test_item(bowItemText, "Weapon 1")
	if not testedBowMainhand then
		error(testedBowMainhandErr, 0)
	end
	testkit.expect(testedBowMainhand.slot and testedBowMainhand.slot.resolved == "Weapon 1", "item_slot_rules: expected bow to be valid in Weapon 1")

	local equippedBelt, equipBeltErr = api.equip_item(stygianBeltItemText, "Belt")
	if not equippedBelt then
		error(equipBeltErr, 0)
	end
	testkit.expect(equippedBelt.slot and equippedBelt.slot.resolved == "Belt", "item_slot_rules: expected stygian belt equip slot")
	testkit.expect(summary and summary.buildName ~= nil, "item_slot_rules: expected build summary before abyss socket check")

	local _, invalidRegularJewelInAbyssErr = api.test_item(jewelItemText, "Belt Abyssal Socket 1")
	testkit.expect(
		invalidRegularJewelInAbyssErr == "item cannot be equipped in slot Belt Abyssal Socket 1",
		"item_slot_rules: expected regular jewel to be invalid in abyss socket"
	)

	local testedAbyssJewel, testedAbyssJewelErr = api.test_item(abyssJewelItemText, "Belt Abyssal Socket 1")
	if not testedAbyssJewel then
		error(testedAbyssJewelErr, 0)
	end
	testkit.expect(testedAbyssJewel.slot and testedAbyssJewel.slot.resolved == "Belt Abyssal Socket 1", "item_slot_rules: expected abyss jewel test slot")

	local equippedAbyssJewel, equipAbyssJewelErr = api.equip_item(abyssJewelItemText, "Belt Abyssal Socket 1")
	if not equippedAbyssJewel then
		error(equipAbyssJewelErr, 0)
	end
	testkit.expect(equippedAbyssJewel.slot and equippedAbyssJewel.slot.resolved == "Belt Abyssal Socket 1", "item_slot_rules: expected abyss jewel equip slot")

	local equippedBow, equipBowErr = api.equip_item(bowItemText, "Weapon 1")
	if not equippedBow then
		error(equipBowErr, 0)
	end
	testkit.expect(equippedBow.slot and equippedBow.slot.resolved == "Weapon 1", "item_slot_rules: expected bow equip slot")

	local testedQuiver, testedQuiverErr = api.test_item(quiverItemText, "Weapon 2")
	if not testedQuiver then
		error(testedQuiverErr, 0)
	end
	testkit.expect(testedQuiver.slot and testedQuiver.slot.resolved == "Weapon 2", "item_slot_rules: expected quiver to become valid with bow main hand")

	local _, invalidShieldAfterBowErr = api.test_item(shieldItemText, "Weapon 2")
	testkit.expect(
		invalidShieldAfterBowErr == "item cannot be equipped in slot Weapon 2",
		"item_slot_rules: expected shield to be invalid after bow main hand equip"
	)

	local equippedQuiver, equipQuiverErr = api.equip_item(quiverItemText, "Weapon 2")
	if not equippedQuiver then
		error(equipQuiverErr, 0)
	end
	testkit.expect(equippedQuiver.slot and equippedQuiver.slot.resolved == "Weapon 2", "item_slot_rules: expected quiver equip slot")

	local beltSummary, beltSummaryErr = api.get_summary()
	if not beltSummary then
		error(beltSummaryErr, 0)
	end
	testkit.expect(beltSummary.buildName ~= nil, "item_slot_rules: expected summary after slot mutations")

	print("slotRulesBuild", summary.buildName or "")
	print("slotRulesLife", testkit.summaryStat(beltSummary, "Life"))
	print("slotRulesAbyss", equippedAbyssJewel.slot and equippedAbyssJewel.slot.resolved or "")

	api.stop()
	return true
end)
