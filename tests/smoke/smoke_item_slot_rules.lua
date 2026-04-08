local api = PoBHeadless
local smokekit = require("smokekit")
local smokeItems = require("smoke_items")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()

smokekit.runQueuedSmoke(api, xmlPath, function(_, summary)
	local shieldItemText = smokeItems.shield_item
	local wandItemText = smokeItems.wand_item
	local sceptreItemText = smokeItems.sceptre_item
	local bowItemText = smokeItems.bow_item
	local quiverItemText = smokeItems.quiver_item
	local stygianBeltItemText = smokeItems.stygian_belt_item
	local abyssJewelItemText = smokeItems.abyss_jewel_item
	local jewelItemText = smokeItems.watchers_eye

	local _, invalidTestSlotErr = api.test_item(wandItemText, "Fake Slot")
	testkit.expect(invalidTestSlotErr == "invalid item slot" or invalidTestSlotErr == "item cannot be equipped in slot Fake Slot", "item_slot_rules: expected invalid slot error")

	local testedShield, testedShieldErr = api.test_item(shieldItemText, "Weapon 2")
	if not testedShield then
		return false, testedShieldErr
	end
	testkit.expect(testedShield.slot and testedShield.slot.resolved == "Weapon 2", "item_slot_rules: expected shield to be valid in Weapon 2")

	local testedOffhandWand, testedOffhandWandErr = api.test_item(wandItemText, "Weapon 2")
	if not testedOffhandWand then
		return false, testedOffhandWandErr
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
		return false, testedBowMainhandErr
	end
	testkit.expect(testedBowMainhand.slot and testedBowMainhand.slot.resolved == "Weapon 1", "item_slot_rules: expected bow to be valid in Weapon 1")

	local equippedBelt, equipBeltErr = api.equip_item(stygianBeltItemText, "Belt")
	if not equippedBelt then
		return false, equipBeltErr
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
		return false, testedAbyssJewelErr
	end
	testkit.expect(testedAbyssJewel.slot and testedAbyssJewel.slot.resolved == "Belt Abyssal Socket 1", "item_slot_rules: expected abyss jewel test slot")

	local equippedAbyssJewel, equipAbyssJewelErr = api.equip_item(abyssJewelItemText, "Belt Abyssal Socket 1")
	if not equippedAbyssJewel then
		return false, equipAbyssJewelErr
	end
	testkit.expect(equippedAbyssJewel.slot and equippedAbyssJewel.slot.resolved == "Belt Abyssal Socket 1", "item_slot_rules: expected abyss jewel equip slot")

	local equippedBow, equipBowErr = api.equip_item(bowItemText, "Weapon 1")
	if not equippedBow then
		return false, equipBowErr
	end
	testkit.expect(equippedBow.slot and equippedBow.slot.resolved == "Weapon 1", "item_slot_rules: expected bow equip slot")

	local testedQuiver, testedQuiverErr = api.test_item(quiverItemText, "Weapon 2")
	if not testedQuiver then
		return false, testedQuiverErr
	end
	testkit.expect(testedQuiver.slot and testedQuiver.slot.resolved == "Weapon 2", "item_slot_rules: expected quiver to become valid with bow main hand")

	local _, invalidShieldAfterBowErr = api.test_item(shieldItemText, "Weapon 2")
	testkit.expect(
		invalidShieldAfterBowErr == "item cannot be equipped in slot Weapon 2",
		"item_slot_rules: expected shield to be invalid after bow main hand equip"
	)

	local equippedQuiver, equipQuiverErr = api.equip_item(quiverItemText, "Weapon 2")
	if not equippedQuiver then
		return false, equipQuiverErr
	end
	testkit.expect(equippedQuiver.slot and equippedQuiver.slot.resolved == "Weapon 2", "item_slot_rules: expected quiver equip slot")

	local beltSummary, beltSummaryErr = api.get_summary()
	if not beltSummary then
		return false, beltSummaryErr
	end
	testkit.expect(beltSummary.buildName ~= nil, "item_slot_rules: expected summary after slot mutations")

	print("slotRulesBuild", summary.buildName or "")
	print("slotRulesLife", testkit.summaryStat(beltSummary, "Life"))
	print("slotRulesAbyss", equippedAbyssJewel.slot and equippedAbyssJewel.slot.resolved or "")
	return true
end)
