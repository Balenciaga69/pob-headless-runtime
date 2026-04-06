local json = require("dkjson")

local M = {}

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

local function classifyError(message)
	local text = tostring(message or "unknown error")
	if text:match("unsupported method") or text:match("invalid request") or text:match(" is required") then
		return "INVALID_INPUT", false
	end
	if text:match("experimental") then
		return "EXPERIMENTAL_API", false
	end
	if text:match("unsupported config field") then
		return "UNSUPPORTED_FIELD", false
	end
	if text:match("timed out") or text:match("did not settle within") then
		return "TIMEOUT", true
	end
	if text:match("build not initialized") or text:match("build/config not initialized") or text:match("items not initialized") then
		return "BUILD_NOT_READY", true
	end
	return "UPSTREAM_FAILURE", false
end

local function buildError(id, message)
	local code, retryable = classifyError(message)
	return {
		id = id,
		ok = false,
		error = {
			code = code,
			message = tostring(message or "unknown error"),
			retryable = retryable,
		},
	}
end

local function buildSuccess(id, result)
	return {
		id = id,
		ok = true,
		result = result,
	}
end

local function normalizeParams(request)
	if request.params == nil then
		return {}
	end
	if type(request.params) ~= "table" then
		return nil, "invalid request: params must be an object"
	end
	return request.params
end

local function assertRequestShape(request, api)
	if type(request) ~= "table" then
		return nil, "invalid request: expected JSON object"
	end
	if type(request.method) ~= "string" or request.method == "" then
		return nil, "invalid request: method is required"
	end
	if not getStableMethods(api)[request.method] then
		return nil, "unsupported method: " .. tostring(request.method) .. " (experimental or unknown)"
	end
	return request
end

function M.decodeRequest(input)
	if type(input) ~= "string" or input == "" then
		return nil, "invalid request: request body is empty"
	end

	local request, _, err = json.decode(input)
	if err then
		return nil, "invalid request: " .. tostring(err)
	end

	return assertRequestShape(request)
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
	if method == "load_build_xml" or method == "load_build_code" then
		return true
	end

	if type(params.build_xml) == "string" and params.build_xml ~= "" then
		local _, err = api.load_build_xml(params.build_xml, params.build_name)
		if err then
			return nil, err
		end
		return true
	end

	if type(params.build_code) == "string" and params.build_code ~= "" then
		local _, err = api.load_build_code(params.build_code, params.build_name)
		if err then
			return nil, err
		end
		return true
	end

	return true
end

local function dispatchStableMethod(api, method, params)
	if method == "load_build_xml" then
		local xmlText = params.xmlText or params.build_xml
		local loaded, err = api.load_build_xml(xmlText, params.name or params.build_name)
		if not loaded then
			return nil, err
		end
		local summary, summaryErr = api.get_summary()
		if not summary then
			return nil, summaryErr
		end
		return {
			loaded = true,
			summary = summary,
		}
	end

	if method == "load_build_code" then
		local code = params.code or params.build_code
		local loaded, err = api.load_build_code(code, params.name or params.build_name)
		if not loaded then
			return nil, err
		end
		local summary, summaryErr = api.get_summary()
		if not summary then
			return nil, summaryErr
		end
		return {
			loaded = true,
			summary = summary,
		}
	end

	if method == "get_summary" then
		return api.get_summary()
	end

	if method == "get_stats" then
		return api.get_stats(params.fields)
	end

	if method == "compare_item_stats" then
		local itemText = params.item_text or params.itemText
		return api.compare_item_stats(itemText, params.slot, params.fields)
	end

	if method == "simulate_node_delta" then
		local treeParams = {
			add = params.add,
			remove = params.remove,
			masteryEffects = params.masteryEffects,
		}
		return api.simulate_node_delta(treeParams, params.fields)
	end

	if method == "get_runtime_status" then
		return api.get_runtime_status()
	end

	if method == "health" then
		return api.health()
	end

	return nil, "unsupported method: " .. tostring(method)
end

function M.dispatchRequest(api, request)
	local validRequest, requestErr = assertRequestShape(request, api)
	if not validRequest then
		return buildError(request and request.id or nil, requestErr)
	end

	if type(api) ~= "table" then
		return buildError(validRequest.id, "invalid api: expected table")
	end

	local params, paramsErr = normalizeParams(validRequest)
	if not params then
		return buildError(validRequest.id, paramsErr)
	end

	local ok, preloadErr = preloadBuild(api, validRequest.method, params)
	if not ok then
		return buildError(validRequest.id, preloadErr)
	end

	local result, dispatchErr = dispatchStableMethod(api, validRequest.method, params)
	if dispatchErr then
		return buildError(validRequest.id, dispatchErr)
	end

	return buildSuccess(validRequest.id, result)
end

function M.run(api, reader, writer)
	local request, requestErr = M.readRequest(reader)
	local response
	if not request then
		response = buildError(nil, requestErr)
	else
		response = M.dispatchRequest(api, request)
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
