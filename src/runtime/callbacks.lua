-- Callback manager that guards frame hook execution.
local M = {}

-- Create a callback manager instance.
-- Uses a separate runtime namespace to clearly separate entry layer and callback execution responsibilities.
function M.new()
    -- Keep callback state isolated from the rest of the runtime objects.
    local state = {
        callbackTable = {},
        mainObject = nil,
        headlessDone = false,
        activeDepth = 0
    }

    -- Run the main object handler first, then let the headless override replace it if needed.
    function state.runCallback(name, ...)
        -- Nested callback depth is tracked so settle logic can detect re-entry.
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
        -- Register or replace a callback by name.
        state.callbackTable[name] = func
    end

    function state.getCallback(name)
        -- Fetch the current callback without executing it.
        return state.callbackTable[name]
    end

    function state.setMainObject(obj)
        -- Store the live PoB main object for later dispatch.
        state.mainObject = obj
    end

    function state.markHeadlessDone()
        -- Signal the settle loop that runtime execution can stop.
        state.headlessDone = true
    end

    return state
end

return M
