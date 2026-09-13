--[[
    server/gamemodes.lua
    Assembles the player-facing view of gamemode data for /me/gamemodes/*.
    Contains no per-gamemode branching -- purely generic aggregation over
    whatever the registry/statistics/history modules already hold.
]]

GameModes = {}

function GameModes.ListPublic()
    local list = {}
    for _, record in ipairs(GameModeRegistry.GetAll()) do
        list[#list + 1] = {
            id = record.id,
            name = record.name,
            displayName = record.displayName,
            version = record.version,
            schemaVersion = record.schemaVersion,
            status = record.status,
            capabilities = record.capabilities
        }
    end
    return list
end

function GameModes.GetForPlayer(playerRef)
    local list = {}
    for _, record in ipairs(GameModeRegistry.GetAll()) do
        list[#list + 1] = {
            id = record.id,
            displayName = record.displayName,
            status = record.status,
            capabilities = record.capabilities,
            statistics = Statistics.GetAll(playerRef, record.id)
        }
    end
    return list
end

function GameModes.GetOneForPlayer(playerRef, gameModeId)
    local record = GameModeRegistry.Get(gameModeId)
    if not record then return nil end
    return {
        id = record.id,
        displayName = record.displayName,
        status = record.status,
        capabilities = record.capabilities,
        statistics = Statistics.GetAll(playerRef, gameModeId)
    }
end
