local api = PoBHeadless
local testkit = require("testkit")

local function firstExistingPath(paths)
	for _, path in ipairs(paths) do
		local handle = io.open(path, "rb")
		if handle then
			handle:close()
			return path
		end
	end
	return paths[1]
end

local fixtureRoot = firstExistingPath({
	GetUserPath() .. "/pob-headless-runtime/tests/fixtures/mirage_example_xml.xml",
	GetUserPath() .. "/custom/pob-headless-runtime/tests/fixtures/mirage_example_xml.xml",
}):gsub("[/\\][^/\\]+$", "")
local xmlPath = fixtureRoot .. "/mirage_example_xml.xml"
local codePath = fixtureRoot .. "/mirage_exmple_code.txt"

local function readAll(path)
	local file, err = io.open(path, "rb")
	if not file then
		return nil, err
	end
	local text = file:read("*a")
	file:close()
	return text
end

local loaded = false
local savedCode
local baselineSummary
local fixtureCode
local roundtripLoaded = false

api.queue(function()
	if not loaded then
		local build, err = api.load_build_file(xmlPath)
		if not build then
			error(err, 0)
		end
		loaded = true
		return false
	end

	local summary, err = api.get_summary()
	if not summary then
		return false
	end

	if not baselineSummary then
		baselineSummary = summary
		fixtureCode = readAll(codePath)
		if not fixtureCode then
			error("failed to read code fixture: " .. tostring(codePath), 0)
		end
		fixtureCode = fixtureCode:gsub("%s+$", "")

		local build, loadErr = api.load_build_code(fixtureCode, "Roundtrip Test")
		if not build then
			error(loadErr, 0)
		end
		return false
	end

	local roundtripSummary, roundtripErr = api.get_summary()
	if not roundtripSummary then
		return false
	end

	if not roundtripLoaded then
		roundtripLoaded = true
		local code, codeErr = api.save_build_code()
		if not code then
			error(codeErr, 0)
		end
		testkit.expect(type(code) == "string" and #code > 0, "build_code: expected non-empty build code")
		savedCode = code

		local build, loadErr = api.load_build_code(savedCode, "Roundtrip Saved")
		if not build then
			error(loadErr, 0)
		end
		return false
	end

	testkit.expectSummaryUnchanged(
		baselineSummary,
		roundtripSummary,
		{ "Life", "EnergyShield", "CombinedDPS" },
		"build_code"
	)
	testkit.expect(
		baselineSummary.mainSkill == roundtripSummary.mainSkill,
		"build_code: expected main skill to remain unchanged"
	)

	print("buildCodeLength", #savedCode)
	print("mainSkill", roundtripSummary.mainSkill or "")
	print("life", testkit.summaryStat(roundtripSummary, "Life"))
	print("energyShield", testkit.summaryStat(roundtripSummary, "EnergyShield"))
	print("combinedDps", testkit.summaryStat(roundtripSummary, "CombinedDPS"))

	api.stop()
	return true
end)
