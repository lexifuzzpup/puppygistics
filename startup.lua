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

    for name, config in pairs(system_config.active_providers or {}) do
        system:addActiveProvider(Inventory:new(name))
    end
    for name, config in pairs(system_config.passive_providers or {}) do
        system:addPassiveProvider(Inventory:new(name))
    end
    for name, config in pairs(system_config.storages or {}) do
        system:addStorage(Inventory:new(name))
    end
    for name, config in pairs(system_config.requesters or {}) do
        local requester = RequesterInventory:new(name)
        for item_id, count in pairs(config) do
            requester:addFilterItem(item_id, count)
        end
        system:addRequester(requester)
    end

    return system
end

---@param filename string
local function loadConfig(filename)
    local storage_config = readJson(filename)

    local is_array = (#storage_config ~= 0)

    if is_array then
        table.insert(systems, storage_config)
    else
        for system_id, system_config in pairs(storage_config.systems) do
            local system = parseSystem(system_config)
            systems[system_id] = system
        end
    end
end

local function compact_storages()
    for system_id, system in pairs(systems) do
        log(1, "Compacting system " .. system_id .. "...")
        system:compactStorage()
    end
end


log(1, "Loading config")
loadConfig("/storage.json")

log(1, "Performing startup storage compaction")
compact_storages()

log(1, "Done!")
log(1, "All systems active")


local update_number = 1
while true do
    for system_id, system in pairs(systems) do
        log(0, "\nUpdating system " .. system_id)

        if update_number % settings.get("updates.storage") == 0 then
            system:updateStorages()
        end
        system:updateActiveProviders()
        system:updatePassiveProviders()
        system:updateRequesters()
    end

    if update_number % settings.get("updates.compact") == 0 then
        log(1, "Performing automatic storage compaction")
        compact_storages()
    end

    update_number = update_number + 1
end