---@class SemaphorePermit
---@field semaphore Semaphore
local SemaphorePermit = {}
SemaphorePermit.__index = SemaphorePermit

---@return SemaphorePermit
function SemaphorePermit:new(semaphore)
    local new = {}

    new.semaphore = semaphore

    setmetatable(new, self)

    return new
end

function SemaphorePermit:destroy()
    self.semaphore:destroyPermit(self)
end

---@class Semaphore
---@field max_permits integer how many permits can be out at a time
---@field permits table[] list of administered permits
local Semaphore = {}
Semaphore.__index = Semaphore

---@return Semaphore
function Semaphore:new(max_permits)
    local new = {}

    new.max_permits = max_permits
    new.permits = {}

    setmetatable(new, self)

    return new
end

---@return SemaphorePermit
function Semaphore:obtainPermit()
    local permit = SemaphorePermit:new(self)

    while #self.permits >= self.max_permits do
        coroutine.yield()
    end

    table.insert(self.permits, permit)

    return permit
end

---@param permit SemaphorePermit
function Semaphore:destroyPermit(permit)
    for index, other_permit in pairs(self.permits) do
        if other_permit == permit then
            table.remove(self.permits, index)
            return
        end
    end
end

return Semaphore