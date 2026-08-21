local basalt = require("basalt")
local log = require("log")
local Inventory = require("inventory")
local ActiveProviderInventory = require("active-provider-inventory")
local PassiveProviderInventory = require("passive-provider-inventory")
local StorageInventory = require("storage-inventory")
local RequesterInventory = require("requester-inventory")
local LogisticsSystem = require("logistics-system")
local statistics = require("statistics")
local createDashboard = require("dashboard")

---@class MainframeConfig
---@field members table<string, { type: string, config: table | nil }>
local MainframeConfig = {}

---@class Mainframe
---@field config MainframeConfig
---@field system LogisticsSystem
---@field config_filepath string
---@field dashboard table
---@field dashboard_needs_update boolean
---@field next_compact number
local Mainframe = {}
Mainframe.__index = Mainframe

---@return Mainframe
function Mainframe:new()
    local new = {
        dashboard_needs_update = false,
        next_compact = os.clock()
    }

    setmetatable(new, self)

    return new
end

function Mainframe:loadConfig(filepath)
    if not fs.exists(filepath) then
        error("Config file " .. filepath .. " does not exist")
    end
    local file = fs.open(filepath, "r")
    local success, contents = pcall(file.readAll)
    file.close()


    if not success then error("Failed to read config file: " .. contents) end

    local config = textutils.unserialize(contents)
    if not config then config = textutils.unserializeJSON(contents) end
    if not config then error("Config file is malformed (must be lua-serialized or json)") end

    local success, malformed_error = pcall(function()
        if config == nil then error("config cannot be nil") end
        if config.members == nil then error("config.members cannot be nil") end

        for i, member in pairs(config.members) do
            local path = "config.members[" .. i .. "]"
            if type(member) ~= "table" then error(path .. " must be a table") end

            if member.type == nil then error(path .. ".type cannot be nil") end

            local config_type = type(member.config)
            if config_type ~= "table" and config_type ~= "nil" then
                error(path .. ".config must be a table or nil")
            end
        end
    end)

    if not success then error("Config file is malformed: " .. malformed_error) end

    self.config = config
    self.config_filepath = filepath
end

function Mainframe:saveConfig()
    local contents = textutils.serialise(self.config)

    local file = fs.open(self.config_filepath, "w")
    pcall(file.write, contents)
    file.close()
end

function Mainframe:createFileLogger(filepath)
    local log_file = fs.open(filepath, "w")
    log_file.write("")
    log_file.close()

    local level_names = {
        [0] = "VERBOSE",
        [1] = "DEBUG",
        [2] = "INFO",
        [3] = "WARN",
        [4] = "ERROR",
        [5] = "FATAL"
    }

    log.addHandler(function(level, text)
        local level_name = level_names[level] or "?"

        local hour = tostring(math.floor(os.time()))
        if #hour == 1 then hour = "0" .. hour end

        local minute = tostring(math.floor((os.time() * 60) % 60))
        if #minute == 1 then minute = "0" .. minute end

        local second = tostring(math.floor((os.time() * 3600) % 60))
        if #second == 1 then second = "0" .. second end

        local time = "Day " .. os.day() .. ", " .. hour .. ":" .. minute .. ":" .. second

        local file = fs.open(filepath, "a")
        file.write(time .. " " .. level_name .. " " .. text .. "\n")
        file.close()
    end)
end

-- local config_page = tabs:addTab("Config")
-- local statistics_page = tabs:addTab("Statistics")

---@param name string name of the peripheral
---@param system_config MainframeConfig config of the system
---@return string | nil, table
function Mainframe:getInventoryType(name, system_config)
    if not peripheral.hasType(name, "inventory") then return nil, {} end

    local member = system_config.members[name]

    if member == nil then
        return "unassigned", {}
    end

    return member.type or "unassigned", member.config or {}
end

---@param name string name of the peripheral
---@param type string new type to set
---@param config table config for the inventory
---@return Inventory | nil
function Mainframe:_createInventory(name, type, config)
    if type == "active_provider" then
        local active_provider = ActiveProviderInventory:new(name, config)

        self.system:addInventory(active_provider)
        return active_provider
    elseif type == "passive_provider" then
        local passive_provider = PassiveProviderInventory:new(name, config)

        self.system:addInventory(passive_provider)
        return passive_provider
    elseif type == "requester" then
        local requester = RequesterInventory:new(name, config)

        self.system:addInventory(requester)
        return requester
    elseif type == "storage" then
        local storage = StorageInventory:new(name, config)

        self.system:addInventory(storage)
        return storage
    elseif type == "unassigned" then
        local unassigned = Inventory:new(name, "unassigned")

        self.system:addInventory(unassigned)
        return unassigned
    end
end

---@param name string name of the peripheral
function Mainframe:addPeripheral(name)
    if not peripheral.isPresent(name) then
        log.warn("Failed to add peripheral " .. name .. " because it isn't present")
        return nil
    end

    local type, config = self:getInventoryType(name, self.config)

    if type == nil then return nil end

    local inventory = self:_createInventory(name, type, config)

    if inventory == nil then
        log.warn("Unknown inventory type " .. type .. " for " .. name)
    else
        inventory:init()
        log.info("Added inventory " .. inventory.name .. " (" .. type .. ")")
    end

    self.dashboard.addMember(inventory)

    return inventory
