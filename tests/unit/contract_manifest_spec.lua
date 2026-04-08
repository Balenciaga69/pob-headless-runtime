local json = require("dkjson")
local expect = require("testkit").expect

local function readExisting(path)
    local handle = io.open(path, "rb")
    if not handle then
        return nil
    end
    local text = handle:read("*a")
    handle:close()
    return text
end

local function readJson(path)
    local text = readExisting(path)
    expect(text ~= nil, "expected file to exist: " .. path)
    local value, _, decodeErr = json.decode(text)
    expect(value ~= nil and decodeErr == nil, "expected valid json file: " .. path)
    return value
end

local function resolveToolPath(relativePath)
    local candidates = {
        "pob-headless-runtime/" .. relativePath,
        "custom/pob-headless-runtime/" .. relativePath,
    }
    for _, candidate in ipairs(candidates) do
        if readExisting(candidate) ~= nil then
            return candidate
        end
    end
    return candidates[1]
end

do
    local manifest = readJson(resolveToolPath("contracts/stable_api_v1.json"))
    expect(manifest.contract_version == "stable_api_v1", "expected stable_api_v1 contract version")
    expect(manifest.entry_points.machine == "json_worker.lua", "expected json worker machine entry")
    expect(manifest.namespaces.stable == "top_level", "expected stable namespace manifest")
    expect(
        manifest.namespaces.experimental == "experimental",
        "expected experimental namespace manifest"
    )
    expect(
        type(manifest.stable_methods.get_summary) == "table",
        "expected stable get_summary manifest"
    )
    expect(
        type(manifest.stable_methods.get_display_stats) == "table",
        "expected stable get_display_stats manifest"
    )
    expect(
        type(manifest.stable_methods.equip_item) == "table",
        "expected equip_item manifest"
    )
    expect(type(manifest.experimental_methods) == "table", "expected experimental methods list")
end

do
    local healthRequest = readJson(resolveToolPath("contracts/examples/health.request.json"))
    expect(healthRequest.method == "health", "expected health request example")
end

do
    local displayStatsRequest =
        readJson(resolveToolPath("contracts/examples/display_stats.request.json"))
    expect(
        displayStatsRequest.method == "get_display_stats",
        "expected display stats request example"
    )
end

do
    local healthResponse = readJson(resolveToolPath("contracts/examples/health.response.json"))
    expect(healthResponse.ok == true, "expected health response example success")
    expect(healthResponse.meta.api_version == "v1", "expected health response metadata example")
end

do
    local displayStatsResponse =
        readJson(resolveToolPath("contracts/examples/display_stats.response.json"))
    expect(displayStatsResponse.ok == true, "expected display stats response example success")
    expect(
        displayStatsResponse.result._meta.skillContext.selectionSource == "calcs",
        "expected display stats skill context example"
    )
end

do
    local unsupportedResponse =
        readJson(resolveToolPath("contracts/examples/unsupported_field.response.json"))
    expect(unsupportedResponse.ok == false, "expected unsupported field response example failure")
    expect(
        unsupportedResponse.error.code == "UNSUPPORTED_FIELD",
        "expected unsupported field example code"
    )
    expect(
        unsupportedResponse.error.details.field == "enemyLevel",
        "expected unsupported field example details"
    )
end
