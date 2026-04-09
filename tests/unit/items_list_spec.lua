local itemsServiceModule = require("api.items.orchestrator")
local expect = require("testkit").expect

do
    local service = itemsServiceModule.new(
        {
            runtime = {
                ensure_build_ready = function()
                    return {
                        itemsTab = {
                            items = {
                                [20] = {
                                    id = 20,
                                    name = "Beta",
                                    raw = "Beta raw",
                                },
                                [10] = {
                                    id = 10,
                                    name = "Alpha",
                                    raw = "Alpha raw",
                                },
                            },
                        },
                    }
                end,
            },
        },
        {
            stats = {},
        }
    )
    service.pob = {
        get_items = function(_, build)
            return build.itemsTab.items
        end,
    }

    local result, err = service:list_items()
    expect(result ~= nil and err == nil, "expected list_items to succeed")
    expect(type(result.items) == "table", "expected items payload table")
    expect(result.items[1].id == 10, "expected deterministic first item")
    expect(result.items[1].item.name == "Alpha", "expected first item summary")
    expect(result.items[2].id == 20, "expected deterministic second item")
    expect(result.items[2].raw == "Beta raw", "expected raw payload")
end
