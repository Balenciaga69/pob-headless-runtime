local simulationUtil = require("util.simulation")
local expect = require("testkit").expect

do
    local compared = {
        fields = { "Life", "FireResist" },
        before = { Life = 100 },
        after = { Life = 120, FireResist = 30 },
        delta = { Life = 20, FireResist = 30 },
        changedFields = { "Life", "FireResist" },
        _meta = {
            before = { buildName = "Before" },
            after = { buildName = "After" },
        },
    }

    local result = simulationUtil.buildResult("tree", compared, {
        restored = true,
        simulationMode = "snapshot_restore",
        tree = {
            addedNodes = { 12345 },
            removedNodes = { 67890 },
        },
    })

    expect(result.kind == "tree", "expected simulation kind")
    expect(result.compareFields[1] == "Life", "expected compareFields to mirror compared fields")
    expect(result.before.Life == 100, "expected before payload to be hoisted")
    expect(result.after.FireResist == 30, "expected after payload to be hoisted")
    expect(result.delta.Life == 20, "expected delta payload to be hoisted")
    expect(result.changedFields[2] == "FireResist", "expected changedFields to be hoisted")
    expect(result.restored == true, "expected restored flag")
    expect(result.simulationMode == "snapshot_restore", "expected simulationMode")
    expect(result.comparison == compared, "expected original comparison payload to be preserved")
    expect(result.tree.addedNodes[1] == 12345, "expected extra payload to be merged")
    expect(result._meta.after.buildName == "After", "expected meta to be hoisted")
end
