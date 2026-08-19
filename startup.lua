local basalt = require("basalt")
local log = require("log")
local Inventory = require("inventory")
local RequesterInventory = require("requester-inventory")
local LogisticsSystem = require("logistics-system")
local readJson = require("json")
local statistics = require("statistics")
local createDashboard = require("dashboard")

local log_file = fs.open("latest.log", "w")
log_file.write("")
log_file.close()

log.addHandler(function(level, text)
    local level_name = "?"

    if level == 0 then level_name = "VERBOSE"
    elseif level == 1 then level_name = "DEBUG"
    elseif level == 2 then level_name = "INFO"
    elseif level == 3 then level_name = "WARN"
    elseif level == 4 then level_name = "ERROR"
    elseif level == 5 then level_name = "FATAL"
    end

    local hour = tostring(math.floor(os.time()))
    if #hour == 1 then hour = "0" .. hour end

    local minute = tostring(math.floor((os.time() * 60) % 60))
    if #minute == 1 then minute = "0" .. minute end

    local second = tostring(math.floor((os.time() * 3600) % 60))
    if #second == 1 then second = "0" .. second end

    local time = "Day " .. os.day() .. ", " .. hour .. ":" .. minute .. ":" .. second

    local file = fs.open("latest.log", "a")
    file.write(time .. " " .. level_name .. " " .. text .. "\n")
    file.close()
end)

