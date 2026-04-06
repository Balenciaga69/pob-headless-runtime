local M = {}

function M.expect(condition, message)
	if not condition then
		error(message or "expectation failed", 0)
	end
end

function M.normalizeNumber(value)
	return tonumber(value) or 0
end

function M.summaryStat(summary, field)
	local container = summary and summary.stats or summary
	return M.normalizeNumber(container and container[field])
end

function M.expectSummaryUnchanged(beforeSummary, afterSummary, fields, label)
	for _, field in ipairs(fields or {}) do
		M.expect(
			M.summaryStat(beforeSummary, field) == M.summaryStat(afterSummary, field),
			string.format("%s changed summary field %s unexpectedly", label or "summary", field)
		)
	end
end

function M.expectDeltaMatches(beforeSummary, afterSummary, delta, fields, label)
	for _, field in ipairs(fields or {}) do
		local beforeValue = M.summaryStat(beforeSummary, field)
		local afterValue = M.summaryStat(afterSummary, field)
		local deltaValue = M.normalizeNumber(delta and delta[field])
		M.expect(
			afterValue - beforeValue == deltaValue,
			string.format(
				"%s delta mismatch for %s: expected %s, got %s",
				label or "summary",
				field,
				afterValue - beforeValue,
				deltaValue
			)
		)
	end
end

function M.summaryReady(summary, err)
	if summary then
		return summary, true
	end

	if err == "no output available" or err == "build not initialized" then
		return nil, false
	end

	error(err, 0)
end

function M.newQueuedBuildFlow(api, xmlPath)
	local loaded = false
	local build

	return {
		load = function()
			if loaded then
				return build
			end

			local loadedBuild, err = api.load_build_file(xmlPath)
			if err then
				error(err, 0)
			end

			build = loadedBuild
			loaded = true
			return false
		end,
		build = function()
			return build
		end,
		summary = function()
			local summary, err = api.get_summary()
			return M.summaryReady(summary, err)
		end,
	}
end

return M
