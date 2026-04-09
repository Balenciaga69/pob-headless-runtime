-- Item orchestrator that coordinates parse, simulate, compare, and equip flows.
local compareFields = require("api.items.helpers.compare_fields")
local parser = require("api.items.helpers.parser")
local slotResolver = require("api.items.helpers.slot_resolver")
local tooltipCollector = require("api.items.helpers.tooltip_collector")
local itemsPob = require("api.items.pob")
local simulationUtil = require("util.simulation")
local statsCompareUtil = require("util.stats_compare")
local tableUtil = require("util.table")

local M = {}
M.__index = M

local function isSlotShown(slot)
    if not slot then
        return false
    end
    if type(slot.IsShown) == "function" then
        return slot:IsShown()
    end
    if type(slot.shown) == "function" then
        return slot.shown()
    end
    return true
end

function M.new(repos, services)
    return setmetatable({
        runtime = repos.runtime,
        stats = services.stats,
        pob = itemsPob.new(),
    }, M)
end

function M:parse_item(itemText)
    local build, err = self.runtime:ensure_build_ready({ "itemsTab" }, "items not initialized")
    if not build then
        return nil, err
    end
    local item, parseErr = parser.parseItemForBuild(build, itemText)
    if not item then
        return nil, parseErr
    end
    return parser.summarizeItem(item)
end

