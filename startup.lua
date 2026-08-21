local basalt = require("basalt")
local log = require("log")
local Semaphore = require("semaphore")
local Mainframe = require("mainframe")

settings.define("logging.level", {
    description = "Logging level for the system. verbose=0, debug=1, info=2, warning=3, error=4, fatal=5",
    default = 2,
    type = "number"
})
settings.define("puppygistics.updates.storage", {
    description = "How many updates should pass before storage contents are updated",
    default = 20,
    type = "number"
})
settings.define("puppygistics.updates.compact", {
    description = "How many updates should pass before storage is re-compacted.",
    default = 1000,
    type = "number"
})
settings.define("puppygistics.parallelism", {
    description = "How many parallel inventory operations to allow",
    default = 128,
    type = "number"
})
PeripheralSemaphore = Semaphore:new(settings.get("puppygistics.parallelism"))

local mainframe = Mainframe:new()

log.info("Reading config")
mainframe:loadConfig("/puppygistics.json")
mainframe:createFileLogger("/latest.log")

parallel.waitForAny(
    function() mainframe:run() end,
    function() basalt.run() end,
    function()
        os.pullEventRaw("terminate")
        mainframe:shutdown()
    end
)