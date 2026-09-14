--[[
    server/api.lua
    Registers every HTTP route and the middleware around them. This is the
    only file that should ever need to change when adding a new endpoint.
]]

local function clientIp(req)
    return (req.headers['x-forwarded-for'] or req.address or 'unknown')
end

--- Applies the global per-IP API rate limit. Returns false (and already
-- responded) if the caller should be blocked.
local function checkRateLimit(req, res)
    local ok = RateLimit.CheckApi(clientIp(req))
    if not ok then
        Response.TooManyRequests(res)
        return false
    end
    return true
end

--- Resolves the bearer token to a playerRef, or responds 401 and returns nil.
local function requireAuth(req, res)
    local token = Auth.ExtractBearer(req.headers)
    local playerRef = Auth.ResolveToken(token)
    if not playerRef then
        Response.Unauthorized(res, 'Missing or invalid session token')
        return nil
    end
    return playerRef
end

-- ==========================================================================
-- AUTH
-- ==========================================================================

local function completeVerify(res, submittedCode)
    local ok, playerRefOrCode, message = Otp.Verify(submittedCode)
    if not ok then
        return Response.Error(res, 401, playerRefOrCode, message)
    end
    local session = Auth.CreateSession(playerRefOrCode)
    local refresh = Auth.CreateRefreshToken(playerRefOrCode)
    Response.Ok(res, {
        sessionToken = session.token,
        expiresAt = session.expiresAt,
        refreshToken = refresh.token,
        refreshExpiresAt = refresh.expiresAt
    })
end

Router.Add('POST', '/api/v1/auth/code/verify', function(req, res)
    if not checkRateLimit(req, res) then return end
    local ok2 = RateLimit.CheckAuth(clientIp(req))
    if not ok2 then return Response.TooManyRequests(res, 'Too many login attempts') end

    if req.body == nil then
        return Response.BadRequest(res, 'Invalid JSON body')
    end
    local valid, err = Validation.RequireFields(req.body, { 'code' })
    if not valid then return Response.BadRequest(res, err) end

    completeVerify(res, req.body.code)
end)

-- Same as above, but the code travels in the URL instead of a JSON body --
-- no Content-Type: application/json header needed, so browsers treat this
-- as a "simple" CORS request and skip the OPTIONS preflight entirely.
-- e.g. POST /api/v1/auth/code/verify/482913
Router.Add('POST', '/api/v1/auth/code/verify/:code', function(req, res)
    if not checkRateLimit(req, res) then return end
    local ok2 = RateLimit.CheckAuth(clientIp(req))
    if not ok2 then return Response.TooManyRequests(res, 'Too many login attempts') end

    completeVerify(res, req.params.code)
end)

Router.Add('POST', '/api/v1/auth/logout', function(req, res)
    if not checkRateLimit(req, res) then return end
    local token = Auth.ExtractBearer(req.headers)
    if token then Auth.Revoke(token) end
    Response.Ok(res, { loggedOut = true })
end)

-- Exchanges a refresh token for a new session token + a rotated refresh
-- token, so a website can stay logged in without the player re-running
-- /code every Config.Session.tokenExpireSeconds. One-time use: the old
-- refresh token is invalidated the moment it's redeemed.
Router.Add('POST', '/api/v1/auth/refresh/:refreshToken', function(req, res)
    if not checkRateLimit(req, res) then return end
    local ok, resultOrCode, message = Auth.Refresh(req.params.refreshToken)
    if not ok then return Response.Error(res, 401, resultOrCode, message) end
    Response.Ok(res, resultOrCode)
end)

Router.Add('GET', '/api/v1/auth/session', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    Response.Ok(res, { playerRef = playerRef, valid = true })
end)

-- ==========================================================================
-- PLAYER (/me/*)
-- ==========================================================================

Router.Add('GET', '/api/v1/me', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    local profile = Players.GetProfile(playerRef)
    if not profile then return Response.NotFound(res, 'Player not found') end
    Response.Ok(res, profile)
end)

Router.Add('GET', '/api/v1/me/status', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    local status = Players.GetStatus(playerRef)
    if not status then return Response.NotFound(res, 'Player not found') end
    Response.Ok(res, status)
end)

Router.Add('GET', '/api/v1/me/identifiers', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    Response.Ok(res, Identifiers.GetStored(playerRef))
end)

Router.Add('GET', '/api/v1/me/economy', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    local balances, online = Economy.GetForPlayer(playerRef)
    Response.Ok(res, { online = online, balances = balances })
end)

Router.Add('GET', '/api/v1/me/inventory', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    local items, online = Inventory.GetForPlayer(playerRef)
    Response.Ok(res, { online = online, items = items })
end)

Router.Add('GET', '/api/v1/me/sessions', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    Response.Ok(res, Pagination.Apply(Sessions.GetHistory(playerRef, 500), req))
end)

Router.Add('GET', '/api/v1/me/activity', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    Response.Ok(res, Pagination.Apply(Activity.GetForPlayer(playerRef, 500), req))
end)

-- ==========================================================================
-- SERVER INFO (public, no auth -- current player count + names)
-- ==========================================================================

Router.Add('GET', '/api/v1/server', function(req, res)
    if not checkRateLimit(req, res) then return end
    Response.Ok(res, ServerInfo.GetSnapshot())
end)

-- ==========================================================================
-- HEALTH / VERSION
-- ==========================================================================

Router.Add('GET', '/api/v1/health', function(req, res)
    Response.Ok(res, {
        status = 'healthy',
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0',
        timestamp = os.time(),
        metrics = Metrics.Snapshot()
    })
end)

Router.Add('GET', '/api/v1/version', function(req, res)
    Response.Ok(res, {
        apiVersion = Config.Api.version,
        resourceVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0'
    })
end)

-- ==========================================================================
-- EVENTS (poll-based feed -- see server/events.lua for why this is polling
-- rather than a true push channel: FXServer's HTTP handler completes a
-- response as soon as res.send() is called, so it isn't a good fit for a
-- long-held SSE/WebSocket connection. Poll this on an interval instead
-- of re-fetching /me/* -- much cheaper, and you get a diff, not a snapshot.
-- ==========================================================================

Router.Add('GET', '/api/v1/events', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    local since = tonumber(req.query and req.query.since) or 0
    Response.Ok(res, { events = Events.Since(since, playerRef), serverTime = os.time() })
end)

-- ==========================================================================
-- API DOCS
-- ==========================================================================

Router.Add('GET', '/api/v1/docs/openapi.json', function(req, res)
    Response.Raw(res, 200, OpenApi.Generate())
end)
