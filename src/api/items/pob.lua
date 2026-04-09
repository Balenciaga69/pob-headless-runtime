-- Adapter that centralizes direct access to PoB item/calcs/config tabs.
local M = {}
M.__index = M

function M.new()
    return setmetatable({}, M)
end

function M:render_tooltip(build, collector, item, slot)
    -- Tooltip rendering must call the live PoB items tab with its expected collector contract.
    return pcall(build.itemsTab.AddItemTooltip, build.itemsTab, collector, item, slot)
end

function M:get_misc_calculator(build)
    -- This is the supported PoB hook for temporary item replacement simulation.
    return build.calcsTab:GetMiscCalculator()
end

function M:get_item_by_slot(build, slotName)
    -- Slot and equipped-item lookup stay here so callers do not index itemsTab directly.
    local slot = build.itemsTab.slots and build.itemsTab.slots[slotName] or nil
    local equippedItem = slot and slot.selItemId and build.itemsTab.items[slot.selItemId] or nil
    return slot, equippedItem
end

function M:add_and_equip_item(build, item, slot)
    -- Equipping an item mutates several PoB tabs in lockstep; keep that sequence behind one adapter call.
    build.itemsTab:AddItem(item, true)
    slot:SetSelItemId(item.id)
    build.itemsTab:PopulateSlots()
    build.itemsTab:AddUndoState()
    build.buildFlag = true
    if build.configTab and build.configTab.BuildModList then
        build.configTab:BuildModList()
    end
    return build.itemsTab.items[item.id]
end

function M:get_ordered_slots(build)
    return build.itemsTab and build.itemsTab.orderedSlots or {}
end

function M:get_items(build)
    return build.itemsTab and build.itemsTab.items or {}
end

return M
