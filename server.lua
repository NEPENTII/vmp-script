--[[
    server.lua
    Entry point: wires the HTTP handler and player connect/disconnect events
    that keep Players/Sessions in sync, and exposes the GameModeBridge
    exports declared in fxmanifest.lua.
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
-- Exports consumed by gamemode-template / GameMode resources
-- ==========================================================================

exports('GetPlayerRef', function(source)
    return Identifiers.ResolvePlayerRef(source)
end)

-- برعکس GetPlayerRef: از یه playerRef (که از server-api گرفتی، مثلاً توی
-- HandleCommand)، لیست identifierهای همون بازیکن رو برمی‌گردونه. GameMode
-- می‌تونه یکی از این identifierها رو مستقیم به‌عنوان target خودش استفاده کنه.
exports('GetIdentifiersForPlayerRef', function(playerRef)
    return Identifiers.GetStored(playerRef)
end)

exports('RegisterGameMode', function(definition)
    return GameModeBridge.Register(definition)
end)

exports('GameModeHeartbeat', function(gameModeId)
    return GameModeBridge.Heartbeat(gameModeId)
end)

exports('RecordStatistic', function(playerRef, gameModeId, statName, value)
    return Statistics.Record(playerRef, gameModeId, statName, value)
end)

exports('IncrementStatistic', function(playerRef, gameModeId, statName, amount)
    return Statistics.Increment(playerRef, gameModeId, statName, amount)
end)

exports('RecordHistory', function(playerRef, gameModeId, entry)
    return GameModeRegistry.RecordHistory(playerRef, gameModeId, entry)
end)

exports('RecordActivity', function(playerRef, gameModeId, event, data)
    return Activity.RecordForGameMode(playerRef, gameModeId, event, data)
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    print('[server-api] stopping.')
end)

CreateThread(function()
    Wait(500)
    print(('[server-api] API Bank ready. %d GameMode(s) currently registered.'):format(#GameModeRegistry.GetAll()))
end)
