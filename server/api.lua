--[[
    server/api.lua
    Registers every HTTP route and the middleware around them. This is the
    only file that should ever need to change when adding a new *generic*
    endpoint -- GameMode-specific behavior never belongs here.
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

--- Validates an internal (gamemode/admin) HMAC-signed request.
-- Expects headers: x-gamemode-id, x-timestamp, x-signature
local function requireGameModeSignature(req, res)
    local gameModeId = req.headers['x-gamemode-id']
    local timestamp = req.headers['x-timestamp']
    local signature = req.headers['x-signature']
    if not (gameModeId and timestamp and signature) then
        Response.Unauthorized(res, 'Missing signature headers')
        return nil
    end
    local bodyRaw = req.body and json.encode(req.body) or ''
    if not Permissions.VerifyGameModeRequest(signature, gameModeId, timestamp, bodyRaw) then
        Response.Unauthorized(res, 'Invalid signature')
        return nil
    end
    return gameModeId
end

--- Validates an admin/internal API key (see Config.Security.adminApiKeys).
-- Expects headers: x-api-key-id, x-api-signature
-- signature = HMAC(secret, method .. path .. rawBody)
local function requireAdmin(req, res)
    local keyId = req.headers['x-api-key-id']
    local signature = req.headers['x-api-signature']
    if not (keyId and signature) then
        Response.Unauthorized(res, 'Missing admin auth headers')
        return nil
    end
    local bodyRaw = req.body and json.encode(req.body) or ''
    if not Permissions.VerifyAdminRequest(keyId, signature, req.method, req.path, bodyRaw) then
        Response.Unauthorized(res, 'Invalid admin signature')
        return nil
    end
    return keyId
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

Router.Add('GET', '/api/v1/me/statistics', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    local byGameMode = {}
    for _, record in ipairs(GameModeRegistry.GetAll()) do
        byGameMode[record.id] = Statistics.GetAll(playerRef, record.id)
    end
    Response.Ok(res, byGameMode)
end)

Router.Add('GET', '/api/v1/me/activity', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    Response.Ok(res, Pagination.Apply(Activity.GetForPlayer(playerRef, 500), req))
end)

-- ==========================================================================
-- GAMEMODES (public + player-scoped)
-- ==========================================================================

Router.Add('GET', '/api/v1/gamemodes', function(req, res)
    if not checkRateLimit(req, res) then return end
    Response.Ok(res, GameModes.ListPublic())
end)

Router.Add('GET', '/api/v1/me/gamemodes', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    Response.Ok(res, GameModes.GetForPlayer(playerRef))
end)

Router.Add('GET', '/api/v1/me/gamemodes/:gameModeId', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    local data = GameModes.GetOneForPlayer(playerRef, req.params.gameModeId)
    if not data then return Response.NotFound(res, 'GameMode not found', 'GAME_MODE_NOT_FOUND') end
    Response.Ok(res, data)
end)

Router.Add('GET', '/api/v1/me/gamemodes/:gameModeId/statistics', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    if not GameModeRegistry.Get(req.params.gameModeId) then
        return Response.NotFound(res, 'GameMode not found', 'GAME_MODE_NOT_FOUND')
    end
    Response.Ok(res, Statistics.GetAll(playerRef, req.params.gameModeId))
end)

Router.Add('GET', '/api/v1/me/gamemodes/:gameModeId/history', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    if not GameModeRegistry.Get(req.params.gameModeId) then
        return Response.NotFound(res, 'GameMode not found', 'GAME_MODE_NOT_FOUND')
    end
    Response.Ok(res, Pagination.Apply(GameModeRegistry.GetHistory(playerRef, req.params.gameModeId, 500), req))
end)

Router.Add('GET', '/api/v1/me/gamemodes/:gameModeId/activity', function(req, res)
    if not checkRateLimit(req, res) then return end
    local playerRef = requireAuth(req, res)
    if not playerRef then return end
    if not GameModeRegistry.Get(req.params.gameModeId) then
        return Response.NotFound(res, 'GameMode not found', 'GAME_MODE_NOT_FOUND')
    end
    Response.Ok(res, Pagination.Apply(Activity.GetForPlayerGameMode(playerRef, req.params.gameModeId, 500), req))
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
        registeredGameModes = #GameModeRegistry.GetAll(),
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

-- ==========================================================================
-- INTERNAL (GameMode <-> server-api over HTTP, HMAC-signed)
-- Only needed if a GameMode isn't a Lua resource able to use the export
-- bridge directly (e.g. an external process). Lua GameModes should prefer
-- exports['server-api']:RegisterGameMode(...) etc, see adapters/gamemode.lua.
-- ==========================================================================

Router.Add('POST', '/api/v1/internal/gamemodes/register', function(req, res)
    if not checkRateLimit(req, res) then return end
    local gameModeId = requireGameModeSignature(req, res)
    if not gameModeId then return end
    if req.body == nil then return Response.BadRequest(res, 'Invalid JSON body') end
    if req.body.id ~= gameModeId then
        return Response.Forbidden(res, 'Signature gameModeId does not match body id')
    end

    local ok, resultOrCode, err = GameModeRegistry.Register(req.body)
    if not ok then
        return Response.Error(res, 400, resultOrCode, err)
    end
    Response.Ok(res, resultOrCode)
end)

Router.Add('POST', '/api/v1/internal/gamemodes/:gameModeId/heartbeat', function(req, res)
    if not checkRateLimit(req, res) then return end
    local signedId = requireGameModeSignature(req, res)
    if not signedId then return end
    if signedId ~= req.params.gameModeId then
        return Response.Forbidden(res, 'Signature gameModeId mismatch')
    end
    local ok, code = GameModeRegistry.Heartbeat(req.params.gameModeId)
    if not ok then return Response.NotFound(res, 'GameMode not found', code) end
    Response.Ok(res, { acknowledged = true })
end)

Router.Add('POST', '/api/v1/internal/gamemodes/:gameModeId/statistics', function(req, res)
    if not checkRateLimit(req, res) then return end
    local signedId = requireGameModeSignature(req, res)
    if not signedId or signedId ~= req.params.gameModeId then
        return Response.Forbidden(res, 'Signature gameModeId mismatch')
    end
    local valid, err = Validation.RequireFields(req.body or {}, { 'playerRef', 'stat', 'op', 'value' })
    if not valid then return Response.BadRequest(res, err) end

    local b = req.body
    if b.op == 'increment' then
        Statistics.Increment(b.playerRef, signedId, b.stat, b.value)
    elseif b.op == 'set' then
        Statistics.Set(b.playerRef, signedId, b.stat, b.value)
    else
        return Response.BadRequest(res, 'op must be "increment" or "set"')
    end
    Webhooks.Fire('statistics_updated', { playerRef = b.playerRef, gameModeId = signedId, stat = b.stat })
    Response.Ok(res, Statistics.GetAll(b.playerRef, signedId))
end)

Router.Add('POST', '/api/v1/internal/gamemodes/:gameModeId/history', function(req, res)
    if not checkRateLimit(req, res) then return end
    local signedId = requireGameModeSignature(req, res)
    if not signedId or signedId ~= req.params.gameModeId then
        return Response.Forbidden(res, 'Signature gameModeId mismatch')
    end
    local valid, err = Validation.RequireFields(req.body or {}, { 'playerRef', 'entry' })
    if not valid then return Response.BadRequest(res, err) end

    local ok, code, err2 = GameModeRegistry.RecordHistory(req.body.playerRef, signedId, req.body.entry)
    if not ok then return Response.Error(res, 400, code, err2) end
    Webhooks.Fire('history_recorded', { playerRef = req.body.playerRef, gameModeId = signedId })
    Response.Ok(res, { recorded = true })
end)

Router.Add('POST', '/api/v1/internal/gamemodes/:gameModeId/activity', function(req, res)
    if not checkRateLimit(req, res) then return end
    local signedId = requireGameModeSignature(req, res)
    if not signedId or signedId ~= req.params.gameModeId then
        return Response.Forbidden(res, 'Signature gameModeId mismatch')
    end
    local valid, err = Validation.RequireFields(req.body or {}, { 'playerRef', 'event' })
    if not valid then return Response.BadRequest(res, err) end

    local entry, code = Activity.RecordForGameMode(req.body.playerRef, signedId, req.body.event, req.body.data)
    if not entry then return Response.BadRequest(res, 'Unknown event for this GameMode', code) end
    Response.Ok(res, entry)
end)

-- ==========================================================================
-- ADMIN (bank/site -> server-api -> GameMode, HMAC-signed with an admin key)
-- Lets an external, trusted backend (e.g. your website/bank) push a command
-- DOWN into a running GameMode resource, the reverse direction of the block
-- above. See Config.Security.adminApiKeys and server/gamemode-commands.lua.
-- ==========================================================================

Router.Add('POST', '/api/v1/admin/gamemodes/:gameModeId/command', function(req, res)
    if not checkRateLimit(req, res) then return end
    local keyId = requireAdmin(req, res)
    if not keyId then return end

    -- playerRef اختیاریه (اگه GameMode از data.target پشتیبانی کنه کافیه)، ولی
    -- command همیشه لازمه
    local valid, err = Validation.RequireFields(req.body or {}, { 'command' })
    if not valid then return Response.BadRequest(res, err) end

    local ok, resultOrCode, err2 = GameModeCommands.Dispatch(
        req.params.gameModeId,
        req.body.playerRef,
        req.body.command,
        req.body.data
    )
    if not ok then return Response.Error(res, 400, resultOrCode, err2) end

    Response.Ok(res, { result = resultOrCode, info = err2 })
end)
