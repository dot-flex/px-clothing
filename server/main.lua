if not ClothingProtection or not ClothingProtection.ready then return end

local sessions, locks, lastRequest, receipts = {}, {}, {}, {}
local ready = false
local handlers, probes, handlersReady = {}, {}, false

local function samePlayer(source, player)
    local current = ClothingServer.player(source)
    return current ~= nil and current.getIdentifier() == player.getIdentifier()
end

RegisterNetEvent('px-clothing:probe', function(id)
    local source = source
    if not Appearance.integer(id, 1, 2147483647) then return end
    local now = GetGameTimer()
    if probes[source] and now - probes[source] < 750 then return end
    probes[source] = now
    local available = ready and handlersReady and ClothingServer.player(source) ~= nil
    TriggerClientEvent('px-clothing:serviceStatus', source, id, available)
end)

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and type(result) == 'table' and result or fallback
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS nopixel_clothing_outfits (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(100) NOT NULL,
            name VARCHAR(40) NOT NULL,
            skin LONGTEXT NOT NULL,
            INDEX owner (identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS nopixel_clothing_tattoos (
            identifier VARCHAR(100) NOT NULL PRIMARY KEY,
            tattoos LONGTEXT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    ready = true
end)

local function nearShop(source, shopId)
    local ped = GetPlayerPed(source)
    if ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local nearest, nearestDistance
    for id, shop in ipairs(Config.Shops) do
        local target = shop.target or {}
        local dx, dy, dz = coords.x - (target.x or shop.x), coords.y - (target.y or shop.y), coords.z - (target.z and target.z + 1.0 or shop.z)
        local distance = dx * dx + dy * dy + dz * dz
        if (not shopId or shopId == id) and distance <= Config.ServerDistance ^ 2 and (not nearestDistance or distance < nearestDistance) then nearest, nearestDistance = id, distance end
    end
    return nearest
end

local function balances(player)
    local bank = player.getAccount('bank')
    return { cash = player.getMoney(), bank = bank and bank.money or 0 }
end

local function outfits(identifier)
    return MySQL.query.await('SELECT id, name FROM nopixel_clothing_outfits WHERE identifier = ? ORDER BY id DESC', { identifier }) or {}
end

local function registerRequest(name, handler)
    handlers[name] = function(source, cb, payload)
        local player = ClothingServer.player(source)
        if not ready or not player then cb({ ok = false, retry = true, error = ClothingLocale.t('Clothing service is not ready.') }); return end
        local identifier = player.getIdentifier()
        if locks[identifier] then cb({ ok = false, error = ClothingLocale.t('Please wait for the current request.') }); return end
        local now = GetGameTimer()
        if lastRequest[source] and now - lastRequest[source] < 150 then cb({ ok = false, error = ClothingLocale.t('Please try again in a moment.') }); return end
        lastRequest[source] = now
        locks[identifier] = true
        local ok, result = pcall(function() return handler(source, player, type(payload) == 'table' and payload or {}) end)
        locks[identifier] = nil
        if not samePlayer(source, player) then return end
        if not ok then
            cb({ ok = false, error = ClothingLocale.t('The request could not be completed. Please try again.') })
        else
            cb(result or { ok = true })
        end
    end
end

local function sessionFor(source, player, payload)
    local session = sessions[source]
    if not session or session.identifier ~= player.getIdentifier() or payload.token ~= session.token then return nil, ClothingLocale.t('Your session has closed. Reopen the shop.') end
    if os.time() - session.started > Config.SessionSeconds then return nil, ClothingLocale.t('Your session expired. Exit and reopen the shop.') end
    if not nearShop(source, session.shopId) then return nil, ClothingLocale.t('Return to the shop where you opened this session.') end
    return session
end

registerRequest('open', function(source, player, payload)
    if payload.shopId ~= nil and not Appearance.integer(payload.shopId, 1, #Config.Shops) then return { ok = false, error = ClothingLocale.t('Invalid shop.') } end
    local shopId = nearShop(source, payload.shopId)
    if not shopId then return { ok = false, error = ClothingLocale.t('Visit the correct shop to customize your character.') } end
    local tabs = Appearance.shopTabs(Config.Shops[shopId])
    local available = false
    for _, enabled in pairs(tabs) do if enabled then available = true end end
    if not available then return { ok = false, error = ClothingLocale.t('This location has no available services.') } end
    local skin, skinError, skinId = ClothingServer.skin(player)
    if not skin then return { ok = false, error = skinError } end
    local tattooRow = MySQL.single.await('SELECT tattoos FROM nopixel_clothing_tattoos WHERE identifier = ?', { player.getIdentifier() })
    local tattoos = Appearance.tattoos(tattooRow and decode(tattooRow.tattoos, {}) or {}, skin.sex) or {}
    local token = ('%s:%s:%s'):format(source, GetGameTimer(), math.random(100000, 999999))
    sessions[source] = { identifier = player.getIdentifier(), token = token, baseline = skin, tattoos = tattoos, started = os.time(), shopId = shopId, tabs = tabs, skinId = skinId }
    receipts[source] = nil
    return { ok = true, token = token, skin = skin, tattoos = tattoos, balances = balances(player), outfits = tabs.apparel and outfits(player.getIdentifier()) or {}, enabledTabs = tabs, service = Config.Shops[shopId].service or 'clothing' }
end)

registerRequest('outfit', function(source, player, payload)
    local session, err = sessionFor(source, player, payload)
    if not session then return { ok = false, error = err } end
    if not session.tabs.apparel then return { ok = false, error = ClothingLocale.t('Outfits are only available at clothing stores.') } end
    if not Appearance.integer(payload.id, 1, 2147483647) then return { ok = false, error = ClothingLocale.t('Invalid outfit.') } end
    local row = MySQL.single.await('SELECT skin FROM nopixel_clothing_outfits WHERE id = ? AND identifier = ?', { payload.id, session.identifier })
    local outfit = row and decode(row.skin)
    if not outfit or outfit.sex ~= session.baseline.sex then return { ok = false, error = ClothingLocale.t('This outfit does not fit your character.') } end
    local skin = Appearance.clothes(session.baseline, outfit)
    local clean = Appearance.sanitize(skin, session.baseline, session.tabs)
    if not clean then return { ok = false, error = ClothingLocale.t('This outfit contains invalid clothing.') } end

    session.pricingBase = clean
    return { ok = true, baseline = clean }
end)

registerRequest('deleteOutfit', function(source, player, payload)
    local session, err = sessionFor(source, player, payload)
    if not session then return { ok = false, error = err } end
    if not session.tabs.apparel then return { ok = false, error = ClothingLocale.t('Outfits are only available at clothing stores.') } end
    if not Appearance.integer(payload.id, 1, 2147483647) then return { ok = false, error = ClothingLocale.t('Invalid outfit.') } end
    MySQL.update.await('DELETE FROM nopixel_clothing_outfits WHERE id = ? AND identifier = ?', { payload.id, session.identifier })
    return { ok = true, outfits = outfits(session.identifier) }
end)

registerRequest('checkout', function(source, player, payload)
    if receipts[source] and receipts[source].token == payload.token then return receipts[source].result end
    local session, err = sessionFor(source, player, payload)
    if not session then return { ok = false, error = err } end
    local skin, invalid = Appearance.sanitize(payload.skin, session.baseline, session.tabs)
    if not skin then return { ok = false, error = invalid } end
    if player.framework ~= 'esx' then
        for key in pairs(Appearance.fields) do
            if not ClothingIllenium.supported(key) and skin[key] ~= session.baseline[key] then return { ok = false, error = ClothingLocale.t('This option is unsupported by your appearance provider.') } end
        end
    end
    local tattoos = Appearance.tattoos(payload.tattoos, skin.sex)
    if not tattoos then return { ok = false, error = ClothingLocale.t('Invalid tattoo selection.') } end
    if not session.tabs.tattoos and json.encode(tattoos) ~= json.encode(session.tattoos) then return { ok = false, error = ClothingLocale.t('Tattoos are only available at tattoo studios.') } end
    local account = payload.account == 'cash' and 'money' or payload.account == 'bank' and 'bank'
    if not account then return { ok = false, error = ClothingLocale.t('Choose cash or bank.') } end
    local name = type(payload.outfitName) == 'string' and payload.outfitName:match('^%s*(.-)%s*$') or ''
    if #name > 40 or name:find('[%c]') then return { ok = false, error = ClothingLocale.t('Use an outfit name of 1–40 characters.') } end
    if name ~= '' then
        if not session.tabs.apparel then return { ok = false, error = ClothingLocale.t('Outfits can only be saved at clothing stores.') } end
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM nopixel_clothing_outfits WHERE identifier = ?', { session.identifier })
        if count >= Config.MaxOutfits then return { ok = false, error = ClothingLocale.t('Your wardrobe is full. Delete an outfit first.') } end
    end
    local quote = Appearance.quote(session.pricingBase or session.baseline, skin, session.tattoos, tattoos)
    local balance = player.getAccount(account)
    if not balance or balance.money < quote.total then return { ok = false, error = ClothingLocale.t('Not enough money in the selected account.'), balances = balances(player) } end
    local queries = {
        ClothingServer.saveQuery(player, session, skin, tattoos),
        { query = 'INSERT INTO nopixel_clothing_tattoos (identifier, tattoos) VALUES (?, ?) ON DUPLICATE KEY UPDATE tattoos = VALUES(tattoos)', values = { session.identifier, json.encode(tattoos) } }
    }
    if name ~= '' then queries[#queries + 1] = { query = 'INSERT INTO nopixel_clothing_outfits (identifier, name, skin) VALUES (?, ?, ?)', values = { session.identifier, name, json.encode(skin) } } end

    if not samePlayer(source, player) then return { ok = false, error = ClothingLocale.t('Your character session has changed.') } end
    if quote.total > 0 and not player.removeAccountMoney(account, quote.total, ClothingLocale.t('Appearance purchase')) then return { ok = false, error = ClothingLocale.t('Payment was declined.'), balances = balances(player) } end
    local success, saved = pcall(function() return MySQL.transaction.await(queries) end)
    if not success or not saved then
        local refunded = quote.total == 0 or player.addAccountMoney(account, quote.total, ClothingLocale.t('Appearance purchase refund'))
        return { ok = false, error = refunded and ClothingLocale.t('Saving failed. Your payment was refunded.') or ClothingLocale.t('Saving failed and the refund could not complete. Contact server staff.') }
    end
    local result = { ok = true, skin = skin, tattoos = tattoos, quote = quote, balances = balances(player) }
    if sessions[source] == session then sessions[source] = nil end
    if samePlayer(source, player) then
        receipts[source] = { token = payload.token, result = result }
        TriggerClientEvent('px-clothing:committed', source, payload.token, result)
    end
    return result
end)

registerRequest('tattoos', function(_, player)
    local row = MySQL.single.await('SELECT tattoos FROM nopixel_clothing_tattoos WHERE identifier = ?', { player.getIdentifier() })
    return { ok = true, tattoos = row and decode(row.tattoos, {}) or {} }
end)

RegisterNetEvent('px-clothing:request', function(id, name, payload)
    local source = source
    if type(id) ~= 'string' or #id == 0 or #id > 80 then return end
    if type(name) ~= 'string' then return end
    local function reply(result)
        TriggerClientEvent('px-clothing:response', source, id, name, result)
    end
    local handler = handlers[name]
    if not handler then reply({ ok = false, error = ClothingLocale.t('Unknown clothing request.') }); return end
    handler(source, reply, payload)
end)
handlersReady = true

RegisterNetEvent('px-clothing:cancel', function(token)
    local session = sessions[source]
    if session and session.token == token and not locks[session.identifier] then sessions[source] = nil end
end)

AddEventHandler('playerDropped', function()
    sessions[source], receipts[source], lastRequest[source] = nil, nil, nil
    probes[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if ClothingFramework.dependency(resource) or resource == 'oxmysql' or resource == GetCurrentResourceName() then
        TriggerClientEvent('px-clothing:serviceUnavailable', -1)
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        for source, session in pairs(sessions) do
            if os.time() - session.started > Config.SessionSeconds + 60 and not locks[session.identifier] then sessions[source] = nil end
        end
    end
end)
