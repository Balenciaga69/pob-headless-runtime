-- Runtime session that orchestrates build, callbacks, and services.
local apiModule = require("api.init")
local repoModule = require("api.repo")
local serviceModule = require("api.service")
local accessUtil = require("util.access")
local fileUtil = require("util.file")
local runtimeStateUtil = require("runtime.runtime_state")
local legacyAdapter = require("runtime.session.legacy_adapter")

local M = {}

local Session = {}
Session.__index = Session

local function formatBool(value)
	-- Render booleans in the timeout message payload.
	return value and "true" or "false"
end

local function buildTimeoutMessage(status, maxFrames, maxSeconds)
	-- Format a timeout message that includes the current readiness flags.
	return string.format(
		"headless runtime did not settle within %d frame(s) / %.2f second(s) (pending=%d, mainReady=%s, buildReady=%s, calcsReady=%s, outputReady=%s)",
		maxFrames,
		maxSeconds,
		status.pendingActionCount or 0,
		formatBool(status.mainReady),
		formatBool(status.buildReady),
		formatBool(status.calcsReady),
		formatBool(status.outputReady)
	)
end

function Session:getBuild()
	-- Refresh the cached build from the current main object before returning it.
	self.build = accessUtil.getBuildMode(self.callbacks.mainObject)
	return self.build
end

function Session:isInsideCallback()
	-- Re-entrant callback execution is unsafe for frame advancement.
	return (self.callbacks.activeDepth or 0) > 0 or self.executingPendingActions == true
end

function Session:ensureMainReady()
	-- Try once immediately, then let one frame pass if the main object is still missing.
	local main = accessUtil.getMainObjectMain(self.callbacks.mainObject)
	if main then
		return main
	end

	self:runFramesIfIdle(1)
	main = accessUtil.getMainObjectMain(self.callbacks.mainObject)
	if main then
		return main
	end

	return nil
end

function Session:runFramesIfIdle(frameCount)
	-- Do not advance frames while already inside callback execution.
	if self:isInsideCallback() then
		self:getBuild()
		return
	end
	self:runFrames(frameCount)
end

function Session:runFrames(frameCount)
	-- Dispatch OnInit once, then keep stepping frames until the runtime asks us to stop.
	if not self.initDispatched then
		self.callbacks.runCallback("OnInit")
		self.initDispatched = true
	end

	for _ = 1, frameCount or 10 do
		if runtimeStateUtil.shouldStop(self.callbacks) then
			break
		end
		self.callbacks.runCallback("OnFrame")
		self:getBuild()
		self:runPendingActions()
		self:getBuild()
		if runtimeStateUtil.shouldStop(self.callbacks) then
			break
		end
	end
end

function Session:getStatus()
	-- Expose readiness flags that drive settle loops and external tooling.
	local main = accessUtil.getMainObjectMain(self.callbacks.mainObject)
	local build = accessUtil.getBuildMode(self.callbacks.mainObject)
	local calcsTab = build and build.calcsTab or nil
	local output = calcsTab and calcsTab.mainOutput or nil
	local promptMsg = runtimeStateUtil.getPromptMessage(self.callbacks)

	return {
		initDispatched = self.initDispatched == true,
		mainReady = main ~= nil,
		buildReady = build ~= nil,
		calcsReady = calcsTab ~= nil,
		outputReady = output ~= nil,
		pendingActionCount = #self.pendingActions,
		executingPendingActions = self.executingPendingActions == true,
		insideCallback = self:isInsideCallback(),
		activeDepth = self.callbacks.activeDepth or 0,
		headlessDone = self.callbacks.headlessDone == true,
		promptMsg = promptMsg,
		stopRequested = runtimeStateUtil.shouldStop(self.callbacks),
	}
end

function Session:runUntilSettled(options)
	-- Advance the runtime until it is ready, a caller predicate passes, or a timeout hits.
	if self:isInsideCallback() then
		return nil, "runUntilSettled() cannot be called from inside callbacks"
	end

	options = options or {}
	local maxFrames = math.max(1, tonumber(options.maxFrames) or 200)
	local maxSeconds = tonumber(options.maxSeconds) or 5
	local startClock = os.clock()
	local predicate = options["until"]

	local function isSettled(status)
		if type(predicate) == "function" then
			return predicate(status, self) == true
		end

		return status.initDispatched
			and status.mainReady
			and status.pendingActionCount == 0
	end

	local frames = 0
	while true do
		local status = self:getStatus()
		if status.stopRequested then
			return status, nil
		end
		if isSettled(status) then
			return status, nil
		end
		if frames >= maxFrames then
			return nil, buildTimeoutMessage(status, maxFrames, maxSeconds)
		end
		if maxSeconds >= 0 and (os.clock() - startClock) >= maxSeconds then
			return nil, buildTimeoutMessage(status, maxFrames, maxSeconds)
		end

		self:runFrames(1)
		frames = frames + 1
	end
end

function Session:enqueueAction(action)
	-- Queue work so it can run on the next safe frame boundary.
	self.pendingActions[#self.pendingActions + 1] = action
end

function Session:runPendingActions()
	-- Pending actions run under callback depth so nested execution is tracked correctly.
	if #self.pendingActions == 0 then
		return
	end

	self.executingPendingActions = true
	self.callbacks.activeDepth = (self.callbacks.activeDepth or 0) + 1
	local remaining = {}
	for _, action in ipairs(self.pendingActions) do
		local ok, doneOrErr = pcall(action, self.api, self)
		if not ok then
			self.callbacks.activeDepth = self.callbacks.activeDepth - 1
			self.executingPendingActions = false
			error(doneOrErr)
		end
		if doneOrErr ~= true then
			remaining[#remaining + 1] = action
		end
		if runtimeStateUtil.shouldStop(self.callbacks) then
			break
		end
	end

	self.pendingActions = remaining
	self.callbacks.activeDepth = self.callbacks.activeDepth - 1
	self.executingPendingActions = false
end

function Session:finalizeBuild()
	-- Publish the final build object and respect any prompt that still blocks completion.
	local promptMsg = runtimeStateUtil.getPromptMessage(self.callbacks)
	if promptMsg then
		return nil, promptMsg
	end

	local build = self:getBuild()
	_G.build = build
	return build, nil
end

function Session:loadHeadlessScript(argv)
	-- Optional helper scripts are loaded after the runtime is prepared.
	local scriptPath = os.getenv("POB_HEADLESS_SCRIPT")
	if not scriptPath or scriptPath == "" then
		return
	end

	local scriptText, err = fileUtil.readAll(scriptPath, "headless helper")
	if not scriptText then
		error(err)
	end

	local scriptFunc, compileErr = load(scriptText, "@" .. scriptPath)
	if not scriptFunc then
		error("Failed to compile headless helper " .. scriptPath .. ": " .. tostring(compileErr))
	end

	local previousArg = rawget(_G, "arg")
	_G.arg = argv or {}
	scriptFunc(unpack(argv or {}))
	_G.arg = previousArg
end

function Session:installLegacyHelpers()
	-- Install the compatibility surface expected by older helper entry points.
	legacyAdapter.install(self)
end

function Session:getAdapters()
	-- Deprecated compatibility alias; use getRepos() for new code.
	return self.repos
end

function Session:getRepos()
	return self.repos
end

function Session:getServices()
	return self.services
end

function M.new(context, callbacks)
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
