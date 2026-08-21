local Inventory = require("inventory")

---@class RequesterInventory : Inventory
---@field config { filter: table<string, integer> }
local RequesterInventory = {}
setmetatable(RequesterInventory, { __index = Inventory })
RequesterInventory.__index = RequesterInventory

---@param name string peripheral name for the inventory
---@param config table config for the logistics network member
---@return RequesterInventory
function RequesterInventory:new(name, config)
    local new = Inventory:new(name, "requester")

    new.config = config

    setmetatable(new, RequesterInventory)

    return new
end

function RequesterInventory:pullFrom(remote, item, count)
    local satisfied_count = self.item_counts[item.name] or 0
    local filter_count = self.config.filter[item.name] or 0

    local pull_count = math.max(0, filter_count - satisfied_count)
    local new_count = Inventory.pullFrom(self, remote, item, pull_count)
    local delta_count = new_count - pull_count

    return count + delta_count
end

return RequesterInventory