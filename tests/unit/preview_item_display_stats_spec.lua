local itemsServiceModule = require("api.items.orchestrator")
local expect = require("testkit").expect

do
    local calls = {}
    local slot = {
        selItemId = 10,
        slotName = "Ring 1",
        label = "Ring 1",
    }
    local build = {
        buildName = "Fixture",
        characterLevel = 100,
        itemsTab = {},
        calcsTab = {
            mainEnv = {
                player = {
                    output = {
                        Life = 120,
                    },
                },
            },
        },
    }

    local service = itemsServiceModule.new(
        {
            runtime = {
                ensure_build_ready = function()
                    return build
                end,
                rebuild_output = function()
                    calls[#calls + 1] = "rebuild_output"
                    return { Life = 120 }
                end,
                run_frames_if_idle = function(_, count)
                    calls[#calls + 1] = { "run_frames_if_idle", count }
                end,
            },
        },
        {
            stats = {
                build_meta = function(_, currentBuild)
                    return { buildName = currentBuild.buildName, mainSkill = "Preview Skill" }
                end,
                displayStats = {
                    build_entries = function(_, currentBuild)
                        return {
                            {
                                type = "stat",
                                label = "Life",
                                value = currentBuild.calcsTab.mainEnv.player.output.Life,
                            },
                        }
                    end,
                },
            },
        }
    )

    local previewItem = { id = 99, raw = "preview raw" }
    service.simulate_outputs = function(_, itemText, requestedSlot)
        expect(itemText == "Rarity: Rare", "expected preview item text")
        expect(requestedSlot == "Ring 1", "expected requested slot")
        return {
            build = build,
            item = previewItem,
            itemSummary = { raw = "preview raw", name = "Preview Item" },
            slot = slot,
            slotSummary = { requested = "Ring 1", resolved = "Ring 1", autoResolved = false },
            equippedItemSummary = { raw = "old raw", name = "Old Item" },
        }
    end
    service.pob = {
        add_item = function(_, _, item)
            calls[#calls + 1] = { "add_item", item.id }
            return item
        end,
        set_slot_item = function(_, currentSlot, itemId)
            calls[#calls + 1] = { "set_slot_item", currentSlot.slotName, itemId }
            currentSlot.selItemId = itemId
        end,
        refresh_item_state = function(_, _, skipUndo)
            calls[#calls + 1] = { "refresh_item_state", skipUndo }
        end,
        delete_item = function(_, _, item, deferUndo)
            calls[#calls + 1] = { "delete_item", item.id, deferUndo }
        end,
    }

    local result, err = service:preview_item_display_stats("Rarity: Rare", "Ring 1")

    expect(result ~= nil and err == nil, "expected preview_item_display_stats to succeed")
    expect(result.kind == "item", "expected item kind")
    expect(result.restored == true, "expected restored flag")
    expect(result.simulationMode == "snapshot_restore", "expected snapshot_restore mode")
    expect(result.slot.resolved == "Ring 1", "expected slot summary")
    expect(result.currentItem.name == "Old Item", "expected current item summary")
    expect(result.candidateItem.name == "Preview Item", "expected candidate item summary")
    expect(result.displayStats._meta.mainSkill == "Preview Skill", "expected display meta")
    expect(result.displayStats.entries[1].label == "Life", "expected display stats entry")
    expect(calls[1][1] == "add_item", "expected preview item add")
    expect(calls[2][1] == "set_slot_item", "expected temporary equip")
    expect(calls[3][1] == "refresh_item_state", "expected temporary refresh")
    expect(calls[6][1] == "delete_item", "expected preview item delete")
    expect(calls[7][1] == "set_slot_item", "expected restore slot item")
    expect(slot.selItemId == 10, "expected original slot item restored")
end
