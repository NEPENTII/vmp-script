--[[
    server/validation.lua
    Generic request-body validation.
]]

Validation = {}

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
