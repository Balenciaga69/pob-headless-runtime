-- Config adapter with a narrowed writable field set.
local tableUtil = require("util.table")

local M = {}
M.__index = M

local CONFIG_FIELD_SPECS = {
	-- Only these config fields may be patched through the headless API.
	bandit = { apply = function(build, input, value) input.bandit = tostring(value) end },
	pantheonMajorGod = { apply = function(build, input, value) input.pantheonMajorGod = tostring(value) end },
	pantheonMinorGod = { apply = function(build, input, value) input.pantheonMinorGod = tostring(value) end },
	enemyLevel = { apply = function(build, input, value) build.configTab.enemyLevel = tonumber(value) or build.configTab.enemyLevel end },
	enemyFireResist = { apply = function(build, input, value) input.enemyFireResistance = tonumber(value) end },
	enemyColdResist = { apply = function(build, input, value) input.enemyColdResistance = tonumber(value) end },
	enemyLightningResist = { apply = function(build, input, value) input.enemyLightningResistance = tonumber(value) end },
	enemyChaosResist = { apply = function(build, input, value) input.enemyChaosResistance = tonumber(value) end },
	enemyArmour = { apply = function(build, input, value) input.enemyArmour = tonumber(value) end },
	enemyEvasion = { apply = function(build, input, value) input.enemyEvasion = tonumber(value) end },
	usePowerCharges = { apply = function(build, input, value) input.usePowerCharges = value end },
	useFrenzyCharges = { apply = function(build, input, value) input.useFrenzyCharges = value end },
	useEnduranceCharges = { apply = function(build, input, value) input.useEnduranceCharges = value end },
	conditionShockedGround = { apply = function(build, input, value) input.conditionShockedGround = value end },
	conditionFortify = { apply = function(build, input, value) input.conditionFortify = value end },
	conditionLeeching = { apply = function(build, input, value) input.conditionLeeching = value end },
	buffOnslaught = { apply = function(build, input, value) input.buffOnslaught = value end },
	enemyIsBoss = { apply = function(build, input, value) input.enemyIsBoss = tostring(value) end },
}

function M.new(runtimeRepo)
	-- Bind the config adapter to the runtime adapter.
	return setmetatable({
		runtime = runtimeRepo,
	}, M)
end

function M:snapshot()
	-- Capture the current config input state for restore flows.
	local build, err = self.runtime:ensure_build_ready({ "configTab", "calcsTab" }, "build/config not initialized")
	if not build then
		return nil, err
	end
	return {
		input = tableUtil.shallowCopy(build.configTab.input or {}),
		enemyLevel = build.configTab.enemyLevel,
	}, build
end

function M:restore(snapshot)
	-- Restore config input state from a snapshot and rebuild output.
	local build, err = self.runtime:ensure_build_ready({ "configTab", "calcsTab" }, "build/config not initialized")
	if not build then
		return nil, err
	end
	build.configTab.input = tableUtil.shallowCopy(snapshot and snapshot.input or {})
	build.configTab.enemyLevel = snapshot and snapshot.enemyLevel or build.configTab.enemyLevel
	self.runtime:rebuild_config(build)
	return true
end

function M:apply_patch(params)
	-- Apply a validated config patch and return the effective summary.
	local build, err = self.runtime:ensure_build_ready({ "configTab", "calcsTab" }, "build/config not initialized")
	if not build then
		return nil, err
	end
	if type(params) ~= "table" then
		return nil, "config must be a table"
	end

	local input = build.configTab.input or {}
	build.configTab.input = input
	for key in pairs(params) do
		if not CONFIG_FIELD_SPECS[key] then
			return nil, "unsupported config field: " .. tostring(key)
		end
	end
	for key, spec in pairs(CONFIG_FIELD_SPECS) do
		local value = params[key]
		if value ~= nil then
			spec.apply(build, input, value)
		end
	end

	self.runtime:rebuild_config(build)
	self.runtime:run_frames_if_idle(1)

	return {
		bandit = input.bandit or build.bandit,
		pantheonMajorGod = input.pantheonMajorGod or build.pantheonMajorGod,
		pantheonMinorGod = input.pantheonMinorGod or build.pantheonMinorGod,
		enemyLevel = build.configTab.enemyLevel,
	}
end

return M
