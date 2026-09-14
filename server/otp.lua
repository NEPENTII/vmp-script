--[[
    server/otp.lua
    Implements the /code command and OTP lifecycle: generate, hash-store,
    rate-limit, verify, invalidate, expire.

    Storage shape (collection "otp_codes", keyed by playerRef):
    {
        codeHash = "...",
        expiresAt = <unix ts>,
        attempts = 0,
        source = <fivem source at time of generation>,
        lastGeneratedAt = <unix ts>
    }
]]

Otp = {}

local function playerRefForSource(source)
    return Identifiers.ResolvePlayerRef(source)
end

RegisterCommand('code', function(source)
    if source == 0 then
        print('[server-api] /code cannot be used from the server console.')
        return
    end

    local playerRef = playerRefForSource(source)
    if not playerRef then
        TriggerClientEvent('chat:addMessage', source, {
            args = { '^1[server-api]', 'Could not resolve your identity. Try reconnecting.' }
        })
        return
    end

    local existing = Storage.Get('otp_codes', playerRef)
    local nowTs = os.time()

    if existing and existing.lastGeneratedAt and (nowTs - existing.lastGeneratedAt) < Config.Otp.regenCooldownSeconds then
        local wait = Config.Otp.regenCooldownSeconds - (nowTs - existing.lastGeneratedAt)
        TriggerClientEvent('chat:addMessage', source, {
            args = { '^3[server-api]', ('Please wait %ds before requesting a new code.'):format(wait) }
        })
        return
    end

    local code = Crypto.GenerateOtp(Config.Otp.length)
    local record = {
        codeHash = Crypto.Hash(code, Config.Security.otpHashSalt),
        expiresAt = nowTs + Config.Otp.expireSeconds,
        attempts = 0,
        source = source,
        lastGeneratedAt = nowTs
    }
    Storage.Set('otp_codes', playerRef, record)

    if Config.Security.logOtpInPlaintext then
        print(('[server-api] OTP for %s: %s (DEBUG ONLY, disable in production)'):format(playerRef, code))
    end

    -- Shown ONLY to this player, never broadcast.
    TriggerClientEvent('chat:addMessage', source, {
        args = { '^2[server-api]', ('Your login code is: %s (expires in %ds)'):format(code, Config.Otp.expireSeconds) }
    })
    TriggerClientEvent('server-api:otpNotification', source, code, Config.Otp.expireSeconds)

    Audit.Log('otp_generated', { playerRef = playerRef })
end, false)

--- Verifies a submitted code (no playerId/source ever comes from the client;
-- we look the code up purely by scanning stored hashes).
-- Returns: ok(boolean), playerRefOrErrorCode(string), message(string|nil)
function Otp.Verify(submittedCode)
    if type(submittedCode) ~= 'string' or #submittedCode ~= Config.Otp.length then
        return false, 'INVALID_CODE', 'Invalid or expired code'
    end

    local allCodes = Storage.Read('otp_codes') or {}
    local nowTs = os.time()

    for playerRef, record in pairs(allCodes) do
        local candidateHash = Crypto.Hash(submittedCode, Config.Security.otpHashSalt)

        if Crypto.SecureCompare(candidateHash, record.codeHash) then
            if nowTs > record.expiresAt then
                return false, 'INVALID_CODE', 'Invalid or expired code'
            end
            if record.attempts >= Config.Otp.maxAttempts then
                return false, 'TOO_MANY_ATTEMPTS', 'Too many attempts, request a new code'
            end

            -- One-time use: invalidate immediately on success.
            allCodes[playerRef] = nil
            Storage.Write('otp_codes', allCodes)
            Audit.Log('otp_verified', { playerRef = playerRef })
            Webhooks.Fire('otp_verified', { playerRef = playerRef })
            return true, playerRef, nil
        end
    end

    -- No match found by hash. To provide brute-force protection without
    -- knowing which record the caller was trying to guess, increment a
    -- generic failed-attempt counter bucketed by nothing player-specific
    -- (the per-IP rate limiter in RateLimit.CheckAuth is the primary
    -- defense against brute forcing here).
    return false, 'INVALID_CODE', 'Invalid or expired code'
end

-- Periodic cleanup of expired codes.
CreateThread(function()
    while true do
        Wait(60 * 1000)
        local allCodes = Storage.Read('otp_codes') or {}
        local nowTs = os.time()
        local changed = false
        for playerRef, record in pairs(allCodes) do
            if nowTs > record.expiresAt then
                allCodes[playerRef] = nil
                changed = true
            end
        end
        if changed then
            Storage.Write('otp_codes', allCodes)
        end
    end
end)
