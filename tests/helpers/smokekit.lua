local M = {}

local function fileExists(path)
	local handle = io.open(path, "rb")
	if handle then
		handle:close()
		return true
	end
	return false
end

function M.requireXmlArg()
	local xmlPath = arg and arg[1]
	if not xmlPath or xmlPath == "" then
		print("Missing build XML path.")
		os.exit(1)
	end
	return xmlPath
end

function M.resolveFixturePath(relativePath)
	local candidates = {
		"../pob-headless-runtime/tests/fixtures/" .. relativePath,
		"../custom/pob-headless-runtime/tests/fixtures/" .. relativePath,
		"tests/fixtures/" .. relativePath,
		"pob-headless-runtime/tests/fixtures/" .. relativePath,
		"custom/pob-headless-runtime/tests/fixtures/" .. relativePath,
	}
	for _, path in ipairs(candidates) do
		if fileExists(path) then
			return path
		end
	end
	error("fixture not found: " .. relativePath, 0)
end

function M.readFixture(relativePath)
	local path = M.resolveFixturePath(relativePath)
	local handle, err = io.open(path, "rb")
	if not handle then
		error("failed to read fixture: " .. tostring(err), 0)
	end
	local text = handle:read("*a")
	handle:close()
	return text
end

function M.runQueuedSmoke(api, xmlPath, run)
	local testkit = require("testkit")
	local flow = testkit.newQueuedBuildFlow(api, xmlPath)

	api.queue(function()
		if not flow.load() then
			return false
		end

		local summary, ready = flow.summary()
		if not ready then
			return false
		end

		if run(flow, summary) then
			api.stop()
			return true
		end

		return false
	end)
end

return M
