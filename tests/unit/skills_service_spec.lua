local skillsServiceModule = require("api.skills.orchestrator")
local expect = require("testkit").expect

do
    local calls = {
        runFrames = 0,
    }
    local service = skillsServiceModule.new({
        runtime = {
            ensure_build_ready = function()
                return {
                    mainSocketGroup = 1,
                    skillsTab = {
                        socketGroupList = {
                            { displaySkillList = { {} }, mainActiveSkill = 1 },
                        },
                    },
                    calcsTab = { input = {} },
                }
            end,
            run_frames_if_idle = function(_, count)
                calls.runFrames = calls.runFrames + (count or 0)
            end,
        },
    })
    service.pob = {
        get_selected_group_index = function(_, _)
            return 1
        end,
        get_group = function(_, build, groupIndex)
            return build.skillsTab.socketGroupList[groupIndex]
        end,
        set_selected_group_index = function(build, groupIndex)
            build.mainSocketGroup = groupIndex
        end,
        set_calcs_skill_number = function(build, groupIndex)
            build.calcsTab = build.calcsTab or { input = {} }
            build.calcsTab.input = build.calcsTab.input or {}
            build.calcsTab.input.skill_number = groupIndex
        end,
        get_socket_groups = function(_, build)
            return build.skillsTab.socketGroupList
        end,
        get_calcs_skill_number = function(_, build)
            return build.calcsTab.input.skill_number
        end,
    }

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
            ensure_build_ready = function()
                return {
                    mainSocketGroup = 2,
                    skillsTab = {
                        socketGroupList = {
                            { displaySkillList = {}, mainActiveSkill = 1 },
                            [2] = {
                                label = "Cold",
                                displayLabel = "Cold",
                                mainActiveSkill = 3,
                                displaySkillList = {
                                    [3] = {
                                        activeEffect = {
                                            grantedEffect = {
                                                name = "Vortex",
                                                parts = { [1] = { name = "Hit" } },
                                            },
                                            srcInstance = { skillPart = 1 },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    calcsTab = { input = {} },
                }
            end,
            run_frames_if_idle = function(_, count)
                calls.runFrames = calls.runFrames + (count or 0)
            end,
        },
    }
    local service = skillsServiceModule.new(repos)
    service.pob = {
        get_selected_group_index = function(_, build)
            return build.mainSocketGroup
        end,
        get_group = function(_, build, groupIndex)
            return build.skillsTab.socketGroupList[groupIndex]
        end,
        set_selected_group_index = function(build, groupIndex)
            build.mainSocketGroup = groupIndex
        end,
        set_calcs_skill_number = function(build, groupIndex)
            build.calcsTab = build.calcsTab or { input = {} }
            build.calcsTab.input = build.calcsTab.input or {}
            build.calcsTab.input.skill_number = groupIndex
        end,
        get_socket_groups = function(_, build)
            return build.skillsTab.socketGroupList
        end,
        get_calcs_skill_number = function(_, build)
            return build.calcsTab.input.skill_number
        end,
    }

    local result, err = service:restore_skill_selection({
        group = { index = 2, displayLabel = "Cold" },
        skill = { index = 3, name = "Vortex" },
        part = { index = 1 },
    })
    expect(result ~= nil and err == nil, "expected restore_skill_selection to succeed")
    expect(calls.runFrames == 1, "expected restore_skill_selection to advance one frame")
    expect(result.skill.name == "Vortex", "expected restored skill snapshot")
end
