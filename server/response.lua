--[[
    server/response.lua
    Uniform { success, data } / { success, error } envelope for every route.
]]

Response = {}

local function send(res, statusCode, body)
    res.writeHead(statusCode, { ['Content-Type'] = 'application/json' })
    res.send(json.encode(body))
end

function Response.Ok(res, data, statusCode)
    send(res, statusCode or 200, { success = true, data = data or {} })
end

--- Sends `data` as-is (no {success,data} envelope). Only for endpoints
-- whose consumers expect a specific raw shape, e.g. an OpenAPI document.
function Response.Raw(res, statusCode, data)
    send(res, statusCode or 200, data)
end

function Response.Error(res, statusCode, code, message)
    send(res, statusCode or 400, {
        success = false,
        error = { code = code or 'ERROR', message = message or 'Something went wrong' }
    })
end

-- Common shortcuts
function Response.BadRequest(res, message, code) Response.Error(res, 400, code or 'BAD_REQUEST', message or 'Bad request') end
function Response.Unauthorized(res, message, code) Response.Error(res, 401, code or 'UNAUTHORIZED', message or 'Unauthorized') end
function Response.Forbidden(res, message, code) Response.Error(res, 403, code or 'FORBIDDEN', message or 'Forbidden') end
function Response.NotFound(res, message, code) Response.Error(res, 404, code or 'NOT_FOUND', message or 'Not found') end
function Response.TooManyRequests(res, message, code) Response.Error(res, 429, code or 'RATE_LIMITED', message or 'Too many requests') end
function Response.ServerError(res, message, code) Response.Error(res, 500, code or 'INTERNAL_ERROR', message or 'Internal server error') end
