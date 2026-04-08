-- Runtime session that orchestrates build, callbacks, and services.
local apiModule = require("api.init")
local repoModule = require("api.repo")
local serviceModule = require("api.service")
local accessUtil = require("util.access")
local sessionLoop = require("runtime.session.loop")
local sessionStatus = require("runtime.session.status")
local sessionActions = require("runtime.session.actions")
local sessionHelpers = require("runtime.session.helpers")

local M = {}

local Session = {}
Session.__index = Session

function Session:getBuild()
    -- Refresh the cached build from the current main object before returning it.
    self.build = accessUtil.getBuildMode(self.callbacks.mainObject)
    return self.build
end

function Session:isInsideCallback()
    -- Delegate the re-entrancy check to the status helper module.
    return sessionStatus.isInsideCallback(self)
end

function Session:ensureMainReady()
    -- Delegate the one-frame retry logic to the loop helper module.
    return sessionLoop.ensureMainReady(self)
end

function Session:runFramesIfIdle(frameCount)
    -- Avoid advancing frames while a callback is already on the stack.
    return sessionLoop.runFramesIfIdle(self, frameCount)
end

function Session:runFrames(frameCount)
    -- Keep the main frame stepping logic isolated in the loop helper.
    return sessionLoop.runFrames(self, frameCount)
end

function Session:getStatus()
    -- Return the current readiness snapshot through the status helper.
    return sessionStatus.getStatus(self)
end

function Session:runUntilSettled(options)
    -- Reuse the loop helper so timeout and predicate handling stay centralized.
    return sessionLoop.runUntilSettled(self, options)
end

function Session:enqueueAction(action)
    -- Queue deferred work through the action helper.
    return sessionActions.enqueueAction(self, action)
end

function Session:runPendingActions()
    -- Execute queued actions under the same callback-depth rules.
    return sessionActions.runPendingActions(self)
end

function Session:finalizeBuild()
    -- Publish the final build through the status helper.
    return sessionStatus.finalizeBuild(self)
end

function Session:loadHeadlessScript(argv)
    -- Load optional helper scripts through the helper module.
    return sessionHelpers.loadHeadlessScript(self, argv)
end

function Session:installLegacyHelpers()
    -- Expose compatibility helpers without spreading legacy code into session.lua.
    return sessionHelpers.installLegacyHelpers(self)
end

function Session:getAdapters()
    -- Preserve the deprecated adapter alias for old callers.
    return sessionHelpers.getAdapters(self)
end

function Session:getRepos()
    -- Expose the repo bundle through the helper module.
    return sessionHelpers.getRepos(self)
end

function Session:getServices()
    -- Expose the service bundle through the helper module.
    return sessionHelpers.getServices(self)
end

function M.new(context, callbacks)
    -- Build the session object, then wire repos, services, and API facades.
    local session = setmetatable({
        context = context,
        callbacks = callbacks,
        build = nil,
        initDispatched = false,
        pendingActions = {},
        executingPendingActions = false,
    }, Session)

    session.repos = repoModule.create(session)
    session.services = serviceModule.create(session, session.repos)
    session.api = apiModule.create(session)
    return session
end

return M
