--[[
    client/notify.lua
    Shows the login code as a native GTA notification bubble (top-right),
    in addition to the chat message the server already sends. Purely
    cosmetic/UX -- the server never trusts anything back from the client.
]]

RegisterNetEvent('server-api:otpNotification')
AddEventHandler('server-api:otpNotification', function(code, expireSeconds)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(('Your login code: ~g~%s~s~ (expires in %ds)'):format(code, expireSeconds))
    EndTextCommandThefeedPostTicker(false, true)
end)
