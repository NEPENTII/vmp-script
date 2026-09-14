--[[
    server/auth.lua
    Issues, validates, and revokes session tokens. This is the only bridge
    between "a browser proved it knows a valid OTP" and "a browser gets a
    bearer token that scopes every subsequent /me/* call".

    Storage shape (collection "sessions", keyed by token):
    { playerRef, issuedAt, expiresAt }
]]

Auth = {}

function Auth.CreateSession(playerRef)
    local token = Crypto.GenerateToken(Config.Session.tokenBytes)
    local nowTs = os.time()
    local session = {
        token = token,
        playerRef = playerRef,
        issuedAt = nowTs,
        expiresAt = nowTs + Config.Session.tokenExpireSeconds
    }
    Storage.Set('sessions', token, session)
    Audit.Log('session_created', { playerRef = playerRef })
    return session
end

--- Issues a long-lived refresh token tied to a playerRef. Storage shape
-- (collection "refresh_tokens", keyed by token): { playerRef, issuedAt, expiresAt }
function Auth.CreateRefreshToken(playerRef)
    local token = Crypto.GenerateToken(Config.Session.refreshTokenBytes)
    local nowTs = os.time()
    local record = {
        token = token,
        playerRef = playerRef,
        issuedAt = nowTs,
        expiresAt = nowTs + Config.Session.refreshTokenExpireSeconds
    }
    Storage.Set('refresh_tokens', token, record)
    return record
end

--- Redeems a refresh token for a brand-new session token + a rotated
-- refresh token (the old one is invalidated -- one-time use, like the OTP).
-- Returns ok(boolean), sessionOrErrorCode, message(string|nil)
function Auth.Refresh(refreshToken)
    if not refreshToken or refreshToken == '' then
        return false, 'INVALID_REFRESH_TOKEN', 'Missing or invalid refresh token'
    end
    local record = Storage.Get('refresh_tokens', refreshToken)
    if not record then
        return false, 'INVALID_REFRESH_TOKEN', 'Missing or invalid refresh token'
    end
    if os.time() > record.expiresAt then
        Storage.Delete('refresh_tokens', refreshToken)
        return false, 'INVALID_REFRESH_TOKEN', 'Refresh token expired'
    end

    -- Rotate: invalidate the used refresh token, issue a new one + new session.
    Storage.Delete('refresh_tokens', refreshToken)
    local session = Auth.CreateSession(record.playerRef)
    local newRefresh = Auth.CreateRefreshToken(record.playerRef)
    return true, {
        sessionToken = session.token,
        expiresAt = session.expiresAt,
        refreshToken = newRefresh.token,
        refreshExpiresAt = newRefresh.expiresAt
    }, nil
end

function Auth.RevokeRefreshToken(refreshToken)
    if refreshToken then Storage.Delete('refresh_tokens', refreshToken) end
end

--- Returns playerRef if the token is valid and not expired, else nil.
function Auth.ResolveToken(token)
    if not token or token == '' then return nil end
    local session = Storage.Get('sessions', token)
    if not session then return nil end
    if os.time() > session.expiresAt then
        Storage.Delete('sessions', token)
        return nil
    end
    return session.playerRef, session
end

function Auth.Revoke(token)
    local session = Storage.Get('sessions', token)
    if session then
        Audit.Log('session_revoked', { playerRef = session.playerRef })
    end
    Storage.Delete('sessions', token)
end

-- Extracts a bearer token from the Authorization header.
function Auth.ExtractBearer(headers)
    local h = headers and (headers['authorization'] or headers['Authorization'])
    if not h then return nil end
    return h:match('^Bearer%s+(.+)$')
end

-- Periodic cleanup of expired sessions + refresh tokens.
CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        local sessions = Storage.Read('sessions') or {}
        local nowTs = os.time()
        local changed = false
        for token, session in pairs(sessions) do
            if nowTs > session.expiresAt then
                sessions[token] = nil
                changed = true
            end
        end
        if changed then
            Storage.Write('sessions', sessions)
        end

        local refreshTokens = Storage.Read('refresh_tokens') or {}
        local refreshChanged = false
        for token, record in pairs(refreshTokens) do
            if nowTs > record.expiresAt then
                refreshTokens[token] = nil
                refreshChanged = true
            end
        end
        if refreshChanged then
            Storage.Write('refresh_tokens', refreshTokens)
        end
    end
end)
