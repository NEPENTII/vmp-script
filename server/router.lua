--[[
    server/router.lua
    A tiny generic router sitting on top of FXServer's SetHttpHandler.
    Routes are registered once (in server/api.lua) with a method, a path
    pattern using `:param` segments, and a handler.
]]

Router = {}

local routes = {} -- array of { method, segments, handler }

local function splitPath(path)
    -- strip query string, leading/trailing slashes
    path = path:match('^([^?]*)') or path
    local segments = {}
    for seg in path:gmatch('[^/]+') do
        segments[#segments + 1] = seg
    end
    return segments
end

local function urlDecode(s)
    return (s:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end):gsub('+', ' '))
end

--- Parses the `?a=1&b=2` portion of a path into a plain string-keyed table.
local function parseQuery(path)
    local query = {}
    local qs = path:match('^[^?]*%?(.*)$')
    if not qs then return query end
    for pair in qs:gmatch('[^&]+') do
        local k, v = pair:match('^([^=]+)=?(.*)$')
        if k then
            query[urlDecode(k)] = urlDecode(v or '')
        end
    end
    return query
end

--- Register a route. pattern example: "/api/v1/me/sessions"
function Router.Add(method, pattern, handler)
    routes[#routes + 1] = {
        method = method:upper(),
        segments = splitPath(pattern),
        handler = handler
    }
end

local function matchRoute(route, method, requestSegments)
    if route.method ~= method then return nil end
    if #route.segments ~= #requestSegments then return nil end

    local params = {}
    for i, seg in ipairs(route.segments) do
        local paramName = seg:match('^:(.+)$')
        if paramName then
            params[paramName] = requestSegments[i]
        elseif seg ~= requestSegments[i] then
            return nil
        end
    end
    return params
end

function Router.Handle(req, res)
    local ok, err = pcall(function()
        Router.dispatch(req, res)
    end)
    if not ok then
        print(('[server-api] router error: %s'):format(tostring(err)))
        pcall(function() Response.ServerError(res) end)
    end
end

function Router.dispatch(req, res)
    -- CORS
    local origin = req.headers['origin'] or req.headers['Origin']
    if origin and Router.OriginAllowed(origin) then
        res.setHeader('Access-Control-Allow-Origin', origin)
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')
    end

    if req.method == 'OPTIONS' then
        res.writeHead(204, {})
        res.send('')
        return
    end

    local requestSegments = splitPath(req.path)
    req.query = parseQuery(req.path)

    for _, route in ipairs(routes) do
        local params = matchRoute(route, req.method, requestSegments)
        if params then
            req.params = params
            local routeKey = route.method .. ' ' .. table.concat(route.segments, '/')
            local startedMs = GetGameTimer()
            local capturedStatus = nil
            local metricRes = setmetatable({
                writeHead = function(statusCode, headers)
                    capturedStatus = statusCode
                    res.writeHead(statusCode, headers)
                end
            }, { __index = res })
            Router.readBody(req, function(body)
                req.body = body
                route.handler(req, metricRes)
                Metrics.RecordRequest(routeKey, GetGameTimer() - startedMs, capturedStatus)
            end)
            return
        end
    end

    Response.NotFound(res, 'No such API route')
end

function Router.OriginAllowed(origin)
    if #Config.Api.corsAllowlist == 0 then return false end
    for _, allowed in ipairs(Config.Api.corsAllowlist) do
        if allowed == '*' or allowed == origin then return true end
    end
    return false
end

--- Reads and JSON-decodes the request body (if any), then calls `cb(bodyTable)`.
function Router.readBody(req, cb)
    if req.method ~= 'POST' and req.method ~= 'PUT' and req.method ~= 'PATCH' then
        cb({})
        return
    end
    req.setDataHandler(function(data)
        if not data or data == '' then
            cb({})
            return
        end
        local ok, decoded = pcall(json.decode, data)
        if ok and type(decoded) == 'table' then
            cb(decoded)
        else
            cb(nil) -- signals invalid JSON to the caller
        end
    end)
end
