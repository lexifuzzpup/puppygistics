local Inventory = require("inventory")

---@class RequesterInventory : Inventory
---@field filter table<string, integer>
local RequesterInventory = {}
setmetatable(RequesterInventory, { __index = Inventory })
RequesterInventory.__index = RequesterInventory

---@param name string peripheral name for the inventory
---@return RequesterInventory
function RequesterInventory:new(name, item_cache)
    local new = Inventory:new(name)

    new.filter = {}

    setmetatable(new, RequesterInventory)

    return new
end

---@param item_id string namespaced id of the item
---@param count integer how much to keep of the item
function RequesterInventory:addFilterItem(item_id, count)
    self.filter[item_id] = count
end

---@param item ItemDetail item_cache details for the item
function RequesterInventory:supportsItem(item)
    return self.filter[item.name] ~= nil
end

function RequesterInventory:pullFrom(remote, item_id, count)
    local satisfied_count = self.item_counts[item_id] or 0
    local filter_count = self.filter[item_id] or 0

    local pull_count = math.max(0, filter_count - satisfied_count)
    local new_count = Inventory.pullFrom(self, remote, item_id, pull_count)
    local delta_count = new_count - pull_count

    return count + delta_count
end

return RequesterInventory