-- Stats comparison helpers for consistent delta formatting.
local M = {}

-- Keep only numeric fields so compare payloads stay free of text or nested tables.
function M.pickNumericFields(stats, fields)
	local result = {}
	for _, field in ipairs(fields or {}) do
		local value = stats and stats[field]
		if type(value) == "number" then
			result[field] = value
		end
	end
	return result
end

-- Compute numeric deltas and return the fields that actually changed.
function M.numericDelta(beforeStats, afterStats, fields)
	local delta = {}
	local changedFields = {}
	for _, field in ipairs(fields or {}) do
		local beforeValue = beforeStats and beforeStats[field]
		local afterValue = afterStats and afterStats[field]
		if type(beforeValue) == "number" or type(afterValue) == "number" then
			local beforeNumber = tonumber(beforeValue) or 0
			local afterNumber = tonumber(afterValue) or 0
			local diff = afterNumber - beforeNumber
			delta[field] = diff
			if diff ~= 0 then
				changedFields[#changedFields + 1] = field
			end
		end
	end
	return delta, changedFields
end

return M
