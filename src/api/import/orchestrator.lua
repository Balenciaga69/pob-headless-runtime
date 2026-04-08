-- Import orchestrator that chooses the safest import path.
local M = {}
M.__index = M

local function isNonEmptyString(value)
    -- Treat only non-empty strings as valid scalar identifiers.
    return type(value) == "string" and value ~= ""
end

function M.new(repos, services)
    return setmetatable({
        runtime = repos.runtime,
        skills = services.skills,
        pob = require("api.import.pob").new(),
    }, M)
end

function M:normalize_offline_import_params(params)
    -- Validate the minimal offline-import payload shape.
    if type(params) ~= "table" then
        return nil, "import params must be a table"
    end
    if params.passiveTreeJson == nil and params.itemsJson == nil and params.character == nil then
        return nil, nil
    end
    if type(params.character) ~= "table" then
        return nil, "character is required"
    end
    if type(params.passiveTreeJson) ~= "string" or params.passiveTreeJson == "" then
        return nil, "passiveTreeJson is required"
    end
    if type(params.itemsJson) ~= "string" or params.itemsJson == "" then
        return nil, "itemsJson is required"
    end
    if not isNonEmptyString(params.character.name) then
        return nil, "character.name is required"
    end
    if not isNonEmptyString(params.character.class) then
        return nil, "character.class is required"
    end
    if tonumber(params.character.level) == nil then
        return nil, "character.level is required"
    end
    if not isNonEmptyString(params.character.league) then
        return nil, "character.league is required"
    end
    return params
end

function M:ensure_importer_ready()
    -- Make sure the import tab is available before starting an import flow.
    local build, err =
        self.runtime:ensure_build_ready({ "importTab" }, "build/import not initialized")
    if not build then
        return nil, err
    end
    return build, self.pob:get_import_tab(build)
end

function M:wait_for_importer_idle(importTab, expectedMode, errorMessage)
    -- Wait until the importer exits the importing state and reaches the expected mode.
    local status, err = self.runtime:run_until_settled({
        maxFrames = 200,
        maxSeconds = 15,
        ["until"] = function()
            return importTab.charImportMode ~= "IMPORTING"
        end,
    })
    if not status then
        return nil, errorMessage .. ": " .. tostring(err)
    end
    if importTab.charImportMode ~= expectedMode then
        return nil, errorMessage
    end
    return true
end

function M:execute_offline_import(params)
    -- Import a build from offline JSON payloads.
    local build, importTabOrErr = self:ensure_importer_ready()
    if not build then
        return nil, importTabOrErr
    end
    local importTab = importTabOrErr
    if not importTab.ImportPassiveTreeAndJewels or not importTab.ImportItemsAndSkills then
        return nil, "build/import not initialized"
    end

    self.pob:configure_reset_flags(importTab)
    self.pob:import_offline_payload(importTab, params)
    self.runtime:rebuild_imported_build(build)
    self.runtime:run_frames_if_idle(1)
    return { build = build, importMode = "offline_payload" }
end

function M:execute_remote_import()
    -- Pull updated data from PoB's remote importer flow.
    local build, importTabOrErr = self:ensure_importer_ready()
    if not build then
        return nil, importTabOrErr
    end
    local importTab = importTabOrErr

    if not self.pob:has_remote_import_hashes(importTab) then
        return nil,
            "Update failed: Character must be imported in PoB before it can be automatically updated"
    end
    local accountName = self.pob:get_account_name(importTab)
    if type(accountName) ~= "string" or accountName == "" then
        return nil,
            "Update failed: Account name must be set within PoB before it can be automatically updated"
    end
    if self.pob:get_import_mode(importTab) ~= "GETACCOUNTNAME" then
        return nil, "Update failed: Unknown import error - is PoB importing set up correctly?"
    end
    if not common or not common.sha1 then
        return nil, "Update failed: importer hashing support is unavailable"
    end
    if common.sha1(accountName) ~= importTab.lastAccountHash then
        return nil,
            "Update failed: Build comes from an account that is not configired in PoB - character must be imported in PoB before it can be automatically updated"
    end
    if self.runtime:is_inside_callback() then
        return nil, "Update failed: remote importer update cannot run inside callbacks"
    end

    local ok, downloadErr = self.pob:download_character_list(importTab)
    if not ok then
        return nil, "Update failed: " .. tostring(downloadErr)
    end
    local _, listErr = self:wait_for_importer_idle(
        importTab,
        "SELECTCHAR",
        "Update failed: Import not fully set up on this build"
    )
    if listErr then
        return nil, listErr
    end

    local selectedChar = self.pob:get_selected_character(importTab)
    if not selectedChar or common.sha1(selectedChar.name) ~= importTab.lastCharacterHash then
        return nil, "Update failed: Selected character not found - was it deleted or renamed?"
    end

    self.pob:configure_reset_flags(importTab)
    local passiveOk, passiveErr = self.pob:download_passive_tree(importTab)
    if not passiveOk then
        return nil, "Update failed: " .. tostring(passiveErr)
    end
    local _, treeErr = self:wait_for_importer_idle(
        importTab,
        "SELECTCHAR",
        "Update failed: Unable to download the passive tree"
    )
    if treeErr then
        return nil, treeErr
    end

    local itemsOk, itemsErr = self.pob:download_items(importTab)
    if not itemsOk then
        return nil, "Update failed: " .. tostring(itemsErr)
    end
    local _, itemErr = self:wait_for_importer_idle(
        importTab,
        "SELECTCHAR",
        "Update failed: Unable to download items and skills"
    )
    if itemErr then
        return nil, itemErr
    end

    self.runtime:rebuild_imported_build(build)
    self.runtime:run_frames_if_idle(1)
    return { build = build, importMode = "remote_import" }
end

function M:update_imported_build(params)
    -- Pick the correct import path, then restore selection state afterward.
    local offlineParams, offlineErr = self:normalize_offline_import_params(params or {})
    if offlineErr then
        return nil, offlineErr
    end

    local selectedSkillSnapshot = self.skills:get_selected_skill()
    local result, err
    if offlineParams then
        result, err = self:execute_offline_import(offlineParams)
    else
        result, err = self:execute_remote_import()
    end
    if not result then
        return nil, err
    end

    local restoredSkill, restoreErr = self.skills:restore_skill_selection(selectedSkillSnapshot)
    if restoreErr and selectedSkillSnapshot then
        return nil, restoreErr
    end
    self.runtime:rebuild_imported_build(result.build)
    self.runtime:run_frames_if_idle(1)

    return {
        updated = true,
        importMode = result.importMode,
        restoredSkillSelection = restoredSkill ~= nil,
        skillSelection = restoredSkill or self.skills:get_selected_skill(),
    }
end

return M
