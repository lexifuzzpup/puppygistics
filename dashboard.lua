local statistics = require("statistics")
local item_cache = require("item-cache")
local basalt = require("basalt")
local log = require("log")

local number_place_suffixes = { "", "k", "M", "B", "T", "q", "Q" }
local function format_number(number)
    local places = 1
    while number > 1000 do
        places = places + 1
        number = number / 1000
    end

    number = math.ceil(number * 10) / 10

    return number .. (number_place_suffixes[places] or "")
end

local function createLogsTab(tabs)
    local logs_page = tabs:addTab("Logs")

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

    return {}
end

local function createStatisticsTab(tabs)
    local page = tabs:addTab("Statistics")

    ---@type table<string, { update: function, frame: table, button: table, color_active: integer, color_inactive: integer }>
    local frames = {}
    local function update()
        for name, frame in pairs(frames) do
            frame.update()
        end
    end

    local function setFrame(name)
        for frame_name, frame in pairs(frames) do
            local show = frame_name == name

            frame.frame:setVisible(show)
            frame.frame:setDisabled(not show)
            if show then
                frame.button:setBackground(frame.color_active)
            else
                frame.button:setBackground(frame.color_inactive)
            end
        end
    end

    page:addLabel({
        text = "Display statistics for",
        x = 2,
        y = 1,
    })
    local resolution_values = {
        15, 30, 60, 300, 1800, math.huge
    }
    local resolution_names = {
        "last 15s", "last 30s", "last 1m", "last 5m", "last 30m", "all time"
    }
    local time_resolution = resolution_values[1]
    local resolution_dropdown = page:addDropdown({
        x = 25,
        y = 1,
        width = 18,
        text = "",
        dropHeight = #resolution_values,
        items = resolution_names,
    })
    resolution_dropdown:select(1)

    resolution_dropdown:onChange(function(self, index, item)
        time_resolution = resolution_values[index]
        update()
    end)

    local button_bar_width = 13
    local default_frame_x = 13
    local default_frame_y = 2

    local button_bar = page:addColumn({
        width = button_bar_width,
        height = basalt.fill(),
        x = 1,
        y = 2,
        background = colors.black
    })

    -- logistics tab
    do
        local frame = page:addFrame({
            x = default_frame_x,
            y = default_frame_y,
            width = basalt.fill(),
            height = "{parent.height - 1}",
            background = colors.black
        })
        local button = button_bar:addButton({
            text = "Transfers",
            width = button_bar_width,
            height = 1
        })
        button:onClick(function()
            setFrame("logistics")
        end)

        local transferred_per_second = frame:addLabel({
            text = "",
            x = 2,
            y = 1
        })

        local items_transferred_table = frame:addTable({
            x = 2,
            y = 2,
            columns = {
                { title = "Item", width = basalt.fill() },
                { title = "Count", width = 8 }
            },
            data = {},
            width = basalt.fill(),
            height = basalt.fill(),
            headerBackground = colors.blue,
            scrollbar = "always"
        })

        items_transferred_table:sortBy(2, false)

        local items_transferred_table_formatters = {
            [2] = function(value)
                if time_resolution == math.huge then return format_number(value)
                else return format_number(value / time_resolution * 60) .. "/m" end
            end
        }

        frames.logistics = {
            frame = frame, button = button,
            color_active = colors.blue,
            color_inactive = colors.gray,
            update = function()
                local latest_transferred = 0
                local latest_items_transferred = {}

                local i = 1
                local current_epoch = os.epoch("utc")
                while true do
                    local epoch = statistics.epochs[#statistics.epochs - i + 1] or {}

                    local sampled_epoch = epoch.time or 0
                    if sampled_epoch == 0 then break end
                    if sampled_epoch <= current_epoch - time_resolution * 1000 or sampled_epoch > current_epoch then break end

                    latest_transferred = latest_transferred + epoch.transferred

                    for item_id, count in pairs(epoch.items_transferred) do
                        latest_items_transferred[item_id] = (latest_items_transferred[item_id] or 0) + count
                    end

                    i = i + 1
                end

                if time_resolution == math.huge then
                    transferred_per_second.text =
                        format_number(latest_transferred) ..
                        " items transfered"
                else
                    transferred_per_second.text =
                        format_number(latest_transferred / time_resolution * 60) ..
                        " items transfered / m"
                end

                local table_data = {}
                for item_id in pairs(latest_items_transferred) do
                    table.insert(table_data, {
                        (item_cache.get(item_id) or {}).display_name or item_id,
                        latest_items_transferred[item_id]
                    })
                end

                local scroll_offset = items_transferred_table.offset
                items_transferred_table:setData(table_data, items_transferred_table_formatters)
                items_transferred_table.offset = scroll_offset
            end
        }
    end

    -- operations tab
    do
        local frame = page:addFrame({
            x = default_frame_x,
            y = default_frame_y,
            width = basalt.fill(),
            height = "{parent.height - 2}",
            background = colors.black
        })
        local button = button_bar:addButton({
            text = "Operations",
            width = button_bar_width,
            height = 1,
        })
        button:onClick(function()
            setFrame("operations")
        end)

        local operations_per_second = frame:addLabel({
            text = "",
            x = 2,
            y = 1
        })

        local operations_table = frame:addTable({
            x = 2,
            y = 2,
            columns = {
                { title = "Inventory", width = basalt.fill() },
                { title = "Inserts", width = 8 },
                { title = "Extracts", width = 8 }
            },
            data = {},
            width = basalt.fill(),
            height = basalt.fill(),
            headerBackground = colors.red,
            scrollbar = "always"
        })

        operations_table:sortBy(2, false)

        local operations_table_formatters = {
            [2] = function(value)
                if time_resolution == math.huge then return format_number(value)
                else return format_number(value / time_resolution * 60) .. "/m" end
            end,
            [3] = function(value)
                if time_resolution == math.huge then return format_number(value)
                else return format_number(value / time_resolution * 60) .. "/m" end
            end
        }

        frames.operations = {
            frame = frame, button = button,
            color_active = colors.red,
            color_inactive = colors.gray,
            update = function()
                local latest_operations = 0
                local latest_inventory_operations = {}

                local i = 1
                local current_epoch = os.epoch("utc")
                while true do
                    local epoch = statistics.epochs[#statistics.epochs - i + 1] or {}
                    local sampled_epoch = epoch.time or 0

                    if sampled_epoch == 0 then break end
                    if sampled_epoch <= current_epoch - time_resolution * 1000 or sampled_epoch > current_epoch then break end

                    latest_operations = latest_operations + epoch.operations

                    local inventory_keys = {}

                    local insertions = epoch.insertions
                    local extractions = epoch.extractions

                    for inventory_id in pairs(insertions) do
                        inventory_keys[inventory_id] = true
                    end
                    for inventory_id in pairs(extractions) do
                        inventory_keys[inventory_id] = true
                    end

                    for inventory_id in pairs(inventory_keys) do
                        local op = latest_inventory_operations[inventory_id]
                        if op == nil then
                            op = { 0, 0 }
                            latest_inventory_operations[inventory_id] = op
                        end

                        op[1] = op[1] + (insertions[inventory_id] or 0)
                        op[2] = op[2] + (extractions[inventory_id] or 0)
                    end

                    i = i + 1
                end

                if time_resolution == math.huge then
                    operations_per_second.text =
                        format_number(latest_operations) ..
                        " operations made"
                else
                    operations_per_second.text =
                        format_number(latest_operations / time_resolution * 60) ..
                        " operations made / m"
                end

                local table_data = {}

                for inventory_id in pairs(latest_inventory_operations) do
                    local ops = latest_inventory_operations[inventory_id]
                    table.insert(table_data, {
                        inventory_id,
                        ops[1],
                        ops[2]
                    })
                end

                local scroll_offset = operations_table.offset
                operations_table:setData(table_data, operations_table_formatters)
                operations_table.offset = scroll_offset
            end
        }
    end

    setFrame("logistics")

    return { update = update }
end

local function createShellTab(tabs)
    local page = tabs:addTab("Shell")

    local program = page:addProgram({
        x = 1,
        y = 1,
        width = basalt.fill(),
        height = basalt.fill(),
    })

    program:execute("rom/programs/shell.lua")

    tabs:onChange(function()
        if tabs.active == 3 then
            program:focus()
        end
    end)
end

local function createInventoryTab(tabs)
    local page = tabs:addTab("Inventory")

    local function update() end

    local total_items_label = page:addLabel({
        text = "",
        x = 2,
        y = 2
    })

    local inventory_table = page:addTable({
        columns = {
            { title = "Item", width = basalt.fill() },
            { title = "Count", width = 8 }
        },
        data = {},
        width = basalt.fill(),
        height = basalt.fill(),
        headerBackground = colors.brown,
        scrollbar = "always"
    })

    inventory_table:sortBy(2, false)

    local operations_table_formatters = {
        [2] = function(value)
            return format_number(value)
        end
    }

    ---@param system LogisticsSystem|nil
    update = function(system)
        if system == nil then return end

        local total_items = 0
        local items_counts = {}

        for _, inventory in pairs(system.inventories) do
            for item_id, count in pairs(inventory.item_counts) do
                if count > 0 then
                    items_counts[item_id] = (items_counts[item_id] or 0) + count
                    total_items = total_items + count
                end
            end
        end

        total_items_label.text =
            format_number(total_items) ..
            " total items"

        local table_data = {}

        for item_id, count in pairs(items_counts) do
            table.insert(table_data, {
                (item_cache.get(item_id) or {}).display_name or item_id,
                count
            })
        end

        local scroll_offset = inventory_table.offset
        inventory_table:setData(table_data, operations_table_formatters)
        inventory_table.offset = scroll_offset
    end

    return { update = update }
end

return function(frame)
    local tabs = frame:addTabControl({
        x = 1,
        y = 1,
        width = basalt.fill(),
        height = basalt.fill(),
    })

    ---@type LogisticsSystem
    local system = nil

    local logsTab = createLogsTab(tabs)
    local statisticsTab = createStatisticsTab(tabs)
    local inventoryTab = createInventoryTab(tabs)
    local shellTab = createShellTab(tabs)

    return {
        update = function()
            statisticsTab.update()
            inventoryTab.update(system)
        end,
        setSystem = function(new_system)
            system = new_system
        end
    }
end