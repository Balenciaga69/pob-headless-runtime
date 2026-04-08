-- Headless stubs for GUI and native-only APIs.
local contextModule = require("entry.context")
local pathUtil = require("util.path")
local tableUtil = require("util.table")
local pobCode = require("api.repo.pob_code")

local M = {}

local CAPABILITY_MATRIX = {
	deterministicFake = {
		"GetScreenSize",
		"GetScreenScale",
		"GetVirtualScreenSize",
		"GetDPIScaleOverridePercent",
		"DrawStringWidth",
		"DrawStringCursorIndex",
		"GetAsyncCount",
		"Copy",
		"Paste",
		"GetTime",
		"GetScriptPath",
		"GetRuntimePath",
		"GetUserPath",
		"SetWorkDir",
		"GetWorkDir",
		"Exit",
	},
	safeNoOp = {
		"RenderInit",
		"SetDPIScaleOverridePercent",
		"SetClearColor",
		"SetDrawLayer",
		"SetViewport",
		"SetDrawColor",
		"DrawImage",
		"DrawImageQuad",
		"DrawString",
		"NewFileSearch",
		"SetWindowTitle",
		"SetCursorPos",
		"ShowCursor",
		"MakeDir",
		"RemoveDir",
		"ConPrintTable",
		"ConExecute",
		"ConClear",
		"SetProfiling",
	},
	unsupported = {
		"LaunchSubScript",
		"AbortSubScript",
		"IsSubScriptRunning",
		"SpawnProcess",
		"OpenURL",
		"Restart",
		"TakeScreenshot",
	},
	compatibilityShim = {
		"Deflate",
		"Inflate",
	},
}

local function cloneCapabilityMatrix()
	-- Copy the capability matrix so callers cannot mutate the source tables.
	return {
		deterministicFake = tableUtil.copyArray(CAPABILITY_MATRIX.deterministicFake),
		safeNoOp = tableUtil.copyArray(CAPABILITY_MATRIX.safeNoOp),
		unsupported = tableUtil.copyArray(CAPABILITY_MATRIX.unsupported),
		compatibilityShim = tableUtil.copyArray(CAPABILITY_MATRIX.compatibilityShim),
	}
end

local function unsupportedStub(name)
	-- Build an erroring stub for APIs that cannot run in headless mode.
	return function()
		error(name .. "() is unavailable in the headless runtime; this flow requires a real GUI/runtime host", 2)
	end
end

function M.getCapabilityMatrix()
	-- Return a defensive copy of the capability matrix.
	return cloneCapabilityMatrix()
end

