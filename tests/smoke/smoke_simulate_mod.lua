local api = PoBHeadless
local smokekit = require("smokekit")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()

smokekit.runQueuedSmoke(api, xmlPath, function(_, baselineSummary)
	local simulated, simulateErr = api.simulate_mod("+20 to maximum Life", "Ring 1", { "Life", "FireResist", "ColdResist" })
	if not simulated then
		return false, simulateErr
	end

	testkit.expect(simulated.modLine == "+20 to maximum Life", "simulate_mod: expected mod line echo")
	testkit.expect(simulated.slot and simulated.slot.resolved == "Ring 1", "simulate_mod: expected simulate_mod slot")
	testkit.expect(simulated.currentItem ~= nil, "simulate_mod: expected current item summary")
	testkit.expect(simulated.candidateItem ~= nil, "simulate_mod: expected candidate item summary")
	testkit.expect(simulated.kind == "mod", "simulate_mod: expected mod simulation kind")
	testkit.expect(simulated.restored == true, "simulate_mod: expected mod simulation restore flag")
	testkit.expect(simulated.simulationMode == "calculator", "simulate_mod: expected mod simulation mode")
	testkit.expect(type(simulated.comparison) == "table", "simulate_mod: expected comparison payload")
	testkit.expect(type(simulated.comparison.delta) == "table", "simulate_mod: expected comparison delta")
	testkit.expect(type(simulated.delta) == "table", "simulate_mod: expected top-level delta table")

	testkit.expectDeltaMatches(
		simulated.before,
		simulated.after,
		simulated.delta,
		{ "Life", "FireResist", "ColdResist" },
		"simulate_mod"
	)
	testkit.expect(testkit.normalizeNumber(simulated.delta.Life) ~= 0, "simulate_mod: expected non-zero simulated life delta")

	local afterSimulateSummary, afterSimulateErr = api.get_summary()
	if not afterSimulateSummary then
		return false, afterSimulateErr
	end
	testkit.expectSummaryUnchanged(
		baselineSummary,
		afterSimulateSummary,
		{ "Life", "FireResist", "ColdResist", "EnergyShield", "CombinedDPS" },
		"simulate_mod"
	)

	local _, missingSlotErr = api.simulate_mod("+20 to maximum Life")
	testkit.expect(missingSlotErr == "slot is required", "simulate_mod: expected required slot error")

	local _, invalidSlotErr = api.simulate_mod("+20 to maximum Life", "Fake Slot", { "Life" })
	testkit.expect(invalidSlotErr == "invalid item slot", "simulate_mod: expected invalid slot error")

	local _, missingModErr = api.simulate_mod("", "Ring 1", { "Life" })
	testkit.expect(missingModErr == "modLine is required", "simulate_mod: expected required mod line error")

	local _, invalidFieldsErr = api.simulate_mod("+20 to maximum Life", "Ring 1", "Life")
	testkit.expect(invalidFieldsErr == "fields must be a table", "simulate_mod: expected invalid fields error")

	print("simulateLife", testkit.normalizeNumber(simulated.delta.Life))
	print("simulateChanged", #simulated.changedFields)
	return true
end)
