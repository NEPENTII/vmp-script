--[[
    server/inventory.lua
    API-facing wrapper around InventoryAdapter.
]]

Inventory = {}

function Inventory.GetForPlayer(playerRef)
    if not Players.IsOnline(playerRef) then
        return {}, false
    end
    local source = Players.GetSource(playerRef)
    return InventoryAdapter.GetItems(source), true
end
