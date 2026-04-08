local buildGuard = require("api.repo.build_guard")
local statsCompareUtil = require("util.stats_compare")
local tableUtil = require("util.table")
local expect = require("testkit").expect

do
	local source = { "Life", "Mana" }
	local copied = tableUtil.copyArray(source)
	source[1] = "Changed"

	expect(copied[1] == "Life", "expected copyArray to detach from source array")
	expect(copied[2] == "Mana", "expected copyArray to keep values")
end

do
	local source = { Life = 100, nested = { value = 1 } }
	local copied = tableUtil.shallowCopy(source)
	source.Life = 200

	expect(copied.Life == 100, "expected shallowCopy to detach top-level scalar values")
	expect(copied.nested == source.nested, "expected shallowCopy to keep nested references")
end

do
	local session = {
		getBuild = function()
			return {
				itemsTab = {},
				calcsTab = {},
			}
		end,
	}

	local build, err = buildGuard.getBuildWithTabs(session, { "itemsTab", "calcsTab" }, "items not initialized")
	expect(build ~= nil and err == nil, "expected getBuildWithTabs to return build when all tabs exist")
	expect(build.itemsTab ~= nil, "expected build payload to be preserved")
end

do
	local session = {
		getBuild = function()
			return {
				itemsTab = {},
			}
		end,
	}

	local build, err = buildGuard.getBuildWithTabs(session, { "itemsTab", "calcsTab" }, "items not initialized")
	expect(build == nil, "expected getBuildWithTabs to fail when tab is missing")
	expect(err == "items not initialized", "expected getBuildWithTabs to return caller error message")
end

do
	local session = {
		getBuild = function()
			return {
				configTab = {
					input = {},
				},
			}
		end,
	}

	local result, err = buildGuard.withBuild(session, { "configTab" }, "build/config not initialized", function(build)
		return build.configTab.input, nil
	end)
	expect(result ~= nil and err == nil, "expected withBuild to forward callback result")
end

do
	local stats = {
		Life = 100,
		Label = "text",
		FireResist = 25,
	}

	local picked = statsCompareUtil.pickNumericFields(stats, { "Life", "Label", "FireResist" })
	expect(picked.Life == 100, "expected pickNumericFields to keep Life")
	expect(picked.FireResist == 25, "expected pickNumericFields to keep FireResist")
	expect(picked.Label == nil, "expected pickNumericFields to ignore non-numeric fields")
end

do
	local delta, changedFields = statsCompareUtil.numericDelta(
		{ Life = 100, FireResist = 20, Label = "before" },
		{ Life = 140, FireResist = 20, ChaosResist = 15, Label = "after" },
		{ "Life", "FireResist", "ChaosResist", "Label" }
	)

	expect(delta.Life == 40, "expected numericDelta to calculate increased values")
	expect(delta.FireResist == 0, "expected numericDelta to include unchanged numeric values")
	expect(delta.ChaosResist == 15, "expected numericDelta to treat missing numeric before values as zero")
	expect(delta.Label == nil, "expected numericDelta to ignore non-numeric fields")
	expect(#changedFields == 2, "expected changedFields to list only non-zero deltas")
	expect(changedFields[1] == "Life", "expected changedFields ordering to follow requested fields")
	expect(changedFields[2] == "ChaosResist", "expected changedFields to include newly-added numeric field")
end
