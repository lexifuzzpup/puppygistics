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

---@type table<number, LogisticsSystem>
local systems = {}

local function parseSystem(system_config)
    local system = LogisticsSystem:new()

    local all_storages = {}

    for _, name in pairs(peripheral.getNames()) do
        if peripheral.hasType(name, "inventory") then
            all_storages[name] = true
        end
    end

    for name, config in pairs(system_config.active_providers or {}) do
        system:addActiveProvider(Inventory:new(name))
        all_storages[name] = nil
    end
    for name, config in pairs(system_config.passive_providers or {}) do
        system:addPassiveProvider(Inventory:new(name))
        all_storages[name] = nil
    end
    for name, config in pairs(system_config.requesters or {}) do
        local requester = RequesterInventory:new(name)
        for item_id, count in pairs(config) do
            requester:addFilterItem(item_id, count)
        end
        system:addRequester(requester)
        all_storages[name] = nil
    end

    for name in pairs(all_storages) do
        system:addStorage(Inventory:new(name))
    end

    return system
end

local function shutdown()
    log(1, "Shutting down system")
end

---@param filename string
local function loadConfig(filename)
    local storage_config = readJson(filename)

    local is_multisystem = (storage_config.systems ~= nil)

    if is_multisystem then
        for system_id, system_config in pairs(storage_config.systems) do
            local system = parseSystem(system_config)
            systems[system_id] = system
        end
    else
        systems[1] = parseSystem(storage_config)
    end
end

local function compact_storages()
    local success = true

    for system_id, system in pairs(systems) do
        log(1, "Compacting system " .. system_id .. "...")

        local success, error_message = pcall(function()
            system:compactStorage()
        end)

        if not success then
            log(3, "Failed to compact storage for system " .. system_id .. ":")
            log(3, tostring(error_message))
            success = false
        end
    end

    return success
end


local function main()
    log(1, "Loading config")
    loadConfig("/puppygistics.json")

    log(1, "Performing startup storage compaction")
    local success = compact_storages()

    if not success then
        log(4, "Failed to start system")
    else
        log(1, "Done!")
        log(1, "All systems active")
        local update_number = 1
        while true do
            for system_id, system in pairs(systems) do
                log(0, "\nUpdating system " .. system_id)

                local success, error_message = pcall(function()
                    if update_number % settings.get("updates.storage") == 0 then
                        system:updateStorages()
                    end
                    system:updateActiveProviders()
                    system:updatePassiveProviders()
                    system:updateRequesters()
                end)

                if not success then
                    log(3, "Failed to update system " .. system_id .. ":")
                    log(3, tostring(error_message))
                end
            end

            if update_number % settings.get("updates.compact") == 0 then
                log(1, "Performing automatic storage compaction")
                compact_storages()
            end

            update_number = update_number + 1
        end
    end
end

parallel.waitForAny(main, function()
    os.pullEventRaw("terminate")
    shutdown()
end)