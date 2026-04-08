-- Writable config field specs exposed through the headless API.
return {
    bandit = {
        apply = function(build, input, value)
            input.bandit = tostring(value)
        end,
        read = function(build, input)
            return input.bandit or build.bandit
        end,
    },
    pantheonMajorGod = {
        apply = function(build, input, value)
            input.pantheonMajorGod = tostring(value)
        end,
        read = function(_, input)
            return input.pantheonMajorGod
        end,
    },
    pantheonMinorGod = {
        apply = function(build, input, value)
            input.pantheonMinorGod = tostring(value)
        end,
        read = function(_, input)
            return input.pantheonMinorGod
        end,
    },
    enemyLevel = {
        apply = function(build, input, value, pob)
            pob:set_enemy_level(build, tonumber(value) or pob:get_enemy_level(build))
        end,
        read = function(build, _, pob)
            return pob:get_enemy_level(build)
        end,
    },
    enemyFireResist = {
        apply = function(build, input, value)
            input.enemyFireResistance = tonumber(value)
        end,
        read = function(_, input)
            return input.enemyFireResistance
        end,
    },
    enemyColdResist = {
        apply = function(build, input, value)
            input.enemyColdResistance = tonumber(value)
        end,
        read = function(_, input)
            return input.enemyColdResistance
        end,
    },
    enemyLightningResist = {
        apply = function(build, input, value)
            input.enemyLightningResistance = tonumber(value)
        end,
        read = function(_, input)
            return input.enemyLightningResistance
        end,
    },
    enemyChaosResist = {
        apply = function(build, input, value)
            input.enemyChaosResistance = tonumber(value)
        end,
        read = function(_, input)
            return input.enemyChaosResistance
        end,
    },
    enemyArmour = {
        apply = function(build, input, value)
            input.enemyArmour = tonumber(value)
        end,
        read = function(_, input)
            return input.enemyArmour
        end,
    },
    enemyEvasion = {
        apply = function(build, input, value)
            input.enemyEvasion = tonumber(value)
        end,
        read = function(_, input)
            return input.enemyEvasion
        end,
    },
    usePowerCharges = {
        apply = function(build, input, value)
            input.usePowerCharges = value
        end,
        read = function(_, input)
            return input.usePowerCharges
        end,
    },
    useFrenzyCharges = {
        apply = function(build, input, value)
            input.useFrenzyCharges = value
        end,
        read = function(_, input)
            return input.useFrenzyCharges
        end,
    },
    useEnduranceCharges = {
        apply = function(build, input, value)
            input.useEnduranceCharges = value
        end,
        read = function(_, input)
            return input.useEnduranceCharges
        end,
    },
    conditionShockedGround = {
        apply = function(build, input, value)
            input.conditionShockedGround = value
        end,
        read = function(_, input)
            return input.conditionShockedGround
        end,
    },
    conditionFortify = {
        apply = function(build, input, value)
            input.conditionFortify = value
        end,
        read = function(_, input)
            return input.conditionFortify
        end,
    },
    conditionLeeching = {
        apply = function(build, input, value)
            input.conditionLeeching = value
        end,
        read = function(_, input)
            return input.conditionLeeching
        end,
    },
    buffOnslaught = {
        apply = function(build, input, value)
            input.buffOnslaught = value
        end,
        read = function(_, input)
            return input.buffOnslaught
        end,
    },
    enemyIsBoss = {
        apply = function(build, input, value)
            input.enemyIsBoss = tostring(value)
        end,
        read = function(_, input)
            return input.enemyIsBoss
        end,
    },
}
