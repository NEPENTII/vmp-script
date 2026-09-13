--[[
    server/adapters/gamemode.lua

    This is the *inbound* side of the GameMode bridge: the functions a
    `gamemode-template`-based resource calls (via exports on server-api) to
    register itself, send heartbeats, and record data. It intentionally
    contains zero GameMode-specific logic -- everything is keyed by the
    caller-supplied gameModeId and validated against that GameMode's own
    registered schema.

    A GameMode resource calls these like:
        exports['server-api']:RegisterGameMode({ id = 'racing', ... })
        exports['server-api']:GameModeHeartbeat('racing')
        exports['server-api']:RecordStatistic(playerRef, 'racing', 'wins', 1)

    See docs/gamemodes/<id>.md (auto-generated) for the contract of each
    registered GameMode.
]]

GameModeBridge = {}

function GameModeBridge.Register(definition)
    return GameModeRegistry.Register(definition)
end

function GameModeBridge.Heartbeat(gameModeId)
    return GameModeRegistry.Heartbeat(gameModeId)
end

function GameModeBridge.Unregister(gameModeId)
    return GameModeRegistry.SetStatus(gameModeId, 'inactive')
end

-- Exports are wired up in server.lua once all modules are loaded.
