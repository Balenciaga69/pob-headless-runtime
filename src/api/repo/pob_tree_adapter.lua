-- Adapter that centralizes tree-tab refresh behavior after tree mutations.
local M = {}
M.__index = M

function M.new()
	return setmetatable({}, M)
end

function M:refresh_active_spec(build)
	-- Tree mutations must refresh the active spec so PoB updates tree-tab dependent state consistently.
	if build.treeTab and build.treeTab.SetActiveSpec then
		build.treeTab:SetActiveSpec(build.treeTab.activeSpec or 1)
	end
end

return M
