-- Resolve requested slots against PoB slot rules.
local M = {}

function M.normalizeRequestedSlot(requestedSlot)
	if requestedSlot == nil then
		return nil
	end
	if type(requestedSlot) ~= "string" then
		return nil, "slot must be a string"
	end
	if requestedSlot == "" then
		return nil, "slot must not be empty"
	end
	return requestedSlot
end

function M.summarizeSlot(slotName, slot, requestedSlot)
	return {
		requested = requestedSlot,
		resolved = slotName,
		label = slot and slot.label or nil,
		slotNum = slot and slot.slotNum or nil,
		nodeId = slot and slot.nodeId or nil,
		autoResolved = requestedSlot == nil and slotName ~= nil,
	}
end

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

local function findAutoResolvedSlot(build, item)
	local itemsTab = build and build.itemsTab
	if not itemsTab or not item then
		return nil, "items not initialized"
	end

	local preferredSlotName = item.GetPrimarySlot and item:GetPrimarySlot() or nil
	if type(preferredSlotName) == "string" and preferredSlotName ~= "" then
		local preferredSlot = itemsTab.slots and itemsTab.slots[preferredSlotName] or nil
		if preferredSlot and itemsTab.IsItemValidForSlot and itemsTab:IsItemValidForSlot(item, preferredSlotName) then
			return preferredSlotName, preferredSlot
		end
	end

	local firstValidSlotName, firstValidSlot = nil, nil
	for _, slot in ipairs(itemsTab.orderedSlots or {}) do
		if slot and slot.slotName and isSlotShown(slot) and itemsTab:IsItemValidForSlot(item, slot.slotName) then
			if slot.selItemId == 0 then
				return slot.slotName, slot
			end
			if not firstValidSlotName then
				firstValidSlotName = slot.slotName
				firstValidSlot = slot
			end
		end
	end

	if firstValidSlotName then
		return firstValidSlotName, firstValidSlot
	end
	return nil, "unable to resolve item slot"
end

function M.resolveSlot(build, item, requestedSlot)
	local itemsTab = build and build.itemsTab
	if not itemsTab or not item then
		return nil, "items not initialized"
	end

	if requestedSlot == nil then
		return findAutoResolvedSlot(build, item)
	end

	local slotName = requestedSlot
	if type(slotName) ~= "string" or slotName == "" then
		return nil, "unable to resolve item slot"
	end
	if not itemsTab.slots or not itemsTab.slots[slotName] then
		return nil, "invalid item slot"
	end
	if itemsTab.IsItemValidForSlot and not itemsTab:IsItemValidForSlot(item, slotName) then
		return nil, "item cannot be equipped in slot " .. tostring(slotName)
	end

	return slotName, itemsTab.slots[slotName]
end

return M
