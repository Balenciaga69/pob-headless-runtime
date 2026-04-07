local requestUtil = require("transport.json_stdio.request")
local responseUtil = require("transport.json_stdio.response")
local dispatchUtil = require("transport.json_stdio.dispatch")

local M = {}

function M.readRequest(reader)
	return requestUtil.readRequest(reader)
end

function M.encodeResponse(response)
	return responseUtil.encodeResponse(response)
end

function M.dispatchRequest(api, request, options)
	return dispatchUtil.dispatchRequest(api, request, options)
end

function M.run(api, reader, writer, options)
	local request, requestErr = M.readRequest(reader)
	local response
	if not request then
		response = responseUtil.buildErrorResponse(nil, requestErr, options)
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
