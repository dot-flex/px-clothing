ClothingRuntime = { serverReady = false, stopped = false, epoch = 0 }
local probeId = 0
local lastStatusId = 0
local requests, abandonedOpens = {}, {}
local requestSequence = 0
local requestPrefix = ('%s:%s'):format(GetGameTimer(), math.random(100000, 999999))

local function abandonOpen(id, request)
    if request.name ~= 'open' then return end
    abandonedOpens[id] = true
    SetTimeout(120000, function() abandonedOpens[id] = nil end)
end

RegisterNetEvent('px-clothing:response', function(id, name, result)
    if type(id) ~= 'string' or type(result) ~= 'table' then return end
    local request = requests[id]
    if not request then
        if name == 'open' and abandonedOpens[id] then
            abandonedOpens[id] = nil
            if result.ok and result.token then TriggerServerEvent('px-clothing:cancel', result.token) end
        end
        return
    end
    if request.name ~= name then return end
    requests[id] = nil
    if request.epoch ~= ClothingRuntime.epoch or ClothingRuntime.stopped then
        if name == 'open' and result.ok then TriggerServerEvent('px-clothing:cancel', result.token) end
        result = { ok = false, error = ClothingLocale.t('Your character session has changed.') }
    elseif result.retry then
        ClothingRuntime.serverReady = false
    end
    request.promise:resolve(result)
end)

function ClothingRuntime.probe()
    probeId = probeId + 1
    TriggerServerEvent('px-clothing:probe', probeId)
end

function ClothingRuntime.playerReady()
    local ok, loaded = pcall(ClothingClient.loaded)
    if not ok or not loaded or not NetworkIsPlayerActive(PlayerId()) then return false end
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return false end
    local model = GetEntityModel(ped)
    return model == joaat('mp_m_freemode_01') or model == joaat('mp_f_freemode_01')
end

RegisterNetEvent('px-clothing:serviceStatus', function(id, ready)

    if type(id) == 'number' and id > lastStatusId and id <= probeId then
        lastStatusId = id
        ClothingRuntime.serverReady = ready == true
    end
end)

RegisterNetEvent('px-clothing:serviceUnavailable', function()
    ClothingRuntime.serverReady = false
    lastStatusId = probeId
end)

CreateThread(function()
    while not ClothingRuntime.stopped do
        if not ClothingRuntime.serverReady and ClothingRuntime.playerReady() then
            ClothingRuntime.probe()
        end
        Wait(1000)
    end
end)

function ClothingRuntime.waitForService(timeout)
    if ClothingRuntime.serverReady then return true end
    ClothingRuntime.probe()
    local deadline = GetGameTimer() + timeout
    while not ClothingRuntime.serverReady and not ClothingRuntime.stopped and GetGameTimer() < deadline do Wait(50) end
    return ClothingRuntime.serverReady
end

function ClothingRuntime.rpc(name, payload)
    if not ClothingRuntime.serverReady or ClothingRuntime.stopped then
        return { ok = false, retry = true, error = ClothingLocale.t('The clothing service is starting. Please try again shortly.') }
    end
    requestSequence = requestSequence + 1
    local id = requestPrefix .. ':' .. requestSequence
    local request = { promise = promise.new(), name = name, epoch = ClothingRuntime.epoch }
    requests[id] = request

    if name ~= 'checkout' then
        SetTimeout(15000, function()
            if requests[id] ~= request then return end
            requests[id] = nil
            abandonOpen(id, request)
            ClothingRuntime.serverReady = false
            request.promise:resolve({ ok = false, retry = true, error = ClothingLocale.t('The clothing service timed out. Please try again.') })
        end)
    end
    TriggerServerEvent('px-clothing:request', id, name, payload or {})
    return Citizen.Await(request.promise)
end

AddEventHandler('px-clothing:playerLogout', function()
    ClothingRuntime.epoch = ClothingRuntime.epoch + 1
    ClothingRuntime.serverReady = false
    lastStatusId = probeId
    for id, request in pairs(requests) do
        requests[id] = nil
        abandonOpen(id, request)
        request.promise:resolve({ ok = false, error = ClothingLocale.t('Your character session has changed.') })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ClothingRuntime.stopped = true
        ClothingRuntime.epoch = ClothingRuntime.epoch + 1
    end
end)
