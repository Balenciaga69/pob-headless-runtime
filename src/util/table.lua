-- Table helpers for small standard-library gaps.
local M = {}

-- Copy a dense array so callers do not mutate shared defaults or capability tables.
function M.copyArray(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

-- Copy one table layer for snapshot/restore flows and output wrapping.
function M.shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

return M
