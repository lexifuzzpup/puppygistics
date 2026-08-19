---@class LinkedListEntry
---@field previous any | nil
---@field value any
---@field next any | nil
local LinkedListEntry = {}

---@generic T
---@class LinkedList
---@field first LinkedListEntry | nil
---@field last LinkedListEntry | nil
---@field length integer
local LinkedList = {}
LinkedList.__index = LinkedList

function LinkedList:new()
    local new = {}

    new.length = 0

    setmetatable(new, self)

    return new
end

---deletes an item from the list, returning true if removed
---@generic T
---@param value T
---@return boolean
function LinkedList:delete(value)
    local current = self.first

    while current ~= nil do
        if current.value == value then
            if current.previous ~= nil then
                current.previous.next = current.next
            end
            if current.next ~= nil then
                current.next.previous = current.previous
            end
            return true
        end
        current = current.next
    end

    return false
end

---adds an item to the end of the list
---@generic T
---@param value T
function LinkedList:push(value)
    ---@type LinkedListEntry
    local item = { previous = self.last, value = value }

    if self.first == nil then
        self.first = item
    end
    if self.last ~= nil then
        self.last.next = item
    end
    self.last = item

    self.length = self.length + 1
end

---adds an item to the beginning of the list
---@generic T
---@param value T
function LinkedList:unshift(value)
    ---@type LinkedListEntry
    local item = { value = value, next = self.first }

    if self.last == nil then
        self.last = item
    end
    if self.first ~= nil then
        self.first.next = item
    end
    self.first = item

    self.length = self.length + 1
end

function LinkedList:__len()
    return self.length
end

return LinkedList