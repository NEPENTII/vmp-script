--[[
    server/gamemode-registry.lua
    The central dynamic registry described in the spec. GameModes register
    themselves at startup via the GameModeBridge export; server-api never
    hardcodes a GameMode's identity or behavior.

    Storage shape (collection "gamemode_registry", keyed by gameModeId):
    {
        id, name, displayName, version, schemaVersion, status,
        capabilities = {...}, statisticNames = {...}, events = {...},
        registeredAt, lastUpdatedAt, lastHeartbeatAt
    }

    History storage (collection "gamemode_history", array):
    { gameModeId, playerRef, entry = {...}, timestamp }
]]

GameModeRegistry = {}

local KNOWN_CAPABILITIES = {
    sessions = true, statistics = true, history = true, activity = true,
    matches = true, leaderboard = true, vehicles = true, tracks = true,
    achievements = true, inventory = true, economy = true, vip = true,
    custom = true
}

--- definition = {
--    id, name, displayName, version, schemaVersion,
--    capabilities = {...}, statisticNames = {...}, events = {...},
--    schema = { fieldName = "type", ... }
-- }
function GameModeRegistry.Register(definition)
    if type(definition) ~= 'table' or not definition.id then
        return false, 'MISSING_ID', 'GameMode definition requires an id'
    end

    for _, cap in ipairs(definition.capabilities or {}) do
        if not KNOWN_CAPABILITIES[cap] then
            return false, 'UNKNOWN_CAPABILITY', ('Unknown capability: %s'):format(cap)
        end
    end

    if definition.schema then
        local ok, err = GameModeSchema.Register(definition.id, definition.schemaVersion or '1.0', definition.schema)
        if not ok then
            return false, 'INVALID_SCHEMA', err
        end
    end

    EventRegistry.RegisterGameModeEvents(definition.id, definition.events or {})

    local nowTs = os.time()
    local existing = Storage.Get('gamemode_registry', definition.id)

    -- resourceName = همون ریسورسی که این export رو صدا زده (خودکار، بدون این‌که
    -- خود GameMode مجبور باشه اسمش رو صریح بده) — این همون export ی هست که
    -- GameModeCommands.Dispatch بعداً برای رسوندن دستورهای بانک صداش می‌زنه.
    local resourceName = definition.resourceName or GetInvokingResource() or (existing and existing.resourceName) or definition.id

    local record = {
        id = definition.id,
        name = definition.name or definition.id,
        displayName = definition.displayName or definition.name or definition.id,
        version = definition.version or '1.0.0',
        schemaVersion = definition.schemaVersion or '1.0',
        status = 'active',
        capabilities = definition.capabilities or {},
        statisticNames = definition.statisticNames or {},
        events = definition.events or {},
        resourceName = resourceName,
        commandsExport = definition.commandsExport or 'HandleCommand',
        registeredAt = existing and existing.registeredAt or nowTs,
        lastUpdatedAt = nowTs,
        lastHeartbeatAt = nowTs
    }

    Storage.Set('gamemode_registry', definition.id, record)
    Audit.Log('gamemode_registered', { gameModeId = definition.id, version = record.version })
    DocsGenerator.GenerateForGameMode(record)
    DocsGenerator.GenerateRegistryIndex()

    return true, record
end

function GameModeRegistry.Heartbeat(gameModeId)
    local record = Storage.Get('gamemode_registry', gameModeId)
    if not record then
        return false, 'GAME_MODE_NOT_FOUND'
    end
    record.lastHeartbeatAt = os.time()
    if record.status ~= 'active' then
        record.status = 'active'
        DocsGenerator.GenerateForGameMode(record)
    end
    Storage.Set('gamemode_registry', gameModeId, record)
    return true
end

function GameModeRegistry.SetStatus(gameModeId, status)
    local record = Storage.Get('gamemode_registry', gameModeId)
    if not record then return false, 'GAME_MODE_NOT_FOUND' end
    record.status = status
    record.lastUpdatedAt = os.time()
    Storage.Set('gamemode_registry', gameModeId, record)
    DocsGenerator.GenerateForGameMode(record)
    return true
end

function GameModeRegistry.Get(gameModeId)
    return Storage.Get('gamemode_registry', gameModeId)
end

function GameModeRegistry.GetAll()
    local all = Storage.Read('gamemode_registry') or {}
    local list = {}
    for _, record in pairs(all) do
        list[#list + 1] = record
    end
    return list
end

--- Records a history entry for a player under a GameMode, validated
-- against that GameMode's registered schema.
function GameModeRegistry.RecordHistory(playerRef, gameModeId, entry)
    local record = GameModeRegistry.Get(gameModeId)
    if not record then
        return false, 'GAME_MODE_NOT_FOUND'
    end
    local ok, err = GameModeSchema.Validate(gameModeId, entry)
    if not ok then
        return false, 'SCHEMA_VALIDATION_FAILED', err
    end
    Storage.Append('gamemode_history', {
        gameModeId = gameModeId,
        playerRef = playerRef,
        entry = entry,
        timestamp = os.time()
    })
    return true
end

function GameModeRegistry.GetHistory(playerRef, gameModeId, limit)
    local all = Storage.Read('gamemode_history') or {}
    local matching = {}
    for _, h in ipairs(all) do
        if h.playerRef == playerRef and h.gameModeId == gameModeId then
            matching[#matching + 1] = h
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

-- Mark gamemodes inactive if their heartbeat has gone stale.
CreateThread(function()
    while true do
        Wait(Config.GameMode.heartbeatIntervalSeconds * 1000)
        local nowTs = os.time()
        for _, record in ipairs(GameModeRegistry.GetAll()) do
            if record.status == 'active' and (nowTs - (record.lastHeartbeatAt or 0)) > Config.GameMode.heartbeatTimeoutSeconds then
                GameModeRegistry.SetStatus(record.id, 'inactive')
                Audit.Log('gamemode_timeout', { gameModeId = record.id })
            end
        end
    end
end)
