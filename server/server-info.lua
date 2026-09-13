--[[
    server/server-info.lua
    Public, no-auth server info: hostname + currently connected players
    (source id + name). Pulled straight from FiveM's own player list via
    GetPlayers()/GetPlayerName(), so it reflects everyone connected right
    now -- not just players who've logged into the API via /code.
]]

ServerInfo = {}

--- Server name as configured on the server (sv_hostname convar).
function ServerInfo.GetServerName()
    return GetConvar('sv_hostname', 'FXServer')
end

--- { source, name } for every currently connected player.
function ServerInfo.GetOnlinePlayers()
    local list = {}
    for _, source in ipairs(GetPlayers()) do
        list[#list + 1] = {
            source = tonumber(source),
            name = GetPlayerName(source)
        }
    end
    return list
end

--- Combined snapshot: server name + player count + player list.
function ServerInfo.GetSnapshot()
    local players = ServerInfo.GetOnlinePlayers()
    return {
        serverName = ServerInfo.GetServerName(),
        maxPlayers = tonumber(GetConvar('sv_maxclients', '0')) or 0,
        playerCount = #players,
        players = players
    }
end
