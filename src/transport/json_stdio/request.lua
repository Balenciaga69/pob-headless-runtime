local json = require("dkjson")
local transportError = require("transport.error")

local M = {}

-- Validate that the decoded payload has the minimum request envelope.
function M.assertRequestEnvelope(request)
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

-- Normalize params into a table so dispatch code can assume object-shaped input.
function M.normalizeParams(request)
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

-- Require a non-empty string parameter and map missing values to a stable transport error.
function M.requireNonEmptyString(params, key, alias)
	local value = params[key]
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil, transportError.new(
		transportError.codes.INVALID_PARAMS,
		tostring(alias or key) .. " is required"
	)
end

-- Decode a JSON request body and validate the top-level envelope.
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

	return M.assertRequestEnvelope(request)
end

-- Read the full request body from the provided reader or stdin.
function M.readRequest(reader)
	reader = reader or function()
		return io.read("*a")
	end
	return M.decodeRequest(reader())
end

return M
