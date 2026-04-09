local statsSkillContext = require("api.stats.skill_context")
local expect = require("testkit").expect

do
    local vitality = {
        activeEffect = {
            grantedEffect = {
                name = "Vitality",
            },
        },
    }
    local herald = {
        activeEffect = {
            grantedEffect = {
                name = "Herald of Thunder",
            },
        },
    }
    local damageSkill = {
        activeEffect = {
            grantedEffect = {
                name = "Kinetic Blast",
                parts = {
                    [1] = { name = "All Projectiles" },
                },
            },
            srcInstance = {
                skillPartCalcs = 1,
            },
        },
    }
    local build = {
        mainSocketGroup = 2,
        skillsTab = {
            socketGroupList = {
                [1] = {
                    displayLabel = "Vitality, Herald of Thunder",
                    mainActiveSkillCalcs = 1,
                    displaySkillListCalcs = {
                        [1] = vitality,
                        [2] = herald,
                    },
                },
                [2] = {
                    displayLabel = "Kinetic Blast",
                    mainActiveSkillCalcs = 1,
                    displaySkillListCalcs = {
                        [1] = damageSkill,
                    },
                },
            },
        },
        calcsTab = {
            input = {
                skill_number = 1,
            },
            mainEnv = {
                player = {
                    mainSkill = damageSkill,
                },
            },
        },
    }

    local context = statsSkillContext.resolve(build)
    expect(context ~= nil, "expected calcs skill context")
    expect(context.name == "Kinetic Blast", "expected calcs main skill name")
    expect(context.socketGroupIndex == 2, "expected calcs main skill group")
    expect(context.skillIndex == 1, "expected calcs main skill index")
    expect(context.skillPartIndex == 1, "expected calcs main skill part")
    expect(context.skillPartName == "All Projectiles", "expected calcs main skill part name")
    expect(context.selectionSource == "calcs", "expected calcs main skill source")
end

do
    local frostbolt = {
        activeEffect = {
            grantedEffect = {
                name = "Frostbolt",
            },
        },
    }
    local build = {
        mainSocketGroup = 1,
        skillsTab = {
            socketGroupList = {
                [1] = {
                    displayLabel = "Frostbolt",
                    mainActiveSkill = 1,
                    displaySkillList = {
                        [1] = frostbolt,
                    },
                },
            },
        },
        calcsTab = {
            input = {
                skill_number = 1,
            },
        },
    }

    local context = statsSkillContext.resolve(build)
    expect(context ~= nil, "expected fallback skill context")
    expect(context.name == "Frostbolt", "expected fallback main skill name")
    expect(context.socketGroupIndex == 1, "expected fallback main skill group")
    expect(context.skillIndex == 1, "expected fallback main skill index")
    expect(context.selectionSource == "main", "expected fallback main skill source")
end
