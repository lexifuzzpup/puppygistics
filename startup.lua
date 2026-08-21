local basalt = require("basalt")
local log = require("log")
local Semaphore = require("semaphore")
local Mainframe = require("mainframe")

settings.define("logging.level", {
    description = "Logging level for the system. verbose=0, debug=1, info=2, warning=3, error=4, fatal=5",
    default = 2,
    type = "number"
})
settings.define("logging.file.enabled", {
    description = "Whether or not to log to a file",
    default = false,
    type = "boolean"
})
settings.define("puppygistics.updates.active_provider", {
    description = "Frequency (in updates) at which active_provider inventories should be re-polled",
    default = 1,
    type = "number"
})
settings.define("puppygistics.updates.passive_provider", {
    description = "Frequency (in updates) at which passive_provider inventories should be re-polled",
    default = 1,
    type = "number"
})
settings.define("puppygistics.updates.storage", {
    description = "Frequency (in updates) at which storage inventories should be re-polled",
    default = 20,
    type = "number"
})
settings.define("puppygistics.updates.requester", {
    description = "Frequency (in updates) at which requester inventories should be re-polled",
    default = 1,
    type = "number"
})
settings.define("puppygistics.compacting.interval", {
    description = "How many seconds should pass between storage compactions",
    default = 60,
    type = "number"
})
settings.define("puppygistics.compacting.enabled", {
    description = "Enables storage compaction on startup and at set intervals",
    default = false,
    type = "boolean"
})
settings.define("puppygistics.parallelism", {
    description = "How many parallel inventory operations to allow.",
    default = 128,
    type = "number"
})
PeripheralSemaphore = Semaphore:new(settings.get("puppygistics.parallelism"))

local mainframe = Mainframe:new()

log.info("Reading config")
mainframe:loadConfig("/puppygistics.config.lua")

if settings.get("logging.file.enabled") then
    mainframe:createFileLogger("/latest.log")
end

parallel.waitForAny(
    function() mainframe:run() end,
    function() basalt.run() end,
    function()
        os.pullEventRaw("terminate")
        mainframe:shutdown()
    end
)