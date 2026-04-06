-- Path helpers for Windows and Lua path normalization.
local M = {}

-- Return the active platform path separator.
function M.getPathSeparator()
	return package.config:sub(1, 1)
end

-- Normalize path separators to the current operating system.
function M.normalize(path)
	local value = path or ""
	if M.getPathSeparator() == "\\" then
		return (value:gsub("/", "\\"))
	end
	return (value:gsub("\\", "/"))
end

-- Check whether a path is absolute.
function M.isAbsolute(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local value = M.normalize(path)
	return value:match("^%a:[/\\]") ~= nil or value:match("^[/\\]") ~= nil
end

-- Trim trailing separators so later joins stay clean.
function M.trimTrailingSeparator(path)
	return (path or ""):gsub("[/\\]+$", "")
end

-- Normalize a working directory by trimming trailing separators.
function M.normalizeDir(path)
	return M.trimTrailingSeparator(path)
end

-- Return the parent directory, or "." when none exists.
function M.dirname(path)
	local value = M.normalize(path or "")
	return value:match("^(.*)[/\\][^/\\]+$") or "."
end

-- Join path fragments using the current platform separator.
-- Nil and empty fragments are ignored, and separators are normalized.
function M.join(...)
	-- Collect the variadic arguments into a table first.
	local parts = { ... }
	local filtered = {}
	-- Drop nil and empty fragments, and coerce everything to strings.
	for index = 1, #parts do
		local part = parts[index]
		if part ~= nil and part ~= "" then
			filtered[#filtered + 1] = tostring(part)
		end
	end

	-- Return early when there are no usable fragments.
	if #filtered == 0 then
		return ""
	end

	-- Use the separator for the active platform.
	local sep = M.getPathSeparator()
	-- Normalize the first fragment and trim its trailing separator.
	local result = M.trimTrailingSeparator(M.normalize(filtered[1]))
	-- Append the remaining fragments one by one.
	for index = 2, #filtered do
		-- Normalize the current fragment and strip leading separators.
		local segment = M.normalize(filtered[index]):gsub("^[/\\]+", "")
		-- Rebuild the path without duplicating separators.
		result = M.trimTrailingSeparator(result) .. sep .. segment
	end

	return result
end

return M
