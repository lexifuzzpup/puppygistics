local log = require("log")
local LinkedList = require("linked-list")
local item_cache = require("item-cache")

---@class LogisticsSystem
---@field storages LinkedList<Inventory>
---@field passive_providers LinkedList<Inventory>
---@field active_providers LinkedList<Inventory>
---@field requesters LinkedList<Inventory>
---@field inventories table<string, Inventory>
local LogisticsSystem = {}
LogisticsSystem.__index = LogisticsSystem

---@return LogisticsSystem
function LogisticsSystem:new()
    local new = {}

    new.storages = LinkedList:new()
    new.passive_providers = LinkedList:new()
    new.active_providers = LinkedList:new()
    new.requesters = LinkedList:new()
    new.inventories = {}

    setmetatable(new, self)

    return new
end

---@param item ItemDetail item_cache details for the item
---@param skip_count integer how many inventories to skip forward
---@param storage_only boolean whether or not to exclude requesters in searches
---@return Inventory | nil
function LogisticsSystem:_findDestination(item, skip_count, storage_only)
    local next = nil
    local search_stage = 0

    if storage_only then search_stage = 1 end

    while true do
        if next == nil then
            if search_stage == 0 then
                next = self.requesters.first
                search_stage = 1
            elseif search_stage == 1 then
                next = self.storages.first
                search_stage = 2
            else
                break
            end
        else
            if next.value:supportsItem(item) then
                if skip_count > 0 then
                    skip_count = skip_count - 1
                else
                    return next.value
                end
            end

            next = next.next
        end
    end
end

---@param item_id string namespaced id of the item
---@param skip_count integer how many inventories to skip forward
---@param storage_only boolean whether or not to exclude requesters in searches
---@return Inventory | nil
function LogisticsSystem:_findSource(item_id, skip_count, storage_only)
    local next = nil
    local search_stage = 0

    if storage_only then search_stage = 2 end

    while true do
        if next == nil then
            if search_stage == 0 then
                next = self.active_providers.first
                search_stage = 1
            elseif search_stage == 1 then
                next = self.passive_providers.first
                search_stage = 2
            elseif search_stage == 2 then
                next = self.storages.first
                search_stage = 3
            else
                break
            end
        else
            if next.value:hasItem(item_id) then
                if skip_count > 0 then
                    skip_count = skip_count - 1
                else
                    return next.value
                end
            end

            next = next.next
        end
    end
end

---@param source_inventory Inventory inventory to push from
---@param item ItemDetail item detail from item_cache
---@param count integer quantity of the item to push
---@param storage_only boolean? whether or not to exclude requesters in searches
function LogisticsSystem:pushFrom(source_inventory, item, count, storage_only)
    if storage_only == nil then storage_only = false end

    log(0, " -> Pushing " .. count .. "x " .. item.name)

    local attempt = 0
    while count > 0 do
        local destination_inventory = self:_findDestination(item, attempt, storage_only)
        if destination_inventory == nil then break end

        if destination_inventory ~= source_inventory then
            log(0, "   -> Try " .. destination_inventory.name)

            count = source_inventory:pushTo(destination_inventory, item, count)
        end

        attempt = attempt + 1
    end
end

---@param destination_inventory Inventory inventory to pull to
---@param item ItemDetail item detail from item_cache
---@param count integer quantity of the item to push
---@param storage_only boolean? whether or not to exclude requesters in searches
function LogisticsSystem:pullTo(destination_inventory, item, count, storage_only)
    if storage_only == nil then storage_only = false end

    log(0, " -> Pulling " .. count .. "x " .. item.name)

    local attempt = 0
    while count > 0 do
        local source_inventory = self:_findSource(item.name, attempt, storage_only)
        if source_inventory == nil then break end

        if source_inventory ~= destination_inventory then
            log(0, "   -> Try " .. source_inventory.name)

            count = destination_inventory:pullFrom(source_inventory, item, count)
        end

        attempt = attempt + 1
    end
end

