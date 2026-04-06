-- Legacy helper adapter for the historical global surface.
local accessUtil = require("util.access")

local M = {}

-- Install legacy helpers to global environment so existing headless scripts don't need immediate rewrites.
function M.install(session)
    -- Expose the old helper surface by wiring session-backed globals.
    local api = session.api

    function _G.newBuild()
        -- Reset the build mode and advance one frame to let PoB rebuild state.
        local main = accessUtil.getMainObjectMain(session.callbacks.mainObject)
        if not main then
            error("main runtime is not ready")
        end
        main:SetMode("BUILD", false, "Help, I'm stuck in Path of Building!")
        session:runFrames(1)
    end

    function _G.loadBuildFromXML(xmlText, name)
        -- Preserve the historical XML import helper name.
        return api.load_build_xml(xmlText, name)
    end

    function _G.loadBuildFromJSON(getItemsJSON, getPassiveSkillsJSON)
        -- Preserve the old JSON import helper used by legacy scripts.
        local main = accessUtil.getMainObjectMain(session.callbacks.mainObject)
        if not main then
            error("main runtime is not ready")
        end
        main:SetMode("BUILD", false, "")
        session:runFrames(1)
        local build = session:getBuild()
        local charData = build.importTab:ImportItemsAndSkills(getItemsJSON)
        build.importTab:ImportPassiveTreeAndJewels(getPassiveSkillsJSON, charData)
        return build
    end

    api.queue = function(action)
        -- Queue work for deferred execution on a safe frame boundary.
        if type(action) ~= "function" then
            error("queue(action) expects a function")
        end
        session:enqueueAction(action)
    end

    api.stop = function()
        -- Mark the runtime as complete for the settle loop.
        session.callbacks.markHeadlessDone()
    end

    _G.PoBHeadless = api
end

return M
