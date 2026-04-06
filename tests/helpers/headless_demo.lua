--[[
	headless_demo.lua - Headless Build Demo Script
	
	This script runs PathOfBuilding in headless (GUI-less) mode to load a build
	from an XML file and print its statistics without launching the graphical interface.
--]]

--[[
	xmlPath: string
	The file path to the build XML file passed as the first command-line argument.
	Path of Building stores character/build data in XML format.
--]]
local xmlPath = arg[1]
local api = PoBHeadless
local accessUtil = require("util.access")

--[[
	Validation: Check if xmlPath was provided.
	If not, print error message and exit with code 1 (error status).
--]]
if not xmlPath or xmlPath == "" then
	print("Missing build XML path. Provide the path as the first argument to HeadlessWrapper.")
	os.exit(1)
end

--[[
	buildRequested: boolean
	Flag to track whether the build XML has been loaded.
	Prevents loading the same build multiple times.
--]]
local buildRequested = false

--[[
	summaryPrinted: boolean
	Flag to track whether the build statistics have been printed.
	Used to ensure we only print the summary once.
--]]
local summaryPrinted = false

--[[
	safePrintStats(buildMode) -> boolean
	Extracts and prints build statistics in a safe manner (checks for nil values).
	
	Parameters:
		- buildMode: table - The build mode object containing all build data
	
	Returns:
		- boolean: true if stats were printed successfully, false if build not ready
	
	Prints:
		- Total DPS (damage per second)
		- Life (total health)
		- Energy Shield (ES)
		- Fire/Cold/Lightning resistances
		- Number of item slots used
		- First item name
		- Number of passive tree nodes allocated
--]]
local function safePrintStats(buildMode)
	local summary, err = api.get_summary()
	if not summary then
		print("Build not ready yet:", err)
		return false
	end

	local mainOutput = summary.stats
	
	print("=== Build summary ===")
	
	-- Print DPS (damage per second) - formatted to 2 decimal places
	print(string.format("Total DPS: %.2f", mainOutput.TotalDPS or 0))
	
	-- Print Life (health pool) - formatted as integer
	print(string.format("Life: %.0f", mainOutput.Life or 0))
	
	-- Print Energy Shield
	print(string.format("Energy Shield: %.0f", mainOutput.EnergyShield or 0))
	
	-- Print elemental resistances (with % symbol)
	print(string.format("Fire Resist: %.0f%%", mainOutput.FireResist or 0))
	print(string.format("Cold Resist: %.0f%%", mainOutput.ColdResist or 0))
	print(string.format("Lightning Resist: %.0f%%", mainOutput.LightningResist or 0))

	-- Get items tab to display item information
	local itemsTab = buildMode.itemsTab
	if itemsTab and itemsTab.list then
		-- Print number of item slots (# gets array length)
		print("Item slots:", #itemsTab.list)
		
		-- Print first item if exists
		if itemsTab.list[1] then
			local item = itemsTab.list[1]
			-- Try name first, fall back to base type, then "unknown"
			print("First item:", item.name or item.base or "unknown")
		end
	end

	--[[
		tableSize(tbl) -> number
		Helper function to count entries in a table (since # only works for sequential arrays).
		
		Parameters:
			- tbl: table - The table to count entries in
		
		Returns:
			- number: The count of key-value pairs in the table
	--]]
	local function tableSize(tbl)
		local count = 0
		if tbl then
			-- pairs() iterates over all key-value pairs in a table
			for _ in pairs(tbl) do
				count = count + 1
			end
		end
		return count
	end

	-- Print number of passive tree nodes allocated
	-- buildMode.spec.allocatedNodes contains a table of allocated passive skills
	print("Nodes allocated:", tableSize(buildMode.spec and buildMode.spec.allocatedNodes))
	print("=====================")
	return true
end
api.queue(function()
	--[[
		buildMode: table
		The BUILD mode object from the application.
		Access pattern: launch.main.modes["BUILD"]
		Uses short-circuit evaluation (and) to safely handle nil values.
	--]]
	local buildMode = accessUtil.getBuildMode(launch)

	if not buildRequested then
		buildRequested = true
		local _, err = api.load_build_file(xmlPath)
		if err then
			print("Unable to load build:", err)
			os.exit(1)
		end
		return false
	end

	if summaryPrinted then
		return true
	end

	buildMode = accessUtil.getBuildMode(launch)
	if not buildMode then
		return false
	end

	if not safePrintStats(buildMode) then
		return false
	end

	summaryPrinted = true
	api.stop()
	return true
end)
