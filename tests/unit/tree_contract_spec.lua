local treeRepoModule = require("api.tree.orchestrator")
local expect = require("testkit").expect

local function newTreeRepo()
    local state = {
        allocNodes = { [100] = true, [200] = true },
        masterySelections = { [900] = 901 },
        nodes = {
            [100] = { dn = "Start Node", type = "Normal", sd = { "+5 Strength" } },
            [200] = { dn = "Mastery Node", type = "Notable", sd = { "+10 Life" } },
            [300] = { dn = "Added Node", type = "Notable", sd = { "+25 Life" } },
            [400] = { dn = "Chaos Inoculation", type = "Keystone", sd = { "1 Maximum Life" } },
        },
        treeVersion = 3,
        curClassId = 3,
        curClassName = "Witch",
        curAscendClassId = 0,
        curAscendClassName = "Occultist",
        curSecondaryAscendClassId = 0,
        curSecondaryAscendClassName = "",
        allocatedMasteryCount = 1,
        allocatedNotableCount = 1,
        allocatedKeystoneCount = 0,
    }

    local build = {
        spec = state,
        calcsTab = {
            mainOutput = {
                Life = 100,
                TotalDPS = 2000,
            },
            BuildOutput = function(self)
                local count = 0
                for _ in pairs(state.allocNodes) do
                    count = count + 1
                end
                self.mainOutput = {
                    Life = 100 + count * 20,
                    TotalDPS = 2000 + count * 1000,
                }
            end,
        },
        treeTab = {
            activeSpec = 1,
            SetActiveSpec = function() end,
        },
    }

    local runtime = {
        ensure_build_ready = function(_, requiredTabs)
            return build
        end,
        rebuild_output = function(_, currentBuild)
            currentBuild.calcsTab:BuildOutput()
            return currentBuild.calcsTab.mainOutput
        end,
    }

    build.spec.CreateUndoState = function()
        return {
            hashList = { 100, 200 },
            hashOverrides = {},
            masteryEffects = {
                { masteryId = 900, effectId = 901 },
            },
        }
    end

    build.spec.RestoreUndoState = function(_, snapshot)
        state.allocNodes = { [100] = true, [200] = true }
        state.masterySelections = { [900] = 901 }
        if snapshot and snapshot.hashList then
            for _, nodeId in ipairs(snapshot.hashList) do
                state.allocNodes[nodeId] = true
            end
        end
    end

    build.spec.ImportFromNodeList = function(
        _,
        classId,
        ascendClassId,
        secondaryAscendClassId,
        nodes,
        _,
        masteryEffects,
        treeVersion
    )
        state.curClassId = classId
        state.curAscendClassId = ascendClassId
        state.curSecondaryAscendClassId = secondaryAscendClassId
        state.treeVersion = treeVersion
        state.allocNodes = {}
        for _, nodeId in ipairs(nodes or {}) do
            state.allocNodes[nodeId] = true
        end
        state.masterySelections = {}
        for masteryId, effectId in pairs(masteryEffects or {}) do
            state.masterySelections[masteryId] = effectId
        end
    end

    return treeRepoModule.new({ runtime = runtime }, {
        stats = {
            pick_fields = function(_, output, fields)
                local result = {}
                for _, field in ipairs(fields or {}) do
                    if output[field] ~= nil then
                        result[field] = output[field]
                    end
                end
                return result
            end,
            build_meta = function(_, buildObj)
                return {
                    buildName = "TestBuild",
                    level = 95,
                    treeVersion = buildObj.spec.treeVersion,
                    mainSkill = "Vortex",
                }
            end,
            compare_stats = function(_, beforeStats, afterStats, fields)
                local delta = {}
                local changedFields = {}
                for _, field in ipairs(fields or {}) do
                    local before = tonumber(beforeStats[field]) or 0
                    local after = tonumber(afterStats[field]) or 0
                    local diff = after - before
                    delta[field] = diff
                    if diff ~= 0 then
                        changedFields[#changedFields + 1] = field
                    end
                end
                return {
                    fields = fields,
                    before = beforeStats,
                    after = afterStats,
                    delta = delta,
                    changedFields = changedFields,
                    _meta = {
                        before = beforeStats._meta,
                        after = afterStats._meta,
                    },
                }
            end,
            get_default_stat_fields = function()
                return { "Life", "TotalDPS" }
            end,
        },
    }),
        state
end

do
    local treeRepo = newTreeRepo()
    local tree = treeRepo:get_tree()

    expect(tree ~= nil, "expected get_tree_state to succeed")
    expect(tree.classId == 3, "expected class id")
    expect(tree.counts.allocatedNodes == 2, "expected allocated node count")
    expect(tree.masteryEffects[1].masteryId == 900, "expected mastery summary")
end

do
    local treeRepo = newTreeRepo()
    local node = treeRepo:get_tree_node(400)

    expect(node ~= nil, "expected get_node to succeed")
    expect(node.type == "Keystone", "expected keystone type")
    expect(node.allocated == false, "expected unallocated node")
    expect(node.displayName == "Chaos Inoculation", "expected display name")
end

do
    local treeRepo = newTreeRepo()
    local search = treeRepo:search_tree_nodes({
        query = "chaos",
        type = "Keystone",
        limit = 5,
    })

    expect(search ~= nil, "expected search_nodes to succeed")
    expect(search.total == 1, "expected one matching node")
    expect(search.nodes[1].id == 400, "expected keystone search hit")
end

do
    local treeRepo = newTreeRepo()
    local snapshot = treeRepo:create_tree_snapshot()
    expect(snapshot ~= nil, "expected create_snapshot to succeed")
    expect(snapshot.kind == "tree_snapshot", "expected snapshot kind")
    expect(snapshot.tree.counts.allocatedNodes == 2, "expected tree data inside snapshot")

    local restored = treeRepo:restore_tree_snapshot(snapshot)
    expect(restored ~= nil, "expected restore_snapshot to succeed")
    expect(restored.restored == true, "expected restored flag")
    expect(restored.tree.counts.allocatedNodes == 2, "expected restored node count")
    expect(
        restored.tree.nodes[1] == 100 and restored.tree.nodes[2] == 200,
        "expected restore node list"
    )
end

do
    local treeRepo = newTreeRepo()
    local result = treeRepo:simulate_node_delta({
        addNodes = { 300, 400 },
        removeNodes = { 200 },
        classId = 6,
        ascendClassId = 2,
        masteryEffects = {
            [900] = 902,
        },
    }, { "Life", "TotalDPS" })

    expect(result ~= nil, "expected simulate_delta to succeed")
    expect(result.kind == "tree", "expected tree simulation kind")
    expect(result.restored == true, "expected tree simulation restore flag")
    expect(result.simulationMode == "snapshot_restore", "expected snapshot restore mode")
    expect(result.delta.Life == 20, "expected life delta from simulated node change")
    expect(result.delta.TotalDPS == 1000, "expected dps delta")
    expect(
        result.tree.before.nodes[1] == 100 and result.tree.before.nodes[2] == 200,
        "expected before tree nodes"
    )
    expect(
        result.tree.after.nodes[1] == 100
            and result.tree.after.nodes[2] == 300
            and result.tree.after.nodes[3] == 400,
        "expected after tree nodes"
    )
    expect(result.tree.target.classId == 6, "expected target class change")
    expect(result.tree.target.ascendClassId == 2, "expected target ascendancy change")
    expect(
        result.tree.addedNodes[1] == 300 and result.tree.addedNodes[2] == 400,
        "expected added node list"
    )
    expect(result.tree.removedNodes[1] == 200, "expected removed node list")
    expect(result.tree.changedMasteryEffects[1].masteryId == 900, "expected mastery diff")
    expect(result.tree.identityChanged == true, "expected identity change flag")
    expect(result.tree.requestedChanges.addNodes[1] == 300, "expected requested change payload")
    expect(result.comparison.delta == result.delta, "expected comparison delta alias")
end

do
    local treeRepo = newTreeRepo()
    local result, err = treeRepo:simulate_node_delta("bad params")
    expect(result == nil, "expected invalid params to fail")
    expect(err == "node delta params must be a table", "expected params validation error")
end
