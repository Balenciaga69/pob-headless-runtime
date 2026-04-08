-- Item service that coordinates parse, simulate, compare, and equip flows.
local simulationUtil = require("util.simulation")
local statsCompareUtil = require("util.stats_compare")
local tableUtil = require("util.table")

local M = {}
M.__index = M

local DEFAULT_ITEM_COMPARE_FIELDS = {
    "TotalDPS",
    "CombinedDPS",
    "Life",
    "EnergyShield",
    "Mana",
    "Armour",
    "Evasion",
    "FireResist",
    "ColdResist",
    "LightningResist",
    "ChaosResist",
    "SpellSuppressionChance",
    "BlockChance",
    "SpellBlockChance",
}

function M.new(repos, services)
    return setmetatable({
        repos = repos,
        services = services,
    }, M)
end

function M:parse_item(itemText)
    local item, buildOrErr = self.repos.items:parse_item(itemText)
    if not item then
        return nil, buildOrErr
    end
    return self.repos.items:summarize_item(item)
end

function M:render_item_tooltip(itemText, slot)
    local rendered, err = self.repos.items:render_tooltip(itemText, slot)
    if not rendered then
        return nil, err
    end
    local plainLines = {}
    for _, line in ipairs(rendered.lines) do
        plainLines[#plainLines + 1] = line.plainText
    end
    return {
        item = rendered.itemSummary,
        slot = rendered.slot,
        lines = rendered.lines,
        plainLines = plainLines,
        separatorCount = rendered.separatorCount,
        text = table.concat(plainLines, "\n"),
    }
end

function M:test_item(itemText, slot)
    local simulation, err = self.repos.items:simulate_outputs(itemText, slot)
    if not simulation then
        return nil, err
    end
    return {
        slot = simulation.slotSummary,
        currentItem = simulation.equippedItemSummary,
        testedItem = simulation.itemSummary,
        compareFields = tableUtil.copyArray(DEFAULT_ITEM_COMPARE_FIELDS),
        stats = self.services.stats:pick_fields(simulation.newOutput, DEFAULT_ITEM_COMPARE_FIELDS),
        delta = statsCompareUtil.numericDelta(
            simulation.baseOutput,
            simulation.newOutput,
            DEFAULT_ITEM_COMPARE_FIELDS
        ),
    }
end

function M:compare_item_stats(itemText, slot, fields)
    if fields ~= nil and type(fields) ~= "table" then
        return nil, "fields must be a table"
    end
    local simulation, err = self.repos.items:simulate_outputs(itemText, slot)
    if not simulation then
        return nil, err
    end

    local compareFields = fields or DEFAULT_ITEM_COMPARE_FIELDS
    local beforeStats = self.services.stats:pick_fields(simulation.baseOutput, compareFields)
    local afterStats = self.services.stats:pick_fields(simulation.newOutput, compareFields)
    beforeStats._meta = self.services.stats:build_meta(simulation.build)
    afterStats._meta = self.services.stats:build_meta(simulation.build)

    local compared, compareErr =
        self.services.stats:compare_stats(beforeStats, afterStats, compareFields)
    if not compared then
        return nil, compareErr
    end

    return simulationUtil.buildResult("item", compared, {
        restored = true,
        simulationMode = "calculator",
        slot = simulation.slotSummary,
        currentItem = simulation.equippedItemSummary,
        candidateItem = simulation.itemSummary,
    })
end

function M:simulate_mod(modLine, slot, fields)
    if type(modLine) ~= "string" or modLine == "" then
        return nil, "modLine is required"
    end
    if type(slot) ~= "string" or slot == "" then
        return nil, "slot is required"
    end
    if fields ~= nil and type(fields) ~= "table" then
        return nil, "fields must be a table"
    end
    local candidateRaw, equippedOrErr =
        self.repos.items:build_candidate_raw_with_appended_mod(slot, modLine)
    if not candidateRaw then
        return nil, equippedOrErr
    end
    local compared, compareErr = self:compare_item_stats(candidateRaw, slot, fields)
    if not compared then
        return nil, compareErr
    end
    return simulationUtil.buildResult("mod", compared.comparison, {
        restored = true,
        simulationMode = "calculator",
        slot = compared.slot,
        currentItem = equippedOrErr.itemSummary or compared.currentItem,
        candidateItem = compared.candidateItem,
        modLine = modLine,
    })
end

function M:equip_item(itemText, slot)
    return self.repos.items:equip_item(itemText, slot)
end

return M
