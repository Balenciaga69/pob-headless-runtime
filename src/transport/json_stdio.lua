local requestUtil = require("transport.json_stdio.request")
local responseUtil = require("transport.json_stdio.response")
local dispatchUtil = require("transport.json_stdio.dispatch")

local M = {}

function M.readRequest(reader)
	-- Delegate request parsing to the request utility module.
    return requestUtil.readRequest(reader)
end

function M.encodeResponse(response)
	-- Delegate JSON encoding to the response utility module.
    return responseUtil.encodeResponse(response)
end

function M.dispatchRequest(api, request, options)
	-- Keep dispatch logic centralized in the dispatch utility.
    return dispatchUtil.dispatchRequest(api, request, options)
end

function M.run(api, reader, writer, options)
	-- Parse one request, execute it, and write one response payload.
    local request, requestErr = M.readRequest(reader)
    local response
    if not request then
        response = responseUtil.buildErrorResponse(nil, requestErr, options)
    else
        response = M.dispatchRequest(api, request, options)
    end

    local payload = M.encodeResponse(response)
	-- Stream the encoded response to the provided writer or stdout.
    if writer then
        writer(payload)
    else
        io.write(payload)
    end
    return response
end

return M
