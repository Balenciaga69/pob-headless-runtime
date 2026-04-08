-- Writable config field specs exposed through the headless API.
return {
    bandit = {
        apply = function(build, input, value)
            input.bandit = tostring(value)
        end,
    },
    pantheonMajorGod = {
        apply = function(build, input, value)
            input.pantheonMajorGod = tostring(value)
        end,
    },
    pantheonMinorGod = {
        apply = function(build, input, value)
            input.pantheonMinorGod = tostring(value)
        end,
    },
    enemyLevel = {
        apply = function(build, input, value, pob)
            pob:set_enemy_level(build, tonumber(value) or pob:get_enemy_level(build))
        end,
    },
    enemyFireResist = {
        apply = function(build, input, value)
            input.enemyFireResistance = tonumber(value)
        end,
    },
    enemyColdResist = {
        apply = function(build, input, value)
            input.enemyColdResistance = tonumber(value)
        end,
    },
    enemyLightningResist = {
        apply = function(build, input, value)
            input.enemyLightningResistance = tonumber(value)
        end,
    },
    enemyChaosResist = {
        apply = function(build, input, value)
            input.enemyChaosResistance = tonumber(value)
        end,
    },
    enemyArmour = {
        apply = function(build, input, value)
            input.enemyArmour = tonumber(value)
        end,
    },
    enemyEvasion = {
        apply = function(build, input, value)
            input.enemyEvasion = tonumber(value)
        end,
    },
    usePowerCharges = {
        apply = function(build, input, value)
            input.usePowerCharges = value
        end,
    },
    useFrenzyCharges = {
        apply = function(build, input, value)
            input.useFrenzyCharges = value
        end,
    },
    useEnduranceCharges = {
        apply = function(build, input, value)
            input.useEnduranceCharges = value
        end,
    },
    conditionShockedGround = {
        apply = function(build, input, value)
            input.conditionShockedGround = value
        end,
    },
    conditionFortify = {
        apply = function(build, input, value)
            input.conditionFortify = value
        end,
    },
    conditionLeeching = {
        apply = function(build, input, value)
            input.conditionLeeching = value
        end,
    },
    buffOnslaught = {
        apply = function(build, input, value)
            input.buffOnslaught = value
        end,
    },
    enemyIsBoss = {
        apply = function(build, input, value)
            input.enemyIsBoss = tostring(value)
        end,
    },
}
