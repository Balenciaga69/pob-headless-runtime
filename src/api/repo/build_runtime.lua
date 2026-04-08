-- Low-level build lifecycle adapter for repo callers.
local accessUtil = require("util.access")
local M = {}
M.__index = M

local function hasRequiredTabs(build, requiredTabs)
	-- Verify that the build has every tab required by the caller.
	for _, tabName in ipairs(requiredTabs or {}) do
		if not build[tabName] then
			return false
		end
	end
	return true
end

function M.new(session)
	-- Bind the runtime adapter to a live session instance.
	return setmetatable({
		session = session,
	}, M)
end

function M:get_build()
	-- Return the current cached build object from the session.
	return self.session:getBuild()
end

function M:ensure_main_ready()
	-- Make sure the main object is ready before proceeding.
	return self.session:ensureMainReady()
end

function M:ensure_build_ready(requiredTabs, errorMessage)
	-- Make sure the build exists and exposes the requested tabs.
	local build = self:get_build()
	if not build then
		return nil, errorMessage or "build not initialized"
	end
	if not hasRequiredTabs(build, requiredTabs) then
		return nil, errorMessage or "build not initialized"
	end
	return build
end

function M:get_status()
	-- Return the current runtime readiness snapshot.
	return self.session:getStatus()
end

function M:run_frames_if_idle(frameCount)
	-- Advance frames only when the runtime is not inside callbacks.
	return self.session:runFramesIfIdle(frameCount)
end

function M:run_until_settled(options)
	-- Run the runtime until readiness or timeout criteria are met.
	return self.session:runUntilSettled(options)
end

function M:is_inside_callback()
	-- Report whether callback execution is already in progress.
	return self.session.isInsideCallback and self.session:isInsideCallback() or false
end

function M:rebuild_output(build)
	-- Force the calcs tab to rebuild its output and return the result.
	build = build or self:ensure_build_ready({ "calcsTab" }, "build not initialized")
	if not build then
		return nil, "build not initialized"
	end

	if build.calcsTab.BuildOutput then
		build.calcsTab:BuildOutput()
	end

	local output = build.calcsTab.mainOutput
	if not output then
		return nil, "no output available"
	end
	return output
end

function M:rebuild_config(build)
	-- Rebuild config state and then refresh the output snapshot.
	build = build or self:ensure_build_ready({ "configTab", "calcsTab" }, "build/config not initialized")
	if not build then
		return nil, "build/config not initialized"
	end

	if build.configTab.BuildModList then
		build.configTab:BuildModList()
	end
	return self:rebuild_output(build)
end

function M:rebuild_imported_build(build)
	-- Refresh the imported build after import-side mutations.
	build = build or self:ensure_build_ready({ "calcsTab" }, "build not initialized")
	if not build then
		return nil, "build not initialized"
	end

	build.outputRevision = (tonumber(build.outputRevision) or 0) + 1
	build.buildFlag = false
	self:rebuild_output(build)
	if build.RefreshStatList then
		build:RefreshStatList()
	end
	if build.RefreshSkillSelectControls then
		build:RefreshSkillSelectControls(build.controls, build.mainSocketGroup, "")
	end
	return true
end

function M:get_main_object_main()
	-- Expose the underlying main object for low-level adapters.
	return accessUtil.getMainObjectMain(self.session.callbacks and self.session.callbacks.mainObject or nil)
end

return M
