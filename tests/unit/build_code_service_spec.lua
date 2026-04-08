local buildServiceModule = require("api.build.orchestrator")
local pobCode = require("api.build.helpers.code")
local expect = require("testkit").expect

do
    local previousCommon = common
    common = {
        xml = {
            ParseXML = function()
                return {
                    {
                        elem = "PathOfBuilding",
                        {
                            elem = "Build",
                            attrib = {
                                level = "97",
                                className = "Templar",
                                ascendClassName = "Hierophant",
                            },
                        },
                        { elem = "Tree" },
                    },
                }
            end,
        },
    }

    local captured = {}
    local xmlText =
        '<PathOfBuilding><Build level="97" className="Templar" ascendClassName="Hierophant"></Build><Tree></Tree></PathOfBuilding>'
    local encoded = pobCode.encode_xml(xmlText)
    local buildState = {
        buildName = "Encoded Build",
        characterLevel = 97,
        targetVersion = "3_28",
        xmlSectionList = { "Build", "Tree" },
        spec = {
            curClassName = "Templar",
            curAscendClassName = "Hierophant",
            treeVersion = "3_28",
        },
        SaveDB = function()
            captured.saveSession = true
            return xmlText
        end,
    }

    local session = {
        callbacks = {
            mainObject = {
                main = {
                    newMode = nil,
                    modes = {
                        BUILD = buildState,
                    },
                },
            },
        },
        ensureMainReady = function()
            return {
                SetMode = function(_, _, _, name, decodedXml)
                    captured.name = name
                    captured.decodedXml = decodedXml
                end,
            }
        end,
        runFramesIfIdle = function() end,
        runUntilSettled = function(_, options)
            captured.waitPredicate = options and options["until"] ~= nil
            return {
                buildReady = true,
                calcsReady = true,
                outputReady = true,
            }
        end,
        isInsideCallback = function()
            return false
        end,
        getBuild = function()
            captured.loadSession = true
            return buildState
        end,
    }
    local service = buildServiceModule.new({}, {
        importer = { update_imported_build = function() end },
        skills = { process_socket_groups = function() end },
    }, session, {})

    local build, err = service:load_build_code(encoded, "Encoded Build")
    expect(build ~= nil and err == nil, "expected load_build_code to succeed")
    expect(
        captured.decodedXml == xmlText,
        "expected load_build_code to decode xml before delegation"
    )
    expect(captured.name == "Encoded Build", "expected load_build_code to forward name")

    local code, saveErr = service:save_build_code()
    expect(code ~= nil and saveErr == nil, "expected save_build_code to succeed")
    local roundtripXml = pobCode.decode_to_xml(code)
    expect(roundtripXml == xmlText, "expected save_build_code to encode xml output")
    expect(captured.saveSession ~= nil, "expected save_build_code to call saveBuildXml")

    common = previousCommon
end

do
    local service = buildServiceModule.new({}, {
        importer = { update_imported_build = function() end },
        skills = { process_socket_groups = function() end },
    }, {}, {})
    local build, err = service:load_build_code(nil, "Broken")
    expect(build == nil, "expected missing code to fail")
    expect(err == "code is required", "expected missing code error")
end
