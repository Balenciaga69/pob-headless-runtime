-- Tree adapter that uses snapshot-based simulation.
local simulationUtil = require("util.simulation")
local statsCompareUtil = require("util.stats_compare")
local tableUtil = require("util.table")

local M = {}
M.__index = M

local DEFAULT_NODE_SEARCH_LIMIT = 20

local function copyUndoState(state)
	-- Copy undo state deeply enough for snapshot and restore flows.
	if type(state) ~= "table" then
		return state
	end

	local copy = tableUtil.shallowCopy(state)
	copy.hashList = tableUtil.copyArray(state.hashList)
	copy.hashOverrides = tableUtil.shallowCopy(state.hashOverrides)
	copy.masteryEffects = tableUtil.shallowCopy(state.masteryEffects)
	return copy
end

local function summarizeMasteryEffects(spec)
	-- Normalize mastery selections into a stable, sorted summary.
	local effects = {}
	for masteryId, effectId in pairs(spec and spec.masterySelections or {}) do
		effects[#effects + 1] = {
			masteryId = tonumber(masteryId),
			effectId = tonumber(effectId),
		}
	end
	table.sort(effects, function(a, b)
		return a.masteryId < b.masteryId
	end)
	return effects
end

local function normalizeNodeList(values, fieldName)
	-- Normalize a node id list, de-duplicating and sorting the result.
	if values == nil then
		return {}
	end
	if type(values) ~= "table" then
		return nil, fieldName .. " must be a table"
	end

	local normalized = {}
	local seen = {}
	for _, value in ipairs(values) do
		local nodeId = tonumber(value)
		if not nodeId then
			return nil, fieldName .. " must contain numeric node ids"
		end
		if not seen[nodeId] then
			seen[nodeId] = true
			normalized[#normalized + 1] = nodeId
		end
	end

	table.sort(normalized)
	return normalized
end

local function normalizeMasteryEffects(values)
	-- Normalize mastery effect mappings into numeric ids.
	if values == nil then
		return nil
	end
	if type(values) ~= "table" then
		return nil, "masteryEffects must be a table"
	end

	local normalized = {}
	for masteryId, effectId in pairs(values) do
		local numericMasteryId = tonumber(masteryId)
		local numericEffectId = tonumber(effectId)
		if not numericMasteryId or not numericEffectId then
			return nil, "masteryEffects must map numeric mastery ids to numeric effect ids"
		end
		normalized[numericMasteryId] = numericEffectId
	end

	return normalized
end

local function normalizeNodeDeltaParams(params)
	-- Validate and normalize the node delta request payload.
	if type(params) ~= "table" then
		return nil, "node delta params must be a table"
	end

	local addNodes, addErr = normalizeNodeList(params.addNodes, "addNodes")
	if not addNodes then
		return nil, addErr
	end
	local removeNodes, removeErr = normalizeNodeList(params.removeNodes, "removeNodes")
	if not removeNodes then
		return nil, removeErr
	end
	local masteryEffects, masteryErr = normalizeMasteryEffects(params.masteryEffects)
	if masteryErr then
		return nil, masteryErr
	end

	return {
		addNodes = addNodes,
		removeNodes = removeNodes,
		classId = params.classId ~= nil and tonumber(params.classId) or nil,
		ascendClassId = params.ascendClassId ~= nil and tonumber(params.ascendClassId) or nil,
		secondaryAscendClassId = params.secondaryAscendClassId ~= nil and tonumber(params.secondaryAscendClassId) or nil,
		treeVersion = params.treeVersion,
		masteryEffects = masteryEffects,
	}
end

local function normalizeNodeSearchParams(params)
	-- Validate and normalize node search parameters.
	params = params or {}
	if type(params) ~= "table" then
		return nil, "search params must be a table"
	end

	local limit = tonumber(params.limit or DEFAULT_NODE_SEARCH_LIMIT) or DEFAULT_NODE_SEARCH_LIMIT
	limit = math.max(1, math.floor(limit))
	local query = params.query
	if query ~= nil then
		if type(query) ~= "string" then
			return nil, "search query must be a string"
		end
		query = string.lower(query)
	end
	local nodeType = params.type
	if nodeType ~= nil and type(nodeType) ~= "string" then
		return nil, "search type must be a string"
	end

	return {
		query = query,
		type = nodeType,
		allocatedOnly = params.allocatedOnly == true,
		limit = limit,
	}
end

local function diffMasteryEffects(beforeEffects, afterEffects)
	-- Compute mastery effect changes between two tree states.
	local beforeById, afterById, changed = {}, {}, {}
	for _, entry in ipairs(beforeEffects or {}) do
		beforeById[entry.masteryId] = entry.effectId
	end
	for _, entry in ipairs(afterEffects or {}) do
		afterById[entry.masteryId] = entry.effectId
	end
	for masteryId, effectId in pairs(afterById) do
		if beforeById[masteryId] ~= effectId then
			changed[#changed + 1] = { masteryId = masteryId, before = beforeById[masteryId], after = effectId }
		end
	end
	for masteryId, effectId in pairs(beforeById) do
		if afterById[masteryId] == nil then
			changed[#changed + 1] = { masteryId = masteryId, before = effectId, after = nil }
		end
	end
	table.sort(changed, function(a, b) return a.masteryId < b.masteryId end)
	return changed
end

local function diffNodeLists(beforeNodes, afterNodes)
	-- Compute node ids added to and removed from the tree.
	local beforeSet, afterSet, added, removed = {}, {}, {}, {}
	for _, nodeId in ipairs(beforeNodes or {}) do
		beforeSet[nodeId] = true
	end
	for _, nodeId in ipairs(afterNodes or {}) do
		afterSet[nodeId] = true
		if not beforeSet[nodeId] then
			added[#added + 1] = nodeId
		end
	end
	for _, nodeId in ipairs(beforeNodes or {}) do
		if not afterSet[nodeId] then
			removed[#removed + 1] = nodeId
		end
	end
	table.sort(added)
	table.sort(removed)
	return added, removed
end

local function buildMeta(statsRepo, build)
	-- Build metadata shared by tree and stat comparison payloads.
	return {
		buildName = build and build.buildName or nil,
		level = build and tonumber(build.characterLevel) or nil,
		treeVersion = build and (build.targetVersion or (build.spec and build.spec.treeVersion) or nil) or nil,
		mainSkill = statsRepo and statsRepo.get_main_skill_name and statsRepo:get_main_skill_name(build) or nil,
	}
end

local function pickFields(output, fields, defaultFields)
	-- Pick only the requested fields from a stats output table.
	local result = {}
	for _, field in ipairs(fields or defaultFields or {}) do
		if output and output[field] ~= nil then
			result[field] = output[field]
		end
	end
	return result
end

local function compareStats(beforeStats, afterStats, fields)
	-- Compare numeric stats and preserve the original metadata envelope.
	local compareFields = fields
	if compareFields == nil then
		compareFields = {}
		for key, value in pairs(beforeStats or {}) do
			if type(key) == "string" and key ~= "_meta" and type(value) == "number" then
				compareFields[#compareFields + 1] = key
			end
		end
		for key, value in pairs(afterStats or {}) do
			if type(key) == "string" and key ~= "_meta" and type(value) == "number" then
				local seen = false
				for _, existing in ipairs(compareFields) do
					if existing == key then
						seen = true
						break
					end
				end
				if not seen then
					compareFields[#compareFields + 1] = key
				end
			end
		end
	end

	local beforePicked = statsCompareUtil.pickNumericFields(beforeStats, compareFields)
	local afterPicked = statsCompareUtil.pickNumericFields(afterStats, compareFields)
	local delta, changedFields = statsCompareUtil.numericDelta(beforeStats, afterStats, compareFields)

	return {
		fields = compareFields,
		before = beforePicked,
		after = afterPicked,
		delta = delta,
		changedFields = changedFields,
		_meta = {
			before = beforeStats._meta,
			after = afterStats._meta,
		},
	}
end

function M.new(runtimeRepo, statsRepo)
	-- Keep the tree adapter stateless by storing only its collaborators.
	return setmetatable({
		runtime = runtimeRepo,
		stats = statsRepo,
	}, M)
end

function M:summarize_tree_state(build)
	-- Summarize the tree's identity, allocation counts, and mastery state.
	local spec = build and build.spec or nil
	local state = {
		treeVersion = spec and spec.treeVersion or nil,
		classId = spec and tonumber(spec.curClassId) or 0,
		className = spec and spec.curClassName or nil,
		ascendClassId = spec and tonumber(spec.curAscendClassId) or 0,
		ascendClassName = spec and spec.curAscendClassName or nil,
		secondaryAscendClassId = spec and tonumber(spec.curSecondaryAscendClassId or 0) or 0,
		secondaryAscendClassName = spec and spec.curSecondaryAscendClassName or nil,
		nodes = {},
		masteryEffects = {},
		counts = {
			allocatedNodes = 0,
			allocatedMasteries = tonumber(spec and spec.allocatedMasteryCount) or 0,
			allocatedNotables = tonumber(spec and spec.allocatedNotableCount) or 0,
			allocatedKeystones = tonumber(spec and spec.allocatedKeystoneCount) or 0,
		},
	}

	for nodeId in pairs(spec and spec.allocNodes or {}) do
		state.nodes[#state.nodes + 1] = nodeId
	end
	table.sort(state.nodes)
	state.counts.allocatedNodes = #state.nodes
	state.masteryEffects = summarizeMasteryEffects(spec)
	return state
end

function M:summarize_node(spec, nodeId, node)
	-- Summarize a single passive tree node for lookup and search.
	nodeId = tonumber(nodeId)
	node = node or (spec and spec.nodes and spec.nodes[nodeId]) or nil
	if not node then
		return nil
	end

	local stats = {}
	for _, statLine in ipairs(node.sd or {}) do
		stats[#stats + 1] = statLine
	end

	local masteryEffects = {}
	for _, effect in ipairs(node.masteryEffects or {}) do
		masteryEffects[#masteryEffects + 1] = {
			effectId = effect and tonumber(effect.effect) or nil,
			stats = effect and effect.sd and tableUtil.copyArray(effect.sd) or {},
		}
	end

	return {
		id = nodeId,
		name = node.name or node.dn or nil,
		displayName = node.dn or node.name or nil,
		type = node.type or nil,
		allocated = spec and spec.allocNodes and spec.allocNodes[nodeId] ~= nil or false,
		classStart = node.type == "ClassStart" or node.type == "AscendClassStart",
		isMultipleChoice = node.isMultipleChoice == true,
		isAscendancy = node.ascendancyName ~= nil,
		ascendancyName = node.ascendancyName or nil,
		group = node.group or nil,
		pathDistance = tonumber(node.pathDist) or nil,
		stats = stats,
		masteryEffects = masteryEffects,
		selectedMasteryEffectId = spec and spec.masterySelections and tonumber(spec.masterySelections[nodeId]) or nil,
	}
end

function M:build_node_search_terms(nodeSummary)
	-- Build lowercase terms used by the node search filter.
	local terms = {}
	if nodeSummary.name then
		terms[#terms + 1] = string.lower(nodeSummary.name)
	end
	if nodeSummary.displayName then
		terms[#terms + 1] = string.lower(nodeSummary.displayName)
	end
	for _, statLine in ipairs(nodeSummary.stats or {}) do
		terms[#terms + 1] = string.lower(statLine)
	end
	return terms
end

function M:get_tree_state()
	-- Return the current summarized tree state.
	local build, err = self.runtime:ensure_build_ready({ "spec" }, "build/spec not initialized")
	if not build then
		return nil, err
	end
	return self:summarize_tree_state(build)
end

function M:get_node(nodeId)
	-- Return a single node summary by id.
	local build, err = self.runtime:ensure_build_ready({ "spec" }, "build/spec not initialized")
	if not build then
		return nil, err
	end
	local numericNodeId = tonumber(nodeId)
	if not numericNodeId then
		return nil, "nodeId must be numeric"
	end
	local nodeSummary = self:summarize_node(build.spec, numericNodeId)
	if not nodeSummary then
		return nil, "node not found"
	end
	return nodeSummary
end

function M:search_nodes(params)
	-- Search nodes by name, type, and allocation state.
	local build, err = self.runtime:ensure_build_ready({ "spec" }, "build/spec not initialized")
	if not build then
		return nil, err
	end

	local normalized, searchErr = normalizeNodeSearchParams(params)
	if not normalized then
		return nil, searchErr
	end

	local results = {}
	for nodeId, node in pairs(build.spec.nodes or {}) do
		local summary = self:summarize_node(build.spec, nodeId, node)
		local include = summary ~= nil
		if include and normalized.allocatedOnly and not summary.allocated then
			include = false
		end
		if include and normalized.type and summary.type ~= normalized.type then
			include = false
		end
		if include and normalized.query and normalized.query ~= "" then
			include = false
			for _, term in ipairs(self:build_node_search_terms(summary)) do
				if term:find(normalized.query, 1, true) then
					include = true
					break
				end
			end
		end
		if include then
			results[#results + 1] = summary
		end
	end

	table.sort(results, function(a, b)
		if a.allocated ~= b.allocated then
			return a.allocated
		end
		local nameA = a.displayName or a.name or ""
		local nameB = b.displayName or b.name or ""
		if nameA ~= nameB then
			return nameA < nameB
		end
		return a.id < b.id
	end)
	while #results > normalized.limit do
		results[#results] = nil
	end

	return {
		query = normalized.query,
		type = normalized.type,
		allocatedOnly = normalized.allocatedOnly,
		limit = normalized.limit,
		total = #results,
		nodes = results,
	}
end

function M:create_snapshot()
	-- Capture the current tree state and undo payload.
	local build, err = self.runtime:ensure_build_ready({ "spec" }, "build/spec not initialized")
	if not build then
		return nil, err
	end
	if not build.spec.CreateUndoState then
		return nil, "tree snapshot requires spec undo support"
	end
	return {
		kind = "tree_snapshot",
		tree = self:summarize_tree_state(build),
		state = copyUndoState(build.spec:CreateUndoState()),
	}
end

function M:restore_snapshot(snapshot)
	-- Restore a previously captured tree snapshot.
	local build, err = self.runtime:ensure_build_ready({ "spec", "calcsTab" }, "build/spec not initialized")
	if not build then
		return nil, err
	end
	if not build.spec.RestoreUndoState then
		return nil, "tree restore requires spec undo support"
	end
	if type(snapshot) ~= "table" or type(snapshot.state) ~= "table" then
		return nil, "tree snapshot must be a table with state"
	end

	build.spec:RestoreUndoState(copyUndoState(snapshot.state))
	if build.spec.BuildClusterJewelGraphs then
		build.spec:BuildClusterJewelGraphs()
	end
	if build.treeTab and build.treeTab.SetActiveSpec then
		build.treeTab:SetActiveSpec(build.treeTab.activeSpec or 1)
	end
	local _, outputErr = self.runtime:rebuild_output(build)
	if outputErr then
		return nil, outputErr
	end

	return {
		restored = true,
		tree = self:summarize_tree_state(build),
	}
end

function M:build_target_tree(currentTree, params)
	-- Merge requested node changes into a target tree state.
	local nodesById = {}
	for _, nodeId in ipairs(currentTree.nodes or {}) do
		nodesById[nodeId] = true
	end
	for _, nodeId in ipairs(params.removeNodes or {}) do
		nodesById[nodeId] = nil
	end
	for _, nodeId in ipairs(params.addNodes or {}) do
		nodesById[nodeId] = true
	end

	local nodes = {}
	for nodeId in pairs(nodesById) do
		nodes[#nodes + 1] = nodeId
	end
	table.sort(nodes)

	local masteryEffects = {}
	if params.masteryEffects then
		masteryEffects = tableUtil.shallowCopy(params.masteryEffects)
	else
		for _, entry in ipairs(currentTree.masteryEffects or {}) do
			masteryEffects[entry.masteryId] = entry.effectId
		end
	end

	return {
		treeVersion = params.treeVersion or currentTree.treeVersion,
		classId = params.classId or currentTree.classId,
		ascendClassId = params.ascendClassId or currentTree.ascendClassId,
		secondaryAscendClassId = params.secondaryAscendClassId or currentTree.secondaryAscendClassId,
		nodes = nodes,
		masteryEffects = masteryEffects,
	}
end

function M:apply_tree_state(build, treeState)
	-- Push the target tree state back into the live build object.
	build.spec:ImportFromNodeList(
		treeState.classId,
		treeState.ascendClassId,
		treeState.secondaryAscendClassId,
		treeState.nodes,
		{},
		treeState.masteryEffects,
		treeState.treeVersion
	)
	if build.spec.BuildClusterJewelGraphs then
		build.spec:BuildClusterJewelGraphs()
	end
	if build.treeTab and build.treeTab.SetActiveSpec then
		build.treeTab:SetActiveSpec(build.treeTab.activeSpec or 1)
	end
	return self.runtime:rebuild_output(build)
end

function M:simulate_delta(params, fields)
	-- Simulate a tree change, compare before/after stats, then restore the snapshot.
	local normalizedParams, paramsErr = normalizeNodeDeltaParams(params)
	if not normalizedParams then
		return nil, paramsErr
	end
	local build, err = self.runtime:ensure_build_ready({ "spec", "calcsTab" }, "build/spec not initialized")
	if not build then
		return nil, err
	end
	if fields ~= nil and type(fields) ~= "table" then
		return nil, "fields must be a table"
	end
	if not build.spec.CreateUndoState or not build.spec.RestoreUndoState or not build.spec.ImportFromNodeList then
		return nil, "tree simulation requires spec undo/import support"
	end

	local beforeOutput, beforeErr = self.runtime:rebuild_output(build)
	if not beforeOutput then
		return nil, beforeErr
	end
	local beforeTree = self:summarize_tree_state(build)
	local beforeStats = pickFields(beforeOutput, fields, self.stats and self.stats.get_default_stat_fields and self.stats:get_default_stat_fields() or nil)
	beforeStats._meta = buildMeta(self.stats, build)

	local snapshot = copyUndoState(build.spec:CreateUndoState())
	local targetTree = self:build_target_tree(beforeTree, normalizedParams)
	local afterOutput, applyErr = self:apply_tree_state(build, targetTree)
	if not afterOutput then
		self:restore_snapshot({ state = snapshot })
		return nil, applyErr
	end

	local afterTree = self:summarize_tree_state(build)
	local afterStats = pickFields(afterOutput, fields, self.stats and self.stats.get_default_stat_fields and self.stats:get_default_stat_fields() or nil)
	afterStats._meta = buildMeta(self.stats, build)

	local compared = compareStats(beforeStats, afterStats, fields)
	local _, restoreErr = self:restore_snapshot({ state = snapshot })
	if restoreErr then
		return nil, restoreErr
	end

	local addedNodes, removedNodes = diffNodeLists(beforeTree.nodes, afterTree.nodes)
	local changedMasteryEffects = diffMasteryEffects(beforeTree.masteryEffects, afterTree.masteryEffects)
	local identityChanged = beforeTree.classId ~= afterTree.classId
		or beforeTree.ascendClassId ~= afterTree.ascendClassId
		or beforeTree.secondaryAscendClassId ~= afterTree.secondaryAscendClassId
		or beforeTree.treeVersion ~= afterTree.treeVersion

	return simulationUtil.buildResult("tree", compared, {
		restored = true,
		simulationMode = "snapshot_restore",
		tree = {
			before = beforeTree,
			after = afterTree,
			target = {
				treeVersion = targetTree.treeVersion,
				classId = targetTree.classId,
				ascendClassId = targetTree.ascendClassId,
				secondaryAscendClassId = targetTree.secondaryAscendClassId,
				nodes = tableUtil.copyArray(targetTree.nodes),
				masteryEffects = normalizeMasteryEffects(targetTree.masteryEffects) and summarizeMasteryEffects({ masterySelections = targetTree.masteryEffects }) or {},
			},
			addedNodes = addedNodes,
			removedNodes = removedNodes,
			changedMasteryEffects = changedMasteryEffects,
			identityChanged = identityChanged,
			requestedChanges = {
				addNodes = tableUtil.copyArray(normalizedParams.addNodes),
				removeNodes = tableUtil.copyArray(normalizedParams.removeNodes),
				classId = normalizedParams.classId,
				ascendClassId = normalizedParams.ascendClassId,
				secondaryAscendClassId = normalizedParams.secondaryAscendClassId,
				treeVersion = normalizedParams.treeVersion,
				masteryEffects = normalizedParams.masteryEffects and summarizeMasteryEffects({ masterySelections = normalizedParams.masteryEffects }) or {},
			},
		},
	})
end

return M
