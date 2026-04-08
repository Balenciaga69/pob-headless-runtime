local api = PoBHeadless
local smokekit = require("smokekit")
local testkit = require("testkit")

local xmlPath = smokekit.resolveFixturePath("mirage_example_xml.xml")
local savedCode
local roundtripLoaded = false

smokekit.runQueuedSmoke(api, xmlPath, function(_, baselineSummary)
    if not roundtripLoaded then
        local fixtureCode = smokekit.readFixture("mirage_exmple_code.txt"):gsub("%s+$", "")
        local build, loadErr = api.load_build_code(fixtureCode, "Roundtrip Test")
        if not build then
            return false, loadErr
        end
        roundtripLoaded = true
        return false
    end

    local roundtripSummary, roundtripErr = api.get_summary()
    if not roundtripSummary then
        return false, roundtripErr
    end

    if not savedCode then
        local code, codeErr = api.save_build_code()
        if not code then
            return false, codeErr
        end
        testkit.expect(
            type(code) == "string" and #code > 0,
            "build_code: expected non-empty build code"
        )
        savedCode = code

        local build, loadErr = api.load_build_code(savedCode, "Roundtrip Saved")
        if not build then
            return false, loadErr
        end
        return false
    end

    local savedRoundtripSummary, savedRoundtripErr = api.get_summary()
    if not savedRoundtripSummary then
        return false, savedRoundtripErr
    end

    testkit.expectSummaryUnchanged(
        baselineSummary,
        savedRoundtripSummary,
        { "Life", "EnergyShield", "CombinedDPS" },
        "build_code"
    )
    testkit.expect(
        baselineSummary.mainSkill == savedRoundtripSummary.mainSkill,
        "build_code: expected main skill to remain unchanged"
    )

    print("buildCodeLength", #savedCode)
    print("mainSkill", savedRoundtripSummary.mainSkill or "")
    print("life", testkit.summaryStat(savedRoundtripSummary, "Life"))
    print("energyShield", testkit.summaryStat(savedRoundtripSummary, "EnergyShield"))
    print("combinedDps", testkit.summaryStat(savedRoundtripSummary, "CombinedDPS"))
    return true
end)
