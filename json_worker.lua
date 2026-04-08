-- JSON stdin/stdout worker for the stable headless API surface.
-- Responsibilities:
-- - bootstrap local module paths
-- - prepare runtime environment
-- - read one JSON request from stdin
-- - start a session and settle runtime state
-- - dispatch the request and write one JSON response to stdout
-- Business logic lives under src/.
local function bootstrapLocalLuaPath()
    local wrapperPath = (arg and arg[0]) or "json_worker.lua"
    local pathSeparator = package.config:sub(1, 1)

    if pathSeparator == "\\" then
        wrapperPath = wrapperPath:gsub("/", "\\")
    else
        wrapperPath = wrapperPath:gsub("\\", "/")
    end

    local toolDir = wrapperPath:match("^(.*)[/\\][^/\\]+$") or "."
    local moduleRoot = toolDir .. pathSeparator .. "src"
    local modulePattern = moduleRoot .. pathSeparator .. "?.lua"
    local moduleInitPattern = moduleRoot .. pathSeparator .. "?" .. pathSeparator .. "init.lua"

    if not package.path:find(modulePattern, 1, true) then
        package.path = modulePattern .. ";" .. package.path
    end
    if not package.path:find(moduleInitPattern, 1, true) then
        package.path = moduleInitPattern .. ";" .. package.path
    end
end

bootstrapLocalLuaPath()

local argv = {
    [0] = arg and arg[0],
}
for index = 1, select("#", ...) do
    argv[index] = select(index, ...)
end

local context = require("entry.context").fromArg0(argv[0])
local bootstrap = require("entry.bootstrap")
local transportError = require("transport.error")

local function readManifestVersion(repoRoot, pathSeparator)
    -- Resolve the upstream PoB version once so every worker response reports the engine identity.
    local manifestPath = repoRoot .. pathSeparator .. "manifest.xml"
    local handle = io.open(manifestPath, "rb")
    if not handle then
        return "unknown"
    end

    local content = handle:read("*a")
    handle:close()
    local version = content and content:match('<Version number="([^"]+)"')
    return version or "unknown"
end

local function stderrPrint(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    io.stderr:write(table.concat(parts, "\t") .. "\n")
end

_G.print = stderrPrint

bootstrap.prepareEnvironment(context)

local transport = require("transport.json_stdio")
local responseOptions = {
    api_version = "v1",
    engine_version = readManifestVersion(context.repoRoot, context.pathSeparator),
    started_at = os.clock(),
}
local request, requestErr = transport.readRequest()

if not request then
    local payload = transport.encodeResponse(
        transportError.response(
            nil,
            requestErr.code,
            requestErr.message,
            requestErr.retryable,
            nil,
            transport.buildMeta(nil, responseOptions)
        )
    )
    io.write(payload)
    os.exit(1)
end

local callbacks = require("runtime.callbacks").new()
local session = require("runtime.session").new(context, callbacks)

bootstrap.launch(context, callbacks)

local _, settleErr = session:runUntilSettled({
    maxFrames = tonumber(os.getenv("POB_HEADLESS_MAX_FRAMES")) or 200,
    maxSeconds = tonumber(os.getenv("POB_HEADLESS_MAX_SECONDS")) or 5,
})

if settleErr then
    local payload = transport.encodeResponse(
        transportError.fromUpstream(
            request.id,
            settleErr,
            transport.buildMeta(request.id, responseOptions)
        )
    )
    io.write(payload)
    os.exit(1)
end

local response = transport.dispatchRequest(session.api, request, responseOptions)
io.write(transport.encodeResponse(response))
if response.ok then
    os.exit(0)
end
os.exit(1)
