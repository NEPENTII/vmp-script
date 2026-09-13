--[[
    server/event-registry.lua
    Tracks which activity/event names exist: a fixed set of base events plus
    whatever each GameMode declares for itself at registration time.
]]

EventRegistry = {}

local BASE_EVENTS = {
    'server_join', 'server_leave', 'gamemode_enter', 'gamemode_leave',
    'kill', 'death', 'inventory_change', 'economy_change', 'item_use',
    'vip_purchase', 'custom'
}

local gameModeEvents = {} -- gameModeId -> array of event names

function EventRegistry.IsBaseEvent(name)
    for _, e in ipairs(BASE_EVENTS) do
        if e == name then return true end
    end
    return false
end

--- Called at GameMode registration time with the events it declares.
function EventRegistry.RegisterGameModeEvents(gameModeId, events)
    gameModeEvents[gameModeId] = events or {}
end

function EventRegistry.GetGameModeEvents(gameModeId)
    return gameModeEvents[gameModeId] or {}
end

--- True if `name` is either a base event or was declared by `gameModeId`.
function EventRegistry.IsValidEvent(name, gameModeId)
    if EventRegistry.IsBaseEvent(name) then return true end
    if gameModeId then
        for _, e in ipairs(EventRegistry.GetGameModeEvents(gameModeId)) do
            if e == name then return true end
        end
    end
    return false
end

function EventRegistry.GetAllBaseEvents()
    return BASE_EVENTS
end
