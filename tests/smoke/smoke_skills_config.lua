local api = PoBHeadless
local testkit = require("testkit")

local xmlPath = arg[1]

if not xmlPath or xmlPath == "" then
	print("Missing build XML path.")
	os.exit(1)
end

local flow = testkit.newQueuedBuildFlow(api, xmlPath)
local selectedSnapshot

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

	if not selectedSnapshot then
		local snapshot, snapshotErr = api.get_selected_skill()
		if not snapshot then
			error(snapshotErr, 0)
		end
		selectedSnapshot = snapshot

		local firstGroup = skills.groups and skills.groups[1]
		if firstGroup and firstGroup.skills and firstGroup.skills[1] then
			local _, selectErr = api.select_skill({
				group = firstGroup.index,
				skill = firstGroup.mainActiveSkill or firstGroup.skills[1].index or 1,
			})
			if selectErr then
				error(selectErr, 0)
			end
		end

		local _, configErr = api.set_config({
			enemyLevel = 83,
			enemyIsBoss = "Pinnacle",
		})
		if configErr then
			error(configErr, 0)
		end

		local restored, restoreErr = api.restore_skill_selection(selectedSnapshot)
		if not restored then
			error(restoreErr, 0)
		end
	end

	local stats, statsErr = api.get_stats({ "Life", "FireResist", "TotalDPS" })
	if not stats then
		error(statsErr, 0)
	end

	testkit.expect(type(skills.groups) == "table" and #skills.groups > 0, "skills_config: expected at least one skill group")
	testkit.expect(summary.buildName ~= nil, "skills_config: expected build name in summary")
	testkit.expect(stats._meta and stats._meta.mainSkill ~= nil, "skills_config: expected main skill meta")
	testkit.expect(stats.Life ~= nil or stats.TotalDPS ~= nil, "skills_config: expected at least one stat value")
	testkit.expect(selectedSnapshot ~= nil, "skills_config: expected selected skill snapshot")

	print("selectedGroup", skills.mainSocketGroup or 0)
	print("selectedSkill", selectedSnapshot and selectedSnapshot.skill and selectedSnapshot.skill.name or "")
	print("life", stats.Life or 0)
	print("fireRes", stats.FireResist or 0)
	print("dps", stats.TotalDPS or 0)

	api.stop()
	return true
end)
