-- Adapter that centralizes direct access to PoB build/skills/spec save-time state.
local M = {}
M.__index = M

function M.new()
	return setmetatable({
		skills = require("api.repo.pob_skills_adapter").new(),
	}, M)
end

function M:prepare_for_save(build)
	if not build then
		return
	end

	if build.spec and build.spec.curClass and build.spec.curClass.classes then
		local ascendId = build.spec.curAscendClassId or 0
		local ascendClass = build.spec.curClass.classes[ascendId] or build.spec.curClass.classes[0]
		if ascendClass and ascendClass.name then
			build.spec.curAscendClassName = ascendClass.name
		end
	end

	self.skills:process_socket_groups(build)
end

return M
