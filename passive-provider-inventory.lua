local Inventory = require("inventory")

---@class PassiveProviderInventory : Inventory
local PassiveProviderInventory = {}
setmetatable(PassiveProviderInventory, { __index = Inventory })
PassiveProviderInventory.__index = PassiveProviderInventory

---@param name string peripheral name for the inventory
---@param config table config for the logistics network member
---@return PassiveProviderInventory
function PassiveProviderInventory:new(name, config)
    local new = Inventory:new(name, "passive_provider")

    setmetatable(new, PassiveProviderInventory)

    return new
end

return PassiveProviderInventory