local itemsAdapterModule = require("api.repo.pob_items_adapter")
local importAdapterModule = require("api.repo.pob_import_adapter")
local treeAdapterModule = require("api.repo.pob_tree_adapter")
local expect = require("testkit").expect

do
	local itemsAdapter = itemsAdapterModule.new()
	local calls = {}
	local collector = {}
	local slot = {
		selItemId = 10,
		SetSelItemId = function(_, id)
			calls[#calls + 1] = { "SetSelItemId", id }
		end,
	}
	local build = {
		itemsTab = {
			items = {
				[10] = { id = 10, name = "Old" },
				[20] = { id = 20, name = "New" },
			},
			slots = {
				Weapon1 = slot,
			},
			AddItemTooltip = function(_, _, _, currentSlot)
				calls[#calls + 1] = { "AddItemTooltip", currentSlot == slot }
			end,
			AddItem = function(_, item)
				calls[#calls + 1] = { "AddItem", item.id }
			end,
			PopulateSlots = function()
				calls[#calls + 1] = { "PopulateSlots" }
			end,
			AddUndoState = function()
				calls[#calls + 1] = { "AddUndoState" }
			end,
		},
		calcsTab = {
			GetMiscCalculator = function()
				calls[#calls + 1] = { "GetMiscCalculator" }
				return function()
					return { Life = 123 }
				end, { Life = 100 }
			end,
		},
		configTab = {
			BuildModList = function()
				calls[#calls + 1] = { "BuildModList" }
			end,
		},
	}

	local ok = itemsAdapter:render_tooltip(build, collector, { id = 99 }, slot)
	local calc, base = itemsAdapter:get_misc_calculator(build)
	local resolvedSlot, equipped = itemsAdapter:get_item_by_slot(build, "Weapon1")
	local equippedItem = itemsAdapter:add_and_equip_item(build, { id = 20 }, slot)

	expect(ok == true, "expected tooltip render to succeed")
	expect(type(calc) == "function", "expected calculator function")
	expect(base.Life == 100, "expected base output")
	expect(resolvedSlot == slot, "expected slot lookup")
	expect(equipped.id == 10, "expected equipped item lookup")
	expect(equippedItem.id == 20, "expected equipped item result")
	expect(calls[1][1] == "AddItemTooltip", "expected tooltip through adapter")
	expect(calls[2][1] == "GetMiscCalculator", "expected calculator through adapter")
	expect(calls[#calls][1] == "BuildModList", "expected config rebuild through adapter")
end

do
	local importAdapter = importAdapterModule.new()
	local importTab = {
		lastAccountHash = "abc",
		lastCharacterHash = "def",
		charImportMode = "GETACCOUNTNAME",
		controls = {
			accountName = { buf = "Account" },
			charImportTreeClearJewels = {},
			charImportItemsClearItems = {},
			charImportItemsClearSkills = {},
			charSelect = {
				selIndex = 1,
				list = {
					{ char = { name = "Character" } },
				},
			},
		},
		DownloadCharacterList = function()
			return true
		end,
		DownloadPassiveTree = function()
			return true
		end,
		DownloadItems = function()
			return true
		end,
		ImportPassiveTreeAndJewels = function(self, passiveTreeJson, character)
			self.lastPassive = passiveTreeJson
			self.lastCharacter = character
		end,
		ImportItemsAndSkills = function(self, itemsJson)
			self.lastItems = itemsJson
		end,
	}

	importAdapter:configure_reset_flags(importTab)
	local charsOk = importAdapter:download_character_list(importTab)
	local passiveOk = importAdapter:download_passive_tree(importTab)
	local itemsOk = importAdapter:download_items(importTab)
	importAdapter:import_offline_payload(importTab, {
		passiveTreeJson = "{}",
		itemsJson = "[]",
		character = { name = "Character" },
	})

	expect(importAdapter:get_import_tab({ importTab = importTab }) == importTab, "expected import tab lookup")
	expect(importAdapter:has_remote_import_hashes(importTab) == true, "expected hash readiness")
	expect(importAdapter:get_account_name(importTab) == "Account", "expected account name")
	expect(importAdapter:get_import_mode(importTab) == "GETACCOUNTNAME", "expected import mode")
	expect(importAdapter:get_selected_character(importTab).name == "Character", "expected selected character")
	expect(charsOk == true and passiveOk == true and itemsOk == true, "expected adapter downloads to succeed")
	expect(importTab.controls.charImportTreeClearJewels.state == true, "expected tree clear flag")
	expect(importTab.controls.charImportItemsClearItems.state == true, "expected item clear flag")
	expect(importTab.lastPassive == "{}", "expected offline passive import through adapter")
	expect(importTab.lastItems == "[]", "expected offline items import through adapter")
end

do
	local treeAdapter = treeAdapterModule.new()
	local called = 0
	treeAdapter:refresh_active_spec({
		treeTab = {
			activeSpec = 2,
			SetActiveSpec = function(_, activeSpec)
				called = activeSpec
			end,
		},
	})
	expect(called == 2, "expected tree active spec refresh through adapter")
end
