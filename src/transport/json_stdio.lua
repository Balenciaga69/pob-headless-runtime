local json = require("dkjson")
local transportError = require("transport.error")

local M = {}
local API_VERSION = "v1"

local DEFAULT_STABLE_METHODS = {
	load_build_xml = true,
	load_build_code = true,
	get_summary = true,
	get_stats = true,
	compare_item_stats = true,
	simulate_node_delta = true,
	get_runtime_status = true,
	health = true,
}

local function getStableMethods(api)
	-- Prefer the API-declared surface; fall back to the hard-coded stable list for tests.
	local stable = {}
	if type(api) == "table" and type(api.get_api_surface) == "function" then
		local surface = api.get_api_surface()
		for _, name in ipairs((surface and surface.stable) or {}) do
			stable[name] = true
		end
	end
	if next(stable) ~= nil then
		return stable
	end
	for name, enabled in pairs(DEFAULT_STABLE_METHODS) do
		stable[name] = enabled
	end
	return stable
end

local function buildMeta(requestId, options)
	options = options or {}
	local startedAt = tonumber(options.started_at)
	local durationMs = 0
	if startedAt and startedAt >= 0 then
		durationMs = math.max(0, math.floor(((os.clock() - startedAt) * 1000) + 0.5))
	end
	return {
		request_id = requestId,
		api_version = tostring(options.api_version or API_VERSION),
		engine_version = tostring(options.engine_version or "unknown"),
		duration_ms = durationMs,
	}
end

M.buildMeta = buildMeta

local function buildErrorResponse(id, err, options)
	return transportError.response(id, err.code, err.message, err.retryable, err.details, buildMeta(id, options))
end

local function buildSuccess(id, result, options)
	return {
		id = id,
		ok = true,
		result = result,
		meta = buildMeta(id, options),
	}
end

local function normalizeParams(request)
	-- Transport params are always modeled as a JSON object.
	if request.params == nil then
		return {}
	end
	if type(request.params) ~= "table" then
		return nil, transportError.new(
			transportError.codes.INVALID_PARAMS,
			"invalid params: params must be an object"
		)
	end
	return request.params
end

local function assertRequestEnvelope(request)
	if type(request) ~= "table" then
		return nil, transportError.new(
			transportError.codes.INVALID_REQUEST,
			"invalid request: expected JSON object"
		)
	end
	if type(request.method) ~= "string" or request.method == "" then
		return nil, transportError.new(
			transportError.codes.INVALID_REQUEST,
			"invalid request: method is required"
		)
	end
	return request
end

local function assertRequestShape(request, api)
	local validRequest, err = assertRequestEnvelope(request)
	if not validRequest then
		return nil, err
	end
	if not getStableMethods(api)[request.method] then
		local surface = type(api) == "table" and type(api.get_api_surface) == "function" and api.get_api_surface() or nil
		local experimental = {}
		for _, name in ipairs((surface and surface.experimental) or {}) do
			experimental[name] = true
		end
		local code = experimental[request.method] and transportError.codes.EXPERIMENTAL_API or transportError.codes.METHOD_NOT_FOUND
		local suffix = experimental[request.method] and " (experimental)" or ""
		return nil, transportError.new(code, "unsupported method: " .. tostring(request.method) .. suffix)
	end
	return validRequest
end

local function requireNonEmptyString(params, key, alias)
	-- Reuse one validator so missing required string params produce one stable code/message shape.
	local value = params[key]
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil, transportError.new(
		transportError.codes.INVALID_PARAMS,
		tostring(alias or key) .. " is required"
	)
end

function M.decodeRequest(input)
	if type(input) ~= "string" or input == "" then
		return nil, transportError.new(
			transportError.codes.INVALID_REQUEST,
			"invalid request: request body is empty"
		)
	end

	local request, _, err = json.decode(input)
	if err then
		return nil, transportError.new(
			transportError.codes.INVALID_REQUEST,
			"invalid request: " .. tostring(err)
		)
	end

	return assertRequestEnvelope(request)
end

function M.encodeResponse(response)
	return json.encode(response)
end

function M.readRequest(reader)
	reader = reader or function()
		return io.read("*a")
	end
	return M.decodeRequest(reader())
end

local function preloadBuild(api, method, params)
	-- Stateless worker calls can inline a build payload in params before the main method runs.
	if method == "load_build_xml" or method == "load_build_code" then
		return true
	end

	if type(params.build_xml) == "string" and params.build_xml ~= "" then
		local _, err = api.load_build_xml(params.build_xml, params.build_name)
		if err then
			return nil, transportError.fromUpstream(nil, err).error
		end
		return true
	end

	if type(params.build_code) == "string" and params.build_code ~= "" then
		local _, err = api.load_build_code(params.build_code, params.build_name)
		if err then
			return nil, transportError.fromUpstream(nil, err).error
		end
		return true
	end

	return true
