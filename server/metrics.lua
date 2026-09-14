--[[
    server/metrics.lua
    In-memory counters only (reset on resource restart) -- this is for a
    quick /health glance, not a long-term metrics store. Wired into
    router.lua's dispatch so every request is counted automatically.
]]

Metrics = {}

local startedAt = os.time()
local totalRequests = 0
local rateLimitedRequests = 0
local errorResponses = 0
local requestsByRoute = {}
local totalResponseTimeMs = 0

function Metrics.RecordRequest(routeKey, durationMs, statusCode)
    totalRequests = totalRequests + 1
    totalResponseTimeMs = totalResponseTimeMs + (durationMs or 0)
    if statusCode == 429 then rateLimitedRequests = rateLimitedRequests + 1 end
    if statusCode and statusCode >= 400 then errorResponses = errorResponses + 1 end
    if routeKey then
        requestsByRoute[routeKey] = (requestsByRoute[routeKey] or 0) + 1
    end
end

function Metrics.Snapshot()
    local avgMs = totalRequests > 0 and (totalResponseTimeMs / totalRequests) or 0
    return {
        uptimeSeconds = os.time() - startedAt,
        totalRequests = totalRequests,
        rateLimitedRequests = rateLimitedRequests,
        errorResponses = errorResponses,
        avgResponseTimeMs = math.floor(avgMs * 100 + 0.5) / 100,
        requestsByRoute = requestsByRoute
    }
end
