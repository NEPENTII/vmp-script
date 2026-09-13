--[[
    server/gamemode-commands.lua

    The *outbound* half of the GameMode bridge: lets an external caller
    (bank/site, via an admin-signed HTTP request) send a command DOWN into
    whichever resource registered a given gameModeId. server-api still never
    hardcodes GameMode-specific behavior -- it only knows the resourceName
    captured at registration time (see gamemode-registry.lua) and calls a
    single, fixed export name on that resource (default "HandleCommand",
    overridable per GameMode via definition.commandsExport).

    Contract the GameMode resource must implement:
        exports('HandleCommand', function(playerRef, command, data)
            -- return ok(boolean), infoOrError
        end)

    playerRef is the same opaque ref used everywhere else in server-api. The
    GameMode resource can turn it back into a concrete player/identifier via
    the new GetIdentifiersForPlayerRef export (see server.lua).
]]

GameModeCommands = {}

--- Dispatches `command` (with `data`) to the resource that registered
-- `gameModeId`. Returns ok, resultOrCode, err.
function GameModeCommands.Dispatch(gameModeId, playerRef, command, data)
    if type(command) ~= 'string' or command == '' then
        return false, 'INVALID_COMMAND'
    end

    local record = GameModeRegistry.Get(gameModeId)
    if not record then
        return false, 'GAME_MODE_NOT_FOUND'
    end

    local resourceName = record.resourceName
    if not resourceName then
        return false, 'NO_COMMAND_HANDLER'
    end

    if GetResourceState(resourceName) ~= 'started' then
        return false, 'GAME_MODE_OFFLINE'
    end

    local exportName = record.commandsExport or 'HandleCommand'
    local target = exports[resourceName]
    if not target or type(target[exportName]) ~= 'function' then
        return false, 'NO_COMMAND_HANDLER'
    end

    local callOk, resultA, resultB = pcall(function()
        return target[exportName](target, playerRef, command, data)
    end)

    if not callOk then
        return false, 'HANDLER_ERROR', tostring(resultA)
    end

    Audit.Log('gamemode_command_dispatched', {
        gameModeId = gameModeId,
        command = command,
        ok = resultA == true
    })
    Webhooks.Fire('gamemode_command_dispatched', {
        gameModeId = gameModeId,
        command = command
    })

    return true, resultA, resultB
end
