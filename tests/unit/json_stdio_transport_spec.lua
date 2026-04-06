local transport = require("transport.json_stdio")
local expect = require("testkit").expect

do
	local request, err = transport.decodeRequest('{"id":"1","method":"health","params":{}}')
	expect(request ~= nil and err == nil, "expected health request to decode")
	expect(request.method == "health", "expected health method")
end

do
	local request, err = transport.decodeRequest('{"id":"1","method":"equip_item","params":{}}')
	expect(request ~= nil and err == nil, "expected experimental method to pass envelope decode")
	expect(request.method == "equip_item", "expected equip_item method to survive decode")
end

do
	local request, err = transport.decodeRequest('{"id":"1","method":')
	expect(request == nil, "expected invalid json to fail")
	expect(err.code == "INVALID_REQUEST", "expected invalid request code")
end

do
	local calls = {}
	local api = {
		health = function()
			calls[#calls + 1] = "health"
			return { ok = true }
		end,
	}

	local response = transport.dispatchRequest(api, {
		id = "health-1",
		method = "health",
		params = {},
	})

	expect(response.ok == true, "expected health response success")
	expect(response.result.ok == true, "expected health result payload")
	expect(calls[1] == "health", "expected health dispatch")
end

do
	local calls = {}
	local api = {
		load_build_code = function(code, name)
			calls[#calls + 1] = { "load_build_code", code, name }
			return { loaded = true }
		end,
		get_summary = function()
			calls[#calls + 1] = { "get_summary" }
			return { buildName = "Fixture" }
		end,
	}

	local response = transport.dispatchRequest(api, {
		id = "load-1",
		method = "load_build_code",
		params = {
			code = "abc123",
			name = "Fixture",
		},
	})

	expect(response.ok == true, "expected load_build_code response success")
	expect(response.result.loaded == true, "expected loaded marker")
	expect(response.result.summary.buildName == "Fixture", "expected summary payload")
	expect(calls[1][1] == "load_build_code", "expected load_build_code dispatch")
	expect(calls[2][1] == "get_summary", "expected summary after load")
end

do
	local calls = {}
	local api = {
		load_build_xml = function(xmlText, name)
			calls[#calls + 1] = { "load_build_xml", xmlText, name }
			return { loaded = true }
		end,
		get_stats = function(fields)
			calls[#calls + 1] = { "get_stats", fields }
			return { Life = 1234 }
		end,
	}

	local response = transport.dispatchRequest(api, {
		id = "stats-1",
		method = "get_stats",
		params = {
			build_xml = "<PathOfBuilding/>",
			build_name = "Fixture",
			fields = { "Life" },
		},
	})

	expect(response.ok == true, "expected get_stats response success")
	expect(response.result.Life == 1234, "expected stats payload")
	expect(calls[1][1] == "load_build_xml", "expected preload via build_xml")
	expect(calls[2][1] == "get_stats", "expected get_stats dispatch")
end

do
	local response = transport.run({}, function()
		return '{"id":"bad","method":"get_stats","params":"oops"}'
	end, function(_) end)

	expect(response.ok == false, "expected invalid params to fail")
	expect(response.error.code == "INVALID_PARAMS", "expected invalid params code")
end

do
	local api = {
		get_api_surface = function()
			return {
				stable = { "health" },
				experimental = { "equip_item" },
			}
		end,
	}

	local response = transport.dispatchRequest(api, {
		id = "exp-1",
		method = "equip_item",
		params = {},
	})

	expect(response.ok == false, "expected experimental method failure")
	expect(response.error.code == "EXPERIMENTAL_API", "expected experimental api code")
end

do
	local api = {
		get_stats = function()
			return nil, "build not initialized"
		end,
	}

	local response = transport.dispatchRequest(api, {
		id = "build-1",
		method = "get_stats",
		params = {},
	})

	expect(response.ok == false, "expected build error")
	expect(response.error.code == "BUILD_NOT_READY", "expected build not ready code")
	expect(response.error.retryable == true, "expected build not ready retryable")
end

do
	local response = transport.dispatchRequest({}, {
		id = "params-1",
		method = "compare_item_stats",
		params = {},
	})

	expect(response.ok == false, "expected compare_item_stats param failure")
	expect(response.error.code == "INVALID_PARAMS", "expected invalid params for missing item")
	expect(response.error.message:match("item_text or itemText is required"), "expected missing item text message")
end
