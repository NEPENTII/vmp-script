fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'server-api'
author 'Developer NEPENTII '
description 'Central API Bank for the game server (auth, players, economy, inventory, gamemode registry, dynamic API Developer NEPENTII Github https://github.com/benyaminpc1-ctrl/vmp-script)'
version '1.0.0'

client_scripts {
    'client/notify.lua'
}

server_scripts {
    'config.lua',

    -- Core infrastructure (order matters: lower-level modules first)
    'server/crypto.lua',
    'server/storage.lua',
    'server/validation.lua',
    'server/response.lua',
    'server/rate-limit.lua',
    'server/permissions.lua',
    'server/audit.lua',
    'server/metrics.lua',
    'server/events.lua',
    'server/webhooks.lua',
    'server/pagination.lua',

    -- Adapters (must load before anything that uses them)
    'server/adapters/storage.lua',
    'server/adapters/identifiers.lua',
    'server/adapters/framework.lua',
    'server/adapters/economy.lua',
    'server/adapters/inventory.lua',
    'server/adapters/gamemode.lua',

    -- Domain modules
    'server/identifiers.lua',
    'server/otp.lua',
    'server/auth.lua',
    'server/players.lua',
    'server/sessions.lua',
    'server/economy.lua',
    'server/inventory.lua',
    'server/event-registry.lua',
    'server/activity.lua',
    'server/statistics.lua',
    'server/gamemode-schema.lua',
    'server/gamemode-registry.lua',
    'server/gamemode-commands.lua',
    'server/gamemodes.lua',
    'server/server-info.lua',
    'server/docs-generator.lua',
    'server/openapi.lua',
    'server/router.lua',
    'server/api.lua',

    -- Entry point (starts the HTTP handler, wires everything together)
    'server.lua'
}

-- Persisted JSON storage lives here (created at runtime if missing)
server_export 'GetPlayerRef'
server_export 'GetIdentifiersForPlayerRef'
server_export 'RegisterGameMode'
server_export 'GameModeHeartbeat'
server_export 'RecordStatistic'
server_export 'IncrementStatistic'
server_export 'RecordHistory'
server_export 'RecordActivity'
