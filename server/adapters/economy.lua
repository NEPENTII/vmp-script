--[[
    server/adapters/economy.lua
    Exposes whatever balances the detected framework actually provides.
    Returns an empty table (not fabricated data) when nothing is available.
]]

EconomyAdapter = {}

--- Returns a map of balance name -> amount, e.g. { money = 500, bank = 12000 }.
-- Only includes keys the underlying framework actually exposes.
function EconomyAdapter.GetBalances(source)
    if Config.Economy.override == 'none' then
        return {}
    end

    local player = FrameworkAdapter.GetPlayer(source)
    if not player then
        return {}
    end

    if FrameworkAdapter.name == 'esx' then
        local balances = {}
        local ok, accounts = pcall(function() return player.getAccounts() end)
        if ok and accounts then
            for _, account in ipairs(accounts) do
                -- account.name is e.g. "money", "bank", "black_money" - whatever ESX defines
                balances[account.name] = account.money
            end
        end
        return balances
    elseif FrameworkAdapter.name == 'qbcore' then
        local balances = {}
        local ok, moneyTable = pcall(function() return player.PlayerData.money end)
        if ok and type(moneyTable) == 'table' then
            for k, v in pairs(moneyTable) do
                balances[k] = v
            end
        end
        return balances
    end

    -- Unknown/no framework: nothing to report. Do NOT invent balances.
    return {}
end
