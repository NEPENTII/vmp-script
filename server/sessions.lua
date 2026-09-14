--[[
    server/sessions.lua
    Tracks join/leave sessions per player (distinct from Auth's browser
    session tokens). Storage shape (collection "game_sessions", array):
    { sessionId, playerRef, serverId, joinedAt, leftAt, duration, sourceId,
      disconnectReason }

    "active" sessions (leftAt == nil) are also kept in a fast in-memory map.
]]

Sessions = {}

local active = {} -- playerRef -> session record (mirrors the one in storage)

function Sessions.StartSession(playerRef, source)
    if active[playerRef] then
        return active[playerRef] -- already has an active session
    end

    local session = {
        sessionId = Crypto.GenerateToken(8),
        playerRef = playerRef,
        serverId = GetConvar('sv_hostname', 'unknown'),
        joinedAt = os.time(),
        leftAt = nil,
        duration = nil,
        sourceId = source,
        disconnectReason = nil
    }
    active[playerRef] = session
    Storage.Append('game_sessions', session)
    Players.MarkOnline(playerRef, source)
    Activity.Record(playerRef, 'server_join', { source = source })
    return session
end

function Sessions.EndActiveSession(playerRef, reason)
    local session = active[playerRef]
    if not session then return end

    session.leftAt = os.time()
    session.duration = session.leftAt - session.joinedAt
    session.disconnectReason = reason

    -- Persist by rewriting the matching entry in the session log.
    local all = Storage.Read('game_sessions') or {}
    for i, s in ipairs(all) do
        if s.sessionId == session.sessionId then
            all[i] = session
            break
        end
    end
    Storage.Write('game_sessions', all)

    Players.TouchLastSeen(playerRef)
    Activity.Record(playerRef, 'server_leave', { reason = reason, duration = session.duration })
    active[playerRef] = nil
end

function Sessions.GetActive(playerRef)
    return active[playerRef]
end

function Sessions.GetHistory(playerRef, limit)
    local all = Storage.Read('game_sessions') or {}
    local matching = {}
    for _, s in ipairs(all) do
        if s.playerRef == playerRef then
            matching[#matching + 1] = s
        end
    end
    table.sort(matching, function(a, b) return a.joinedAt > b.joinedAt end)
    if limit then
        local trimmed = {}
        for i = 1, math.min(limit, #matching) do trimmed[i] = matching[i] end
        return trimmed
    end
    return matching
end

--- Total lifetime play time in seconds (sum of all completed + active sessions).
function Sessions.GetTotalPlayTime(playerRef)
    local total = 0
    for _, s in ipairs(Sessions.GetHistory(playerRef)) do
        total = total + (s.duration or (os.time() - s.joinedAt))
    end
    return total
end
