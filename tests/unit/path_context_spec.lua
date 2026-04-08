local entryContextModule = require("entry.context")
local entryBootstrapModule = require("entry.bootstrap")
local packagePathUtil = require("util.package_path")
local pathUtil = require("util.path")
local expect = require("testkit").expect

do
	local normalized = pathUtil.normalize("g:/repo/custom/pob_headless_refactor/headless_bridge.lua")
	expect(pathUtil.isAbsolute(normalized) == true, "expected normalized Windows path to be absolute")
	expect(pathUtil.dirname(normalized):match("pob_headless_refactor$") ~= nil, "expected dirname to keep tool directory")

	local joined = pathUtil.join("g:/repo", "custom", "pob_headless_refactor", "lua")
	expect(joined:match("custom") ~= nil and joined:match("lua$") ~= nil, "expected join to concatenate path segments")
end

do
	local context = entryContextModule.fromArg0("g:/repo/custom/pob_headless_refactor/headless_bridge.lua")
	expect(context.repoRoot:match("repo$") ~= nil, "expected repoRoot to be derived from arg0")
	expect(context.luaDir:match("src$") ~= nil, "expected luaDir to point at the src root")
	expect(context.entryDir:match("src[/\\]entry$") ~= nil, "expected entryDir to point at entry namespace")
	expect(context.runtimeModuleDir:match("src[/\\]runtime$") ~= nil, "expected runtimeModuleDir to point at runtime namespace")
	expect(context.compatibilityDir:match("src[/\\]compatibility$") ~= nil, "expected compatibilityDir to point at compatibility namespace")
	expect(context.currentWorkDir == context.sourceDir, "expected currentWorkDir to default to sourceDir")
	expect(
		entryContextModule.resolveCompatibilityPath(context, "lua-utf8.lua"):match("compatibility[/\\]lua%-utf8.lua$") ~= nil,
		"expected compatibility resolver to isolate shim path"
	)
end

do
	local context = entryContextModule.fromArg0("g:/repo/pob_headless_refactor/headless_bridge.lua")
	expect(context.repoRoot:match("g:[/\\]repo$") ~= nil, "expected repoRoot to work without custom nesting")
	expect(context.sourceDir:match("g:[/\\]repo[/\\]src$") ~= nil, "expected sourceDir to point at repo src root")
end

do
	local originalPath = package.path
	local fakeDir = pathUtil.join("g:/repo", "custom", "pob_headless_refactor", "src")

	package.path = ""
	packagePathUtil.prependLuaModuleDir(fakeDir)
	local once = package.path
	packagePathUtil.prependLuaModuleDir(fakeDir)
	local twice = package.path

	expect(once == twice, "expected prependLuaModuleDir to avoid duplicate entries")
	package.path = originalPath
end
