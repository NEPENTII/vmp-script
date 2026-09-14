--[[
    server/openapi.lua
    A hand-maintained (not per-request-generated) OpenAPI 3.0 document for
    every fixed route in server/api.lua.

    Update this file whenever a route is added/changed in api.lua.
]]

OpenApi = {}

local function op(summary, opts)
    opts = opts or {}
    return {
        summary = summary,
        tags = opts.tags or { 'general' },
        security = opts.auth == 'bearer' and { { bearerAuth = {} } } or nil,
        parameters = opts.parameters,
        responses = {
            ['200'] = { description = 'Success' },
            ['400'] = { description = 'Bad request' },
            ['401'] = { description = 'Missing/invalid session token' },
            ['404'] = { description = 'Not found' },
            ['429'] = { description = 'Rate limited' }
        }
    }
end

local PAGINATION_PARAMS = {
    { name = 'limit', ['in'] = 'query', schema = { type = 'integer' }, description = 'Max items to return (default 50, max 200)' },
    { name = 'offset', ['in'] = 'query', schema = { type = 'integer' }, description = 'Items to skip (default 0)' }
}

function OpenApi.Generate()
    return {
        openapi = '3.0.3',
        info = {
            title = 'server-api',
            version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0',
            description = 'Central API Bank for the game server.'
        },
        components = {
            securitySchemes = {
                bearerAuth = { type = 'http', scheme = 'bearer', bearerFormat = 'session token from /auth/code/verify' }
            }
        },
        paths = {
            ['/api/v1/auth/code/verify'] = {
                post = op('Verify OTP code (JSON body: {code})', { tags = { 'auth' } })
            },
            ['/api/v1/auth/code/verify/{code}'] = {
                post = op('Verify OTP code (path param, no body/preflight needed)', { tags = { 'auth' } })
            },
            ['/api/v1/auth/refresh'] = {
                post = op('Exchange a refresh token for a new session + rotated refresh token', { tags = { 'auth' } })
            },
            ['/api/v1/auth/logout'] = {
                post = op('Revoke the current session token', { tags = { 'auth' }, auth = 'bearer' })
            },
            ['/api/v1/auth/session'] = {
                get = op('Check whether the current session token is valid', { tags = { 'auth' }, auth = 'bearer' })
            },
            ['/api/v1/me'] = { get = op('Full profile for the logged-in player', { tags = { 'me' }, auth = 'bearer' }) },
            ['/api/v1/me/status'] = { get = op('Online status', { tags = { 'me' }, auth = 'bearer' }) },
            ['/api/v1/me/identifiers'] = { get = op('Stored identifiers (incl. Steam hex)', { tags = { 'me' }, auth = 'bearer' }) },
            ['/api/v1/me/economy'] = { get = op('Framework balances', { tags = { 'me' }, auth = 'bearer' }) },
            ['/api/v1/me/inventory'] = { get = op('Framework inventory', { tags = { 'me' }, auth = 'bearer' }) },
            ['/api/v1/me/sessions'] = { get = op('Recent play sessions', { tags = { 'me' }, auth = 'bearer', parameters = PAGINATION_PARAMS }) },
            ['/api/v1/me/activity'] = { get = op('Recent activity feed', { tags = { 'me' }, auth = 'bearer', parameters = PAGINATION_PARAMS }) },
            ['/api/v1/server'] = { get = op('Public server info: name, player count, player list', { tags = { 'server' } }) },
            ['/api/v1/health'] = { get = op('Health + request metrics snapshot', { tags = { 'server' } }) },
            ['/api/v1/version'] = { get = op('API + resource version', { tags = { 'server' } }) },
            ['/api/v1/events'] = { get = op('Recent event feed since a timestamp (poll-based)', { tags = { 'events' }, auth = 'bearer',
                parameters = { { name = 'since', ['in'] = 'query', schema = { type = 'integer' }, description = 'Unix timestamp; only events after this are returned' } } }) },
            ['/api/v1/docs/openapi.json'] = { get = op('This document', { tags = { 'server' } }) }
        }
    }
end
