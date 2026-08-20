local log = require("log")
local item_cache = require("item-cache")

---@class LogisticsSystem
---@field storages {}
---@field passive_providers {}
---@field active_providers {}
---@field requesters {}
---@field inventories table<string, Inventory>
---@field inventory_names string[]
---@field inventory_types table<Inventory, "active_provider" | "passive_provider" | "storage" | "requester">
local LogisticsSystem = {}
LogisticsSystem.__index = LogisticsSystem

---@return LogisticsSystem
function LogisticsSystem:new()
    local new = {}

    new.storages = {}
    new.passive_providers = {}
    new.active_providers = {}
    new.requesters = {}
    new.inventories = {}
    new.inventory_names = {}
    new.inventory_types = {}

    setmetatable(new, self)

    return new
end

---@param item ItemDetail item_cache details for the item
---@param skip_count integer how many inventories to skip forward
---@return Inventory | nil
function LogisticsSystem:_findDestination(item, skip_count)
    for _, requester in pairs(self.requesters) do
        if requester:supportsItem(item) then
            if skip_count > 0 then skip_count = skip_count - 1
            else return requester end
        end
    end
    for _, storage in pairs(self.storages) do
        if storage:supportsItem(item) then
            if skip_count > 0 then skip_count = skip_count - 1
            else return storage end
        end
    end
end

---@param item_id string namespaced id of the item
---@param skip_count integer how many inventories to skip forward
---@return Inventory | nil
function LogisticsSystem:_findSource(item_id, skip_count)
    for _, active_provider in pairs(self.active_providers) do
        if active_provider:hasItem(item_id) then
            if skip_count > 0 then skip_count = skip_count - 1
            else return active_provider end
        end
    end
    for _, passive_provider in pairs(self.passive_providers) do
        if passive_provider:hasItem(item_id) then
            if skip_count > 0 then skip_count = skip_count - 1
            else return passive_provider end
        end
    end
    for _, storage in pairs(self.storages) do
        if storage:hasItem(item_id) then
            if skip_count > 0 then skip_count = skip_count - 1
            else return storage end
        end
    end
end

---@param source_inventory Inventory inventory to push from
---@param item ItemDetail item detail from item_cache
---@param count integer quantity of the item to push
---@return integer count how many items were unable to be pushed
function LogisticsSystem:pushFrom(source_inventory, item, count)
    log.verbose(" -> Pushing " .. count .. "x " .. item.name)

    local attempt = 0
    while count > 0 do
        local destination_inventory = self:_findDestination(item, attempt)
        if destination_inventory == nil then break end

        if destination_inventory ~= source_inventory then
            log.verbose("   -> Try " .. destination_inventory.name)

            count = source_inventory:pushTo(destination_inventory, item, count)
        end

        attempt = attempt + 1
    end

    return count
end

---@param destination_inventory Inventory inventory to pull to
---@param item ItemDetail item detail from item_cache
---@param count integer quantity of the item to push
---@return integer count how many items were unable to be pushed
function LogisticsSystem:pullTo(destination_inventory, item, count)
    log.verbose(" -> Pulling " .. count .. "x " .. item.name)

    local attempt = 0
    while count > 0 do
        local source_inventory = self:_findSource(item.name, attempt)
        if source_inventory == nil then break end

        if source_inventory ~= destination_inventory then
            log.verbose("   -> Try " .. source_inventory.name)

            count = destination_inventory:pullFrom(source_inventory, item, count)
        end

        attempt = attempt + 1
    end

    return count
end

---@param types table<string, true> bag of inventory types to skip
function LogisticsSystem:updateInventories(types)
    local functions = {}
    for inventory, type in pairs(self.inventory_types) do
        if types[type] then
            table.insert(functions, function()
                inventory:updateCache()
            end)
        end
    end

    parallel.waitForAll(table.unpack(functions))
end

function LogisticsSystem:updateActiveProviders()
    local functions = {}

    for name, active_provider in pairs(self.active_providers) do
        log.verbose("Updating active provider " .. name)

        for item_id in pairs(active_provider.item_counts) do
            table.insert(functions, function()
                local count = active_provider.item_counts[item_id]
                self:pushFrom(active_provider, item_cache.get(item_id), count)
            end)
        end
    end

    parallel.waitForAll(table.unpack(functions))
end

function LogisticsSystem:updateRequesters()
    local functions = {}

    for name, requester in pairs(self.requesters) do
        log.verbose("Updating requester " .. name)

        for item_id, filter_count in pairs(requester.filter) do
            local satisfied_count = requester.item_counts[item_id] or 0
            local count = filter_count - satisfied_count

            if count > 0 then
                log.verbose(name .. " requesting " .. item_id .. " (" .. satisfied_count .. "/" .. filter_count .. " satisfied)")
                
                local item = item_cache.get(item_id)
                if item ~= nil then
                    table.insert(functions, function()
                        local new_count = self:pullTo(requester, item, count)

                        if new_count ~= count then
                            log.debug(name .. " pulled " .. count - new_count .. "x " .. item_id .. " (" .. (satisfied_count + count - new_count) .. "/" .. filter_count .. " satisfied)")
                        end
                    end)
                else
                    log.debug("Failed to pull " .. item_id .. " because no cache of its type exists")
                end
            end
        end
    end

    parallel.waitForAll(table.unpack(functions))
end

function LogisticsSystem:compactStorage()
    local storage_names = {}
    for name in pairs(self.storages) do
        table.insert(storage_names, name)
    end
    local storage_names_reversed = {}
    for i = 1, #storage_names do
        storage_names_reversed[i] = storage_names[#storage_names - i + 1]
    end

    log.info("Starting storage compaction")

    for _, destination_name in pairs(storage_names) do
        local destination = self.storages[destination_name]

        for _, source_name in pairs(storage_names_reversed) do
            local source = self.storages[source_name]

            log.debug("Compact: trying to merge " .. source.name .. " to " .. destination.name)

            for item_id, item_count in pairs(source.item_counts) do
                source:pushTo(destination, item_cache.get(item_id), item_count)
            end

            if source.name == destination.name then break end
        end
    end
end

---@param name string
---@return Inventory | nil, "active_provider" | "passive_provider" | "storage" | "requester" | nil
function LogisticsSystem:removeInventory(name)
    local inventory = self.inventories[name]

    for i, inventory_name in pairs(self.inventory_names) do
        if inventory_name == name then
            table.remove(self.inventory_names, i)
            break
        end
    end

    if inventory == nil then return end
    self.inventories[name] = nil

    local type = self.inventory_types[inventory]
    self.inventory_types[inventory] = nil

    if type == "active_provider" then
        self.active_providers[name] = nil
    elseif type == "passive_provider" then
        self.passive_providers[name] = nil
    elseif type == "storage" then
        self.storages[name] = nil
    elseif type == "requester" then
        self.requesters[name] = nil
    end

    return inventory, type
end

---@param inventory Inventory
---@param type "active_provider" | "passive_provider" | "storage" | "requester"
function LogisticsSystem:addInventory(inventory, type)
    if type == "active_provider" then
        self.active_providers[inventory.name] = inventory
    elseif type == "passive_provider" then
        self.passive_providers[inventory.name] = inventory
    elseif type == "storage" then
        self.storages[inventory.name] = inventory
    elseif type == "requester" then
        self.requesters[inventory.name] = inventory
    end

    self.inventories[inventory.name] = inventory
    self.inventory_types[inventory] = type
    table.insert(self.inventory_names, inventory.name)
end

return LogisticsSystem