local skillsServiceModule = require("api.service.skills")
local expect = require("testkit").expect

do
	local calls = {
		runFrames = 0,
	}
	local service = skillsServiceModule.new({
		runtime = {
			run_frames_if_idle = function(_, count)
				calls.runFrames = calls.runFrames + (count or 0)
			end,
		},
		skills = {
			apply_selection = function()
				return {
					group = { index = 1 },
				}
			end,
			list_skills = function()
				return {
					mainSocketGroup = 1,
					groups = {
						{ index = 1, isSelected = true, skills = {} },
					},
				}
			end,
		},
	})

	local result, err = service:select_skill({ group = 1 })
	expect(result ~= nil and err == nil, "expected select_skill to succeed")
	expect(calls.runFrames == 1, "expected select_skill to advance one frame")
end

do
	local calls = {
		runFrames = 0,
	}
	local repos = {
		runtime = {
			run_frames_if_idle = function(_, count)
				calls.runFrames = calls.runFrames + (count or 0)
			end,
		},
		skills = {
			list_skills = function()
				return {
					groups = {
						{
							index = 2,
							label = "Cold",
							displayLabel = "Cold",
							isSelected = false,
							skills = {
								{ index = 3, name = "Vortex" },
							},
						},
					},
				}
			end,
			apply_selection = function(_, params)
				expect(params.group == 2, "expected resolved group index")
				expect(params.skill == 3, "expected resolved skill index")
				expect(params.part == 1, "expected resolved part index")
				return {
					group = { index = 2 },
				}
			end,
			get_selected_skill = function()
				return {
					group = { index = 2 },
					skill = { index = 3, name = "Vortex" },
					part = { index = 1, name = "Hit" },
				}
			end,
		},
	}
	local service = skillsServiceModule.new(repos)

	local result, err = service:restore_skill_selection({
		group = { index = 2, displayLabel = "Cold" },
		skill = { index = 3, name = "Vortex" },
		part = { index = 1 },
	})
	expect(result ~= nil and err == nil, "expected restore_skill_selection to succeed")
	expect(calls.runFrames == 1, "expected restore_skill_selection to advance one frame")
	expect(result.skill.name == "Vortex", "expected restored skill snapshot")
end
