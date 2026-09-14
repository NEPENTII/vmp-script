--[[
    server/event-registry.lua
    Tracks which activity/event names exist.
]]

EventRegistry = {}

local BASE_EVENTS = {
    'server_join', 'server_leave',
    'kill', 'death', 'inventory_change', 'economy_change', 'item_use',
    'vip_purchase', 'custom'
}

function EventRegistry.IsBaseEvent(name)
    for _, e in ipairs(BASE_EVENTS) do
        if e == name then return true end
    end
    return false
end

--- True if `name` is a known base event.
function EventRegistry.IsValidEvent(name)
    return EventRegistry.IsBaseEvent(name)
end

function EventRegistry.GetAllBaseEvents()
    return BASE_EVENTS
end
