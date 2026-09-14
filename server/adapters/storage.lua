--[[
    server/adapters/storage.lua

    Default storage backend: flat JSON files, one per collection, under
    `Config.Storage.jsonPath`. Swap `Config.Storage.driver` and implement
    the same three functions against a real database if you outgrow this.

    NOTE: this is intentionally simple (whole-file read/modify/write). It is
    fine for small-to-medium servers. If you need concurrent-write safety
    at scale, route this through oxmysql or another real DB instead.
]]

StorageAdapter = {}

local resourceName = GetCurrentResourceName()
local cache = {} -- collection -> decoded table (in-memory cache to avoid re-reading every call)

local function ensureDir()
    -- FiveM's `SaveResourceFile` creates directories on demand when the
    -- path contains a subfolder, so no explicit mkdir is required here.
end

local function pathFor(collection)
    return ('%s/%s.json'):format(Config.Storage.jsonPath, collection)
end

local function loadFromDisk(collection)
    local raw = LoadResourceFile(resourceName, pathFor(collection))
    if not raw or raw == '' then
        return nil
    end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or decoded == nil then
        print(('[server-api] WARNING: failed to decode storage file %s, treating as empty'):format(pathFor(collection)))
        return nil
    end
    return decoded
end

function StorageAdapter.Read(collection)
    if cache[collection] ~= nil then
        return cache[collection]
    end

    local data = loadFromDisk(collection)
    if data == nil then
        data = {}
    end
    cache[collection] = data
    return data
end

function StorageAdapter.Write(collection, data)
    ensureDir()
    cache[collection] = data
    local ok, encoded = pcall(json.encode, data)
    if not ok then
        print(('[server-api] ERROR: failed to encode collection %s'):format(collection))
        return false
    end
    SaveResourceFile(resourceName, pathFor(collection), encoded, -1)
    return true
end
