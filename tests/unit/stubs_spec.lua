local compatibilityStubs = require("compatibility.stubs")
local compatibilityUtf8 = require("compatibility.lua-utf8")
local stubs = compatibilityStubs
local expect = require("testkit").expect

expect(compatibilityUtf8.char(0x41) == "A", "expected utf8 compatibility module to load directly")

local function contains(values, target)
    for _, value in ipairs(values or {}) do
        if value == target then
            return true
        end
    end
    return false
end

local callbacks
callbacks = {
    headlessDone = false,
    runCallback = function()
        return nil
    end,
    setCallback = function() end,
    getCallback = function()
        return nil
    end,
    setMainObject = function() end,
    markHeadlessDone = function()
        callbacks.headlessDone = true
    end,
}

stubs.install({
    sourceDir = "src",
    runtimeDir = "runtime",
    repoRoot = "repo",
    currentWorkDir = "src",
}, callbacks)

local capabilityMatrix = stubs.getCapabilityMatrix()
expect(
    contains(capabilityMatrix.deterministicFake, "Copy"),
    "expected Copy to be marked deterministic"
)
expect(
    contains(capabilityMatrix.unsupported, "OpenURL"),
    "expected OpenURL to be marked unsupported"
)
expect(
    contains(capabilityMatrix.compatibilityShim, "Inflate"),
    "expected Inflate to be marked compatibility shim"
)

expect(_G.Copy("sample text") == true, "expected Copy to acknowledge fake clipboard write")
expect(_G.Paste() == "sample text", "expected Paste to read fake clipboard")

local openOk, openErr = pcall(_G.OpenURL, "https://example.com")
expect(openOk == false, "expected OpenURL to fail fast in headless mode")
expect(
    type(openErr) == "string" and openErr:match("OpenURL%(%).*unavailable"),
    "expected explicit OpenURL error"
)

_G.Exit()
expect(callbacks.headlessDone == true, "expected Exit to request headless shutdown")

local exportedMatrix = _G.GetHeadlessStubCapabilities()
expect(
    contains(exportedMatrix.safeNoOp, "RenderInit"),
    "expected exported matrix to include safeNoOp capabilities"
)
