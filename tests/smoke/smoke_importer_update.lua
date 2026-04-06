local api = PoBHeadless
local testkit = require("testkit")
local fixtureRoot = GetUserPath() .. "/custom/pob_headless_refactor/tests/fixtures"
local xmlPath = fixtureRoot .. "/mirage_example_xml.xml"
local passivePath = fixtureRoot .. "/importer_remote_passive.json"
local itemsPath = fixtureRoot .. "/importer_remote_items.json"
local accountName = "CodexSmokeAccount"
local characterName = "CodexSmokeCharacter"
local accountHash = "422c3d1cc68db6e0068c059001a2fb8fec2f8558"
local characterHash = "acd8e9c1033d10a6f3f0a2984352cbf621166444"

local function readText(path)
	local handle, err = io.open(path, "rb")
	if not handle then
		error("failed to read fixture: " .. tostring(err), 0)
	end

	local text = handle:read("*a")
	handle:close()
	return text
end

local build, loadErr = api.load_build_file(xmlPath)
if not build then
	error(loadErr, 0)
end

local baselineSummary, baselineErr = api.get_summary()
if not baselineSummary then
	error(baselineErr, 0)
end

local selectedSkill, selectedSkillErr = api.get_selected_skill()
if not selectedSkill then
	error(selectedSkillErr, 0)
end

testkit.expect(selectedSkill.skill and type(selectedSkill.skill.name) == "string", "importer_update: expected baseline selected skill")

local importTab = build.importTab
testkit.expect(importTab ~= nil, "importer_update: expected real importTab on loaded build")
testkit.expect(importTab.controls ~= nil, "importer_update: expected importer controls")
testkit.expect(importTab.controls.accountName ~= nil, "importer_update: expected account name control")
build.treeTab.activeSpec = math.max(1, tonumber(build.treeTab and build.treeTab.activeSpec) or 1)

local passiveJson = readText(passivePath)
local itemsJson = readText(itemsPath)
local observedCalls = {}

importTab.controls.accountName.buf = accountName
importTab.lastAccountHash = accountHash
importTab.lastCharacterHash = characterHash
importTab.charImportMode = "GETACCOUNTNAME"

importTab.DownloadCharacterList = function(self)
	observedCalls[#observedCalls + 1] = "characters"
	self.charImportMode = "IMPORTING"
	self.controls.charSelect = self.controls.charSelect or {}
	self.controls.charSelect.list = {
		{
			char = {
				name = characterName,
			},
		},
	}
	self.controls.charSelect.selIndex = 1
	self.charImportMode = "SELECTCHAR"
end

importTab.DownloadPassiveTree = function(self)
	observedCalls[#observedCalls + 1] = "passive"
	self.charImportMode = "IMPORTING"
	local passiveData, passiveErr = self:ProcessJSON(passiveJson)
	testkit.expect(passiveData ~= nil and passiveErr == nil, "importer_update: expected passive importer fixture to parse")
	self.charImportMode = "SELECTCHAR"
end

importTab.DownloadItems = function(self)
	observedCalls[#observedCalls + 1] = "items"
	self.charImportMode = "IMPORTING"
	self:ImportItemsAndSkills(itemsJson)
	self.charImportMode = "SELECTCHAR"
end

local result, updateErr = api.update_imported_build()
if not result then
	error(updateErr, 0)
end

local updatedSummary, summaryErr = api.get_summary()
if not updatedSummary then
	error(summaryErr, 0)
end

testkit.expect(result.updated == true, "importer_update: expected updated flag")
testkit.expect(result.importMode == "remote_import", "importer_update: expected remote import mode")
testkit.expect(result.restoredSkillSelection == true, "importer_update: expected skill restore after remote import")
testkit.expect(result.skillSelection and result.skillSelection.skill and type(result.skillSelection.skill.name) == "string", "importer_update: expected restored skill selection")
testkit.expect(#observedCalls == 3, "importer_update: expected remote importer download sequence")
testkit.expect(observedCalls[1] == "characters", "importer_update: expected character list download first")
testkit.expect(observedCalls[2] == "passive", "importer_update: expected passive tree download second")
testkit.expect(observedCalls[3] == "items", "importer_update: expected items download third")
testkit.expect(updatedSummary.level == 100, "importer_update: expected imported character level to update")
testkit.expect(type(updatedSummary.mainSkill) == "string" and updatedSummary.mainSkill ~= "", "importer_update: expected summary main skill to remain restored")
testkit.expect(testkit.summaryStat(updatedSummary, "Life") ~= testkit.summaryStat(baselineSummary, "Life"), "importer_update: expected importer smoke to change life")

print("importerMode", result.importMode)
print("importerLevel", updatedSummary.level or 0)
print("importerLifeDelta", testkit.summaryStat(updatedSummary, "Life") - testkit.summaryStat(baselineSummary, "Life"))
print("importerSkill", updatedSummary.mainSkill or "")

api.stop()
