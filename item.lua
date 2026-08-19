---@class Item
---@field inventory Inventory
---@field slot_id integer
---@field name string
---@field count integer
local ItemStack = {}
ItemStack.__index = ItemStack

---@param inventory Inventory
---@param slot_id integer
---@param name string
---@param count integer
function ItemStack:new(inventory, slot_id, name, count)
    local new = {}

    new.inventory = inventory
    new.slot_id = slot_id
    new.name = name
    new.count = count

    setmetatable(new, self)

    return new
end

---@param target Inventory inventory to send this item to
---@param max integer maximum item count to send to the inventory
function ItemStack:addTo(target, max)
    local new_count = self.inventory:pushTo(target, self.name, math.min(max, self.count))
    self.count = new_count
end