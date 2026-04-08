-- Adapter that centralizes direct access to PoB importer controls and state.
local M = {}
M.__index = M

local function isNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

function M.new()
    return setmetatable({}, M)
end

function M:get_import_tab(build)
    return build.importTab
end

function M:configure_reset_flags(importTab)
    -- Import flows expect these clear flags before replacing tree, items, and skills state.
    local controls = importTab.controls or {}
    if controls.charImportTreeClearJewels then
        controls.charImportTreeClearJewels.state = true
    end
    if controls.charImportItemsClearItems then
        controls.charImportItemsClearItems.state = true
    end
    if controls.charImportItemsClearSkills then
        controls.charImportItemsClearSkills.state = true
    end
end

function M:has_remote_import_hashes(importTab)
    -- Remote update needs both hashes because PoB uses them to verify the imported account/character pair.
    return isNonEmptyString(importTab.lastAccountHash)
        and isNonEmptyString(importTab.lastCharacterHash)
end

function M:get_account_name(importTab)
    return importTab.controls
            and importTab.controls.accountName
            and importTab.controls.accountName.buf
        or nil
end

function M:get_import_mode(importTab)
    return importTab.charImportMode
end

function M:download_character_list(importTab)
    return pcall(importTab.DownloadCharacterList, importTab)
end

function M:download_passive_tree(importTab)
    return pcall(importTab.DownloadPassiveTree, importTab)
end

function M:download_items(importTab)
    return pcall(importTab.DownloadItems, importTab)
end

function M:get_selected_character(importTab)
    -- Character selection is nested under importer controls; hide that control shape from repo callers.
    local charSelect = importTab.controls and importTab.controls.charSelect or nil
    local selectedEntry = charSelect and charSelect.list and charSelect.list[charSelect.selIndex]
        or nil
    return selectedEntry and selectedEntry.char or nil
end

function M:import_offline_payload(importTab, params)
    -- Offline import still uses upstream PoB behavior; the adapter only centralizes the call boundary.
    importTab:ImportPassiveTreeAndJewels(params.passiveTreeJson, params.character)
    importTab:ImportItemsAndSkills(params.itemsJson)
end

return M
