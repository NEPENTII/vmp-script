--[[
    server/adapters/framework.lua
    Detects which (if any) framework is running, without assuming one
    exists. Other adapters (economy, inventory) ask this module which
    framework is active rather than probing resources themselves.
]]

FrameworkAdapter = {
    name = 'none', -- 'esx' | 'qbcore' | 'ox' | 'none'
    object = nil    -- the framework's shared object/export table, once detected
}

local function resourceRunning(name)
    return GetResourceState(name) == 'started'
end

local function detect()
    if Config.Framework.override ~= 'auto' then
        FrameworkAdapter.name = Config.Framework.override
    elseif resourceRunning('es_extended') then
        FrameworkAdapter.name = 'esx'
    elseif resourceRunning('qb-core') then
        FrameworkAdapter.name = 'qbcore'
    elseif resourceRunning('ox_core') then
        FrameworkAdapter.name = 'ox'
    else
        FrameworkAdapter.name = 'none'
    end

    if FrameworkAdapter.name == 'esx' then
        local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
        FrameworkAdapter.object = ok and obj or nil
    elseif FrameworkAdapter.name == 'qbcore' then
        local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
        FrameworkAdapter.object = ok and obj or nil
    elseif FrameworkAdapter.name == 'ox' then
        -- ox_core exposes its API via exports, not a shared object; callers
        -- should use exports('ox_core', ...) directly where needed.
        FrameworkAdapter.object = nil
    else
        FrameworkAdapter.object = nil
    end

    print(('[server-api] Framework detected: %s'):format(FrameworkAdapter.name))
end

-- Detect once resources have finished starting so exports are available.
CreateThread(function()
    Wait(1000)
    detect()
end)

AddEventHandler('onResourceStart', function(resName)
    if resName == 'es_extended' or resName == 'qb-core' or resName == 'ox_core' then
        Wait(500)
        detect()
    end
end)

function FrameworkAdapter.GetPlayer(source)
    if FrameworkAdapter.name == 'esx' and FrameworkAdapter.object then
        return FrameworkAdapter.object.GetPlayerFromId(source)
    elseif FrameworkAdapter.name == 'qbcore' and FrameworkAdapter.object then
        return FrameworkAdapter.object.Functions.GetPlayer(source)
    end
    return nil
end
