--[[
    server/events.lua
    A capped in-memory event log, fed from Webhooks.Fire (every event that
    triggers a webhook also lands here). Lets a website poll
    GET /api/v1/events?since=<unix ts> instead of re-fetching /me/* on a
    timer. Not a real push channel (see note in api.lua) -- just a much
    cheaper poll.
]]

Events = {}

local MAX_EVENTS = 500
local buffer = {} -- array, oldest first

function Events.Record(eventName, payload)
    buffer[#buffer + 1] = {
        event = eventName,
        timestamp = os.time(),
        data = payload or {}
    }
    if #buffer > MAX_EVENTS then
        table.remove(buffer, 1)
    end
end

--- Every event with timestamp > sinceTs, optionally only ones whose
-- payload.playerRef matches scopedToPlayerRef (nil = no scoping).
function Events.Since(sinceTs, scopedToPlayerRef)
    local out = {}
    for _, entry in ipairs(buffer) do
        if entry.timestamp > (sinceTs or 0) then
            if not scopedToPlayerRef or entry.data.playerRef == scopedToPlayerRef then
                out[#out + 1] = entry
            end
        end
    end
    return out
end
