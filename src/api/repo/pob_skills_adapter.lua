-- Adapter that centralizes direct access to PoB skills/calcs tabs.
local M = {}
M.__index = M

function M.new()
	return setmetatable({}, M)
end

function M:get_socket_groups(build)
	return build.skillsTab and build.skillsTab.socketGroupList or {}
end

function M:get_group(build, groupIndex)
	local groups = self:get_socket_groups(build)
	return groups and groups[groupIndex] or nil
end

function M:get_selected_group_index(build)
	return build.mainSocketGroup
end

function M:set_selected_group_index(build, groupIndex)
	build.mainSocketGroup = groupIndex
end

function M:get_calcs_input(build)
	local input = build.calcsTab.input or {}
	build.calcsTab.input = input
	return input
end

function M:get_calcs_skill_number(build)
	local input = build.calcsTab and build.calcsTab.input or nil
	return input and input.skill_number or nil
end

function M:set_calcs_skill_number(build, groupIndex)
	local input = self:get_calcs_input(build)
	input.skill_number = groupIndex
	return input
end

function M:process_socket_groups(build)
	if build.skillsTab and build.skillsTab.socketGroupList and build.skillsTab.ProcessSocketGroup then
		for _, socketGroup in ipairs(build.skillsTab.socketGroupList) do
			build.skillsTab:ProcessSocketGroup(socketGroup)
		end
	end
end

return M
