local treeServiceModule = require("api.tree.orchestrator")
local expect = require("testkit").expect

do
    local service = treeServiceModule.new({}, {
        stats = {
            get_default_stat_fields = function()
                return { "Life" }
            end,
            pick_fields = function(_, output)
                return { Life = output.Life }
            end,
            build_meta = function()
                return { buildName = "After" }
            end,
            compare_stats = function(_, beforeStats, afterStats, fields)
                return {
                    fields = fields,
                    before = beforeStats,
                    after = afterStats,
                    delta = { Life = (afterStats.Life or 0) - (beforeStats.Life or 0) },
                    changedFields = { "Life" },
                    _meta = {
                        before = beforeStats._meta,
                        after = afterStats._meta,
                    },
                }
            end,
        },
    })
    service.runtime = {
        ensure_build_ready = function()
            return {
                spec = {
                    allocNodes = { [100] = true, [200] = true },
                    masterySelections = { [900] = 901 },
                    nodes = {
                        [100] = { dn = "Start", type = "Normal", sd = {} },
                        [200] = { dn = "Old", type = "Notable", sd = {} },
                        [300] = { dn = "New", type = "Notable", sd = {} },
                    },
                    CreateUndoState = function()
                        return { hashList = { 100, 200 }, masteryEffects = {} }
                    end,
                    RestoreUndoState = function() end,
                    ImportFromNodeList = function(_, _, _, _, nodes, _, masteryEffects)
                        local alloc = {}
                        for _, nodeId in ipairs(nodes or {}) do
                            alloc[nodeId] = true
                        end
                        service._allocNodes = alloc
                        service._masteryEffects = masteryEffects or {}
                    end,
                },
                calcsTab = {
                    mainOutput = { Life = 100 },
                },
                treeTab = {
                    activeSpec = 1,
                    SetActiveSpec = function() end,
                },
            }
        end,
        rebuild_output = function(_, build)
            local alloc = service._allocNodes or build.spec.allocNodes
            build.spec.allocNodes = alloc
            build.spec.masterySelections = service._masteryEffects or { [900] = 901 }
            build.calcsTab.mainOutput = { Life = 120 }
            return build.calcsTab.mainOutput
        end,
    }
    service.pob = {
        refresh_active_spec = function() end,
    }

    local resolved, err = service:simulate_node_delta({ addNodes = { 300 } }, { "Life" })
    expect(resolved ~= nil and err == nil, "expected simulate_node_delta to succeed")
    expect(resolved.kind == "tree", "expected simulation kind")
    expect(
        resolved.comparison.delta.Life == resolved.delta.Life,
        "expected comparison payload to be preserved"
    )
    expect(
        resolved.compareFields[1] == "Life",
        "expected top-level compare fields to remain intact"
    )
    expect(resolved.tree.addedNodes[1] == 300, "expected addedNodes to be backfilled")
    expect(#resolved.tree.removedNodes == 0, "expected no removed nodes")
    expect(#resolved.tree.changedMasteryEffects == 0, "expected no mastery diff")
end
