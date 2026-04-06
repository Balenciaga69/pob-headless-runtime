local api = PoBHeadless
local testkit = require("testkit")

local xmlPath = arg[1]

if not xmlPath or xmlPath == "" then
	print("Missing build XML path.")
	os.exit(1)
end

local flow = testkit.newQueuedBuildFlow(api, xmlPath)

api.queue(function()
	if not flow.load() then
		return false
	end

	local baselineSummary, ready = flow.summary()
	if not ready then
		return false
	end

	local compared, compareErr = api.compare_config_stats({
		enemyLevel = 83,
		enemyIsBoss = "Pinnacle",
	}, { "Life", "FireResist", "CombinedDPS" })
	if not compared then
		error(compareErr, 0)
	end

	testkit.expect(type(compared.config) == "table", "config_compare: expected config payload")
	testkit.expect(compared.kind == "config", "config_compare: expected config simulation kind")
	testkit.expect(compared.restored == true, "config_compare: expected config simulation restore flag")
	testkit.expect(compared.simulationMode == "snapshot_restore", "config_compare: expected config simulation mode")
	testkit.expect(type(compared.comparison) == "table", "config_compare: expected comparison payload")
	testkit.expect(type(compared.comparison.delta) == "table", "config_compare: expected comparison delta")
	testkit.expect(type(compared.comparison.fields) == "table" and #compared.comparison.fields == 3, "config_compare: expected compare fields")
	testkit.expect(compared.comparison._meta and compared.comparison._meta.before, "config_compare: expected compare meta")
	testkit.expect(type(compared.delta) == "table", "config_compare: expected top-level delta table")
	testkit.expect(type(compared.before) == "table", "config_compare: expected top-level before table")
	testkit.expect(type(compared.after) == "table", "config_compare: expected top-level after table")
	testkit.expect(type(compared.changedFields) == "table", "config_compare: expected top-level changed fields table")

	testkit.expectDeltaMatches(
		compared.before,
		compared.after,
		compared.delta,
		{ "Life", "FireResist", "CombinedDPS" },
		"config_compare"
	)

	local afterCompareSummary, afterCompareErr = api.get_summary()
	if not afterCompareSummary then
		error(afterCompareErr, 0)
	end
	testkit.expectSummaryUnchanged(
		baselineSummary,
		afterCompareSummary,
		{ "Life", "FireResist", "ColdResist", "EnergyShield", "CombinedDPS" },
		"config_compare"
	)

	local _, invalidConfigErr = api.compare_config_stats({ invalidField = true }, { "CombinedDPS" })
	testkit.expect(
		invalidConfigErr ~= nil and invalidConfigErr:match("^unsupported config field:"),
		"config_compare: expected invalid config field error"
	)

	local _, invalidFieldsErr = api.compare_config_stats({ enemyLevel = 83 }, "CombinedDPS")
	testkit.expect(invalidFieldsErr == "fields must be a table", "config_compare: expected invalid fields error")

	print("configCompareDPS", testkit.normalizeNumber(compared.delta.CombinedDPS))
	print("configCompareChanged", #compared.changedFields)

	api.stop()
	return true
end)
