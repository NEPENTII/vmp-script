--[[
    server/permissions.lua
    Central place to decide "can this caller do this action". Kept generic
    on purpose -- server-api does not know about GameMode-specific roles.
]]

Permissions = {}

--- A regular authenticated player may only ever touch their own /me/* data.
-- This is enforced by the router (routes are scoped under /me and resolve
-- playerRef from the session, never from client input) but this helper
-- exists for any extra explicit checks a module wants to run.
function Permissions.OwnsResource(sessionPlayerRef, resourcePlayerRef)
    return sessionPlayerRef ~= nil and sessionPlayerRef == resourcePlayerRef
end

--- Checks an admin/internal API key (see Config.Security.adminApiKeys) using
-- HMAC-signed requests: header `x-api-key-id` + `x-api-signature` where
-- signature = HMAC(secret, method .. path .. body).
function Permissions.VerifyAdminRequest(keyId, signature, method, path, body)
    local secret = Config.Security.adminApiKeys[keyId]
    if not secret then
        return false
    end
    local expected = Crypto.Hmac(secret, method .. path .. (body or ''))
    return Crypto.SecureCompare(expected, signature or '')
end

--- Checks a GameMode server's registration/heartbeat signature using the
-- shared Config.GameMode.hmacSecret.
function Permissions.VerifyGameModeRequest(signature, gameModeId, timestamp, body)
    local expected = Crypto.Hmac(Config.GameMode.hmacSecret, gameModeId .. ':' .. tostring(timestamp) .. ':' .. (body or ''))
    return Crypto.SecureCompare(expected, signature or '')
end
