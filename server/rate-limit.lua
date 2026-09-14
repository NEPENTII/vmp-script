--[[
    server/rate-limit.lua
    Simple in-memory sliding-window rate limiter, keyed by any string
    (caller picks: IP, sessionToken, playerRef, "otp:<playerRef>", etc).
]]

RateLimit = {}

local buckets = {} -- key -> { windowStart = <secs>, count = <n> }

local function now()
    return os.time()
end

--- Returns true if the call is allowed, false if it should be rejected.
-- key: string bucket identifier
-- limit: max calls allowed per window
-- windowSeconds: window size in seconds
function RateLimit.Check(key, limit, windowSeconds)
    local t = now()
    local bucket = buckets[key]

    if not bucket or (t - bucket.windowStart) >= windowSeconds then
        buckets[key] = { windowStart = t, count = 1 }
        return true, limit - 1
    end

    if bucket.count >= limit then
        return false, 0
    end

    bucket.count = bucket.count + 1
    return true, limit - bucket.count
end

--- Convenience wrapper using the global API rate-limit config.
function RateLimit.CheckApi(ipKey)
    return RateLimit.Check('api:' .. ipKey, Config.RateLimit.maxRequestsPerWindow, Config.RateLimit.windowSeconds)
end

--- Convenience wrapper for auth/OTP-verification attempts.
function RateLimit.CheckAuth(ipKey)
    return RateLimit.Check('auth:' .. ipKey, Config.RateLimit.maxAuthAttemptsPerWindow, Config.RateLimit.windowSeconds)
end

-- Periodically clear old buckets so memory doesn't grow forever.
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000)
        local t = now()
        for key, bucket in pairs(buckets) do
            if (t - bucket.windowStart) > 3600 then
                buckets[key] = nil
            end
        end
    end
end)
