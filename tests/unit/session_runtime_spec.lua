local runtimeCallbacksModule = require("runtime.callbacks")
local runtimeSessionModule = require("runtime.session")
local expect = require("testkit").expect

local callbacksModule = runtimeCallbacksModule
local sessionModule = runtimeSessionModule

local function newSession()
    local callbacks = callbacksModule.new()
    callbacks.setMainObject({
        main = {
            modes = {},
        },
    })

    local session = sessionModule.new({
        sourceDir = "src",
        runtimeDir = "runtime",
        repoRoot = ".",
        currentWorkDir = "src",
    }, callbacks)

    return session, callbacks
end

do
    local session = newSession()
    expect(type(session:getRepos()) == "table", "expected session repos table")
    expect(type(session:getServices()) == "table", "expected session services table")
    expect(type(session.api) == "table", "expected session api table")
    expect(type(session.api.load_build_xml) == "function", "expected session api surface")
    expect(type(session.api.experimental) == "table", "expected session experimental namespace")
    expect(
        type(session.api.experimental.load_build_file) == "function",
        "expected experimental build helper namespace"
    )
    expect(
        session.api.load_build_file == nil,
        "expected experimental helper to stay off stable root"
    )
    local status = session:getStatus()
    expect(status.initDispatched == false, "expected initDispatched=false initially")
    expect(status.mainReady == true, "expected mainReady=true with fake main object")
    expect(status.buildReady == false, "expected buildReady=false initially")
    expect(status.pendingActionCount == 0, "expected empty pending queue initially")
end

do
    local session, callbacks = newSession()
    local actionRuns = 0

    session:enqueueAction(function(_, currentSession)
        actionRuns = actionRuns + 1

        callbacks.mainObject.main.modes["BUILD"] = {
            calcsTab = {
                mainOutput = {
                    Life = 321,
                },
            },
        }

        if actionRuns >= 2 then
            callbacks.markHeadlessDone()
            return true
        end

        return false
    end)

    local status, err = session:runUntilSettled({
        maxFrames = 5,
        maxSeconds = 0.5,
    })

    expect(not err, err)
    expect(status.headlessDone == true, "expected headlessDone after stop request")
    expect(status.outputReady == true, "expected outputReady after fake build became available")
    expect(actionRuns == 2, "expected pending action to be retried until completion")
end

do
    local session = newSession()
    session:enqueueAction(function()
        return false
    end)

    local status, err = session:runUntilSettled({
        maxFrames = 2,
        maxSeconds = 0.5,
    })

    expect(status == nil, "expected timeout to return nil status")
    expect(
        type(err) == "string" and err:match("did not settle"),
        "expected bounded loop timeout error"
    )
    expect(err:match("pending=1"), "expected timeout error to include pending count")
end

do
    local session, callbacks = newSession()
    callbacks.activeDepth = 1

    local status, err = session:runUntilSettled()
    expect(status == nil, "expected no status when called inside callback")
    expect(
        err == "runUntilSettled() cannot be called from inside callbacks",
        "expected callback guard error"
    )
end

do
    local session, callbacks = newSession()
    local importPassiveCalls = 0
    local importItemsCalls = 0

    callbacks.mainObject.main.SetMode = function(_, mode)
        callbacks.mainObject.main.modes[mode] = {
            importTab = {
                ImportItemsAndSkills = function(_, itemsJson)
                    importItemsCalls = importItemsCalls + 1
                    expect(itemsJson == '{"items":[]}', "expected item json to be forwarded")
                    return {
                        name = "Offline",
                    }
                end,
                ImportPassiveTreeAndJewels = function(_, treeJson, charData)
                    importPassiveCalls = importPassiveCalls + 1
                    expect(treeJson == '{"hashes":[1]}', "expected passive json to be forwarded")
                    expect(
                        charData and charData.name == "Offline",
                        "expected imported character data to be reused"
                    )
                end,
            },
        }
    end

    session:installLegacyHelpers()

    expect(type(_G.newBuild) == "function", "expected legacy newBuild helper")
    expect(type(_G.loadBuildFromXML) == "function", "expected legacy loadBuildFromXML helper")
    expect(type(_G.loadBuildFromJSON) == "function", "expected legacy loadBuildFromJSON helper")
    expect(type(PoBHeadless.queue) == "function", "expected legacy queue helper")
    expect(type(PoBHeadless.stop) == "function", "expected legacy stop helper")
    expect(type(PoBHeadless.experimental) == "table", "expected legacy experimental namespace")
    expect(
        type(PoBHeadless.load_build_file) == "function",
        "expected legacy flattened experimental helper"
    )
    expect(
        type(PoBHeadless.experimental.load_build_file) == "function",
        "expected legacy namespaced experimental helper"
    )

    local build = _G.loadBuildFromJSON('{"items":[]}', '{"hashes":[1]}')
    expect(build ~= nil, "expected legacy loadBuildFromJSON to return build")
    expect(importItemsCalls == 1, "expected importer items helper to run once")
    expect(importPassiveCalls == 1, "expected importer passive helper to run once")

    PoBHeadless.queue(function(_, currentSession)
        expect(currentSession == session, "expected queue to receive current session")
        return true
    end)
    session:runPendingActions()
    PoBHeadless.stop()
    expect(callbacks.headlessDone == true, "expected stop helper to mark headless done")
end
