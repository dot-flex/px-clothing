ClothingServer = {}

function ClothingServer.player(source)
    local framework = ClothingFramework.name()
    if not framework then return end
    local ok, raw = pcall(function()
        if framework == 'esx' then return exports.es_extended:getSharedObject().GetPlayerFromId(source)
        elseif framework == 'qbox' then return exports.qbx_core:GetPlayer(source)
        else return exports['qb-core']:GetCoreObject().Functions.GetPlayer(source) end
    end)
    if not ok or not raw then return end
    local id = framework == 'esx' and raw.getIdentifier() or raw.PlayerData.citizenid
    if not id then return end
    local player = { framework = framework, id = id }
    function player.getIdentifier() return framework == 'esx' and id or 'qb:' .. id end
    function player.getAccount(account)
        if framework == 'esx' then return raw.getAccount(account) end
        local moneyType = account == 'money' and 'cash' or account
        local amount
        if framework == 'qbox' then amount = exports.qbx_core:GetMoney(id, moneyType)
        else
            local current = exports['qb-core']:GetCoreObject().Functions.GetPlayer(source)
            if not current or current.PlayerData.citizenid ~= id then return end
            amount = current.PlayerData.money[moneyType]
        end
        return type(amount) == 'number' and { money = amount } or nil
    end
    function player.getMoney()
        local account = player.getAccount('money')
        return account and account.money or 0
    end
    function player.removeAccountMoney(account, amount, reason)
        local balance = player.getAccount(account)
        if not balance or balance.money < amount then return false end
        if framework == 'esx' then raw.removeAccountMoney(account, amount, reason); return true end
        local moneyType = account == 'money' and 'cash' or account
        if framework == 'qbox' then return exports.qbx_core:RemoveMoney(id, moneyType, amount, reason) == true end
        return raw.Functions.RemoveMoney(moneyType, amount, reason) == true
    end
    function player.addAccountMoney(account, amount, reason)
        if framework == 'esx' then raw.addAccountMoney(account, amount, reason); return true end
        local moneyType = account == 'money' and 'cash' or account
        if framework == 'qbox' then return exports.qbx_core:AddMoney(id, moneyType, amount, reason) == true end
        return raw.Functions.AddMoney(moneyType, amount, reason) == true
    end
    return player
end

function ClothingServer.skin(player)
    local row
    if player.framework == 'esx' then
        row = MySQL.single.await('SELECT skin FROM users WHERE identifier = ?', { player.id })
    else
        row = MySQL.single.await('SELECT id, skin FROM playerskins WHERE citizenid = ? AND active = 1 ORDER BY id DESC LIMIT 1', { player.id })
    end
    local raw = row and row.skin
    if type(raw) == 'string' then
        local ok, value = pcall(json.decode, raw)
        raw = ok and value or nil
    end
    if type(raw) ~= 'table' then return nil, ClothingLocale.t('Create and save your character with the configured appearance resource first.') end
    local skin = player.framework == 'esx' and raw or ClothingIllenium.decode(raw)
    if not skin or (skin.sex ~= 0 and skin.sex ~= 1) then return nil, ClothingLocale.t('A saved freemode appearance is required. QB/QBox must use illenium-appearance format.') end
    return Appearance.normalize(skin), nil, row.id
end

function ClothingServer.saveQuery(player, session, skin, tattoos)
    if player.framework == 'esx' then
        return { query = 'UPDATE users SET skin = ? WHERE identifier = ?', values = { json.encode(skin), player.id } }
    end
    local appearance = ClothingIllenium.encode(skin)
    appearance.tattoos = ClothingIllenium.tattoos(appearance.tattoos, tattoos)
    return { query = 'UPDATE playerskins SET skin = ? WHERE id = ? AND citizenid = ? AND active = 1', values = { json.encode(appearance), session.skinId, player.id } }
end
