-- Import adapter that preserves runtime safety and state.
local M = {}
M.__index = M

local function isNonEmptyString(value)
	-- Treat only non-empty strings as usable import identifiers.
	return type(value) == "string" and value ~= ""
end

function M.new(runtimeRepo)
	-- Bind the import adapter to the runtime adapter.
	return setmetatable({
		runtime = runtimeRepo,
	}, M)
end

function M:ensure_importer_ready()
	-- Make sure the import tab is available before starting an import flow.
	local build, err = self.runtime:ensure_build_ready({ "importTab" }, "build/import not initialized")
	if not build then
		return nil, err
	end
	return build, build.importTab
end

function M:configure_import_reset_flags(importTab)
	-- Clear import-side flags that should be reset before import actions.
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

	self:configure_import_reset_flags(importTab)
	importTab:ImportPassiveTreeAndJewels(params.passiveTreeJson, params.character)
	importTab:ImportItemsAndSkills(params.itemsJson)
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

	if not isNonEmptyString(importTab.lastAccountHash) or not isNonEmptyString(importTab.lastCharacterHash) then
		return nil, "Update failed: Character must be imported in PoB before it can be automatically updated"
	end
	local accountName = importTab.controls and importTab.controls.accountName and importTab.controls.accountName.buf or nil
	if not isNonEmptyString(accountName) then
		return nil, "Update failed: Account name must be set within PoB before it can be automatically updated"
	end
	if importTab.charImportMode ~= "GETACCOUNTNAME" then
		return nil, "Update failed: Unknown import error - is PoB importing set up correctly?"
	end
	if not common or not common.sha1 then
		return nil, "Update failed: importer hashing support is unavailable"
	end
	if common.sha1(accountName) ~= importTab.lastAccountHash then
		return nil, "Update failed: Build comes from an account that is not configired in PoB - character must be imported in PoB before it can be automatically updated"
	end
	if self.runtime:is_inside_callback() then
		return nil, "Update failed: remote importer update cannot run inside callbacks"
	end

	local ok, downloadErr = pcall(importTab.DownloadCharacterList, importTab)
	if not ok then
		return nil, "Update failed: " .. tostring(downloadErr)
	end
	local _, listErr = self:wait_for_importer_idle(importTab, "SELECTCHAR", "Update failed: Import not fully set up on this build")
	if listErr then
		return nil, listErr
	end

	local charSelect = importTab.controls and importTab.controls.charSelect or nil
	local selectedEntry = charSelect and charSelect.list and charSelect.list[charSelect.selIndex] or nil
	local selectedChar = selectedEntry and selectedEntry.char or nil
	if not selectedChar or common.sha1(selectedChar.name) ~= importTab.lastCharacterHash then
		return nil, "Update failed: Selected character not found - was it deleted or renamed?"
	end

	self:configure_import_reset_flags(importTab)
	local passiveOk, passiveErr = pcall(importTab.DownloadPassiveTree, importTab)
	if not passiveOk then
		return nil, "Update failed: " .. tostring(passiveErr)
	end
	local _, treeErr = self:wait_for_importer_idle(importTab, "SELECTCHAR", "Update failed: Unable to download the passive tree")
	if treeErr then
		return nil, treeErr
	end

	local itemsOk, itemsErr = pcall(importTab.DownloadItems, importTab)
	if not itemsOk then
		return nil, "Update failed: " .. tostring(itemsErr)
	end
	local _, itemErr = self:wait_for_importer_idle(importTab, "SELECTCHAR", "Update failed: Unable to download items and skills")
	if itemErr then
		return nil, itemErr
	end

	self.runtime:rebuild_imported_build(build)
	self.runtime:run_frames_if_idle(1)
	return { build = build, importMode = "remote_import" }
end

return M
