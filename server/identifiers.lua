--[[
    server/identifiers.lua
    Maps volatile FiveM `source` IDs to a stable `playerRef` that survives
    reconnects. playerRef is derived from the player's primary identifier
    but stored as an opaque hashed value so raw identifiers aren't reused
    as public-facing IDs.
]]

Identifiers = {}

--- Resolves (and creates if needed) a stable playerRef for this source.
function Identifiers.ResolvePlayerRef(source)
    local ids = IdentifierAdapter.GetForSource(source)
    local primary = IdentifierAdapter.GetPrimaryIdentifier(ids)
    if not primary then
        return nil, ids
    end

    local playerRef = 'ref_' .. Crypto.Hash(primary, Config.Security.otpHashSalt)

    -- Persist the identifier map for this playerRef (only what's available).
    local existing = Storage.Get('players', playerRef)
    if not existing then
        Storage.Set('players', playerRef, {
            playerRef = playerRef,
            identifiers = ids,
            firstSeen = os.time(),
            name = GetPlayerName(source)
        })
    else
        existing.identifiers = ids
        existing.name = GetPlayerName(source)
        Storage.Set('players', playerRef, existing)
    end

    return playerRef, ids
end

--- Returns the identifiers on file for a playerRef (only ever exposed via /me/identifiers).
function Identifiers.GetStored(playerRef)
    local record = Storage.Get('players', playerRef)
    return record and record.identifiers or {}
end
