--[[
    server/pagination.lua
    Small shared helper so every list endpoint accepts the same
    ?limit=&offset= query params instead of hardcoding a fixed count.
    Cursor here is a simple numeric offset -- good enough for JSON-file
    storage; swap for a real cursor if the storage backend changes.
]]

Pagination = {}

local DEFAULT_LIMIT = 50
local MAX_LIMIT = 200

--- Reads limit/offset off req.query, clamped to sane bounds.
function Pagination.ParseParams(req)
    local limit = tonumber(req.query and req.query.limit) or DEFAULT_LIMIT
    local offset = tonumber(req.query and req.query.offset) or 0
    if limit < 1 then limit = 1 end
    if limit > MAX_LIMIT then limit = MAX_LIMIT end
    if offset < 0 then offset = 0 end
    return limit, offset
end

--- Slices `list` (a plain array, newest-first or whatever order it's
-- already in) according to req's limit/offset, and returns the envelope
-- shape every paginated endpoint should respond with.
function Pagination.Apply(list, req)
    local limit, offset = Pagination.ParseParams(req)
    local total = #list
    local page = {}
    for i = offset + 1, math.min(offset + limit, total) do
        page[#page + 1] = list[i]
    end
    return {
        items = page,
        total = total,
        limit = limit,
        offset = offset,
        hasMore = (offset + limit) < total
    }
end
