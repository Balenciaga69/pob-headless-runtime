-- Build persistence adapter over the live PoB object graph.
local M = {}
local pob = require("api.repo.pob_build_adapter").new()

function M.loadBuildXml(session, xmlText, name)
	-- Load a build from XML text into the running session.
	if type(xmlText) ~= "string" or xmlText == "" then
		return nil, "xmlText is required"
	end

	local main = session:ensureMainReady()
	if not main then
		return nil, "main runtime is not ready"
	end

	main:SetMode("BUILD", false, name or "API Build", xmlText)
	session:runFramesIfIdle(1)
	local build = session:getBuild()
	if build then
		build.buildName = name or build.buildName or "API Build"
	end
	session.lastBuildPath = nil
	return build
end

function M.loadBuildFile(session, path, readAll)
	-- Load a build from a file path using the shared file reader.
	if type(path) ~= "string" or path == "" then
		return nil, "path is required"
	end

	local xmlText, err = readAll(path, "build file")
	if not xmlText then
		return nil, err
	end

	local build, loadErr = M.loadBuildXml(session, xmlText, path:match("([^/\\]+)%.xml$") or path)
	if not build then
		return nil, loadErr
	end

	build.buildName = path:match("([^/\\]+)%.xml$") or build.buildName
	session.lastBuildPath = path
	return build
end

function M.saveBuildXml(session)
	-- Serialize the active build to XML text.
	local build = session:getBuild()
	if not build or not build.SaveDB then
		return nil, "build not initialized"
	end

	pob:prepare_for_save(build)
	local xmlText = build:SaveDB("headless-api-export")
	if not xmlText then
		return nil, "failed to compose xml"
	end

	return xmlText
end

function M.saveBuildFile(session, path, writeAll)
	-- Serialize the active build and write it to disk.
	local build = session:getBuild()
	if not build or not build.SaveDB then
		return nil, "build not initialized"
	end

	local targetPath = path or session.lastBuildPath or build.dbFileName
	if type(targetPath) ~= "string" or targetPath == "" then
		return nil, "path is required"
	end

	local xmlText, err = M.saveBuildXml(session)
	if not xmlText then
		return nil, err
	end

	local result, writeErr = writeAll(targetPath, xmlText, "build file")
	if not result then
		return nil, writeErr
	end

	build.buildName = targetPath:match("([^/\\]+)%.xml$") or build.buildName
	session.lastBuildPath = targetPath
	return result
end

return M
