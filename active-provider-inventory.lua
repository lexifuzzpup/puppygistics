local Inventory = require("inventory")

---@class ActiveProviderInventory : Inventory
local ActiveProviderInventory = {}
setmetatable(ActiveProviderInventory, { __index = Inventory })
ActiveProviderInventory.__index = ActiveProviderInventory

---@param name string peripheral name for the inventory
---@param config table config for the logistics network member
---@return ActiveProviderInventory
function ActiveProviderInventory:new(name, config)
    local new = Inventory:new(name, "active_provider")

    setmetatable(new, ActiveProviderInventory)

    return new
end

return ActiveProviderInventory