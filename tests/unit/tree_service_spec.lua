local treeServiceModule = require("api.service.tree")
local expect = require("testkit").expect

do
	local result = {
		kind = "tree",
		comparison = {
			fields = { "Life" },
			before = { Life = 100 },
			after = { Life = 120 },
			delta = { Life = 20 },
			changedFields = { "Life" },
			_meta = {
				before = { buildName = "Before" },
				after = { buildName = "After" },
			},
		},
		compareFields = { "Life" },
		before = { Life = 100 },
		after = { Life = 120 },
		delta = { Life = 20 },
		changedFields = { "Life" },
		_meta = {
			before = { buildName = "Before" },
			after = { buildName = "After" },
		},
		restored = true,
		simulationMode = "snapshot_restore",
		tree = {
			before = {
				nodes = { 100, 200 },
				masteryEffects = {
					{ masteryId = 900, effectId = 901 },
				},
			},
			after = {
				nodes = { 100, 300 },
				masteryEffects = {
					{ masteryId = 900, effectId = 902 },
				},
			},
		},
	}
	local service = treeServiceModule.new({
		tree = {
			simulate_delta = function()
				return result
			end,
		},
	}, {})

	local resolved, err = service:simulate_node_delta({ addNodes = { 300 } }, { "Life" })
	expect(resolved ~= nil and err == nil, "expected simulate_node_delta to succeed")
	expect(resolved == result, "expected service to return repo result without re-wrapping")
	expect(resolved.kind == "tree", "expected simulation kind")
	expect(resolved.comparison.delta.Life == resolved.delta.Life, "expected comparison payload to be preserved")
	expect(resolved.compareFields[1] == "Life", "expected top-level compare fields to remain intact")
	expect(resolved.tree.addedNodes[1] == 300, "expected addedNodes to be backfilled")
	expect(resolved.tree.removedNodes[1] == 200, "expected removedNodes to be backfilled")
	expect(resolved.tree.changedMasteryEffects[1].masteryId == 900, "expected mastery diff to be backfilled")
end
