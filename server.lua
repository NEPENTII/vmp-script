--[[
    server.lua
    Entry point: wires the HTTP handler and player connect/disconnect events
    that keep Players/Sessions in sync, and exposes the identity exports
    declared in fxmanifest.lua.
]]

SetHttpHandler(Router.Handle)

-- Resolve identity and start a game session as soon as a player finishes
-- connecting (their identifiers are guaranteed available by then).
AddEventHandler('playerJoining', function()
    local source = source
    CreateThread(function()
        local playerRef = Identifiers.ResolvePlayerRef(source)
        if playerRef then
            Sessions.StartSession(playerRef, source)
            Webhooks.Fire('player_connected', { playerRef = playerRef })
        end
    end)
end)

-- ==========================================================================
-- Exports
-- ==========================================================================

exports('GetPlayerRef', function(source)
    return Identifiers.ResolvePlayerRef(source)
end)

exports('GetIdentifiersForPlayerRef', function(playerRef)
    return Identifiers.GetStored(playerRef)
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    print('[server-api] stopping.')
end)

CreateThread(function()
    Wait(500)
    print('[server-api] API Bank ready.')
end)
