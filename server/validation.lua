--[[
    server/validation.lua
    Generic request-body and gamemode-schema validation. No GameMode-specific
    logic here -- only generic type checking against a declared schema.
]]

Validation = {}

local SUPPORTED_TYPES = {
    string = true, number = true, integer = true, boolean = true,
    object = true, array = true, timestamp = true, duration = true, enum = true
}

--- Validate that `body` is a table and has all `required` string keys.
function Validation.RequireFields(body, required)
    if type(body) ~= 'table' then
        return false, 'Request body must be a JSON object'
    end
    for _, field in ipairs(required) do
        if body[field] == nil then
            return false, ('Missing required field: %s'):format(field)
        end
    end
    return true
end

--- Validate a single value against a declared field type.
local function validateType(value, fieldType, enumValues)
    if fieldType == 'string' then
        return type(value) == 'string'
    elseif fieldType == 'number' then
        return type(value) == 'number'
    elseif fieldType == 'integer' then
        return type(value) == 'number' and math.floor(value) == value
    elseif fieldType == 'boolean' then
        return type(value) == 'boolean'
    elseif fieldType == 'object' then
        return type(value) == 'table'
    elseif fieldType == 'array' then
        return type(value) == 'table'
    elseif fieldType == 'timestamp' then
        return type(value) == 'string' or type(value) == 'number'
    elseif fieldType == 'duration' then
        return type(value) == 'number'
    elseif fieldType == 'enum' then
        if type(value) ~= 'string' then return false end
        if not enumValues then return true end
        for _, v in ipairs(enumValues) do
            if v == value then return true end
        end
        return false
    end
    return false
end

--- Validate a schema definition itself (used at GameMode registration time).
-- schema = { fieldName = "string" | { type = "enum", values = {...} }, ... }
function Validation.ValidateSchemaDefinition(schema)
    if type(schema) ~= 'table' then
        return false, 'Schema must be an object'
    end
    for field, def in pairs(schema) do
        local fieldType = type(def) == 'table' and def.type or def
        if not SUPPORTED_TYPES[fieldType] then
            return false, ('Unsupported field type "%s" for field "%s"'):format(tostring(fieldType), field)
        end
    end
    return true
end

--- Validate a data payload against a previously-registered schema definition.
function Validation.ValidateAgainstSchema(payload, schema)
    if type(payload) ~= 'table' then
        return false, 'Payload must be an object'
    end
    for field, def in pairs(schema) do
        local fieldType = type(def) == 'table' and def.type or def
        local enumValues = type(def) == 'table' and def.values or nil
        local value = payload[field]
        if value == nil then
            -- fields are optional unless the schema marks them required
            if type(def) == 'table' and def.required then
                return false, ('Missing required field: %s'):format(field)
            end
        else
            if not validateType(value, fieldType, enumValues) then
                return false, ('Field "%s" does not match declared type "%s"'):format(field, fieldType)
            end
        end
    end
    return true
end
