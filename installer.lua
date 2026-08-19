local function exec(cmd)
    print("$ " .. cmd)
    shell.run(cmd)
end

local prefix = "https://raw.githubusercontent.com/lexifuzzpup/puppygistics/refs/heads/main/"

local files = {
    "inventory.lua",
    "item-cache.lua",
    "json.lua",
    "log.lua",
    "logistics-system.lua",
    "requester-inventory.lua",
    "startup.lua",
    "puppygistics.example.json",
    "dashboard.lua",
    "statistics.lua",
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

exec("mv /puppygistics.example.json /puppygistics.json")
exec("rm /puppygistics.example.json")

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

print("Fully installed!")

print("\n### Configuration ###")
print()
print("The installer will now open the editor for puppygistics.json. Consult the README for help configuring this file.")
print()
print("Press any key to continue.")
os.pullEvent("key")

exec("edit /puppygistics.json")
print("Saved to /puppygistics.json")
print("Puppygistics configuration complete! Your computer is now safe to reboot.")