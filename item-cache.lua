local log = require("log")

---@class ItemDetail
---@field name string
---@field stack_size number
---@field display_name number
---@field tags table<number, true>
local ItemDetail = {}

local item_cache = {}

---parallel-safe item cache
---@return ItemDetail | nil 
function item_cache.get(name)
    ---@type ItemDetail
    local item_detail

    while true do
        item_detail = item_cache[name]

        if item_detail ~= true then break
        else coroutine.yield() end
    end

    return item_detail
end

---@param name string namespaced id of the item
---@param inventory Inventory inventory the item is stored in
---@param slot_id integer slot the item is stored in
function item_cache.add_if_not_present(name, inventory, slot_id)
    if item_cache[name] ~= nil then return end
    if inventory.interface == nil then error("Inventory is not attached") end

    item_cache[name] = true

    local slot_detail_permit = PeripheralSemaphore:obtainPermit()
    local slot_detail = inventory.interface.getItemDetail(slot_id)
    slot_detail_permit:destroy()

    if slot_detail ~= nil then
        local item_detail = {
            name = name,
            stack_size = slot_detail.maxCount,
            display_name = slot_detail.displayName,
            tags = slot_detail.tags
        }

        log.debug("Adding cache item for " .. name)
        log.debug(textutils.serialize(item_detail))

        item_cache[name] = item_detail
    end
end

return item_cache