function M.install(context, callbacks)
	-- Install headless replacements for the GUI/runtime-only global APIs.
	context.clipboardText = context.clipboardText or ""

	_G.runCallback = function(name, ...)
		return callbacks.runCallback(name, ...)
	end

	_G.SetCallback = function(name, func)
		callbacks.setCallback(name, func)
	end

	_G.GetCallback = function(name)
		return callbacks.getCallback(name)
	end

	_G.SetMainObject = function(obj)
		callbacks.setMainObject(obj)
	end

	_G.MarkHeadlessDone = function()
		callbacks.markHeadlessDone()
	end

	local imageHandleClass = {}
	imageHandleClass.__index = imageHandleClass

	function _G.NewImageHandle()
		return setmetatable({}, imageHandleClass)
	end

	function imageHandleClass:Load()
		self.valid = true
	end

	function imageHandleClass:Unload()
		self.valid = false
	end

	function imageHandleClass:IsValid()
		return self.valid
	end

	function imageHandleClass:SetLoadingPriority() end
	function imageHandleClass:ImageSize()
		return 1, 1
	end

	function _G.RenderInit() end
	function _G.GetScreenSize()
		return 1920, 1080
	end
	function _G.GetScreenScale()
		return 1
	end
	function _G.GetVirtualScreenSize()
		return 1920, 1080
	end
	function _G.GetDPIScaleOverridePercent()
		return 1
	end
	function _G.SetDPIScaleOverridePercent() end
	function _G.SetClearColor() end
	function _G.SetDrawLayer() end
	function _G.SetViewport() end
	function _G.SetDrawColor() end
	function _G.DrawImage() end
	function _G.DrawImageQuad() end
	function _G.DrawString() end
	function _G.DrawStringWidth()
		return 1
	end
	function _G.DrawStringCursorIndex()
		return 0
	end
	function _G.StripEscapes(text)
		return text:gsub("%^%d", ""):gsub("%^x%x%x%x%x%x%x", "")
	end
	function _G.GetAsyncCount()
		return 0
	end
	function _G.NewFileSearch() end
	function _G.SetWindowTitle() end
	function _G.GetCursorPos()
		return 0, 0
	end
	function _G.SetCursorPos() end
	function _G.ShowCursor() end
	function _G.IsKeyDown() end
	function _G.Copy(text)
		context.clipboardText = text == nil and "" or tostring(text)
		return true
	end
	function _G.Paste()
		return context.clipboardText
	end
	function _G.Deflate(data)
		local result, compressErr = pobCode.compress_raw(data)
		if not result then
			error(compressErr or "Deflate() failed", 2)
		end
		return result
	end
	function _G.Inflate(data)
		local result, inflateErr = pobCode.decompress_raw(data)
		if not result then
			error(inflateErr or "Inflate() failed", 2)
		end
		return result
	end
	function _G.GetTime()
		return 0
	end
	function _G.GetScriptPath()
		return context.sourceDir
	end
	function _G.GetRuntimePath()
		return context.runtimeDir
	end
	function _G.GetUserPath()
		return context.repoRoot
	end
	function _G.MakeDir() end
	function _G.RemoveDir() end
	function _G.SetWorkDir(path)
		context.currentWorkDir = pathUtil.normalizeDir(path)
	end
	function _G.GetWorkDir()
		return context.currentWorkDir
	end
	_G.LaunchSubScript = unsupportedStub("LaunchSubScript")
	_G.AbortSubScript = unsupportedStub("AbortSubScript")
	_G.IsSubScriptRunning = unsupportedStub("IsSubScriptRunning")

	function _G.LoadModule(fileName, ...)
		if not fileName:match("%.lua") then
			fileName = fileName .. ".lua"
		end
		local func, err = loadfile(contextModule.resolveSourcePath(context, fileName))
		if func then
			return func(...)
		end
		error("LoadModule() error loading '" .. fileName .. "': " .. err)
	end

	function _G.PLoadModule(fileName, ...)
		if not fileName:match("%.lua") then
			fileName = fileName .. ".lua"
		end
		local func, err = loadfile(contextModule.resolveSourcePath(context, fileName))
		if func then
			return _G.PCall(func, ...)
		end
		error("PLoadModule() error loading '" .. fileName .. "': " .. err)
	end

	function _G.PCall(func, ...)
		local ret = { pcall(func, ...) }
		if ret[1] then
			table.remove(ret, 1)
			return nil, unpack(ret)
		end
		return ret[2]
	end

	function _G.ConPrintf(fmt, ...)
		print(string.format(fmt, ...))
	end
	function _G.ConPrintTable() end
	function _G.ConExecute() end
	function _G.ConClear() end
	_G.SpawnProcess = unsupportedStub("SpawnProcess")
	_G.OpenURL = unsupportedStub("OpenURL")
	function _G.SetProfiling() end
	_G.Restart = unsupportedStub("Restart")
	function _G.Exit()
		callbacks.markHeadlessDone()
	end
	_G.TakeScreenshot = unsupportedStub("TakeScreenshot")

	function _G.GetCloudProvider()
		return nil, nil, nil
	end

	local nativeRequire = require
	function _G.require(name)
		if name == "lcurl.safe" then
			return
		end
		return nativeRequire(name)
	end

	_G.GetHeadlessStubCapabilities = function()
		return cloneCapabilityMatrix()
	end
end

return M
