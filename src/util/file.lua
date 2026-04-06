-- File helpers for safe reads and writes.
local M = {}

-- Read an entire file and keep the caller's label in any error message.
function M.readAll(path, label)
	-- Reject invalid paths up front.
	if type(path) ~= "string" or path == "" then
		return nil, tostring(label or "File") .. " path is required"
	end

	local handle, err = io.open(path, "rb")
	if not handle then
		return nil, string.format("Unable to open %s %s: %s", label or "file", tostring(path), tostring(err))
	end

	local text = handle:read("*a")
	handle:close()
	
	-- Treat an empty file as an error so callers do not continue with no data.
	if not text or text == "" then
		return nil, string.format("%s is empty: %s", label or "File", tostring(path))
	end

	return text
end

-- Write an entire file and centralize io.open error handling.
function M.writeAll(path, text, label)
	if type(path) ~= "string" or path == "" then
		return nil, tostring(label or "File") .. " path is required"
	end
	if type(text) ~= "string" or text == "" then
		return nil, tostring(label or "File") .. " contents are required"
	end

	local handle, err = io.open(path, "wb")
	if not handle then
		return nil, string.format("Unable to open %s %s for writing: %s", label or "file", tostring(path), tostring(err))
	end

	local ok, writeErr = handle:write(text)
	handle:close()
	if not ok then
		return nil, string.format("Unable to write %s %s: %s", label or "file", tostring(path), tostring(writeErr))
	end

	return {
		path = path,
		size = #text,
	}
end

return M
