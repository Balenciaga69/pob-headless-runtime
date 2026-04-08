-- Context resolver that turns arg[0] into concrete paths.
local packagePathUtil = require("util.package_path")
local pathUtil = require("util.path")

local M = {}

-- Derive repo structure from entry script location, adding entry/runtime/compatibility layer info.
function M.fromArg0(arg0)
    -- Derive repo and module locations from the entry script path.
    local wrapperPath = pathUtil.normalize(arg0 or "headless_bridge.lua")
    -- Use the platform separator consistently for every derived path.
    local pathSeparator = pathUtil.getPathSeparator()
    local toolDir = pathUtil.dirname(wrapperPath)
    local repoRoot = pathUtil.dirname(toolDir)

    -- Detect the older nested layout and skip the custom layer when it is present.
    if toolDir:match("[/\\]custom[/\\][^/\\]+$") then
        repoRoot = pathUtil.dirname(repoRoot)
    end

    -- These directories are the main roots used by the headless runtime.
    local sourceDir = pathUtil.join(repoRoot, "src")
    local runtimeDir = pathUtil.join(repoRoot, "runtime")
    local luaDir = pathUtil.join(toolDir, "src")

    return {
        pathSeparator = pathSeparator,
        toolDir = toolDir,
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
    -- Source files live under the repo's src directory.
    return pathUtil.join(context.sourceDir, fileName)
end

-- Resolve files under the tool module root.
function M.resolveLuaPath(context, fileName)
    -- Resolve a file under the local Lua module tree unless already absolute.
    if pathUtil.isAbsolute(fileName) then
        return fileName
    end
    -- Local helper modules are rooted under the tool's src directory.
    return pathUtil.join(context.luaDir, fileName)
end

-- Resolve files under the compatibility directory, isolating GUI/runtime dependent shims.
function M.resolveCompatibilityPath(context, fileName)
    -- Resolve a file under the compatibility shim directory unless already absolute.
    if pathUtil.isAbsolute(fileName) then
        return fileName
    end
    -- Compatibility shims stay separate from the primary source tree.
    return pathUtil.join(context.compatibilityDir, fileName)
end

-- Add module search paths needed by headless runtime.
function M.ensurePackagePaths(context)
    -- Prepend the local module roots to package.path once.
    -- Order matters: the tool-local modules should win over bundled defaults.
    packagePathUtil.prependLuaModuleDir(context.luaDir)
    packagePathUtil.prependLuaModuleDir(context.runtimeLuaDir)
end

return M