function M:render_item_tooltip(itemText, requestedSlot)
    local build, err = self.runtime:ensure_build_ready({ "itemsTab" }, "items not initialized")
    if not build then
        return nil, err
    end

    local item, parseErr = parser.parseItemForBuild(build, itemText)
    if not item then
        return nil, parseErr
    end

    local normalizedSlot, slotErr = slotResolver.normalizeRequestedSlot(requestedSlot)
    if slotErr then
        return nil, slotErr
    end

    local collector = tooltipCollector.new()
    local slotName, slot = slotResolver.resolveSlot(build, item, normalizedSlot)
    if not slotName then
        if normalizedSlot ~= nil then
            return nil, slot
        end
        slot = nil
    end

    local ok, tooltipErr = self.pob:render_tooltip(build, collector, item, slot)
    if not ok then
        return nil, "failed to render item tooltip: " .. tostring(tooltipErr)
    end

    local plainLines = {}
    for _, line in ipairs(collector.lines) do
        plainLines[#plainLines + 1] = line.plainText
    end

    return {
        item = parser.summarizeItem(item),
        slot = slotResolver.summarizeSlot(slotName, slot, normalizedSlot),
        lines = collector.lines,
        plainLines = plainLines,
        separatorCount = collector.separators,
        text = table.concat(plainLines, "\n"),
    }
end

function M:simulate_outputs(itemText, requestedSlot)
    local build, err =
        self.runtime:ensure_build_ready({ "itemsTab", "calcsTab" }, "items not initialized")
    if not build then
        return nil, err
    end

    local item, parseErr = parser.parseItemForBuild(build, itemText)
    if not item then
        return nil, parseErr
    end

    local normalizedSlot, slotErr = slotResolver.normalizeRequestedSlot(requestedSlot)
    if slotErr then
        return nil, slotErr
    end

    local slotName, slot = slotResolver.resolveSlot(build, item, normalizedSlot)
    if not slotName then
        return nil, slot
    end

    local calcFunc, baseOutput = self.pob:get_misc_calculator(build)
    local newOutput = calcFunc({
        repSlotName = slotName,
        repItem = item,
    })
    local _, equippedItem = self.pob:get_item_by_slot(build, slotName)

    return {
        build = build,
        item = item,
        itemSummary = parser.summarizeItem(item),
        slotName = slotName,
        slot = slot,
        slotSummary = slotResolver.summarizeSlot(slotName, slot, normalizedSlot),
        requestedSlot = normalizedSlot,
        baseOutput = baseOutput,
        newOutput = newOutput,
        equippedItem = equippedItem,
        equippedItemSummary = parser.summarizeItem(equippedItem),
    }
end

function M:test_item(itemText, slot)
    local simulation, err = self:simulate_outputs(itemText, slot)
    if not simulation then
        return nil, err
    end
    return {
        slot = simulation.slotSummary,
        currentItem = simulation.equippedItemSummary,
        testedItem = simulation.itemSummary,
        compareFields = tableUtil.copyArray(compareFields),
        stats = self.stats:pick_fields(simulation.newOutput, compareFields),
        delta = statsCompareUtil.numericDelta(
            simulation.baseOutput,
            simulation.newOutput,
            compareFields
        ),
    }
end

function M:compare_item_stats(itemText, slot, fields)
    if fields ~= nil and type(fields) ~= "table" then
        return nil, "fields must be a table"
    end
    local simulation, err = self:simulate_outputs(itemText, slot)
    if not simulation then
        return nil, err
    end

    local selectedFields = fields or compareFields
    local beforeStats = self.stats:pick_fields(simulation.baseOutput, selectedFields)
    local afterStats = self.stats:pick_fields(simulation.newOutput, selectedFields)
    beforeStats._meta = self.stats:build_meta(simulation.build)
    afterStats._meta = self.stats:build_meta(simulation.build)

    local compared, compareErr = self.stats:compare_stats(beforeStats, afterStats, selectedFields)
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

function M:get_equipped_item(slotName)
    local build, err = self.runtime:ensure_build_ready({ "itemsTab" }, "items not initialized")
    if not build then
        return nil, err
    end
    if type(slotName) ~= "string" or slotName == "" then
        return nil, "invalid item slot"
    end
    local slot, equippedItem = self.pob:get_item_by_slot(build, slotName)
    if not slot then
        return nil, "invalid item slot"
    end
    if not equippedItem then
        return nil, "no item equipped in slot " .. tostring(slotName)
    end
    return {
        raw = equippedItem.raw or "",
        item = equippedItem,
        itemSummary = parser.summarizeItem(equippedItem),
    }
end

function M:build_candidate_raw_with_appended_mod(slotName, modLine)
    local equipped, err = self:get_equipped_item(slotName)
    if not equipped then
        return nil, err
    end
    return parser.appendModLineToItemRaw(equipped.item, modLine), equipped
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
    local candidateRaw, equippedOrErr = self:build_candidate_raw_with_appended_mod(slot, modLine)
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

function M:restore_preview_item(build, slot, previousItemId, previewItem)
    if previewItem then
        self.pob:delete_item(build, previewItem, true)
    end
    self.pob:set_slot_item(slot, previousItemId or 0)
    self.pob:refresh_item_state(build, true)
    local _, err = self.runtime:rebuild_output(build)
    if not err then
        self.runtime:run_frames_if_idle(1)
        return true
    end
    return nil, err
end

function M:preview_item_display_stats(itemText, requestedSlot)
    local simulation, err = self:simulate_outputs(itemText, requestedSlot)
    if not simulation then
        return nil, err
    end

    local previousItemId = simulation.slot and simulation.slot.selItemId or 0
    local previewItem = self.pob:add_item(simulation.build, simulation.item)
    self.pob:set_slot_item(simulation.slot, previewItem and previewItem.id or nil)
    self.pob:refresh_item_state(simulation.build, true)

    local ok, displayStatsOrErr = pcall(function()
        local _, outputErr = self.runtime:rebuild_output(simulation.build)
        if outputErr then
            error(outputErr)
        end
        self.runtime:run_frames_if_idle(1)
        return {
            _meta = self.stats:build_meta(simulation.build),
            entries = self.stats.displayStats:build_entries(simulation.build),
        }
    end)

    local restored, restoreErr =
        self:restore_preview_item(simulation.build, simulation.slot, previousItemId, previewItem)
    if not restored then
        return nil, restoreErr
    end
    if not ok then
        return nil, displayStatsOrErr
    end

    return {
        kind = "item",
        restored = true,
        simulationMode = "snapshot_restore",
        slot = simulation.slotSummary,
        currentItem = simulation.equippedItemSummary,
        candidateItem = simulation.itemSummary,
        displayStats = displayStatsOrErr,
    }
end

function M:equip_item(itemText, requestedSlot)
    local build, err =
        self.runtime:ensure_build_ready({ "itemsTab", "calcsTab" }, "items not initialized")
    if not build then
        return nil, err
    end

    local item, parseErr = parser.parseItemForBuild(build, itemText)
    if not item then
        return nil, parseErr
    end

    local normalizedSlot, slotErr = slotResolver.normalizeRequestedSlot(requestedSlot)
    if slotErr then
        return nil, slotErr
    end
    local slotName, slot = slotResolver.resolveSlot(build, item, normalizedSlot)
    if not slotName then
        return nil, slot
    end

    local _, previousItem = self.pob:get_item_by_slot(build, slotName)
    local equippedItem = self.pob:add_and_equip_item(build, item, slot)
    self.runtime:rebuild_output(build)
    self.runtime:run_frames_if_idle(1)

    return {
        slot = slotResolver.summarizeSlot(slotName, slot, normalizedSlot),
        previousItem = parser.summarizeItem(previousItem),
        item = parser.summarizeItem(equippedItem),
    }
end

function M:list_equipment()
    local build, err = self.runtime:ensure_build_ready({ "itemsTab" }, "items not initialized")
    if not build then
        return nil, err
    end

    local slots = {}
    for _, slot in ipairs(self.pob:get_ordered_slots(build)) do
        if slot and slot.slotName and isSlotShown(slot) then
            local _, equippedItem = self.pob:get_item_by_slot(build, slot.slotName)
            slots[#slots + 1] = {
                slot = slot.slotName,
                label = slot.label,
                item = parser.summarizeItem(equippedItem),
                raw = equippedItem and equippedItem.raw or nil,
            }
        end
    end

    return {
        slots = slots,
    }
end

function M:list_items()
    local build, err = self.runtime:ensure_build_ready({ "itemsTab" }, "items not initialized")
    if not build then
        return nil, err
    end

    local items = {}
    local itemIds = {}
    local itemsById = self.pob:get_items(build)
    for itemId, item in pairs(itemsById) do
        if item then
            itemIds[#itemIds + 1] = itemId
        end
    end

    table.sort(itemIds, function(left, right)
        if type(left) == "number" and type(right) == "number" then
            return left < right
        end
        return tostring(left) < tostring(right)
    end)

    for _, itemId in ipairs(itemIds) do
        local item = itemsById[itemId]
        items[#items + 1] = {
            id = itemId,
            item = parser.summarizeItem(item),
            raw = item and item.raw or nil,
        }
    end

    return {
        items = items,
    }
end

return M
