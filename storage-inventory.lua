local Inventory = require("inventory")

---@class StorageInventory : Inventory
local StorageInventory = {}
setmetatable(StorageInventory, { __index = Inventory })
StorageInventory.__index = StorageInventory

---@param name string peripheral name for the inventory
---@param config table config for the logistics network member
---@return StorageInventory
function StorageInventory:new(name, config)
    local new = Inventory:new(name, "storage")

    setmetatable(new, StorageInventory)

    return new
end

return StorageInventory