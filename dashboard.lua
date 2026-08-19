local statistics = require("statistics")
local item_cache = require("item-cache")

return function(tabs)
    local page = tabs:addTab("Dashboard")

    local update = function() end

    page:addLabel({
        text = "Display statistics for",
        x = 2,
        y = 2
    })
    local resolution_values = {
        1, 15, 30, 60, 300, 1800, math.huge
    }
    local time_resolution = resolution_values[1]
    local resolution_dropdown = page:addDropdown({
        x = 25,
        y = 2,
        width = 18,
        text = "",
        dropHeight = #resolution_values,
        items = { "last 1s", "last 15s", "last 30s", "last 1m", "last 5m", "last 30m", "all-time" },
    })
    resolution_dropdown:select(1)

    resolution_dropdown:onChange(function(self, index, item)
        time_resolution = resolution_values[index]
        update()
    end)

    local transferred_per_second = page:addLabel({
        text = "",
        x = 2,
        y = 4
    })

    local operations_per_second = page:addLabel({
        text = "",
        x = 30,
        y = 4
    })

    local items_transferred_labels = {}

    for i = 1, 8 do
        table.insert(items_transferred_labels, page:addLabel({
            text = "",
            x = 2,
            y = i + 4,
            foreground = colors.lightGray
        }))
    end

    update = function()
        local latest_transferred = 0
        local latest_operations = 0
        local latest_items_transferred = {}

        for i = 1, math.min(time_resolution, statistics.data.epochs) do
            latest_transferred = latest_transferred + statistics.data.transferred_session[#statistics.data.transferred_session - i + 1]
            latest_operations = latest_operations + statistics.data.operations_session[#statistics.data.operations_session - i + 1]
            
            local items_transferred = statistics.data.items_transferred_session[#statistics.data.items_transferred_session - i + 1]
            for item_id, count in pairs(items_transferred) do
                latest_items_transferred[item_id] = (latest_items_transferred[item_id] or 0) + count
            end
        end
        transferred_per_second.text = latest_transferred .. " items transfered"
        operations_per_second.text = latest_operations .. " operations made"

        if latest_items_transferred ~= nil then
            local item_names = {}
            for item_id in pairs(latest_items_transferred) do
                table.insert(item_names, item_id)
            end
            table.sort(item_names, function(a, b)
                return latest_items_transferred[a] > latest_items_transferred[b]
            end)

            for i = 1, #items_transferred_labels do
                local item_id = item_names[i]
                if latest_items_transferred[item_id] then
                    items_transferred_labels[i].text = latest_items_transferred[item_id] .. " " .. tostring(item_cache.get(item_id).display_name)
                else
                    items_transferred_labels[i].text = ""
                end
            end
        end
    end

    return {
        update = update
    }
end