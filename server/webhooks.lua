--[[
    server/webhooks.lua
    Fires an outbound POST to every configured webhook whose `events` list
    (or '*') matches the event name. Configure targets in Config.Webhooks.
    Failures are logged and swallowed -- a slow/broken webhook target must
    never block or crash the API.
]]

Webhooks = {}

local function matches(entry, eventName)
    if entry.events == '*' then return true end
    if type(entry.events) ~= 'table' then return false end
    for _, e in ipairs(entry.events) do
        if e == '*' or e == eventName then return true end
    end
    return false
end

--- Fire-and-forget. payload is a plain Lua table, JSON-encoded here.
function Webhooks.Fire(eventName, payload)
    Events.Record(eventName, payload)

    local targets = Config.Webhooks or {}
    if #targets == 0 then return end

    local body = json.encode({
        event = eventName,
        timestamp = os.time(),
        data = payload or {}
    })

    for _, entry in ipairs(targets) do
        if matches(entry, eventName) then
            PerformHttpRequest(entry.url, function(statusCode, _, _)
                if not statusCode or statusCode >= 300 then
                    print(('[server-api] webhook to %s returned status %s for event %s')
                        :format(entry.url, tostring(statusCode), eventName))
                end
            end, 'POST', body, { ['Content-Type'] = 'application/json' })
        end
    end
end
