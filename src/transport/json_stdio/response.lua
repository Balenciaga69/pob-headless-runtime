local json = require("dkjson")
local transportError = require("transport.error")

local M = {}
local API_VERSION = "v1"

-- Build the standard transport metadata block for all responses.
function M.buildMeta(requestId, options)
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

-- Wrap a transport error in the standard JSON response envelope.
function M.buildErrorResponse(id, err, options)
	return transportError.response(id, err.code, err.message, err.retryable, err.details, M.buildMeta(id, options))
end

-- Build a successful JSON response envelope.
function M.buildSuccess(id, result, options)
	return {
		id = id,
		ok = true,
		result = result,
		meta = M.buildMeta(id, options),
	}
end

-- Encode a response table into JSON text.
function M.encodeResponse(response)
	return json.encode(response)
end

return M
