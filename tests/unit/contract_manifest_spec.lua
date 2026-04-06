local json = require("dkjson")
local expect = require("testkit").expect

local function readJson(path)
	local handle, err = io.open(path, "rb")
	expect(handle ~= nil, "expected file to exist: " .. path .. " (" .. tostring(err) .. ")")
	local text = handle:read("*a")
	handle:close()
	local value, _, decodeErr = json.decode(text)
	expect(value ~= nil and decodeErr == nil, "expected valid json file: " .. path)
	return value
end

do
	local manifest = readJson("custom/pob-headless-runtime/contracts/stable_api_v1.json")
	expect(manifest.contract_version == "stable_api_v1", "expected stable_api_v1 contract version")
	expect(manifest.entry_points.machine == "json_worker.lua", "expected json worker machine entry")
	expect(manifest.namespaces.stable == "top_level", "expected stable namespace manifest")
	expect(manifest.namespaces.experimental == "experimental", "expected experimental namespace manifest")
	expect(type(manifest.stable_methods.get_summary) == "table", "expected stable get_summary manifest")
	expect(type(manifest.stable_methods.compare_item_stats) == "table", "expected compare_item_stats manifest")
	expect(type(manifest.experimental_methods) == "table", "expected experimental methods list")
end

do
	local healthRequest = readJson("custom/pob-headless-runtime/contracts/examples/health.request.json")
	expect(healthRequest.method == "health", "expected health request example")
end

do
	local healthResponse = readJson("custom/pob-headless-runtime/contracts/examples/health.response.json")
	expect(healthResponse.ok == true, "expected health response example success")
	expect(healthResponse.meta.api_version == "v1", "expected health response metadata example")
end

do
	local unsupportedResponse = readJson("custom/pob-headless-runtime/contracts/examples/unsupported_field.response.json")
	expect(unsupportedResponse.ok == false, "expected unsupported field response example failure")
	expect(unsupportedResponse.error.code == "UNSUPPORTED_FIELD", "expected unsupported field example code")
	expect(unsupportedResponse.error.details.field == "enemyLevel", "expected unsupported field example details")
end
