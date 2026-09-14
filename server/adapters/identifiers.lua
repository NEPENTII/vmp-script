--[[
    server/adapters/identifiers.lua
    Reads whatever identifiers FXServer actually exposes for a given source.
    Never invents identifiers that aren't present.
]]

IdentifierAdapter = {}

local KNOWN_PREFIXES = { 'license', 'license2', 'steam', 'discord', 'fivem', 'xbl', 'live' }

--- Returns a map { license = "...", steam = "...", ... } containing only
-- identifiers that are actually present for this source.
function IdentifierAdapter.GetForSource(source)
    local result = {}
    local numIds = GetNumPlayerIdentifiers(source)
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            local prefix = id:match('^(%a+):')
            if prefix then
                for _, known in ipairs(KNOWN_PREFIXES) do
                    if prefix == known then
                        result[known] = id
                        break
                    end
                end
            end
        end
    end
    return result
end

--- Picks the most stable identifier available to use as the basis of a
-- permanent playerRef. Preference order: license > license2 > steam > discord > fivem.
function IdentifierAdapter.GetPrimaryIdentifier(identifiers)
    local preference = { 'license', 'license2', 'steam', 'discord', 'fivem' }
    for _, key in ipairs(preference) do
        if identifiers[key] then
            return identifiers[key]
        end
    end
    -- fall back to whatever's available, if anything
    for _, v in pairs(identifiers) do
        return v
    end
    return nil
end
