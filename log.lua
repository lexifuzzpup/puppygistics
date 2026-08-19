return function(level, text)
    if level < settings.get("logging.level") then return end

    print(text)

    local file = fs.open("latest.log", "a")
    file.write(text .. "\n")
    file.close()
end