local transportError = require("transport.error")
local requestUtil = require("transport.json_stdio.request")
local responseUtil = require("transport.json_stdio.response")

local M = {}

local DEFAULT_STABLE_METHODS = {
    load_build_xml = true,
    load_build_code = true,
    load_build_file = true,
    save_build_xml = true,
    save_build_code = true,
    save_build_file = true,
    get_summary = true,
    get_stats = true,
    equip_item = true,
    list_equipment = true,
    set_config = true,
    get_config = true,
    get_runtime_status = true,
    health = true,
}

-- Resolve the stable method surface from the API or fall back to the built-in list.
local function getStableMethods(api)
    -- Prefer the API-advertised surface so transport behavior follows runtime capabilities.
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

-- Validate the request envelope and reject unsupported methods before dispatch.
function M.assertRequestShape(request, api)
    -- Reject unsupported methods before any runtime work is attempted.
    local validRequest, err = requestUtil.assertRequestEnvelope(request)
    if not validRequest then
        return nil, err
    end
    if not getStableMethods(api)[request.method] then
        local surface = type(api) == "table"
                and type(api.get_api_surface) == "function"
                and api.get_api_surface()
            or nil
        local experimental = {}
        for _, name in ipairs((surface and surface.experimental) or {}) do
            experimental[name] = true
        end
        local code = experimental[request.method] and transportError.codes.EXPERIMENTAL_API
            or transportError.codes.METHOD_NOT_FOUND
        local suffix = experimental[request.method] and " (experimental)" or ""
        return nil,
            transportError.new(code, "unsupported method: " .. tostring(request.method) .. suffix)
    end
    return validRequest
end

-- Preload build data from stateless request params when the method is not a load call.
local function preloadBuild(api, method, params)
    -- Allow callers to send build payloads inline for convenience.
    if method == "load_build_xml" or method == "load_build_code" or method == "load_build_file" then
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

-- Execute one stable API method and convert upstream failures into transport errors.
local function dispatchStableMethod(api, method, params)
    -- Handle each supported method explicitly so error mapping stays predictable.
    if method == "load_build_xml" then
        local xmlText, paramErr =
            requestUtil.requireNonEmptyString(params, "xmlText", "xmlText or build_xml")
        if not xmlText then
            xmlText, paramErr =
                requestUtil.requireNonEmptyString(params, "build_xml", "xmlText or build_xml")
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
        return { loaded = true, summary = summary }
    end
    if method == "load_build_code" then
        local code, paramErr =
            requestUtil.requireNonEmptyString(params, "code", "code or build_code")
        if not code then
            code, paramErr =
                requestUtil.requireNonEmptyString(params, "build_code", "code or build_code")
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
        return { loaded = true, summary = summary }
    end
    if method == "load_build_file" then
        local path, paramErr = requestUtil.requireNonEmptyString(params, "path", "path")
        if not path then
            return nil, paramErr
        end
        local loaded, err = api.load_build_file(path)
        if not loaded then
            return nil, transportError.fromUpstream(nil, err).error
        end
        local summary, summaryErr = api.get_summary()
        if not summary then
            return nil, transportError.fromUpstream(nil, summaryErr).error
        end
        return { loaded = true, summary = summary }
    end
    if method == "save_build_xml" then
        local result, err = api.save_build_xml()
        if not result then
            return nil, transportError.fromUpstream(nil, err).error
        end
        return { xml = result }
    end
    if method == "save_build_code" then
        local result, err = api.save_build_code()
        if not result then
            return nil, transportError.fromUpstream(nil, err).error
        end
        return { code = result }
    end
    if method == "save_build_file" then
        local result, err = api.save_build_file(params.path)
        if not result then
            return nil, transportError.fromUpstream(nil, err).error
        end
        return result
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
    if method == "equip_item" then
        local itemText, paramErr =
            requestUtil.requireNonEmptyString(params, "item_text", "item_text or itemText")
        if not itemText then
            itemText, paramErr =
                requestUtil.requireNonEmptyString(params, "itemText", "item_text or itemText")
        end
        if not itemText then
            return nil, paramErr
        end
        local result, err = api.equip_item(itemText, params.slot)
        if not result then
            return nil, transportError.fromUpstream(nil, err).error
        end
        return result
    end
    if method == "list_equipment" then
        local result, err = api.list_equipment()
        if not result then
            return nil, transportError.fromUpstream(nil, err).error
        end
        return result
    end
    if method == "set_config" then
        local result, err = api.set_config(params)
        if not result then
            return nil, transportError.fromUpstream(nil, err).error
        end
        return result
    end
    if method == "get_config" then
        local result, err = api.get_config()
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
    return nil,
        transportError.new(
            transportError.codes.METHOD_NOT_FOUND,
            "unsupported method: " .. tostring(method)
        )
end

-- Apply transport validation, preload handling, and stable dispatch in one step.
function M.dispatchRequest(api, request, options)
    -- Validate first, then dispatch, then wrap the result into a response envelope.
    local validRequest, requestErr = M.assertRequestShape(request, api)
    if not validRequest then
        return responseUtil.buildErrorResponse(request and request.id or nil, requestErr, options)
    end
    if type(api) ~= "table" then
        return responseUtil.buildErrorResponse(
            validRequest.id,
            transportError.new(transportError.codes.INTERNAL_ERROR, "invalid api: expected table"),
            options
        )
    end
    local params, paramsErr = requestUtil.normalizeParams(validRequest)
    if not params then
        return responseUtil.buildErrorResponse(validRequest.id, paramsErr, options)
    end
    local ok, preloadErr = preloadBuild(api, validRequest.method, params)
    if not ok then
        return responseUtil.buildErrorResponse(validRequest.id, preloadErr, options)
    end
    local succeeded, result, dispatchErr =
        pcall(dispatchStableMethod, api, validRequest.method, params)
    if not succeeded then
        return responseUtil.buildErrorResponse(
            validRequest.id,
            transportError.new(
                transportError.codes.INTERNAL_ERROR,
                "internal error: " .. tostring(result)
            ),
            options
        )
    end
    if dispatchErr then
        return responseUtil.buildErrorResponse(validRequest.id, dispatchErr, options)
    end
    return responseUtil.buildSuccess(validRequest.id, result, options)
end

return M
