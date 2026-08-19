local log = require("log")

---@class ItemDetail
---@field name string
---@field stack_size number
---@field display_name number
---@field tags table<number, true>
local ItemDetail = {}

local item_cache = {}

---@param name string namespaced id of the item
---@param nbt string|nil nbt hash of the item
---@param inventory Inventory inventory the item is stored in
---@param slot_id integer slot the item is stored in
function item_cache.add_if_not_present(name, nbt, inventory, slot_id)
    if nbt ~= nil then name = name .. "$" .. nbt end

    local item_detail = item_cache[name]

    if item_detail ~= nil then return end
    if inventory.interface == nil then error("Inventory is not attached") end

    local slot_detail = inventory.interface.getItemDetail(slot_id)

    item_detail = {
        name = name,
        stack_size = slot_detail.maxCount,
        display_name = slot_detail.displayName,
        tags = slot_detail.tags
    }

    log(0, "Adding cache item for " .. name)
    log(0, textutils.serialize(item_detail))

    item_cache[name] = item_detail
end

return item_cache