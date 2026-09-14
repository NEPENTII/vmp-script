--[[
    server/economy.lua
    API-facing wrapper around EconomyAdapter. Requires the player to be
    online (balances only make sense for a connected client session).
]]

Economy = {}

function Economy.GetForPlayer(playerRef)
    if not Players.IsOnline(playerRef) then
        return {}, false
    end
    local source = Players.GetSource(playerRef)
    return EconomyAdapter.GetBalances(source), true
end
