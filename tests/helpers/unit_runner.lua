local function normalizePath(path)
	local separator = package.config:sub(1, 1)
	if separator == "\\" then
		return (path or ""):gsub("/", "\\")
	end
	return (path or ""):gsub("\\", "/")
end

local function dirname(path)
	return normalizePath(path):match("^(.*)[/\\][^/\\]+$") or "."
end

local function prependLuaPath(dir)
	local separator = package.config:sub(1, 1)
	local normalized = normalizePath(dir):gsub("[/\\]+$", "")
	local luaPattern = normalized .. separator .. "?.lua"
	local initPattern = normalized .. separator .. "?" .. separator .. "init.lua"

	if not package.path:find(luaPattern, 1, true) then
		package.path = luaPattern .. ";" .. package.path
	end
	if not package.path:find(initPattern, 1, true) then
		package.path = initPattern .. ";" .. package.path
	end
end

local function pathExists(path)
	local handle = io.open(path, "rb")
	if handle then
		handle:close()
		return true
	end
	return false
end

local testScript = arg[1]
if not testScript or testScript == "" then
	io.stderr:write("Missing unit test script path.\n")
	os.exit(1)
end

local runnerPath = (arg and arg[0]) or "unit_runner.lua"
local helpersDir = dirname(runnerPath)
local testsDir = dirname(helpersDir)
local toolRoot = dirname(testsDir)
local parentRoot = dirname(toolRoot)
local repoRoot = parentRoot

if not pathExists(repoRoot .. package.config:sub(1, 1) .. "src" .. package.config:sub(1, 1) .. "Launch.lua") then
	repoRoot = dirname(parentRoot)
end

prependLuaPath(toolRoot .. package.config:sub(1, 1) .. "src")
prependLuaPath(helpersDir)
prependLuaPath(toolRoot .. package.config:sub(1, 1) .. "src" .. package.config:sub(1, 1) .. "compatibility")
prependLuaPath(repoRoot .. package.config:sub(1, 1) .. "runtime" .. package.config:sub(1, 1) .. "lua")

table.remove(arg, 1)
local chunk, err = loadfile(testScript)
if not chunk then
	error("Failed to load unit test script: " .. tostring(err))
end

chunk()
