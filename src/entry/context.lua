-- Context resolver that turns arg[0] into concrete paths.
local packagePathUtil = require("util.package_path")
local pathUtil = require("util.path")

local M = {}

-- Derive repo structure from entry script location, adding entry/runtime/compatibility layer info.
function M.fromArg0(arg0)
    -- Derive repo and module locations from the entry script path.
    local wrapperPath = pathUtil.normalize(arg0 or "headless_bridge.lua")
    local pathSeparator = pathUtil.getPathSeparator()
    local toolDir = pathUtil.dirname(wrapperPath)
    local customDir = pathUtil.dirname(toolDir)
    local repoRoot = pathUtil.dirname(customDir)
    local sourceDir = pathUtil.join(repoRoot, "src")
    local runtimeDir = pathUtil.join(repoRoot, "runtime")
    local luaDir = pathUtil.join(toolDir, "src")

    return {
        pathSeparator = pathSeparator,
        toolDir = toolDir,
        customDir = customDir,
        repoRoot = repoRoot,
        sourceDir = sourceDir,
        runtimeDir = runtimeDir,
        luaDir = luaDir,
        runtimeLuaDir = pathUtil.join(runtimeDir, "lua"),
        entryDir = pathUtil.join(luaDir, "entry"),
        runtimeModuleDir = pathUtil.join(luaDir, "runtime"),
        compatibilityDir = pathUtil.join(luaDir, "compatibility"),
        currentWorkDir = sourceDir
    }
end

-- Resolve files under the source directory.
function M.resolveSourcePath(context, fileName)
    -- Resolve a file under the src tree unless the caller already passed an absolute path.
    if pathUtil.isAbsolute(fileName) then
        return fileName
    end
    return pathUtil.join(context.sourceDir, fileName)
end

-- Resolve files under the tool module root.
function M.resolveLuaPath(context, fileName)
    -- Resolve a file under the local Lua module tree unless already absolute.
    if pathUtil.isAbsolute(fileName) then
        return fileName
    end
    return pathUtil.join(context.luaDir, fileName)
end

-- Resolve files under the compatibility directory, isolating GUI/runtime dependent shims.
function M.resolveCompatibilityPath(context, fileName)
    -- Resolve a file under the compatibility shim directory unless already absolute.
    if pathUtil.isAbsolute(fileName) then
        return fileName
    end
    return pathUtil.join(context.compatibilityDir, fileName)
end

-- Add module search paths needed by headless runtime.
function M.ensurePackagePaths(context)
    -- Prepend the local module roots to package.path once.
    packagePathUtil.prependLuaModuleDir(context.luaDir)
    packagePathUtil.prependLuaModuleDir(context.runtimeLuaDir)
end

return M
