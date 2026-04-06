-- Callback manager that guards frame hook execution.
local M = {}

-- Create a callback manager instance.
-- Uses a separate runtime namespace to clearly separate entry layer and callback execution responsibilities.
function M.new()
    local state = {
        callbackTable = {},
        mainObject = nil,
        headlessDone = false,
        activeDepth = 0
    }

    -- Run the main object handler first, then let the headless override replace it if needed.
    function state.runCallback(name, ...)
        state.activeDepth = state.activeDepth + 1
        local mainResult
        if state.mainObject and state.mainObject[name] then
            mainResult = state.mainObject[name](state.mainObject, ...)
        end
        if state.callbackTable[name] then
            local callbackResult = state.callbackTable[name](...)
            if callbackResult ~= nil then
                state.activeDepth = state.activeDepth - 1
                return callbackResult
            end
        end
        state.activeDepth = state.activeDepth - 1
        return mainResult
    end

    function state.setCallback(name, func)
        state.callbackTable[name] = func
    end

    function state.getCallback(name)
        return state.callbackTable[name]
    end

    function state.setMainObject(obj)
        state.mainObject = obj
    end

    function state.markHeadlessDone()
        state.headlessDone = true
    end

    return state
end

return M
