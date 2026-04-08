local M = {}

-- Formal transport-level error codes exposed to JSON worker callers.
M.codes = {
    INVALID_REQUEST = "INVALID_REQUEST",
    INVALID_PARAMS = "INVALID_PARAMS",
    METHOD_NOT_FOUND = "METHOD_NOT_FOUND",
    EXPERIMENTAL_API = "EXPERIMENTAL_API",
    BUILD_NOT_READY = "BUILD_NOT_READY",
    UNSUPPORTED_FIELD = "UNSUPPORTED_FIELD",
    TIMEOUT = "TIMEOUT",
    INTERNAL_ERROR = "INTERNAL_ERROR",
}

local DEFAULT_RETRYABLE = {
    INVALID_REQUEST = false,
    INVALID_PARAMS = false,
    METHOD_NOT_FOUND = false,
    EXPERIMENTAL_API = false,
    BUILD_NOT_READY = true,
    UNSUPPORTED_FIELD = false,
    TIMEOUT = true,
    INTERNAL_ERROR = false,
}

local function parseTimeoutDetails(text)
    local maxFrames, maxSeconds, pending, mainReady, buildReady, calcsReady, outputReady =
        text:match(
            "did not settle within (%d+) frame%(s%) / ([%d%.]+) second%(s%) %(pending=(%d+), mainReady=(%a+), buildReady=(%a+), calcsReady=(%a+), outputReady=(%a+)%)"
        )
    if not maxFrames then
        return nil
    end
    return {
        max_frames = tonumber(maxFrames),
        max_seconds = tonumber(maxSeconds),
        pending_action_count = tonumber(pending),
        readiness = {
            main_ready = mainReady == "true",
            build_ready = buildReady == "true",
            calcs_ready = calcsReady == "true",
            output_ready = outputReady == "true",
        },
    }
end

local function parseBuildNotReadyDetails(text)
    if text:match("build/config not initialized") then
        return {
            state = "build_config",
        }
    end
    if text:match("items not initialized") then
        return {
            state = "items",
        }
    end
    if text:match("build not initialized") then
        return {
            state = "build",
        }
    end
    return nil
end

local function parseUnsupportedFieldDetails(text)
    local field = text:match("unsupported config field:?%s*([%w_%.%-]+)")
    if not field then
        return nil
    end
    return {
        field = field,
    }
end

function M.new(code, message, retryable, details)
    -- Build a normalized error object with consistent retry policy.
    return {
        code = code,
        message = tostring(message or "unknown error"),
        retryable = retryable == nil and DEFAULT_RETRYABLE[code] or retryable == true,
        details = details,
    }
end

function M.response(id, code, message, retryable, details, meta)
    -- Wrap a normalized transport error in the standard response envelope.
    local errorObject = M.new(code, message, retryable, details)
    if errorObject.details == nil then
        errorObject.details = nil
    end
    return {
        id = id,
        ok = false,
        error = errorObject,
        meta = meta,
    }
end

function M.fromUpstream(id, message, meta)
    -- Map legacy string errors from the existing Lua services into transport codes.
    local text = tostring(message or "unknown error")
    if text:match("unsupported config field") then
        return M.response(
            id,
            M.codes.UNSUPPORTED_FIELD,
            text,
            nil,
            parseUnsupportedFieldDetails(text),
            meta
        )
    end
    if
        text:match("build not initialized")
        or text:match("build/config not initialized")
        or text:match("items not initialized")
    then
        return M.response(
            id,
            M.codes.BUILD_NOT_READY,
            text,
            nil,
            parseBuildNotReadyDetails(text),
            meta
        )
    end
    if text:match("did not settle within") or text:match("timed out") then
        return M.response(id, M.codes.TIMEOUT, text, nil, parseTimeoutDetails(text), meta)
    end
    return M.response(id, M.codes.INTERNAL_ERROR, text, nil, nil, meta)
end

return M