end

local function dispatchStableMethod(api, method, params)
	-- Dispatch only the formal stable methods exposed by the transport contract.
	if method == "load_build_xml" then
		local xmlText, paramErr = requireNonEmptyString(params, "xmlText", "xmlText or build_xml")
		if not xmlText then
			xmlText, paramErr = requireNonEmptyString(params, "build_xml", "xmlText or build_xml")
		end
		if not xmlText then
			return nil, paramErr
		end
		local loaded, err = api.load_build_xml(xmlText, params.name or params.build_name)
		if not loaded then
			return nil, transportError.fromUpstream(nil, err).error
		end
		local summary, summaryErr = api.get_summary()
		if not summary then
			return nil, transportError.fromUpstream(nil, summaryErr).error
		end
		return {
			loaded = true,
			summary = summary,
		}
	end

	if method == "load_build_code" then
		local code, paramErr = requireNonEmptyString(params, "code", "code or build_code")
		if not code then
			code, paramErr = requireNonEmptyString(params, "build_code", "code or build_code")
		end
		if not code then
			return nil, paramErr
		end
		local loaded, err = api.load_build_code(code, params.name or params.build_name)
		if not loaded then
			return nil, transportError.fromUpstream(nil, err).error
		end
		local summary, summaryErr = api.get_summary()
		if not summary then
			return nil, transportError.fromUpstream(nil, summaryErr).error
		end
		return {
			loaded = true,
			summary = summary,
		}
	end

	if method == "get_summary" then
		local result, err = api.get_summary()
		if not result then
			return nil, transportError.fromUpstream(nil, err).error
		end
		return result
	end

	if method == "get_stats" then
		local result, err = api.get_stats(params.fields)
		if not result then
			return nil, transportError.fromUpstream(nil, err).error
		end
		return result
	end

	if method == "compare_item_stats" then
		local itemText, paramErr = requireNonEmptyString(params, "item_text", "item_text or itemText")
		if not itemText then
			itemText, paramErr = requireNonEmptyString(params, "itemText", "item_text or itemText")
		end
		if not itemText then
			return nil, paramErr
		end
		local result, err = api.compare_item_stats(itemText, params.slot, params.fields)
		if not result then
			return nil, transportError.fromUpstream(nil, err).error
		end
		return result
	end

	if method == "simulate_node_delta" then
		local treeParams = {
			add = params.add,
			remove = params.remove,
			masteryEffects = params.masteryEffects,
		}
		local result, err = api.simulate_node_delta(treeParams, params.fields)
		if not result then
			return nil, transportError.fromUpstream(nil, err).error
		end
		return result
	end

	if method == "get_runtime_status" then
		return api.get_runtime_status()
	end

	if method == "health" then
		return api.health()
	end

	return nil, transportError.new(
		transportError.codes.METHOD_NOT_FOUND,
		"unsupported method: " .. tostring(method)
	)
end

function M.dispatchRequest(api, request, options)
	-- Request dispatch is the only place that classifies transport-layer failures for callers.
	local validRequest, requestErr = assertRequestShape(request, api)
	if not validRequest then
		return buildErrorResponse(request and request.id or nil, requestErr, options)
	end

	if type(api) ~= "table" then
		return buildErrorResponse(validRequest.id, transportError.new(
			transportError.codes.INTERNAL_ERROR,
			"invalid api: expected table"
		), options)
	end

	local params, paramsErr = normalizeParams(validRequest)
	if not params then
		return buildErrorResponse(validRequest.id, paramsErr, options)
	end

	local ok, preloadErr = preloadBuild(api, validRequest.method, params)
	if not ok then
		return buildErrorResponse(validRequest.id, preloadErr, options)
	end

	local succeeded, result, dispatchErr = pcall(dispatchStableMethod, api, validRequest.method, params)
	if not succeeded then
		return buildErrorResponse(validRequest.id, transportError.new(
			transportError.codes.INTERNAL_ERROR,
			"internal error: " .. tostring(result)
		), options)
	end
	if dispatchErr then
		return buildErrorResponse(validRequest.id, dispatchErr, options)
	end

	return buildSuccess(validRequest.id, result, options)
end

function M.run(api, reader, writer, options)
	local request, requestErr = M.readRequest(reader)
	local response
	if not request then
		response = buildErrorResponse(nil, requestErr, options)
	else
		response = M.dispatchRequest(api, request, options)
	end

	local payload = M.encodeResponse(response)
	if writer then
		writer(payload)
	else
		io.write(payload)
	end
	return response
end

return M
