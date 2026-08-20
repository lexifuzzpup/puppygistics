local log = require("log")

---@class Epoch
---@field time integer epoch (ms) in utc
---@field transferred integer total items transferred
---@field operations integer total inventory operations made
---@field items_transferred table<string, integer> number of times an item was transferred
---@field extractions table<string, integer> number of times an inventory was extracted from
---@field insertions table<string, integer> number of times an inventory was inserted into
local Epoch = {}
Epoch.__index = Epoch

---@return Epoch
function Epoch:new()
    local new = {
        time = 0,

        transferred = 0,
        operations = 0,

        items_transferred = {},
        extractions = {},
        insertions = {},
    }

    setmetatable(new, self)

    return new
end

local statistics = {
    frozen = false,
    ---@type Epoch[]
    epochs = {},
    next = Epoch:new()
}

---@param item_id string namespaced id of the item with $nbt
---@param count integer quantity of the item was transfered
---@param from_inventory string name of the source inventory
---@param to_inventory string name of the destination inventory
function statistics.trackTransfer(item_id, count, from_inventory, to_inventory)
    if statistics.frozen then return end

    statistics.next.transferred = statistics.next.transferred + count
    statistics.next.items_transferred[item_id] = (statistics.next.items_transferred[item_id] or 0) + count
    statistics.next.operations = statistics.next.operations + 1
    statistics.next.extractions[from_inventory] = (statistics.next.extractions[from_inventory] or 0) + 1
    statistics.next.insertions[to_inventory] = (statistics.next.insertions[to_inventory] or 0) + 1
end

function statistics.freeze()
    log.debug("Statistics frozen")
    statistics.frozen = true
end

function statistics.unfreeze()
    log.debug("Statistics unfrozen")
    statistics.frozen = false
end

function statistics.epoch(time)
    statistics.next.time = time
    table.insert(statistics.epochs, statistics.next)

    statistics.next = Epoch:new()
end

return statistics