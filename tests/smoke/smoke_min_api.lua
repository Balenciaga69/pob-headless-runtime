local api = PoBHeadless
local testkit = require("testkit")

local xmlPath = arg[1]

if not xmlPath or xmlPath == "" then
	print("Missing build XML path.")
	os.exit(1)
end

local flow = testkit.newQueuedBuildFlow(api, xmlPath)

api.queue(function()
	if not flow.load() then
		return false
	end

	local summary, ready = flow.summary()
	if not ready then
		return false
	end

	local skills, skillsErr = api.list_skills()
	if not skills then
		error(skillsErr, 0)
	end
	if not skills.groups or #skills.groups == 0 then
		return false
	end

	testkit.expect(type(skills.groups) == "table" and #skills.groups > 0, "min_api: expected at least one skill group")
	testkit.expect(summary.buildName ~= nil, "min_api: expected build name in summary")

	local stats, statsErr = api.get_stats({ "Life", "TotalDPS" })
	if not stats then
		error(statsErr, 0)
	end
	testkit.expect(stats._meta and stats._meta.mainSkill ~= nil, "min_api: expected main skill meta")
	testkit.expect(stats.Life ~= nil or stats.TotalDPS ~= nil, "min_api: expected at least one stat value")

	local firstGroup = skills.groups[1]
	local firstSkill = firstGroup and firstGroup.skills and firstGroup.skills[1]
	if firstGroup and firstSkill then
		local selected, selectErr = api.select_skill({
			group = firstGroup.index,
			skill = firstGroup.mainActiveSkill or firstSkill.index or 1,
		})
		if not selected then
			error(selectErr, 0)
		end

		testkit.expect(selected.mainSocketGroup == firstGroup.index, "min_api: selected group mismatch")
	end

	local _, configErr = api.set_config({
		enemyLevel = 84,
		enemyIsBoss = "Pinnacle",
	})
	if configErr then
		error(configErr, 0)
	end

	local _, invalidConfigErr = api.set_config({ invalidField = true })
	testkit.expect(
		invalidConfigErr ~= nil and invalidConfigErr:match("^unsupported config field:"),
		"min_api: expected unsupported field error"
	)

	local xmlText, xmlErr = api.save_build_xml()
	if not xmlText then
		error(xmlErr, 0)
	end
	testkit.expect(#xmlText > 0, "min_api: expected exported xml text")

	print("buildName", summary.buildName or "")
	print("mainSkill", stats._meta and stats._meta.mainSkill or "")
	print("skillGroups", #skills.groups)
	print("xmlSize", #xmlText)

	api.stop()
	return true
end)
