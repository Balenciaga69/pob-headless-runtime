-- Item mutation adapter split across parsing and slot resolution.
local parser = require("api.repo.items.parser")
local slotResolver = require("api.repo.items.slot_resolver")

local M = {}
M.__index = M

local function buildItemTooltipCollector()
	return {
		lines = {},
		separators = 0,
		Clear = function(self)
			self.lines = {}
			self.separators = 0
		end,
		AddLine = function(self, _, text)
			self.lines[#self.lines + 1] = {
				kind = "line",
				text = text,
				plainText = _G.StripEscapes and _G.StripEscapes(text or "") or (text or ""),
			}
		end,
		AddSeparator = function(self)
			self.separators = self.separators + 1
			self.lines[#self.lines + 1] = {
				kind = "separator",
				text = "--------",
				plainText = "--------",
			}
		end,
	}
end

function M.new(runtimeRepo)
	return setmetatable({
		runtime = runtimeRepo,
		pob = require("api.repo.pob_items_adapter").new(),
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
	return item, build
end

function M:summarize_item(item)
	return parser.summarizeItem(item)
end

function M:render_tooltip(itemText, requestedSlot)
	local item, buildOrErr = self:parse_item(itemText)
	if not item then
		return nil, buildOrErr
	end
	local build = buildOrErr

	local normalizedSlot, slotErr = slotResolver.normalizeRequestedSlot(requestedSlot)
	if slotErr then
		return nil, slotErr
	end

	local collector = buildItemTooltipCollector()
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

	return {
		item = item,
		itemSummary = parser.summarizeItem(item),
		slot = slotResolver.summarizeSlot(slotName, slot, normalizedSlot),
		lines = collector.lines,
		separatorCount = collector.separators,
	}
end

function M:simulate_outputs(itemText, requestedSlot)
	local build, err = self.runtime:ensure_build_ready({ "itemsTab", "calcsTab" }, "items not initialized")
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

function M:append_mod_line(item, modLine)
	return parser.appendModLineToItemRaw(item, modLine)
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

function M:equip_item(itemText, requestedSlot)
	local build, err = self.runtime:ensure_build_ready({ "itemsTab", "calcsTab" }, "items not initialized")
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

return M
