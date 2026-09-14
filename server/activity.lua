--[[
    server/activity.lua
    Generic activity log. server-api itself never hardcodes what an event
    "means" -- it just validates the event name against EventRegistry and
    stores { playerRef, event, data, timestamp }.
]]

Activity = {}

--- Record an activity event, e.g. server_join/server_leave.
function Activity.Record(playerRef, event, data)
    if not EventRegistry.IsValidEvent(event) then
        print(('[server-api] WARNING: dropped unknown activity event "%s"'):format(tostring(event)))
        return nil
    end
    local entry = {
        playerRef = playerRef,
        event = event,
        data = data or {},
        timestamp = os.time()
    }
    Storage.Append('activity_log', entry)
    return entry
end

function Activity.GetForPlayer(playerRef, limit)
    local all = Storage.Read('activity_log') or {}
    local matching = {}
    for _, entry in ipairs(all) do
        if entry.playerRef == playerRef then
            matching[#matching + 1] = entry
        end
    end
    table.sort(matching, function(a, b) return a.timestamp > b.timestamp end)
    if limit then
        local trimmed = {}
        for i = 1, math.min(limit, #matching) do trimmed[i] = matching[i] end
        return trimmed
    end
    return matching
end
