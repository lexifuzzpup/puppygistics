local log = require("log")
local item_cache = require("item-cache")
local statistics = require("statistics")

---@class Inventory
---@field name string name of the peripheral
---@field interface table | nil underlying peripheral
---@field item_counts table<string, integer> item count cache
---@field slots table<integer, { name: string, count: integer }> item slot cache
---@field item_slots table<string, table<integer, true>> item slot cache
---@field inventory_size integer number of slots in the inventory
---@field slot_sizes table<integer, integer> slot capacity multipliers
local Inventory = {}
Inventory.__index = Inventory

---@param name string peripheral name for the inventory
function Inventory:new(name)
    local new = {}

    new.name = name
    new.interface = peripheral.wrap(name)
    new.item_counts = {}
    new.slots = {}
    new.item_slots = {}
    new.inventory_size = 0
    new.slot_sizes = {}

    setmetatable(new, self)

    return new
end

function Inventory:init()
    self:updateCache()
    self:updateMetadata()
end

---@param slot_id integer slot id in the inventory
---@param item_id string namespaced id of the item with $nbt
---@param count integer item count to remove from the slot
function Inventory:_removeItem(slot_id, item_id, count)
    self.item_counts[item_id] = self.item_counts[item_id] - count

    local slot = self.slots[slot_id]
    slot.count = slot.count - count

    if slot.count <= 0 then
        self.slots[slot_id].name = "minecraft:air"
        (self.item_slots[item_id] or {})[slot_id] = nil
    end
end

---@param slot_id integer slot id in the inventory
---@param item_id string namespaced id of the item with $nbt
---@param count integer item count to add to the slot
function Inventory:_addItem(slot_id, item_id, count)
    self.item_counts[item_id] = (self.item_counts[item_id] or 0) + count

    local slot = self.slots[slot_id]
    if slot == nil then
        slot = { name = item_id, count = 0 }
        self.slots[slot_id] = slot

        local slots = self.item_slots[item_id]
        if slots == nil then
            slots = {}
            self.item_slots[item_id] = slots
        end
        slots[slot_id] = true
    end

    slot.count = slot.count + count
end

---finds the first available slot that an item can be placed in
---@param item ItemDetail item_cache details for the item
---@return integer
function Inventory:_findSlotForItem(item)
    for slot_id = 1, self.inventory_size do
        local slot = self.slots[slot_id]

        if slot == nil or (
            slot.name == item.name and
            slot.count < math.floor(0.5 + item.stack_size * self.slot_sizes[slot_id])
        ) then return slot_id end
    end

    return -1
end

---@param item ItemDetail item_cache details for the item
---@return boolean
function Inventory:supportsItem(item)
    return self:_findSlotForItem(item) ~= -1
end

---@param item_id string namespaced id of the item
---@return boolean
function Inventory:hasItem(item_id)
    return (self.item_counts[item_id] or 0) > 0
end

function Inventory:_clearCache()
    for item in pairs(self.item_counts) do
        self.item_counts[item] = 0

        local item_slots = self.item_slots[item] or {}
        for slot in pairs(item_slots) do
            item_slots[slot] = nil
        end
    end
    for slot_id in pairs(self.slots) do
        self.item_counts[slot_id] = nil
    end
end

---re-pulls the items from the underlying inventory and updates local caches
function Inventory:updateCache()
    self:_clearCache()

    if self.interface == nil then return end

    local inventory_items = self.interface.list()
    if inventory_items == nil then return end

    for slot_id, slot_item in pairs(inventory_items) do
        local item_id = slot_item.name
        if slot_item.nbt ~= nil then
            item_id = item_id .. "$" .. slot_item.nbt
        end

        local previous_count = self.item_counts[item_id] or 0
        self.item_counts[item_id] = previous_count + slot_item.count

        self.slots[slot_id] = slot_item

        local item_slots = self.item_slots[item_id] or {}
        item_slots[slot_id] = true
        self.item_slots[item_id] = item_slots

        item_cache.add_if_not_present(item_id, self, slot_id)
    end
end

function Inventory:updateMetadata()
    if self.interface == nil then return end

    self.inventory_size = self.interface.size()

    local functions = {}

    for slot_id = 1, self.inventory_size do
        table.insert(functions, function()
            self.slot_sizes[slot_id] = self.interface.getItemLimit(slot_id) / 64
        end)
    end

    parallel.waitForAll(table.unpack(functions))
end

---@param remote Inventory inventory object to push items to
---@param item ItemDetail item detail from item_cache
---@param count integer item count to transfer to the destination
---@return integer
function Inventory:pushTo(remote, item, count)
    return remote:pullFrom(self, item, count)
end

---@param remote Inventory inventory object to pull items from
---@param item ItemDetail item detail from item_cache
---@param count integer item count to transfer from the source
---@return integer
function Inventory:pullFrom(remote, item, count)
    if self.interface == nil then return count end

    local item_id = item.name
    if (remote.item_counts[item_id] or 0) <= 0 then return count end

    local item_slots = {}
    for slot_id in pairs(remote.item_slots[item_id] or {}) do
        item_slots[slot_id] = true
    end

    for remote_slot_id in pairs(item_slots) do
        local local_slot_id = self:_findSlotForItem(item)
        if local_slot_id == -1 then break end

        local pulled_count = self.interface.pullItems(remote.name, remote_slot_id, count, local_slot_id)
        remote:_removeItem(remote_slot_id, item_id, pulled_count)
        self:_addItem(local_slot_id, item_id, pulled_count)

        statistics.itemTransferred(item.name, pulled_count, remote.name, self.name)
        log.verbose(remote.name .. " -" .. pulled_count .. "x " .. item_id .. " @ " .. remote_slot_id)
        log.verbose(self.name .. " +" .. pulled_count .. "x " .. item_id .. " @ " .. local_slot_id)

        count = count - pulled_count
        if count <= 0 then break end
    end

    return count
end

return Inventory