settings.define("logging.level", {
    description = "Logging level for the system. verbose=0, debug=1, info=2, warning=3, error=4, fatal=5",
    default = 2,
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

local frame = basalt.getMainFrame()

local tabs = frame:addTabControl({
    x = 1,
    y = 1,
    width = basalt.fill(),
    height = basalt.fill(),
})

local logs_page = tabs:addTab("Logs")
do
    local logs_list = logs_page:addList({
        width = basalt.fill(),
        height = basalt.fill()
    })
    logs_list:onSelect(function(self, index, item)
        local popout = logs_page:addFrame({
            x = 1,
            y = 1,
            width = basalt.fill(),
            height = basalt.fill(),
            background = colors.black
        })

        popout:addLabel({
            x = 1,
            y = 1,
            width = basalt.fill(),
            height = 1,
            text = "Log Detail",
            foreground = colors.black,
            background = colors.yellow
        })

        popout:addTextBox({
            x = 1,
            y = 2,
            width = basalt.fill(),
            height = "{((parent or {}).height or 0) - 5}",
            text = item.text,
            foreground = item.fg or colors.white,
            background = colors.black
        })

        popout:addButton({
            x = "{(((parent or {}).width) or 0) - 8}",
            y = 1,
            width = 10,
            height = 1,
            text = "Close",
            background = colors.red
        }):onClick(function()
            popout:destroy()
            logs_list:focus()
        end)
    end)
    log.addHandler(function(level, text)
        local bgColor = colors.black
        local fgColor = colors.white

        if level == 0 then
            fgColor = colors.gray
        elseif level == 1 then
            fgColor = colors.lightGray
        elseif level == 2 then
            fgColor = colors.white
        elseif level == 3 then
            fgColor = colors.yellow
        elseif level == 4 then
            fgColor = colors.red
        elseif level == 5 then
            bgColor = colors.red
            fgColor = colors.black
        end

        logs_list:addItem({
            text = text,
            bg = bgColor,
            fg = fgColor
        })

        local maxOffset = math.max(0, logs_list:getItemCount() - logs_list:getHeight())
        logs_list:setOffset(maxOffset)
    end)
end

local dashboard = createDashboard(tabs)


-- local config_page = tabs:addTab("Config")
-- local statistics_page = tabs:addTab("Statistics")

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
        log.warn("Failed to add peripheral " .. name .. " because it isn't present")
        return nil
    end

    local type, config = getInventoryType(name, system_config)

    if type == nil then return nil end

    ---@type Inventory
    local inventory = nil

    if type == "active_provider" then
        local active_provider = Inventory:new(name)

        system:addInventory(active_provider, type)
        inventory = active_provider
    elseif type == "passive_provider" then
        local passive_provider = Inventory:new(name)

        system:addInventory(passive_provider, type)
        inventory = passive_provider
    elseif type == "requester" then
        local requester = RequesterInventory:new(name)

        for item_id, count in pairs(config) do
            requester:addFilterItem(item_id, count)
        end

        system:addInventory(requester, type)
        inventory = requester
    elseif type == "storage" then
        local storage = Inventory:new(name)

        system:addInventory(storage, type)
        inventory = storage
    end

    if inventory == nil then
        log.warn("Unknown inventory type " .. type .. " for " .. name)
    else
        inventory:init()
        log.info("Added inventory " .. inventory.name .. " (" .. type .. ")")
    end

    return inventory
end

---@param system LogisticsSystem
local function compact_system(system)
    statistics.freeze()
    local success, error_message = pcall(function()
        system:compactStorage()
    end)

    if not success then
        log.error("Failed to compact system storage:")
        log.error(tostring(error_message))
    end

    statistics.unfreeze()

    return success
end

local function shutdown()
    log.info("Shutting down system")
end


---@param system LogisticsSystem
local function updateLoop(system)
    local update_number = 1
    local update_types = {
        active_provider = true,
        passive_provider = true,
        requester = true,
        storage = false
    }
    local nextStatisticsEpoch = os.clock()
    while true do
        log.verbose("Updating system @ " .. os.clock() .. "s")

        local success, error_message = pcall(function()
            update_types.storage = update_number % settings.get("updates.storage") == 0

            system:updateInventories(update_types)

            parallel.waitForAll(
                function()
                    system:updateActiveProviders()
                end,
                function()
                    system:updateRequesters()
                end
            )
        end)

        if not success then
            log.error("Failed to update system:")
            log.error(tostring(error_message))
        end

        if update_number % settings.get("updates.compact") == 0 then
            log.info("Performing automatic storage compaction")
            compact_system(system)
        end

        if os.clock() > nextStatisticsEpoch then
            nextStatisticsEpoch = math.max(os.clock(), nextStatisticsEpoch + 1)

            statistics.epoch()
            dashboard.update()
        end

        update_number = update_number + 1
    end
end

---@param system LogisticsSystem
---@param system_config table
local function peripheralAttachLoop(system, system_config)
    while true do
        local _, peripheral_name = os.pullEvent("peripheral")

        if peripheral.hasType(peripheral_name, "inventory") then
            addInventory(peripheral_name, system_config, system)
        end
    end
end

---@param system LogisticsSystem
local function peripheralDetachLoop(system)
    while true do
        local _, peripheral_name = os.pullEvent("peripheral_detach")

        local inventory, type = system:removeInventory(peripheral_name)
        log.info("Removed inventory " .. inventory.name .. " (" .. type .. ")")
    end
end

local function main()
    log.info("Reading config")
    local system_config = readJson("/puppygistics.json")

    main_system = LogisticsSystem:new()

    log.info("Adding attached inventories")
    local functions = {}
    for _, name in pairs(peripheral.getNames()) do
        local nname = name
        if peripheral.hasType(name, "inventory") then
            table.insert(functions, function ()
                addInventory(nname, system_config, main_system)
            end)
        end
    end

    parallel.waitForAll(table.unpack(functions))

    log.info("Performing startup storage compaction")
    local success = compact_system(main_system)

    if not success then
        log.fatal("Failed to start system")
    else
        log.info("Done!")
        log.info("System active")

        parallel.waitForAll(
            function() updateLoop(main_system) end,
            function() peripheralAttachLoop(main_system, system_config) end,
            function() peripheralDetachLoop(main_system) end
        )
    end
end

parallel.waitForAny(
    function() main() end,
    function() basalt.run() end,
    function()
        os.pullEventRaw("terminate")
        shutdown()
    end
)