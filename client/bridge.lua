ClothingClient = {}

function ClothingClient.available()
    local framework = ClothingFramework.name()
    if not framework then return false, ClothingLocale.t('Start the configured framework before opening this service.') end
    if framework == 'esx' then
        if GetResourceState('skinchanger') ~= 'started' or GetResourceState('esx_skin') ~= 'started' then return false, ClothingLocale.t('ESX appearance requires skinchanger and esx_skin.') end
    elseif GetResourceState(Config.AppearanceResource) ~= 'started' then
        return false, ClothingLocale.t('QB/QBox appearance requires %s.', Config.AppearanceResource)
    end
    return true
end

function ClothingClient.loaded()
    if not ClothingClient.available() then return false end
    local framework = ClothingFramework.name()
    if framework == 'esx' then return exports.es_extended:getSharedObject().IsPlayerLoaded() end
    if framework == 'qbox' then
        local data = exports.qbx_core:GetPlayerData()
        return LocalPlayer.state.isLoggedIn == true and data and data.citizenid ~= nil
    end
    local data = exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
    return LocalPlayer.state.isLoggedIn == true and data and data.citizenid ~= nil
end

function ClothingClient.skin()
    if ClothingFramework.name() == 'esx' then
        local result
        TriggerEvent('skinchanger:getSkin', function(value) result = Appearance.copy(value) end)
        return result
    end
    return ClothingIllenium.decode(exports[Config.AppearanceResource]:getPedAppearance(PlayerPedId()))
end

function ClothingClient.loadSkin(value)
    if not value._appearance then TriggerEvent('skinchanger:loadSkin', Appearance.copy(value))
    else exports[Config.AppearanceResource]:setPedAppearance(PlayerPedId(), ClothingIllenium.encode(value)) end
end

function ClothingClient.data()
    if ClothingFramework.name() == 'esx' then
        local definitions, maxValues
        TriggerEvent('skinchanger:getData', function(data, max) definitions, maxValues = data, max end)
        return definitions, maxValues
    end
    local definitions, maxValues = {}, {}
    for key, definition in pairs(Appearance.fields) do
        if ClothingIllenium.supported(key) then
            definitions[#definitions + 1] = { name = key, min = definition.min }
            maxValues[key] = definition.max
        end
    end
    local ped = PlayerPedId()
    maxValues.hair_1 = GetNumberOfPedDrawableVariations(ped, 2) - 1
    maxValues.hair_2 = math.max(0, GetNumberOfPedTextureVariations(ped, 2, GetPedDrawableVariation(ped, 2)) - 1)
    maxValues.hair_color_1, maxValues.hair_color_2 = GetNumHairColors() - 1, GetNumHairColors() - 1
    for index, mapping in ipairs(ClothingIllenium.overlays) do maxValues[mapping[1] .. '_1'] = GetPedHeadOverlayNum(index - 1) - 1 end
    return definitions, maxValues
end

function ClothingClient.tattoos(ids)
    if ClothingFramework.name() == 'esx' then return false end
    local ped = PlayerPedId()
    local appearance = exports[Config.AppearanceResource]:getPedAppearance(ped)
    exports[Config.AppearanceResource]:setPedTattoos(ped, ClothingIllenium.tattoos(appearance.tattoos, ids))
    return true
end

function ClothingClient.committed(value)
    if ClothingFramework.name() == 'esx' then
        TriggerEvent('esx_skin:setLastSkin', Appearance.copy(value))
        TriggerServerEvent('esx_skin:setWeight', value)
    end
end

for _, name in ipairs({ 'esx:playerLoaded', 'QBCore:Client:OnPlayerLoaded' }) do
    RegisterNetEvent(name, function() TriggerEvent('px-clothing:playerLoaded') end)
end
for _, name in ipairs({ 'esx:onPlayerLogout', 'QBCore:Client:OnPlayerUnload' }) do
    RegisterNetEvent(name, function() TriggerEvent('px-clothing:playerLogout') end)
end
AddEventHandler('onResourceStop', function(resource)
    if ClothingFramework.dependency(resource) then TriggerEvent('px-clothing:playerLogout') end
end)