end

---@param name string name of the inventory peripheral
function Mainframe:removePeripheral(name)
    local inventory = self.system:removeInventory(name)

    if inventory ~= nil then
        log.info("Removed inventory " .. inventory.name .. " (" .. inventory.type .. ")")
        self.dashboard.removeMember(inventory)
    end
end

---@param inventory Inventory inventory to change the type of
---@param type string new type to set
---@param config table | nil new config for the inventory
function Mainframe:setInventoryType(inventory, type, config)
    config = config or {}

    local new_inventory = self:_createInventory(inventory.name, type, config)

    if new_inventory ~= nil then
        self.system:removeInventory(inventory.name)
        self.system:addInventory(new_inventory)
        new_inventory:init()

        local config_entry = self.config.members[inventory.name]
        if config_entry == nil then
            config_entry = { type = "" }
            self.config.members[inventory.name] = config_entry
        end
        config_entry.type = type
        config_entry.config = config

        self.dashboard.updateMember(new_inventory)

        log.info("Changed inventory type for " .. inventory.name .. " from " .. inventory.type .. " to " .. type)
    end
end

function Mainframe:compactSystem()
    statistics.freeze()
    local success, error_message = pcall(function()
        self.system:compactStorage()
    end)

    if not success then
        log.error("Failed to compact system storage:")
        log.error(tostring(error_message))
    end

    statistics.unfreeze()

    return success
end

function Mainframe:shutdown()
    log.info("Shutting down system")
end

function Mainframe:dashboardUpdateLoop()
    local nextStatisticsEpoch = os.clock()

    while true do
        if os.clock() > nextStatisticsEpoch then
            nextStatisticsEpoch = math.max(os.clock(), nextStatisticsEpoch + 0.2)

            statistics.epoch(os.epoch("utc"))

            if self.system ~= nil then
                self.dashboard_needs_update = true
            end
        end
        coroutine.yield()
    end
end

function Mainframe:updateLoop()
    local update_number = 1
    local update_types = {
        active_provider = false,
        passive_provider = false,
        storage = false,
        requester = false,
    }

    while true do
        log.verbose("Updating system @ " .. os.clock() .. "s")

        local success, error_message = pcall(function()
            local offset = 0
            for name in pairs(update_types) do
                local interval = settings.get("puppygistics.updates." .. name)
                update_types[name] = (update_number + offset) % interval == 0
                offset = offset + 1
            end

            self.system:updateInventories(update_types)

            self.system:updateActiveProviders()
            self.system:updateRequesters()
        end)

        if not success then
            log.error("Failed to update system:")
            log.error(tostring(error_message))
        end

        if self.next_compact < os.clock() then
            self.next_compact = math.max(os.clock(), self.next_compact + settings.get("puppygistics.compacting.interval"))

            if settings.get("puppygistics.compacting.enabled") then
                log.info("Performing automatic storage compaction")
                self:compactSystem()
            end
        end

        if self.dashboard_needs_update then
            self.dashboard.update()
            self.dashboard_needs_update = false
        end

        update_number = update_number + 1

        sleep(0.05)
    end
end

function Mainframe:peripheralAttachLoop()
    while true do
        local _, peripheral_name = os.pullEvent("peripheral")

        if peripheral.hasType(peripheral_name, "inventory") then
            self:addPeripheral(peripheral_name)
        end
    end
end

function Mainframe:peripheralDetachLoop()
    while true do
        local _, peripheral_name = os.pullEvent("peripheral_detach")

        self:removePeripheral(peripheral_name)
    end
end

function Mainframe:startSystem()
    log.info("Adding attached inventories")
    local functions = {}
    local completed_count = 0
    for _, name in pairs(peripheral.getNames()) do
        if peripheral.hasType(name, "inventory") then
            table.insert(functions, function ()
                self:addPeripheral(name)
                completed_count = completed_count + 1
                log.debug("Added peripheral " .. completed_count .. "/" .. #functions)
            end)
        end
    end

    parallel.waitForAll(table.unpack(functions))

    local success = true
    if settings.get("puppygistics.compacting.enabled") then
        log.info("Performing startup storage compaction")
        success = success and self:compactSystem()
    end

    if not success then
        log.fatal("Failed to start system")
    else
        log.info("Done!")
        log.info("System active")

        parallel.waitForAll(
            function() self:updateLoop() end,
            function() self:peripheralAttachLoop() end,
            function() self:peripheralDetachLoop() end
        )
    end
end

function Mainframe:run()
    self.dashboard = createDashboard(self, basalt.getMainFrame())
    self.system = LogisticsSystem:new()

    parallel.waitForAny(
        function() self:startSystem() end,
        function() self:dashboardUpdateLoop() end
    )
end

return Mainframe