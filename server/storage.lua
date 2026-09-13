--[[
    server/storage.lua

    Thin abstraction in front of the actual storage backend. Every other
    module in server-api talks to `Storage.*`, never to the filesystem or a
    database directly. This lets the backend be swapped later (JSON file ->
    SQL) by only touching server/adapters/storage.lua.
]]

Storage = {}

--- Read a whole "table" (collection) by name. Returns a Lua table (array or map).
function Storage.Read(collection)
    return StorageAdapter.Read(collection)
end

--- Overwrite a whole collection with `data`.
function Storage.Write(collection, data)
    return StorageAdapter.Write(collection, data)
end

--- Get a single record by id from a collection (collection stored as map keyed by id).
function Storage.Get(collection, id)
    local data = StorageAdapter.Read(collection) or {}
    return data[id]
end

--- Upsert a single record by id into a collection stored as a map keyed by id.
function Storage.Set(collection, id, record)
    local data = StorageAdapter.Read(collection) or {}
    data[id] = record
    StorageAdapter.Write(collection, data)
    return record
end

--- Delete a record by id from a map-collection.
function Storage.Delete(collection, id)
    local data = StorageAdapter.Read(collection) or {}
    data[id] = nil
    StorageAdapter.Write(collection, data)
end

--- Append a record to a list-collection (collection stored as an array).
function Storage.Append(collection, record)
    local data = StorageAdapter.Read(collection) or {}
    data[#data + 1] = record
    StorageAdapter.Write(collection, data)
    return record
end
