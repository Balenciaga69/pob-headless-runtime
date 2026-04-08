-- Parse item text into PoB item objects.
local M = {}

local MAX_ITEM_TEXT_LENGTH = 10240

function M.summarizeItem(item)
    if not item then
        return nil
    end

    return {
        id = item.id,
        name = item.name,
        title = item.title,
        baseName = item.baseName,
        rarity = item.rarity,
        type = item.type,
        primarySlot = item.GetPrimarySlot and item:GetPrimarySlot() or nil,
        itemLevel = item.itemLevel,
        requiredLevel = item.requirements and item.requirements.level or nil,
        requiredStr = item.requirements and item.requirements.str or nil,
        requiredDex = item.requirements and item.requirements.dex or nil,
        requiredInt = item.requirements and item.requirements.int or nil,
        quality = item.quality,
        raw = item.BuildRaw and item:BuildRaw() or item.raw,
    }
end

local function createItemForBuild(build, itemText)
    if build and build.targetVersionData then
        return new("Item", build.targetVersion, itemText)
    end
    return new("Item", itemText)
end

function M.parseItemForBuild(build, itemText)
    if type(itemText) ~= "string" or itemText == "" then
        return nil, "itemText is required"
    end
    if #itemText > MAX_ITEM_TEXT_LENGTH then
        return nil, string.format("itemText exceeds %d bytes", MAX_ITEM_TEXT_LENGTH)
    end

    local ok, item = pcall(createItemForBuild, build, itemText)
    if not ok then
        return nil, "invalid item text: " .. tostring(item)
    end
    if not item or not item.base then
        return nil, "failed to parse item"
    end

    if item.NormaliseQuality then
        item:NormaliseQuality()
    end
    if item.BuildModList then
        item:BuildModList()
    end
    return item
end

function M.appendModLineToItemRaw(item, modLine)
    if type(modLine) ~= "string" or modLine == "" then
        return nil, "modLine is required"
    end

    local raw = item and ((item.BuildRaw and item:BuildRaw()) or item.raw) or nil
    if type(raw) ~= "string" or raw == "" then
        return nil, "equipped item does not expose raw text"
    end

    return raw .. "\n" .. modLine
end

return M
