local function exec(cmd)
    print("$ " .. cmd)
    shell.run(cmd)
end

local prefix = "https://raw.githubusercontent.com/lexifuzzpup/puppygistics/refs/heads/main/"

local files = {
    "inventory.lua",
    "item-cache.lua",
    "log.lua",
    "logistics-system.lua",
    "active-provider-inventory.lua",
    "passive-provider-inventory.lua",
    "storage-inventory.lua",
    "requester-inventory.lua",
    "startup.lua",
    "dashboard.lua",
    "statistics.lua",
    "semaphore.lua",
    "mainframe.lua",
}

print("\n### DOWNLOADING FILES ###")
for _, file in pairs(files) do
    print("Downloading " .. file)
    local response = http.get(prefix .. file)
    local data = response.readAll()

    local handle = fs.open("/" .. file, "w")
    handle.write(data)
    handle.close()
end

print("\n### DEPDENDENCIES ###")
print("Puppygistics has the following dependencies:")
print("* Basalt 2.5")
print()
print("These will be downloaded and installed automatically.")
print("Press any key to continue.")
os.pullEvent("key")

print("-> Installing Basalt 2.5")
exec("rm basalt.lua")
exec("wget run https://basalt.madefor.cc/2.5/install.lua minified")

print("\n### Configuration ###")
if fs.exists("/puppygistics.json") then
    print("A /puppygistics.json config file was found.")
    print("Would you like to update this config? (Y/n)")

    while true do
        local response = read():lower()

        if #response == 0 or response:sub(1, 1) == "y" then
            fs.move("/puppygistics.json", "/puppygistics.config.lua")
            print("Success!")
            break
        elseif response:sub(1, 1) == "n" then
            print("Keeping the file where it is")
            break
        end
    end
end
local config_filepath = "/puppygistics.config.lua"
if not fs.exists(config_filepath) then
    print()
    print("The installer will now create the following config file:")
    print(config_filepath)
    print("This is configurable via the dashboard.")
    print("Consult the README for help configuring this file manually.")
    print()
    print("Press any key to continue.")
    os.pullEvent("key")

    local file = fs.open(config_filepath, "w")
    file.write("{ members = {} }")
    file.close()
end

print("Puppygistics fully installed!")
print("Your computer is now safe to reboot.")