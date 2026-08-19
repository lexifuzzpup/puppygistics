local prefix = "https://raw.githubusercontent.com/lexifuzzpup/puppygistics/refs/heads/main/"

local files = {
    "inventory.lua",
    "item-cache.lua",
    "json.lua",
    "linked-list.lua",
    "log.lua",
    "logistics-system.lua",
    "requester-inventory.lua",
    "startup.lua",
    "storage.example.json"
}

for _, file in pairs(files) do
    print("Downloading " .. file)
    local response = http.get(prefix .. file)
    local data = response.readAll()

    local handle = fs.open("/" .. file, "w")
    handle.write(data)
    handle.close()
end

local function exec(cmd)
    print("$ " .. cmd)
    shell.run(cmd)
end

exec("mv /storage.example.json /storage.json")

print("Installed!")
print()
print("The installer will now open the editor for storage.json. Consult the README for help configuring this file.")
print()
print("Press any key to continue.")
os.pullEvent("key")

exec("edit /storage.json")
print("Saved to /storage.json")
print("Your computer is now safe to be rebooted.")