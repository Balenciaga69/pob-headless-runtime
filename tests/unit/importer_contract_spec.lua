local importServiceModule = require("api.service.import")
local expect = require("testkit").expect

local function newService()
	local calls = {
		offline = 0,
		remote = 0,
		restore = 0,
		rebuild = 0,
		frames = 0,
	}

	local skillsSnapshot = {
		group = { index = 1, displayLabel = "Main" },
		skill = { index = 1, name = "Vortex" },
		part = { index = 1, name = "Hit" },
	}

	local repos = {
		importer = {
			execute_offline_import = function(_, params)
				calls.offline = calls.offline + 1
				return {
					build = { source = "offline" },
					importMode = "offline_payload",
					params = params,
				}
			end,
			execute_remote_import = function()
				calls.remote = calls.remote + 1
				return {
					build = { source = "remote" },
					importMode = "remote_import",
				}
			end,
		},
		runtime = {
			rebuild_imported_build = function(_, build)
				calls.rebuild = calls.rebuild + 1
				calls.lastBuild = build
				return true
			end,
			run_frames_if_idle = function(_, count)
				calls.frames = calls.frames + (count or 0)
			end,
		},
	}

	local services = {
		skills = {
			get_selected_skill = function()
				return skillsSnapshot
			end,
			restore_skill_selection = function(_, snapshot)
				calls.restore = calls.restore + 1
				calls.restoredSnapshot = snapshot
				return snapshot
			end,
		},
	}

	return importServiceModule.new(repos, services), calls, skillsSnapshot
end

do
	local service, calls, snapshot = newService()
	local result, err = service:update_imported_build({
		passiveTreeJson = "{\"hashes\":[1,2,3]}",
		itemsJson = "{\"items\":[]}",
		character = {
			name = "OccVortex",
			class = "Witch",
			level = 95,
			league = "Standard",
		},
	})

	expect(result ~= nil and err == nil, "expected offline import to succeed")
	expect(result.updated == true, "expected updated flag")
	expect(result.importMode == "offline_payload", "expected offline import mode")
	expect(result.restoredSkillSelection == true, "expected skill restore flag")
	expect(calls.offline == 1, "expected offline importer call")
	expect(calls.remote == 0, "expected no remote importer call")
	expect(calls.restore == 1, "expected one skill restore")
	expect(calls.rebuild == 1, "expected runtime rebuild")
	expect(calls.frames == 1, "expected runtime frame advance")
	expect(calls.restoredSnapshot == snapshot, "expected selected skill snapshot to be restored")
	expect(result.skillSelection == snapshot, "expected returned skill selection to match restored snapshot")
	expect(calls.lastBuild and calls.lastBuild.source == "offline", "expected offline build payload")
end

do
	local service = newService()
	local result, err = service:update_imported_build({
		passiveTreeJson = "{}",
	})

	expect(result == nil, "expected invalid offline import payload to fail")
	expect(err == "character is required", "expected character validation error")
end

do
	local service, calls = newService()
	local result, err = service:update_imported_build()

	expect(result ~= nil and err == nil, "expected remote import to succeed")
	expect(result.importMode == "remote_import", "expected remote import mode")
	expect(calls.remote == 1, "expected remote importer call")
	expect(calls.offline == 0, "expected no offline importer call")
	expect(calls.restore == 1, "expected skill restore after remote import")
	expect(calls.rebuild == 1, "expected runtime rebuild after remote import")
	expect(calls.frames == 1, "expected runtime frame advance after remote import")
end
