local transport = require("transport.json_stdio")
local expect = require("testkit").expect

do
    local request, err = transport.decodeRequest('{"id":"1","method":"health","params":{}}')
    expect(request ~= nil and err == nil, "expected health request to decode")
    expect(request.method == "health", "expected health method")
end

do
    local request, err = transport.decodeRequest('{"id":"1","method":"equip_item","params":{}}')
    expect(request ~= nil and err == nil, "expected stable method to pass envelope decode")
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
    expect(type(response.meta) == "table", "expected response metadata")
    expect(response.meta.request_id == "health-1", "expected request_id metadata")
    expect(response.meta.api_version == "v1", "expected api version metadata")
    expect(response.meta.engine_version == "unknown", "expected default engine version metadata")
    expect(type(response.meta.duration_ms) == "number", "expected duration metadata")
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
    local calls = {}
    local api = {
        get_display_stats = function()
            calls[#calls + 1] = { "get_display_stats" }
            return {
                _meta = { mainSkill = "Kinetic Fusillade" },
                entries = {
                    { type = "stat", label = "Average Damage", formatted = "48585.9" },
                },
            }
        end,
    }

    local response = transport.dispatchRequest(api, {
        id = "display-stats-1",
        method = "get_display_stats",
        params = {},
    })

    expect(response.ok == true, "expected get_display_stats response success")
    expect(response.result._meta.mainSkill == "Kinetic Fusillade", "expected meta payload")
    expect(response.result.entries[1].label == "Average Damage", "expected stats entry")
    expect(calls[1][1] == "get_display_stats", "expected get_display_stats dispatch")
end

do
    local response = transport.run({}, function()
        return '{"id":"bad","method":"get_stats","params":"oops"}'
    end, function(_) end)

    expect(response.ok == false, "expected invalid params to fail")
    expect(response.error.code == "INVALID_PARAMS", "expected invalid params code")
    expect(response.meta.request_id == "bad", "expected invalid params request_id metadata")
    expect(response.meta.api_version == "v1", "expected invalid params api version metadata")
end

do
    local api = {
        get_api_surface = function()
            return {
                stable = { "health" },
                stable = { "health" },
                experimental = { "compare_item_stats" },
            }
        end,
    }

    local response = transport.dispatchRequest(api, {
        id = "exp-1",
        method = "compare_item_stats",
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
        method = "equip_item",
        params = {},
    })

    expect(response.ok == false, "expected equip_item param failure")
    expect(response.error.code == "INVALID_PARAMS", "expected invalid params for missing item")
    expect(
        response.error.message:match("item_text or itemText is required"),
        "expected missing item text message"
    )
    expect(response.meta.request_id == "params-1", "expected missing item request_id metadata")
    expect(response.meta.duration_ms >= 0, "expected non-negative duration metadata")
end

do
    local calls = {}
    local api = {
        equip_item = function(itemText, slot)
            calls[#calls + 1] = { "equip_item", itemText, slot }
            return { slot = { resolved = slot }, item = { name = "Test" } }
        end,
    }

    local response = transport.dispatchRequest(api, {
        id = "equip-1",
        method = "equip_item",
        params = {
            item_text = "Rarity: Rare",
            slot = "Ring 1",
        },
    })

    expect(response.ok == true, "expected equip_item response success")
    expect(response.result.slot.resolved == "Ring 1", "expected slot payload")
    expect(calls[1][1] == "equip_item", "expected equip_item dispatch")
end

do
    local response = transport.dispatchRequest({
        health = function()
            return { ok = true }
        end,
    }, {
        id = "meta-1",
        method = "health",
        params = {},
    }, {
        api_version = "v-test",
        engine_version = "2.63.0",
        started_at = os.clock() - 0.01,
    })

    expect(response.ok == true, "expected metadata override response success")
    expect(response.meta.request_id == "meta-1", "expected metadata override request id")
    expect(response.meta.api_version == "v-test", "expected metadata override api version")
    expect(response.meta.engine_version == "2.63.0", "expected metadata override engine version")
    expect(response.meta.duration_ms >= 0, "expected metadata override duration metadata")
end

do
    local timeout = require("transport.error").fromUpstream(
        "time-1",
        "headless runtime did not settle within 200 frame(s) / 5.00 second(s) (pending=2, mainReady=true, buildReady=false, calcsReady=false, outputReady=false)"
    )

    expect(timeout.error.code == "TIMEOUT", "expected timeout code")
    expect(timeout.error.details.max_frames == 200, "expected timeout max_frames detail")
    expect(timeout.error.details.max_seconds == 5, "expected timeout max_seconds detail")
    expect(timeout.error.details.pending_action_count == 2, "expected timeout pending detail")
    expect(timeout.error.details.readiness.main_ready == true, "expected timeout main_ready detail")
    expect(
        timeout.error.details.readiness.build_ready == false,
        "expected timeout build_ready detail"
    )
end

do
    local unsupported =
        require("transport.error").fromUpstream("cfg-1", "unsupported config field: enemyLevel")
    expect(unsupported.error.code == "UNSUPPORTED_FIELD", "expected unsupported field code")
    expect(unsupported.error.details.field == "enemyLevel", "expected unsupported field detail")
end

do
    local notReady =
        require("transport.error").fromUpstream("build-2", "build/config not initialized")
    expect(notReady.error.code == "BUILD_NOT_READY", "expected build not ready code detail test")
    expect(notReady.error.details.state == "build_config", "expected build not ready state detail")
end
