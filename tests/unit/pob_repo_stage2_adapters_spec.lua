local skillsAdapterModule = require("api.repo.pob_skills_adapter")
local configAdapterModule = require("api.repo.pob_config_adapter")
local statsAdapterModule = require("api.repo.pob_stats_adapter")
local buildAdapterModule = require("api.repo.pob_build_adapter")
local expect = require("testkit").expect

do
	local skillsAdapter = skillsAdapterModule.new()
	local build = {
		mainSocketGroup = 2,
		skillsTab = {
			socketGroupList = {
				{ label = "A" },
				{
					label = "B",
					mainActiveSkill = 1,
					displaySkillList = {
						{
							activeEffect = {
								grantedEffect = { name = "Vortex" },
								srcInstance = { skillPart = 2 },
							},
						},
					},
				},
			},
			ProcessSocketGroup = function(_, group)
				group.processed = true
			end,
		},
		calcsTab = {
			input = {},
		},
	}

	expect(skillsAdapter:get_group(build, 2).label == "B", "expected skill group lookup")
	expect(skillsAdapter:get_selected_group_index(build) == 2, "expected selected group index")
	expect(skillsAdapter:get_calcs_skill_number(build) == nil, "expected nil skill number")
	skillsAdapter:set_calcs_skill_number(build, 2)
	expect(skillsAdapter:get_calcs_skill_number(build) == 2, "expected updated skill number")
	skillsAdapter:set_selected_group_index(build, 1)
	expect(build.mainSocketGroup == 1, "expected selected group mutation")
	skillsAdapter:process_socket_groups(build)
	expect(build.skillsTab.socketGroupList[1].processed == true, "expected socket group processing")
end

do
	local configAdapter = configAdapterModule.new()
	local build = {
		configTab = {
			input = { bandit = "None" },
			enemyLevel = 84,
		},
	}

	local snapshot = configAdapter:copy_snapshot(build)
	local input = configAdapter:get_input(build)
	configAdapter:set_enemy_level(build, 90)
	configAdapter:restore_snapshot(build, {
		input = { bandit = "Alira" },
		enemyLevel = 70,
	})

	expect(snapshot.input.bandit == "None", "expected config snapshot")
	expect(input.bandit == "None", "expected config input lookup")
	expect(configAdapter:get_enemy_level(build) == 70, "expected restored enemy level")
	expect(build.configTab.input.bandit == "Alira", "expected restored config input")
end

do
	local statsAdapter = statsAdapterModule.new()
	local build = {
		mainSocketGroup = 1,
		skillsTab = {
			socketGroupList = {
				{
					mainActiveSkill = 1,
					displaySkillList = {
						{
							activeEffect = {
								grantedEffect = { name = "Kinetic Blast" },
							},
						},
					},
				},
			},
		},
	}

	expect(statsAdapter:get_main_skill_name(build) == "Kinetic Blast", "expected main skill name")
end

do
	local buildAdapter = buildAdapterModule.new()
	local build = {
		spec = {
			curAscendClassId = 1,
			curClass = {
				classes = {
					[0] = { name = "None" },
					[1] = { name = "Occultist" },
				},
			},
		},
		skillsTab = {
			socketGroupList = {
				{},
			},
			ProcessSocketGroup = function(_, group)
				group.processed = true
			end,
		},
	}

	buildAdapter:prepare_for_save(build)
	expect(build.spec.curAscendClassName == "Occultist", "expected ascend class sync")
	expect(build.skillsTab.socketGroupList[1].processed == true, "expected socket group processing on save")
end