function LogisticsSystem:updateActiveProviders()
    local current = self.active_providers.first

    while current ~= nil do
        ---@type Inventory
        local source_inventory = current.value

        log(0, "Updating active provider " .. current.value.name)
        current.value:updateCache()

        for item_id in pairs(source_inventory.item_counts) do
            local count = source_inventory.item_counts[item_id]
            self:pushFrom(source_inventory, item_cache[item_id], count)
        end

        current = current.next
    end
end

function LogisticsSystem:updatePassiveProviders()
    local current = self.passive_providers.first

    while current ~= nil do
        log(0, "Updating passive provider " .. current.value.name)
        current.value:updateCache()

        current = current.next
    end
end

function LogisticsSystem:updateStorages()
    local current = self.storages.first

    while current ~= nil do
        log(0, "Updating storage " .. current.value.name)
        current.value:updateCache()

        current = current.next
    end
end

function LogisticsSystem:updateRequesters()
    local current = self.requesters.first

    while current ~= nil do
        ---@type RequesterInventory
        local destination_inventory = current.value

        log(0, "Updating requester " .. destination_inventory.name)
        destination_inventory:updateCache()

        for item_id, filter_count in pairs(destination_inventory.filter) do
            local satisfied_count = destination_inventory.item_counts[item_id] or 0
            local count = filter_count - satisfied_count
            log(0, " -> Requesting " .. item_id .. " (" .. satisfied_count .. "/" .. filter_count .. " satisfied)")

            if count > 0 then
                local item = item_cache[item_id]
                if item ~= nil then
                    self:pullTo(destination_inventory, item, count)
                else
                    log(0, "Failed to pull " .. item_id .. " because no cache of its type exists")
                end
            end
        end

        current = current.next
    end
end

function LogisticsSystem:compactStorage()
    local currentDestination = self.storages.first

    log(1, "Starting storage compaction")
    while currentDestination ~= nil do
        ---@type Inventory
        local destination = currentDestination.value

        local currentSource = self.storages.last
        while currentSource ~= nil do
            ---@type Inventory
            local source = currentSource.value

            log(0, "Compact: trying to merge " .. source.name .. " to " .. destination.name)

            for item_id, item_count in pairs(source.item_counts) do
                source:pushTo(destination, item_cache[item_id], item_count)
            end

            if source.name == destination.name then break end

            currentSource = currentSource.previous
        end

        currentDestination = currentDestination.next
    end
end

---@param inventory Inventory
function LogisticsSystem:_addInventory(inventory)
    self.inventories[inventory.name] = inventory
end

---@param name string
---@return Inventory
function LogisticsSystem:_removeInventory(name)
    local inventory = self.inventories[name]
    self.inventories[name] = nil

    return inventory
end

---@param inventory Inventory
function LogisticsSystem:addStorage(inventory)
    self.storages:push(inventory)
    self:_addInventory(inventory)
end

---@param inventory Inventory
function LogisticsSystem:addPassiveProvider(inventory)
    self.passive_providers:push(inventory)
    self:_addInventory(inventory)
end

---@param inventory Inventory
function LogisticsSystem:addActiveProvider(inventory)
    self.active_providers:push(inventory)
    self:_addInventory(inventory)
end

---@param inventory Inventory
function LogisticsSystem:addRequester(inventory)
    self.requesters:push(inventory)
    self:_addInventory(inventory)
end

---@param name string
function LogisticsSystem:removeStorage(name)
    log(0, "Remove storage " .. name)
    local inventory = self:_removeInventory(name)
    self.storages:delete(inventory)
end

---@param name string
function LogisticsSystem:removePassiveProvider(name)
    log(0, "Remove passive provider " .. name)
    local inventory = self:_removeInventory(name)
    self.passive_providers:delete(inventory)
end

---@param name string
function LogisticsSystem:removeActiveProvider(name)
    log(0, "Remove active provider " .. name)
    local inventory = self:_removeInventory(name)
    self.active_providers:delete(inventory)
end

---@param name string
function LogisticsSystem:removeRequester(name)
    log(0, "Add requester " .. name)
    local inventory = self:_removeInventory(name)
    self.requesters:delete(inventory)
end

return LogisticsSystem