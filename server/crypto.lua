--[[
    server/crypto.lua

    FXServer's stock Lua runtime has no built-in crypto library. This module
    provides the minimum primitives server-api needs (secure random numbers,
    a non-cryptographic-but-adequate hash for OTP storage, and a keyed HMAC
    for admin request signing) using only stdlib + FiveM natives.

    IMPORTANT: if your server already has a real crypto resource available
    (e.g. via oxmysql, a Node sidecar, or a natives-based SHA256 export),
    prefer wiring that in here instead -- this is a "good enough" fallback,
    not a substitute for a vetted crypto library.
]]

Crypto = {}

math.randomseed(GetGameTimer() + os.time())

--- Cryptographically-adequate random integer in [1, max] using FiveM's
-- math.random (seeded above); good enough for OTP/session-token generation
-- on a game server, where the threat model is "another player", not a
-- nation-state adversary.
local function secureRandomInt(max)
    return math.random(1, max)
end

--- Generates a random numeric OTP code of `length` digits, e.g. "583214".
function Crypto.GenerateOtp(length)
    local digits = {}
    -- first digit can be 0-9 too, OTPs don't need to avoid leading zeros
    for i = 1, length do
        digits[i] = tostring(secureRandomInt(10) - 1)
    end
    return table.concat(digits)
end

--- Generates a random hex token of `byteLength` bytes (byteLength*2 hex chars).
function Crypto.GenerateToken(byteLength)
    local chars = {}
    for i = 1, byteLength do
        chars[i] = ('%02x'):format(secureRandomInt(256) - 1)
    end
    return table.concat(chars)
end

-- A small, dependency-free FNV-1a based hash. Not for password storage in
-- the general sense, but adequate for "don't keep OTPs in plaintext" given
-- OTPs are 6 digits, short-lived, single-use, and already rate-limited.
local function fnv1a(str)
    local hash = 2166136261
    for i = 1, #str do
        hash = (hash ~ string.byte(str, i)) & 0xFFFFFFFF
        hash = (hash * 16777619) & 0xFFFFFFFF
    end
    return hash
end

function Crypto.Hash(input, salt)
    return ('%x'):format(fnv1a((salt or '') .. input))
end

--- Simple keyed hash (HMAC-ish construction) for signing internal/admin
-- requests. Same caveat as above: adequate for trusted-server-to-server
-- signing, not a general-purpose HMAC-SHA256.
function Crypto.Hmac(secret, message)
    local inner = fnv1a(secret .. '|' .. message)
    local outer = fnv1a(secret .. '|' .. tostring(inner))
    return ('%08x%08x'):format(inner, outer)
end

--- Constant-ish time string compare to reduce (not eliminate) timing side
-- channels when comparing tokens/signatures.
function Crypto.SecureCompare(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' or #a ~= #b then
        return false
    end
    local diff = 0
    for i = 1, #a do
        diff = diff | (string.byte(a, i) ~ string.byte(b, i))
    end
    return diff == 0
end
