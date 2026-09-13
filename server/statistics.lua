--[[
    server/statistics.lua
    Generic recordStatistic / incrementStatistic / setStatistic functions.
    Trust boundary: these must only ever be called from trusted server-side
    GameMode code (via the GameModeBridge export), never directly from a
    client event or an unauthenticated API route.

    Storage shape (collection "statistics", keyed by "<playerRef>:<gameModeId>"):
    { playerRef, gameModeId, stats = { statName = value, ... } }
]]

Statistics = {}

local function key(playerRef, gameModeId)
    return playerRef .. ':' .. gameModeId
end

local function getRecord(playerRef, gameModeId)
    local k = key(playerRef, gameModeId)
    return Storage.Get('statistics', k) or { playerRef = playerRef, gameModeId = gameModeId, stats = {} }
end

local function saveRecord(record)
    Storage.Set('statistics', key(record.playerRef, record.gameModeId), record)
end

function Statistics.Set(playerRef, gameModeId, statName, value)
    local record = getRecord(playerRef, gameModeId)
    record.stats[statName] = value
    saveRecord(record)
    return record.stats
end

function Statistics.Increment(playerRef, gameModeId, statName, amount)
    local record = getRecord(playerRef, gameModeId)
    record.stats[statName] = (record.stats[statName] or 0) + (amount or 1)
    saveRecord(record)
    return record.stats
end

function Statistics.Record(playerRef, gameModeId, statName, value)
    -- Alias of Set, kept to match the spec's "recordStatistic" naming.
    return Statistics.Set(playerRef, gameModeId, statName, value)
end

function Statistics.GetAll(playerRef, gameModeId)
    return getRecord(playerRef, gameModeId).stats
end
