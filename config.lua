Config = {}

-- ==========================================================================
-- HTTP / API
-- ==========================================================================
Config.Api = {
    version = 'v1',
    basePath = '/api/v1',
    -- CORS allowlist. '*' is NOT recommended for production.
    corsAllowlist = {
        '*' -- TEMP: wide open for testing. Restrict to your real site before going live.
    },
    -- Native FiveM SetHttpHandler listens on the server's own port by default.
    -- Set to true if you want the API bank to also expose a dedicated port
    -- via a resource like `net` / a reverse proxy in front of FXServer.
    useServerHttpHandler = true
}

-- ==========================================================================
-- OTP / LOGIN CODE SYSTEM
-- ==========================================================================
Config.Otp = {
    length = 6,
    expireSeconds = 120,
    maxAttempts = 5,
    cooldownSeconds = 30,     -- cooldown before a player can request a new code after exhausting attempts
    regenCooldownSeconds = 10 -- minimum seconds between /code uses
}

-- ==========================================================================
-- SESSION TOKENS
-- ==========================================================================
Config.Session = {
    tokenExpireSeconds = 60 * 60 * 12,        -- 12 hours
    tokenBytes = 32,
    refreshTokenExpireSeconds = 60 * 60 * 24 * 30, -- 30 days
    refreshTokenBytes = 32
}

-- ==========================================================================
-- WEBHOOKS
-- ==========================================================================
-- Each entry fires a POST (JSON body: { event, timestamp, data }) whenever
-- a matching event happens. `events` is a list of event names or '*' for all.
-- Event names: otp_verified, player_connected, player_disconnected,
--              statistics_updated, history_recorded
Config.Webhooks = {
    -- { url = 'https://your-site.com/webhooks/server-api', events = '*' },
    -- { url = 'https://discord.com/api/webhooks/...', events = { 'player_banned', 'player_unbanned' } }
}

-- ==========================================================================
-- RATE LIMITING (per IP + per token)
-- ==========================================================================
Config.RateLimit = {
    windowSeconds = 60,
    maxRequestsPerWindow = 120,
    maxAuthAttemptsPerWindow = 10
}

-- ==========================================================================
-- STORAGE
-- ==========================================================================
-- 'json'   -> flat JSON files under storage/ (default, zero external deps)
-- 'custom' -> delegate entirely to server/adapters/storage.lua (e.g. oxmysql)
Config.Storage = {
    driver = 'json',
    jsonPath = 'storage' -- relative to the resource folder
}

-- ==========================================================================
-- FRAMEWORK / ECONOMY / INVENTORY DETECTION
-- ==========================================================================
-- Leave as 'auto' to let the adapters detect what's actually running on
-- this server. Only override if auto-detection picks the wrong resource.
Config.Framework = {
    override = 'esx' -- 'auto' | 'esx' | 'qbcore' | 'ox' | 'none'
}

Config.Economy = {
    override = 'framework' -- 'auto' | 'framework' | 'none' (framework = read balances from ESX)
}

Config.Inventory = {
    override = 'esx_inventory' -- 'auto' | 'ox_inventory' | 'qb-inventory' | 'esx_inventory' | 'framework' | 'none'
}

-- ==========================================================================
-- GAMEMODE REGISTRY
-- ==========================================================================
Config.GameMode = {
    heartbeatIntervalSeconds = 30,
    heartbeatTimeoutSeconds = 90, -- if no heartbeat received in this window, mark inactive
    -- HMAC secret used to authenticate gamemode <-> server-api registration calls.
    -- CHANGE THIS. Generate your own random 64-char string.
    hmacSecret = 'CHANGE_ME_TO_A_LONG_RANDOM_SECRET'
}

-- ==========================================================================
-- SECURITY
-- ==========================================================================
Config.Security = {
    -- API keys allowed to call internal/admin endpoints.
    -- Map of keyId -> secret. Use HMAC signing, never send the raw key in the URL.
    adminApiKeys = {
        -- ['admin-panel'] = 'CHANGE_ME'
    },
    logOtpInPlaintext = false, -- never set true in production
    otpHashSalt = 'CHANGE_ME_TOO'
}

-- ==========================================================================
-- AUDIT LOG
-- ==========================================================================
Config.Audit = {
    retainDays = 30
}

-- ==========================================================================
-- DEBUG
-- ==========================================================================
Config.Debug = false
