-- Build orchestrator handling load and save use cases.
local pobCode = require("api.build.helpers.code")
local loadValidation = require("api.build.helpers.load_validation")
local accessUtil = require("util.access")

local M = {}
M.__index = M

local function wait_for_loaded_build(session)
    -- Process the queued mode switch before checking readiness, otherwise the
    -- previous default build can satisfy the predicate immediately.
    session:runFramesIfIdle(1)

    local status, err = session:runUntilSettled({
        maxFrames = 120,
        maxSeconds = 5,
        ["until"] = function(runtimeStatus)
            local main = accessUtil.getMainObjectMain(session.callbacks.mainObject)
            local build = session:getBuild()
            local sectionCount = build and build.xmlSectionList and #build.xmlSectionList or 0
            local modeSwitchPending = main and main.newMode ~= nil

            return not modeSwitchPending
                and runtimeStatus.buildReady
                and runtimeStatus.calcsReady
                and runtimeStatus.outputReady
                and sectionCount > 0
        end,
    })
    if not status then
        return nil, err
    end
    if status.promptMsg then
        return nil, status.promptMsg
    end
    return session:getBuild()
end

function M.new(repos, services, session, fileUtil)
    return setmetatable({
        services = services,
        session = session,
        fileUtil = fileUtil,
        pob = require("api.build.pob").new(),
    }, M)
end

function M:load_build_xml(xmlText, name)
    if type(xmlText) ~= "string" or xmlText == "" then
        return nil, "xmlText is required"
    end

    local expectedState, parseErr = loadValidation.parse_expected_build_state(xmlText)
    if not expectedState then
        return nil, parseErr
    end

    local main = self.session:ensureMainReady()
    if not main then
        return nil, "main runtime is not ready"
    end

    main:SetMode("BUILD", false, name or "API Build", xmlText)
    if self.session:isInsideCallback() then
        -- Legacy queued smoke scripts call load methods from inside callbacks and
        -- expect the next frame to complete the mode transition asynchronously.
        self.session.lastBuildPath = nil
        return self.session:getBuild()
    end

    local build, loadErr = wait_for_loaded_build(self.session)
    if not build then
        return nil, loadErr
    end
    build, loadErr = loadValidation.validate_loaded_build(build, expectedState)
    if not build then
        return nil, loadErr
    end
    build.buildName = name or build.buildName or "API Build"
    self.session.lastBuildPath = nil
    return build
end

function M:load_build_file(path)
    if type(path) ~= "string" or path == "" then
        return nil, "path is required"
    end

    local xmlText, err = self.fileUtil.readAll(path, "build file")
    if not xmlText then
        return nil, err
    end

    local build, loadErr = self:load_build_xml(xmlText, path:match("([^/\\]+)%.xml$") or path)
    if not build then
        return nil, loadErr
    end

    build.buildName = path:match("([^/\\]+)%.xml$") or build.buildName
    self.session.lastBuildPath = path
    return build
end

function M:save_build_xml()
    local build = self.session:getBuild()
    if not build or not build.SaveDB then
        return nil, "build not initialized"
    end

    self.pob:prepare_for_save(build)
    self.services.skills:process_socket_groups(build)
    local xmlText = self.pob:save_build_xml(build, "headless-api-export")
    if not xmlText then
        return nil, "failed to compose xml"
    end

    return xmlText
end

function M:load_build_code(code, name)
    if type(code) ~= "string" or code == "" then
        return nil, "code is required"
    end

    local xmlText, err = pobCode.decode_to_xml(code)
    if not xmlText then
        return nil, err
    end

    return self:load_build_xml(xmlText, name)
end

function M:save_build_code()
    local xmlText, err = self:save_build_xml()
    if not xmlText then
        return nil, err
    end

    local code, encodeErr = pobCode.encode_xml(xmlText)
    if not code then
        return nil, encodeErr
    end

    return code
end

function M:save_build_file(path)
    local build = self.session:getBuild()
    if not build or not build.SaveDB then
        return nil, "build not initialized"
    end

    local targetPath = path or self.session.lastBuildPath or build.dbFileName
    if type(targetPath) ~= "string" or targetPath == "" then
        return nil, "path is required"
    end

    local xmlText, err = self:save_build_xml()
    if not xmlText then
        return nil, err
    end

    local result, writeErr = self.fileUtil.writeAll(targetPath, xmlText, "build file")
    if not result then
        return nil, writeErr
    end

    build.buildName = targetPath:match("([^/\\]+)%.xml$") or build.buildName
    self.session.lastBuildPath = targetPath
    return result
end

function M:update_imported_build(params)
    return self.services.importer:update_imported_build(params)
end

return M
