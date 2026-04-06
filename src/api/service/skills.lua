-- Skill service that keeps selection and snapshots in sync.
local M = {}
M.__index = M

function M.new(repos)
	return setmetatable({
		repos = repos,
	}, M)
end

function M:list_skills()
	return self.repos.skills:list_skills()
end

function M:get_selected_skill()
	return self.repos.skills:get_selected_skill()
end

function M:select_skill(params)
	local result, err = self.repos.skills:apply_selection(params)
	if not result then
		return nil, err
	end
	self.repos.runtime:run_frames_if_idle(1)
	return self:list_skills()
end

function M:restore_skill_selection(snapshot)
	if type(snapshot) ~= "table" then
		return nil, "snapshot must be a table"
	end

	local groups, groupsErr = self:list_skills()
	if not groups then
		return nil, groupsErr
	end

	local requestedGroup = snapshot.group or {}
	local requestedSkill = snapshot.skill or {}
	local requestedPart = snapshot.part or {}

	local targetGroup = nil
	for _, candidate in ipairs(groups.groups or {}) do
		if tonumber(requestedGroup.index) == candidate.index then
			targetGroup = candidate
			break
		end
	end
	if targetGroup and requestedGroup.displayLabel and targetGroup.displayLabel ~= requestedGroup.displayLabel then
		targetGroup = nil
	end
	if not targetGroup and requestedGroup.displayLabel then
		for _, candidate in ipairs(groups.groups or {}) do
			if candidate.displayLabel == requestedGroup.displayLabel or candidate.label == requestedGroup.label then
				targetGroup = candidate
				break
			end
		end
	end
	if not targetGroup then
		for _, candidate in ipairs(groups.groups or {}) do
			if candidate.isSelected then
				targetGroup = candidate
				break
			end
		end
	end
	if not targetGroup then
		return nil, "unable to resolve skill group from snapshot"
	end

	local params = { group = targetGroup.index }
	local targetSkill = nil
	for _, candidate in ipairs(targetGroup.skills or {}) do
		if tonumber(requestedSkill.index) == candidate.index then
			targetSkill = candidate
			break
		end
	end
	if targetSkill and requestedSkill.name and targetSkill.name ~= requestedSkill.name then
		targetSkill = nil
	end
	if not targetSkill and requestedSkill.name then
		for _, candidate in ipairs(targetGroup.skills or {}) do
			if candidate.name == requestedSkill.name then
				targetSkill = candidate
				break
			end
		end
	end
	if targetSkill then
		params.skill = targetSkill.index
	end
	if targetSkill and requestedPart.index ~= nil then
		params.part = tonumber(requestedPart.index)
	end

	local _, applyErr = self.repos.skills:apply_selection(params)
	if applyErr then
		return nil, applyErr
	end
	self.repos.runtime:run_frames_if_idle(1)
	return self.repos.skills:get_selected_skill()
end

return M
