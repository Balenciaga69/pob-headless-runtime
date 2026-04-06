local buildServiceModule = require("api.service.build")
local pobCode = require("util.pob_code")
local expect = require("testkit").expect

do
	local captured = {}
	local xmlText = "<PathOfBuilding><Build level=\"97\"></Build></PathOfBuilding>"
	local encoded = pobCode.encode_xml(xmlText)

	local repos = {
		build = {
			loadBuildXml = function(session, decodedXml, name)
				captured.loadSession = session
				captured.decodedXml = decodedXml
				captured.name = name
				return { buildName = name, xmlText = decodedXml }
			end,
			saveBuildXml = function(session)
				captured.saveSession = session
				return xmlText
			end,
		},
	}
	local service = buildServiceModule.new(repos, { importer = { update_imported_build = function() end } }, { id = "session" }, {})

	local build, err = service:load_build_code(encoded, "Encoded Build")
	expect(build ~= nil and err == nil, "expected load_build_code to succeed")
	expect(captured.decodedXml == xmlText, "expected load_build_code to decode xml before delegation")
	expect(captured.name == "Encoded Build", "expected load_build_code to forward name")

	local code, saveErr = service:save_build_code()
	expect(code ~= nil and saveErr == nil, "expected save_build_code to succeed")
	local roundtripXml = pobCode.decode_to_xml(code)
	expect(roundtripXml == xmlText, "expected save_build_code to encode xml output")
	expect(captured.saveSession ~= nil, "expected save_build_code to call saveBuildXml")
end

do
	local service = buildServiceModule.new({ build = {} }, { importer = { update_imported_build = function() end } }, {}, {})
	local build, err = service:load_build_code(nil, "Broken")
	expect(build == nil, "expected missing code to fail")
	expect(err == "code is required", "expected missing code error")
end
