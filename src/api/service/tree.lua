-- Tree service that packages snapshot, compare, and delta flows.
local tableUtil = require("util.table")

local M = {}
M.__index = M

local function diffNodeLists(beforeNodes, afterNodes)
	local beforeSet, afterSet, added, removed = {}, {}, {}, {}
	for _, nodeId in ipairs(beforeNodes or {}) do beforeSet[nodeId] = true end
	for _, nodeId in ipairs(afterNodes or {}) do
		afterSet[nodeId] = true
		if not beforeSet[nodeId] then added[#added + 1] = nodeId end
	end
	for _, nodeId in ipairs(beforeNodes or {}) do
		if not afterSet[nodeId] then removed[#removed + 1] = nodeId end
	end
	table.sort(added)
	table.sort(removed)
	return added, removed
end

local function diffMasteryEffects(beforeEffects, afterEffects)
	local beforeById, afterById, changed = {}, {}, {}
	for _, entry in ipairs(beforeEffects or {}) do beforeById[entry.masteryId] = entry.effectId end
	for _, entry in ipairs(afterEffects or {}) do afterById[entry.masteryId] = entry.effectId end
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

function M.new(repos, services)
	return setmetatable({
		repos = repos,
		services = services,
	}, M)
end

function M:get_tree()
	return self.repos.tree:get_tree_state()
end

function M:get_tree_node(nodeId)
	return self.repos.tree:get_node(nodeId)
end

function M:search_tree_nodes(params)
	return self.repos.tree:search_nodes(params)
end

function M:create_tree_snapshot()
	return self.repos.tree:create_snapshot()
end

function M:restore_tree_snapshot(snapshot)
	return self.repos.tree:restore_snapshot(snapshot)
end

function M:simulate_node_delta(params, fields)
	local result, err = self.repos.tree:simulate_delta(params, fields)
	if not result then
		return nil, err
	end

	local tree = result.tree or {}
	local beforeTree = tree.before or {}
	local afterTree = tree.after or {}
	tree.addedNodes = tree.addedNodes or diffNodeLists(beforeTree.nodes, afterTree.nodes)
	tree.removedNodes = tree.removedNodes or select(2, diffNodeLists(beforeTree.nodes, afterTree.nodes))
	tree.changedMasteryEffects = tree.changedMasteryEffects or diffMasteryEffects(beforeTree.masteryEffects, afterTree.masteryEffects)
	result.tree = tree
	return result
end

return M
