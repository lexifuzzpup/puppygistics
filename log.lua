local log_handlers = {}
local log = {}

function log.log(level, text)
    if level < settings.get("logging.level") then return end

    if type(text) == "table" then
        local success, serialized = pcall(textutils.serialize, text)
        if success then
            text = serialized
        else
            local manual = "{\n"

            for k, v in pairs(text) do
                manual = manual .. k .. " = <" .. type(v) .. ">\n"
            end

            text = manual .. "}"
        end
    else
        text = tostring(text)
    end

    for _, callback in pairs(log_handlers) do
        local success, error = pcall(callback, level, text)

        if not success then
            print("Logging error:")
            print(error)
        end
    end
end

function log.addHandler(callback)
    table.insert(log_handlers, callback)
end

function log.verbose(text)
    log.log(0, text)
end
function log.debug(text)
    log.log(1, text)
end
function log.info(text)
    log.log(2, text)
end
function log.warn(text)
    log.log(3, text)
end
function log.error(text)
    log.log(4, text)
end
function log.fatal(text)
    log.log(5, text)
end

return log