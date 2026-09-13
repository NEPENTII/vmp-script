--[[
    server/players.lua
    Aggregates player identity + online status + current gamemode into the
    shapes returned by GET /api/v1/me and /api/v1/me/status.
]]

Players = {}

-- playerRef -> current fivem source, maintained via connect/drop events
local onlineSources = {}
-- playerRef -> currentGameMode (set by RecordActivity / gamemode session events)
local currentGameMode = {}

AddEventHandler('playerConnecting', function()
    -- identity resolution happens on first authenticated action; nothing to do here
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    for playerRef, src in pairs(onlineSources) do
        if src == source then
            onlineSources[playerRef] = nil
            Sessions.EndActiveSession(playerRef, reason)
            Webhooks.Fire('player_disconnected', { playerRef = playerRef, reason = reason })
            break
        end
    end
end)

--- Called (e.g. from a light client/server handshake or first API call)
-- once a source's playerRef is known, to mark them online.
function Players.MarkOnline(playerRef, source)
    onlineSources[playerRef] = source
end

function Players.IsOnline(playerRef)
    return onlineSources[playerRef] ~= nil
end

function Players.GetSource(playerRef)
    return onlineSources[playerRef]
end

function Players.SetCurrentGameMode(playerRef, gameModeId)
    currentGameMode[playerRef] = gameModeId
end

function Players.GetCurrentGameMode(playerRef)
    return currentGameMode[playerRef]
end

--- Full identity/status record for GET /api/v1/me
function Players.GetProfile(playerRef)
    local record = Storage.Get('players', playerRef)
    if not record then return nil end

    local online = Players.IsOnline(playerRef)
    local source = online and Players.GetSource(playerRef) or nil
    local activeSession = Sessions.GetActive(playerRef)

    return {
        playerRef = playerRef,
        name = record.name,
        online = online,
        source = source,
        currentGameMode = Players.GetCurrentGameMode(playerRef),
        onlineDuration = activeSession and (os.time() - activeSession.joinedAt) or 0,
        lastSeen = record.lastSeen
    }
end

function Players.GetStatus(playerRef)
    local profile = Players.GetProfile(playerRef)
    if not profile then return nil end
    return {
        online = profile.online,
        currentGameMode = profile.currentGameMode,
        onlineDuration = profile.onlineDuration
    }
end

function Players.TouchLastSeen(playerRef)
    local record = Storage.Get('players', playerRef)
    if record then
        record.lastSeen = os.time()
        Storage.Set('players', playerRef, record)
    end
end
