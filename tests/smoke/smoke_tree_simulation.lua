local api = PoBHeadless
local smokekit = require("smokekit")
local testkit = require("testkit")

local xmlPath = smokekit.requireXmlArg()
local candidateNodeId

smokekit.runQueuedSmoke(api, xmlPath, function(flow, baselineSummary)
	if not candidateNodeId then
		local loadedBuild = flow.build()
		testkit.expect(loadedBuild ~= nil, "tree_simulation: expected loaded build handle")
		for nodeId, node in pairs(loadedBuild and loadedBuild.spec and loadedBuild.spec.nodes or {}) do
			if loadedBuild.spec.allocNodes[nodeId] == nil and node and node.type ~= "Mastery" then
				candidateNodeId = nodeId
				break
			end
		end
	end
	testkit.expect(candidateNodeId ~= nil, "tree_simulation: expected a candidate node")

	local tree, treeErr = api.get_tree()
	if not tree then
		return false, treeErr
	end
	testkit.expect(type(tree.nodes) == "table" and #tree.nodes > 0, "tree_simulation: expected get_tree nodes payload")

	local snapshot, snapshotErr = api.create_tree_snapshot()
	if not snapshot then
		return false, snapshotErr
	end
	testkit.expect(snapshot.kind == "tree_snapshot", "tree_simulation: expected explicit tree snapshot")

	local queriedNode, queriedNodeErr = api.get_tree_node(candidateNodeId)
	if not queriedNode then
		return false, queriedNodeErr
	end
	testkit.expect(queriedNode.id == candidateNodeId, "tree_simulation: expected queried tree node id")
	testkit.expect(queriedNode.allocated == false, "tree_simulation: expected candidate node to be unallocated before simulation")

	local nodeName = queriedNode.displayName or queriedNode.name
	testkit.expect(type(nodeName) == "string" and nodeName ~= "", "tree_simulation: expected searchable node name")

	local searchResult, searchErr = api.search_tree_nodes({
		query = nodeName,
		limit = 5,
	})
	if not searchResult then
		return false, searchErr
	end
	testkit.expect(type(searchResult.nodes) == "table" and #searchResult.nodes >= 1, "tree_simulation: expected search results")

	local allocatedSearch, allocatedSearchErr = api.search_tree_nodes({
		type = "Notable",
		allocatedOnly = true,
		limit = 10,
	})
	if not allocatedSearch then
		return false, allocatedSearchErr
	end
	testkit.expect((allocatedSearch.total or 0) >= 1, "tree_simulation: expected allocated notable search results")

	local missingNode, missingNodeErr = api.get_tree_node(-1)
	testkit.expect(missingNode == nil, "tree_simulation: expected missing tree node lookup to fail")
	testkit.expect(missingNodeErr == "node not found", "tree_simulation: expected missing node error")

	local simulated, simulateErr = api.simulate_node_delta({
		addNodes = { candidateNodeId },
	}, { "Life", "EnergyShield", "CombinedDPS" })
	if not simulated then
		return false, simulateErr
	end

	testkit.expect(simulated.kind == "tree", "tree_simulation: expected tree simulation kind")
	testkit.expect(simulated.restored == true, "tree_simulation: expected tree simulation restore flag")
	testkit.expect(simulated.simulationMode == "snapshot_restore", "tree_simulation: expected tree simulation mode")
	testkit.expect(type(simulated.tree) == "table", "tree_simulation: expected tree payload")
	testkit.expect(type(simulated.tree.before) == "table", "tree_simulation: expected before tree payload")
	testkit.expect(type(simulated.tree.after) == "table", "tree_simulation: expected after tree payload")
	testkit.expect(type(simulated.tree.target) == "table", "tree_simulation: expected target tree payload")
	testkit.expect(type(simulated.tree.requestedChanges) == "table", "tree_simulation: expected requested tree changes payload")
	testkit.expect(type(simulated.delta) == "table", "tree_simulation: expected top-level delta payload")

	testkit.expect(type(simulated.delta.Life) == "number", "tree_simulation: expected numeric life delta")
	testkit.expect(type(simulated.delta.EnergyShield) == "number", "tree_simulation: expected numeric ES delta")
	testkit.expect(type(simulated.delta.CombinedDPS) == "number", "tree_simulation: expected numeric DPS delta")

	local afterSummary, afterErr = api.get_summary()
	if not afterSummary then
		return false, afterErr
	end
	testkit.expect(
		testkit.normalizeNumber(baselineSummary.stats.Life) == testkit.normalizeNumber(afterSummary.stats.Life),
		"tree_simulation: expected tree simulation to restore life"
	)
	testkit.expect(
		testkit.normalizeNumber(baselineSummary.stats.CombinedDPS) == testkit.normalizeNumber(afterSummary.stats.CombinedDPS),
		"tree_simulation: expected tree simulation to restore dps"
	)

	local restored, restoreErr = api.restore_tree_snapshot(snapshot)
	if not restored then
		return false, restoreErr
	end
	testkit.expect(restored.restored == true, "tree_simulation: expected explicit restore flag")
	testkit.expect(#(restored.tree.nodes or {}) == #(tree.nodes or {}), "tree_simulation: expected explicit restore to preserve node count")

	print("treeDeltaLife", testkit.normalizeNumber(simulated.delta.Life))
	print("treeDeltaChanged", #simulated.changedFields)
	print("treeSearchHits", searchResult.total or 0)
	print("treeAllocatedHits", allocatedSearch.total or 0)
	return true
end)
