local log = require "log"
local statistics = {
    frozen = false,
    data = {
        epochs = 0,

        transferred_session = {},
        transferred_new = 0,

        items_transferred_session = {},
        items_transferred_new = {},

        operations_session = {},
        operations_new = 0,

        extractions_session = {},
        extractions_new = {},

        insertions_session = {},
        insertions_new = {},
    }
}

---@param item_id string namespaced id of the item with $nbt
---@param count integer quantity of the item was transfered
---@param from_inventory string name of the source inventory
---@param to_inventory string name of the destination inventory
function statistics.itemTransferred(item_id, count, from_inventory, to_inventory)
    if statistics.frozen then return end

    statistics.data.transferred_new = statistics.data.transferred_new + count
    statistics.data.items_transferred_new[item_id] = (statistics.data.items_transferred_new[item_id] or 0) + count
    statistics.data.operations_new = statistics.data.operations_new + 1
    statistics.data.extractions_new[from_inventory] = (statistics.data.extractions_new[from_inventory] or 0) + 1
    statistics.data.insertions_new[to_inventory] = (statistics.data.insertions_new[to_inventory] or 0) + 1
end

function statistics.freeze()
    log.debug("Statistics frozen")
    statistics.frozen = true
end

function statistics.unfreeze()
    log.debug("Statistics unfrozen")
    statistics.frozen = false
end

function statistics.epoch()
    statistics.data.epochs = statistics.data.epochs + 1

    table.insert(statistics.data.transferred_session, statistics.data.transferred_new)
    statistics.data.transferred_new = 0

    table.insert(statistics.data.items_transferred_session, statistics.data.items_transferred_new)
    statistics.data.items_transferred_new = {}

    table.insert(statistics.data.operations_session, statistics.data.operations_new)
    statistics.data.operations_new = 0

    table.insert(statistics.data.extractions_session, statistics.data.extractions_new)
    statistics.data.extractions_new = {}

    table.insert(statistics.data.insertions_session, statistics.data.insertions_new)
    statistics.data.insertions_new = {}
end

return statistics