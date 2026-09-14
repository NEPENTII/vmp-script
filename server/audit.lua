--[[
    server/audit.lua
    Append-only audit trail for security-relevant events (auth, admin
    actions). Never logs OTPs or session tokens in plaintext.
]]

Audit = {}

function Audit.Log(eventType, details)
    local entry = {
        id = Crypto.GenerateToken(8),
        type = eventType,
        details = details or {},
        timestamp = os.time()
    }
    Storage.Append('audit_log', entry)
    if Config.Debug then
        print(('[server-api][audit] %s %s'):format(eventType, json.encode(details or {})))
    end
    return entry
end

--- Removes audit entries older than Config.Audit.retainDays. Call periodically.
function Audit.Prune()
    local log = Storage.Read('audit_log') or {}
    local cutoff = os.time() - (Config.Audit.retainDays * 24 * 60 * 60)
    local kept = {}
    for _, entry in ipairs(log) do
        if (entry.timestamp or 0) >= cutoff then
            kept[#kept + 1] = entry
        end
    end
    Storage.Write('audit_log', kept)
end

CreateThread(function()
    while true do
        Wait(60 * 60 * 1000) -- hourly
        Audit.Prune()
    end
end)
