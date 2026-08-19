local log = require("log")
local Inventory = require("inventory")
local RequesterInventory = require("requester-inventory")
local LogisticsSystem = require("logistics-system")
local readJson = require("json")

settings.define("logging.level", {
    description = "Logging level for the system. debug=0, info=1, warning=2, error=3, fatal=4",
    default = 1,
    type = "number"
})
settings.define("updates.storage", {
    description = "How many updates should pass before storage contents are updated",
    default = 20,
    type = "number"
})
settings.define("updates.compact", {
    description = "How many updates should pass before storage is re-compacted",
    default = 1000,
    type = "number"
})

---@type LogisticsSystem
local main_system

---@param name string name of the peripheral
---@param system_config table config of the system
---@return string | nil, table
local function getInventoryType(name, system_config)
    if not peripheral.hasType(name, "inventory") then return nil, {} end

    for other_name, config in pairs(system_config.active_providers or {}) do
        if name == other_name then return "active_provider", config end
    end
    for other_name, config in pairs(system_config.passive_providers or {}) do
        if name == other_name then return "passive_provider", config end
    end
    for other_name, config in pairs(system_config.requesters or {}) do
        if name == other_name then return "requester", config end
    end
    for other_name, config in pairs(system_config.storages or {}) do
        if name == other_name then return "storage", config end
    end

    return "storage", {}
end

---@param name string name of the peripheral
---@param system_config table config of the system
---@param system LogisticsSystem logistics system to add to
local function addInventory(name, system_config, system)
    if not peripheral.isPresent(name) then
        log(2, "Failed to add peripheral " .. name .. " because it isn't present")
        return nil
    end

    local type, config = getInventoryType(name, system_config)

    if type == nil then
        return nil
    end

    log(1, "Add inventory " .. name .. " as " .. type)

    if type == "active_provider" then
        local active_provider = Inventory:new(name)

        system:addActiveProvider(active_provider)
        return active_provider
    elseif type == "passive_provider" then
        local passive_provider = Inventory:new(name)

        system:addPassiveProvider(passive_provider)
        return passive_provider
    elseif type == "requester" then
        local requester = RequesterInventory:new(name)

        for item_id, count in pairs(config) do
            requester:addFilterItem(item_id, count)
        end

        system:addRequester(requester)
        return requester
    elseif type == "storage" then
        local storage = Inventory:new(name)

        system:addStorage(storage)
        return storage
    end

    log(2, "Unknown inventory type " .. type .. " for " .. name)
end

---@param system LogisticsSystem
local function compact_system(system)
    local success, error_message = pcall(function()
        system:compactStorage()
    end)

    if not success then
        log(3, "Failed to compact system storage:")
        log(3, tostring(error_message))
    end

    return success
end

local function shutdown()
    log(1, "Shutting down system")
end


---@param system LogisticsSystem
local function updateLoop(system)
    local update_number = 1
    while true do
        log(0, "\nUpdating system")

        local success, error_message = pcall(function()
            if update_number % settings.get("updates.storage") == 0 then
                system:updateStorages()
            end
            system:updateActiveProviders()
            system:updatePassiveProviders()
            system:updateRequesters()
        end)

        if not success then
            log(3, "Failed to update system:")
            log(3, tostring(error_message))
        end

        if update_number % settings.get("updates.compact") == 0 then
            log(1, "Performing automatic storage compaction")
            compact_system(system)
        end

        update_number = update_number + 1
    end
end

local function main()
    log(1, "Reading config")
    local system_config = readJson("/puppygistics.json")

    main_system = LogisticsSystem:new()

    log(1, "Adding attached inventories")
    for _, name in pairs(peripheral.getNames()) do
        if peripheral.hasType(name, "inventory") then
            addInventory(name, system_config, main_system)
        end
    end

    log(1, "Performing startup storage compaction")
    local success = compact_system(main_system)

    if not success then
        log(4, "Failed to start system")
    else
        log(1, "Done!")
        log(1, "System active")

        parallel.waitForAll(
            function() updateLoop(main_system) end,
        )
    end
end

parallel.waitForAny(main, function()
    os.pullEventRaw("terminate")
    shutdown()
end)