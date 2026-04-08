-- Simulation helpers for snapshot and restore flows.
local tableUtil = require("util.table")

local M = {}

local RESERVED_KEYS = {
    kind = true,
    comparison = true,
    compareFields = true,
    before = true,
    after = true,
    delta = true,
    changedFields = true,
    _meta = true,
    restored = true,
    simulationMode = true
}

-- Wrap a compare result in a stable simulation envelope while preserving legacy fields.
function M.buildResult(kind, compared, extras)
    local result = {
        kind = kind,
        comparison = compared,
        compareFields = compared and compared.fields or nil,
        before = compared and compared.before or nil,
        after = compared and compared.after or nil,
        delta = compared and compared.delta or nil,
        changedFields = compared and compared.changedFields or nil,
        _meta = compared and compared._meta or nil,
        restored = extras and extras.restored == true or false,
        simulationMode = extras and extras.simulationMode or nil
    }

    for key, value in pairs(tableUtil.shallowCopy(extras)) do
        if not RESERVED_KEYS[key] then
            result[key] = value
        end
    end

    return result
end

return M
