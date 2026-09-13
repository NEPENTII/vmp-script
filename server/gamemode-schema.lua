--[[
    server/gamemode-schema.lua
    Stores each GameMode's declared data schema (for its history entries)
    and validates incoming records against it. Supports schema versioning.

    Storage shape (collection "gamemode_schemas", keyed by gameModeId):
    { gameModeId, schemaVersion, fields = { name = "string", ... } }
]]

GameModeSchema = {}

function GameModeSchema.Register(gameModeId, schemaVersion, fields)
    local ok, err = Validation.ValidateSchemaDefinition(fields)
    if not ok then
        return false, err
    end
    Storage.Set('gamemode_schemas', gameModeId, {
        gameModeId = gameModeId,
        schemaVersion = schemaVersion,
        fields = fields
    })
    return true
end

function GameModeSchema.Get(gameModeId)
    return Storage.Get('gamemode_schemas', gameModeId)
end

--- Validates a history/data payload for gameModeId against its registered schema.
function GameModeSchema.Validate(gameModeId, payload)
    local schema = GameModeSchema.Get(gameModeId)
    if not schema then
        return false, 'GameMode has no registered schema'
    end
    return Validation.ValidateAgainstSchema(payload, schema.fields)
end
