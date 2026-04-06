-- Import service that chooses the safest import path.
local M = {}
M.__index = M

local function isNonEmptyString(value)
	-- Treat only non-empty strings as valid scalar identifiers.
	return type(value) == "string" and value ~= ""
end

function M.new(repos, services)
	-- Keep the importer service as a dependency bundle only.
	return setmetatable({
		repos = repos,
		services = services,
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

function M:update_imported_build(params)
	-- Pick the correct import path, then restore selection state afterward.
	local offlineParams, offlineErr = self:normalize_offline_import_params(params or {})
	if offlineErr then
		return nil, offlineErr
	end

	local selectedSkillSnapshot = self.services.skills:get_selected_skill()
	local result, err
	if offlineParams then
		result, err = self.repos.importer:execute_offline_import(offlineParams)
	else
		result, err = self.repos.importer:execute_remote_import()
	end
	if not result then
		return nil, err
	end

	local restoredSkill, restoreErr = self.services.skills:restore_skill_selection(selectedSkillSnapshot)
	if restoreErr and selectedSkillSnapshot then
		return nil, restoreErr
	end
	self.repos.runtime:rebuild_imported_build(result.build)
	self.repos.runtime:run_frames_if_idle(1)

	return {
		updated = true,
		importMode = result.importMode,
		restoredSkillSelection = restoredSkill ~= nil,
		skillSelection = restoredSkill or self.services.skills:get_selected_skill(),
	}
end

return M
