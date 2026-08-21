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
        text = "Display stats for",
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
        x = 20,
        y = 1,
        width = 10,
        text = "",
        dropHeight = #resolution_values,
        items = resolution_names,
    })
    resolution_dropdown:select(1)

    resolution_dropdown:onChange(function(self, index, item)
        time_resolution = resolution_values[index]
        update()
    end)

    page:addLabel({
        text = "as",
        x = 31,
        y = 1,
    })
    local time_format_values = {
        "count", "per_second", "per_minute", "per_hour"
    }
    local time_format_names = {
        "total", "/s", "/m", "/h"
    }
    local epoch_span = 1
    local time_format_formatters = {
        function(value)
            return format_number(value)
        end,
        function(value)
            return format_number(value / epoch_span) .. "/s"
        end,
        function(value)
            return format_number(value / epoch_span * 60) .. "/m"
        end,
        function(value)
            return format_number(value / epoch_span * 3600) .. "/h"
        end
    }
    local time_format = time_format_values[1]
    local time_format_formatter = time_format_formatters[1]
    local time_format_dropdown = page:addDropdown({
        x = 34,
        y = 1,
        width = 7,
        text = "",
        dropHeight = #time_format_values,
        items = time_format_names,
    })
    time_format_dropdown:select(1)

    time_format_dropdown:onChange(function(self, index, item)
        time_format = time_format_values[index]
        time_format_formatter = time_format_formatters[index]
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
            [2] = function(value) return time_format_formatter(value) end
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
                local first_epoch = current_epoch
                while true do
                    local epoch_data = statistics.epochs[#statistics.epochs - i + 1] or {}

                    local sampled_epoch = epoch_data.time or 0
                    if sampled_epoch == 0 then break end
                    if sampled_epoch <= current_epoch - time_resolution * 1000 or sampled_epoch > current_epoch then break end

                    latest_transferred = latest_transferred + epoch_data.transferred

                    for item_id, count in pairs(epoch_data.items_transferred) do
                        latest_items_transferred[item_id] = (latest_items_transferred[item_id] or 0) + count
                    end

                    first_epoch = epoch_data.time

                    i = i + 1
                end

                epoch_span = math.max((current_epoch - first_epoch) / 1000, 0.00000001)

                transferred_per_second.text = "Items transfered: " .. time_format_formatter(latest_transferred)

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
            [2] = function(value) return time_format_formatter(value) end,
            [3] = function(value) return time_format_formatter(value) end
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
                local first_epoch = current_epoch
                while true do
                    local epoch_data = statistics.epochs[#statistics.epochs - i + 1] or {}
                    local sampled_epoch = epoch_data.time or 0

                    if sampled_epoch == 0 then break end
                    if sampled_epoch <= current_epoch - time_resolution * 1000 or sampled_epoch > current_epoch then break end

                    latest_operations = latest_operations + epoch_data.operations

                    local inventory_keys = {}

                    local insertions = epoch_data.insertions
                    local extractions = epoch_data.extractions

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

                    first_epoch = epoch_data.time

                    i = i + 1
                end

                epoch_span = math.max((current_epoch - first_epoch) / 1000, 0.00000001)

                operations_per_second.text = "Operations made: " .. time_format_formatter(latest_operations)

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
        if tabs.active == 5 then
            program:focus()
        end
    end)
end

---@param mainframe Mainframe
local function createInventoryTab(mainframe, tabs)
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

    update = function()
        local total_items = 0
        local items_counts = {}

        for _, inventory in pairs(mainframe.system.inventories) do
            if inventory.type ~= "unassigned" then
                for item_id, count in pairs(inventory.item_counts) do
                    if count > 0 then
                        items_counts[item_id] = (items_counts[item_id] or 0) + count
                        total_items = total_items + count
                    end
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

---@param mainframe Mainframe
local function createMembersTab(mainframe, tabs)
    local page = tabs:addTab("Members")

    local total_members_progress_bar = page:addProgressBar({
        x = 1,
        y = 1,
        width = basalt.fill(),
        height = 1,
        barColor = colors.blue
    })
    local non_storage_members_progress_bar = page:addProgressBar({
        x = 1,
        y = 1,
        width = basalt.fill(),
        height = 1,
        barColor = colors.orange,
        direction = "left",
        background = false
    })
    local total_members_label = page:addLabel({
        text = "",
        x = 2,
        y = 1
    })
    local selected_label = page:addLabel({
        text = "",
        x = 5,
        y = 2
    })

    local list = page:addColumn({
        x = 2,
        y = 3,
        width = basalt.fill(),
        height = "{parent.height - 3}",
        scrollable = true,
        background = colors.black
    })

    local toolbar = page:addRow({
        x = 1,
        y = "{parent.height}",
        width = basalt.fill(),
        height = 1,
        background = colors.gray
    })

    local inventory_cards = {}

    local function updateMemberCount()
        if mainframe.system == nil then return end

        local max_peripherals = 256
        local logistics_members = 0
        local non_storage_members = 0

        for _, peripheral_name in pairs(peripheral.getNames()) do
            if mainframe.system.inventories[peripheral_name] then
                logistics_members = logistics_members + 1
            else
                non_storage_members = non_storage_members + 1
            end
        end

        total_members_label.text =
            logistics_members .. "/" ..
            (max_peripherals - non_storage_members) .. " members (" ..
            (non_storage_members) .. " extra peripherals)"
        total_members_progress_bar.progress = logistics_members / max_peripherals * 100
        non_storage_members_progress_bar.progress = non_storage_members / max_peripherals * 100

        if total_members_progress_bar.progress >= 95 then
            total_members_progress_bar.barColor = colors.red
        elseif total_members_progress_bar.progress >= 80 then
            total_members_progress_bar.barColor = colors.brown
        elseif total_members_progress_bar.progress >= 50 then
            total_members_progress_bar.barColor = colors.green
        else
            total_members_progress_bar.barColor = colors.blue
        end
    end

    local function getSelectedCount()
        local count = 0
        for _, card in pairs(inventory_cards) do
            if card.selected then
                count = count + 1
            end
        end
        return count
    end

    local set_selected_type_button = toolbar:addButton({
        text = "Set Type",
        background = colors.red,
        height = 1,
        width = basalt.auto()
    })

    local clear_selection_button = page:addButton({
        x = 1,
        y = 2,
        text = "X",
        background = colors.brown,
        height = 1,
        width = 3
    })

    local function updateSelectedCount()
        local count = getSelectedCount()

        if count > 0 then
            selected_label.visible = true
            set_selected_type_button.visible = true
            clear_selection_button.visible = true
            selected_label.text = count .. " selected"
        else
            selected_label.visible = false
            clear_selection_button.visible = false
            set_selected_type_button.visible = false
        end
    end

    clear_selection_button:onClick(function()
        for _, card in pairs(inventory_cards) do
            if card.selected then
                card.setSelected(false)
            end
        end
        updateSelectedCount()
    end)

    updateSelectedCount()

    set_selected_type_button:onClick(function()
        local dialog = page:addFrame({
            x = 1,
            y = 1,
            width = basalt.fill(),
            height = basalt.fill(),
            background = false
        })

        local content = dialog:addFrame({
            x = "{(parent.width - 30) / 2}",
            y = "{(parent.height - 8) / 2}",
            width = 30,
            height = 8,
        })

        local selected_count = getSelectedCount()
        content:addLabel({
            text = "Set type for " .. selected_count .. " inventor" .. (selected_count == 1 and "y" or "ies"),
            x = "{(parent.width - self.width + 1) / 2}",
            y = 2
        })

        local type_values = {
            "unassigned",
            "active_provider",
            "passive_provider",
            "storage",
            "requester"
        }
        local type_names = {
            "Unassigned",
            "Active Provider",
            "Passive Provider",
            "Storage",
            "Requester"
        }

        local type_dropdown = page:addDropdown({
            x = "{(parent.width - 30) / 2 + 5}",
            y = "{(parent.height - 8) / 2 + 3}",
            width = 20,
            dropHeight = #type_values,
            items = type_names,
            background = colors.black,
            dropBackground = colors.blue
        })

        local new_type = ""
        type_dropdown:onChange(function(self, index, item)
            new_type = type_values[index]
        end)

        type_dropdown:select(1)


        local cancel_button = content:addButton({
            text = "Cancel",
            x = 3,
            y = 7,
            width = 12,
            height = 1,
            background = colors.red
        })
        cancel_button:onClick(function()
            dialog:destroy()
            type_dropdown:destroy()
        end)

        local set_button = content:addButton({
            text = "Set",
            x = 17,
            y = 7,
            width = 12,
            height = 1,
            background = colors.blue
        })

        set_button:onClick(function()
            dialog:destroy()
            type_dropdown:destroy()

            local callbacks = {}
            for _, card in pairs(inventory_cards) do
                if card.selected then
                    card.setSelected(false)

                    table.insert(callbacks, function()
                        mainframe:setInventoryType(card.inventory, new_type, {})
                    end)
                end
            end

            parallel.waitForAll(table.unpack(callbacks))
            mainframe:saveConfig()

            updateSelectedCount()
        end)
    end)

    local type_order = {
        unassigned = 0,
        active_provider = 1,
        passive_provider = 2,
        requester = 3,
        storage = 4,
    }

    local function sortMembers()
        local children = list:getChildren()
        table.sort(children, function(a, b)
            local card_a = inventory_cards[a.name]
            local card_b = inventory_cards[b.name]

            if card_a.inventory.type ~= card_b.inventory.type then
                return type_order[card_a.inventory.type] < type_order[card_b.inventory.type]
            end

            return card_a.inventory.name < card_b.inventory.name
        end)
    end

    return {
        addMember = function(initial_inventory)
            local card = {
                inventory = nil,
                container = nil,
                setSelected = function(new_selected) end,
                update = function(new_inventory) end,
                selected = false
            }

            local container = list:addFrame({
                width = "{parent.width - 2}",
                height = 2,
                background = false
            })

            local type_label = container:addLabel({
                text = "",
                x = 3,
                y = 2,
                foreground = colors.lightGray
            })

            local icon_top_left = container:addLabel({
                text = "\131",
                x = 1,
                y = 1,
                width = 1,
                height = 1,
                foreground = colors.black,
            })
            local icon_bottom_left = container:addLabel({
                text = "\143",
                x = 1,
                y = 2,
                width = 1,
                height = 1,
                background = colors.black
            })
            local icon_top_right = container:addLabel({
                text = "\131",
                x = "{parent.width}",
                y = 1,
                width = 1,
                height = 1,
                foreground = colors.black,
            })
            local icon_bottom_right = container:addLabel({
                text = "\143",
                x = "{parent.width}",
                y = 2,
                width = 1,
                height = 1,
                background = colors.black
            })

            local inventory_name_label = container:addLabel({
                text = "",
                x = 3,
                y = 1,
                width = basalt.fill(),
                height = 1,
                foreground = colors.white
            })

            local edit_button = container:addButton({
                x = "{parent.width - 5}",
                y = 1,
                text = "Edit",
                width = 4,
                height = 1
            })

            local function setInventoryDetails(name, type)
                container.name = name
                inventory_name_label.text = name

                edit_button.visible = false

                if type == "storage" then
                    type_label.text = "Storage"
                    icon_top_left.background = colors.yellow
                    icon_top_right.background = colors.yellow
                    icon_bottom_left.foreground = colors.yellow
                    icon_bottom_right.foreground = colors.yellow
                elseif type == "active_provider" then
                    type_label.text = "Active Provider"
                    icon_top_left.background = colors.purple
                    icon_top_right.background = colors.purple
                    icon_bottom_left.foreground = colors.purple
                    icon_bottom_right.foreground = colors.purple
                elseif type == "passive_provider" then
                    type_label.text = "Passive Provider"
                    icon_top_left.background = colors.red
                    icon_top_right.background = colors.red
                    icon_bottom_left.foreground = colors.red
                    icon_bottom_right.foreground = colors.red
                elseif type == "requester" then
                    type_label.text = "Requester"
                    icon_top_left.background = colors.blue
                    icon_top_right.background = colors.blue
                    icon_bottom_left.foreground = colors.blue
                    icon_bottom_right.foreground = colors.blue
                    edit_button.visible = true
                elseif type == "unassigned" then
                    type_label.text = "Unassigned"
                    icon_top_left.background = colors.lightGray
                    icon_top_right.background = colors.lightGray
                    icon_bottom_left.foreground = colors.lightGray
                    icon_bottom_right.foreground = colors.lightGray
                end

                edit_button.disabled = not edit_button.visible
            end

            container:onClick(function()
                card.setSelected(not card.selected)
            end)

            edit_button:onClick(function()
                local dialog = page:addFrame({
                    x = 1,
                    y = 1,
                    width = basalt.fill(),
                    height = basalt.fill()
                })

                local content = dialog:addFrame({
                    x = 1,
                    y = 1,
                    width = basalt.fill(),
                    height = basalt.fill(),
                    background = colors.black
                })

                content:addLabel({
                    text = "Edit " .. card.inventory.name,
                    x = "{(parent.width - self.width + 1) / 2}",
                    y = 2
                })
                content:addLabel({
                    text = "(" .. card.inventory.type .. ")",
                    x = "{(parent.width - self.width + 1) / 2}",
                    y = 3
                })

                local cancel_button = content:addButton({
                    text = "Cancel",
                    x = "{((parent or {}).width or 0) / 2 - 13}",
                    y = "{((parent or {}).height or 0) - 1}",
                    width = 12,
                    height = 1,
                    background = colors.red
                })

                local apply_button = content:addButton({
                    text = "Apply",
                    x = "{((parent or {}).width or 0) / 2 + 1}",
                    y = "{((parent or {}).height or 0) - 1}",
                    width = 12,
                    height = 1,
                    background = colors.blue
                })

                cancel_button:onClick(function()
                    dialog:destroy()
                end)
                apply_button:onClick(function()
                    dialog:destroy()
                end)

                if card.inventory.type == "requester" then
                    ---@type RequesterInventory
                    local inventory = card.inventory

                    content:addLabel({
                        text = "Item requests",
                        x = 3,
                        y = 5
                    })
                    content:addLabel({
                        x = 3,
                        y = 6,
                        text = "Format: namespace:item 1",
                        foreground = colors.gray
                    })
                    local filter_items = content:addList({
                        x = 2,
                        y = 7,
                        width = "{parent.width - 2}",
                        height = "{parent.height - 9}",
                        background = colors.gray,
                        emptyText = "<no items>",
                        emptyTextColor = colors.lightGray,
                        scrollbar = "always",
                    })

                    for item_id, count in pairs(inventory.config.filter) do
                        filter_items:addItem(item_id .. " " .. count)
                    end

                    ---@param text string
                    local function validateLine(text)
                        local split = text:find(" ")
                        if split == nil then return false, "", 0 end

                        local item = text:sub(1, split - 1)
                        local count_str = text:sub(split + 1)
                        if not #item or not #count_str then return false, "", 0 end

                        local count = tonumber(count_str)
                        if count == nil or math.floor(count) ~= count then return false, "", 0 end

                        return true, item, count
                    end

                    local function editLine(index)
                        filter_items:selectItem(index)
                        local new = index > #filter_items.items

                        local line_text = new and "" or filter_items.items[index].text
                        local box = content:addInput({
                            x = 2,
                            y = filter_items.y - 1 + index - filter_items.offset,
                            width = "{parent.width - 3}",
                            height = 1,
                            text = line_text,

                            foreground = colors.white,
                            background = colors.black
                        })

                        box._cursor = #line_text + 1

                        local committed = false
                        local function commit()
                            if committed then return end
                            committed = true

                            if validateLine(box.text) then
                                if new then
                                    if #box.text > 0 then
                                        filter_items:addItem(box.text)
                                    end
                                else
                                    if #box.text > 0 then
                                        filter_items.items[index].text = box.text
                                    else
                                        filter_items:removeItem(index)
                                    end
                                end
                            elseif #box.text == 0 then
                                filter_items:removeItem(index)
                            end

                            box:destroy()
                            filter_items:off("scroll", commit)
                        end
                        local function updateColors()
                            if #box.text == 0 or validateLine(box.text) then
                                box.foreground = colors.white
                            else
                                box.foreground = colors.red
                            end
                        end
                        updateColors()

                        local delete_next_backspace = #box.text == 0
                        box:onKey(function(self, key)
                            log.info(key)
                            if key == 259 and #box.text == 0 then
                                if delete_next_backspace then
                                    commit()
                                    if filter_items.items[index - 1] then
                                        editLine(index - 1)
                                    end
                                end
                                delete_next_backspace = true
                            else
                                delete_next_backspace = false
                            end

                            if key == 264 then
                                if index < #filter_items.items then
                                    editLine(index + 1)
                                end
                            elseif key == 265 then
                                if index > 1 then
                                    editLine(index - 1)
                                end
                            end
                        end)

                        box:onChange(updateColors)
                        box:focus()
                        box:onBlur(commit)
                        box:onEnter(function()
                            if validateLine(box.text) then
                                commit()
                                if #box.text > 0 then
                                    filter_items:insertItem(index + 1, "")
                                    editLine(index + 1)
                                end
                            end
                        end)
                        filter_items:onScroll(commit)
                    end

                    filter_items:onKey(function(self, key)
                        local selected = filter_items.selected
                        if type(selected) == "number" then
                            if key == 261 then
                                filter_items:removeItem(selected)
                                filter_items:selectItem(math.min(math.max(selected, 1), #filter_items.items), true)
                            end
                            if key == 257 then
                                editLine(selected)
                            end
                        end
                    end)

                    local last_click = 0
                    local last_click_y = 0
                    filter_items:onClick(function(self, button, x, y)
                        local now = os.clock()
                        if now - last_click < 0.5 and last_click_y == y + filter_items.offset then
                            editLine(math.min(y + filter_items.offset, #filter_items.items + 1))
                        end
                        last_click = now
                        last_click_y = y + filter_items.offset
                    end)

                    apply_button:onClick(function()
                        for item_id in pairs(inventory.config.filter) do
                            inventory.config.filter[item_id] = nil
                        end
                        for _, item in pairs(filter_items.items) do
                            local validated, item_id, count = validateLine(item.text)
                            if validated then
                                inventory.config.filter[item_id] = count
                            end
                        end
                        mainframe.config.members[inventory.name].config = inventory.config
                        mainframe:saveConfig()
                    end)
                end
            end)

            card.setSelected = function(new_selected)
                card.selected = new_selected

                if new_selected then
                    container.background = colors.white
                    inventory_name_label.foreground = colors.black
                    type_label.foreground = colors.gray
                else
                    container.background = false
                    inventory_name_label.foreground = colors.white
                    type_label.foreground = colors.lightGray
                end

                updateSelectedCount()
            end
            card.update = function(new_inventory)
                if card.inventory ~= nil then
                    inventory_cards[card.inventory.name] = nil
                end
                card.inventory = new_inventory
                setInventoryDetails(new_inventory.name, new_inventory.type)
                inventory_cards[initial_inventory.name] = card
            end

            card.update(initial_inventory)

            card.container = container

            updateMemberCount()
            sortMembers()
        end,
        updateMember = function(inventory)
            local card = inventory_cards[inventory.name]

            if card ~= nil then
                card.update(inventory)
            end
            sortMembers()
        end,
        removeMember = function(inventory)
            local card = inventory_cards[inventory.name]

            inventory_cards[card.inventory.name] = nil

            if card ~= nil then
                card.container:destroy()
            end
            sortMembers()
        end,
        update = function()
            updateMemberCount()
        end
    }
end

---@param mainframe Mainframe
return function(mainframe, frame)
    local tabs = frame:addTabControl({
        x = 1,
        y = 1,
        width = basalt.fill(),
        height = basalt.fill(),
    })

    local logsTab = createLogsTab(tabs)
    local statisticsTab = createStatisticsTab(tabs)
    local inventoryTab = createInventoryTab(mainframe, tabs)
    local membersTab = createMembersTab(mainframe, tabs)
    local shellTab = createShellTab(tabs)

    return {
        update = function()
            statisticsTab.update()
            inventoryTab.update()
            membersTab.update()
        end,
        addMember = function(inventory)
            membersTab.addMember(inventory)
        end,
        removeMember = function(inventory)
            membersTab.removeMember(inventory)
        end,
        updateMember = function(inventory)
            membersTab.updateMember(inventory)
        end
    }
end