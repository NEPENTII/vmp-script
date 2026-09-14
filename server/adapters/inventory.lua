--[[
    server/adapters/inventory.lua
    Detects and reads from whatever inventory resource is actually running.
    Never hardcodes item names/icons; returns null icon when unavailable.
]]

InventoryAdapter = { name = 'none' }

local function resourceRunning(name)
    return GetResourceState(name) == 'started'
end

local function detect()
    if Config.Inventory.override ~= 'auto' then
        InventoryAdapter.name = Config.Inventory.override
    elseif resourceRunning('ox_inventory') then
        InventoryAdapter.name = 'ox_inventory'
    elseif resourceRunning('qb-inventory') then
        InventoryAdapter.name = 'qb-inventory'
    elseif resourceRunning('esx_inventory') or resourceRunning('es_extended') then
        InventoryAdapter.name = 'esx_inventory'
    else
        InventoryAdapter.name = 'none'
    end
    print(('[server-api] Inventory system detected: %s'):format(InventoryAdapter.name))
end

CreateThread(function()
    Wait(1200)
    detect()
end)

--- Returns an array of { item, label, amount, slot, metadata, icon|null }.
function InventoryAdapter.GetItems(source)
    if InventoryAdapter.name == 'ox_inventory' then
        local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems(source) end)
        if not ok or not items then return {} end
        local result = {}
        for _, it in pairs(items) do
            result[#result + 1] = {
                item = it.name,
                label = it.label or it.name,
                amount = it.count or it.amount or 0,
                slot = it.slot,
                metadata = it.metadata or {},
                icon = nil -- ox_inventory renders icons client-side by item name; no server-known icon URL
            }
        end
        return result
    elseif InventoryAdapter.name == 'qb-inventory' then
        local player = FrameworkAdapter.GetPlayer(source)
        if not player then return {} end
        local ok, items = pcall(function() return player.PlayerData.items end)
        if not ok or not items then return {} end
        local result = {}
        for slot, it in pairs(items) do
            if it then
                result[#result + 1] = {
                    item = it.name,
                    label = it.label or it.name,
                    amount = it.amount or 0,
                    slot = tonumber(slot) or slot,
                    metadata = it.info or {},
                    icon = it.image or nil
                }
            end
        end
        return result
    elseif InventoryAdapter.name == 'esx_inventory' then
        local player = FrameworkAdapter.GetPlayer(source)
        if not player then return {} end
        local ok, items = pcall(function() return player.getInventory() end)
        if not ok or not items then return {} end
        local result = {}
        for _, it in ipairs(items) do
            if (it.count or 0) > 0 then
                result[#result + 1] = {
                    item = it.name,
                    label = it.label or it.name,
                    amount = it.count,
                    slot = nil,
                    metadata = {},
                    icon = nil
                }
            end
        end
        return result
    end

    -- No detected/supported inventory system: return empty, not fake data.
    return {}
end
