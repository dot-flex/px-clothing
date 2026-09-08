local state, opening, camera, original, originalTattoos, committedTattoos = nil, false, nil, nil, {}, {}
local angle, distance, elevation, targetZ = 0.0, 2.4, 0.25, 0.2
local cameraGoal, cameraInput = {}, {}
local hairCategory = { id = 'hair', label = ClothingLocale.t('Hairstyles'), key = 'hair_1', texture = 'hair_2', component = 2, focus = 'head' }
local savedHeading, wasFrozen, radarVisible, savedWeapon, sessionPed
local blips = {}
local busy = false
local hudHidden = false
local uiReady = false
local tattooRevision = 0
local previewPose = false

RegisterNUICallback('ready', function(_, cb)
    uiReady = true
    if not state then SendNUIMessage({ action = 'close' }) end
    cb({ ok = true })
end)

local skin = ClothingClient.skin

local function applyTattoos(ids)
    local ped = PlayerPedId()
    local sexId = GetEntityModel(ped) == joaat('mp_m_freemode_01') and 0 or 1
    ids = Appearance.tattoos(ids or {}, sexId) or {}
    if ClothingClient.tattoos(ids) then TriggerEvent('px-clothing:decorationsApplied', ped); return end
    local sex = sexId == 0 and 'male' or 'female'
    ClearPedDecorations(ped)
    for _, id in ipairs(ids) do
        local tattoo = ClothingTattoos.byId[id]
        if tattoo and tattoo[sex] then AddPedDecorationFromHashes(ped, joaat(tattoo.collection), joaat(tattoo[sex])) end
    end
    TriggerEvent('px-clothing:decorationsApplied', ped)
end

local loadSkin = ClothingClient.loadSkin

local rpc = ClothingRuntime.rpc

local notify = ClothingNotify

local function tattooClothing()
    local gender = state.skin.sex == 0 and 'male' or 'female'
    local preview = Appearance.copy(state.tattooPreview and Config.TattooPreview[gender] or {})
    if state.tattooPreview and (state.tattooCategory == 'left_leg' or state.tattooCategory == 'right_leg' or state.tattooCategory == 'feet') then
        for key, value in pairs(Config.TattooLegPreview[gender] or {}) do preview[key] = value end
    end
    for _, category in ipairs(Config.Categories) do
        if category.component then
            local drawable = preview[category.key] or state.skin[category.key]
            local texture = preview[category.texture] or state.skin[category.texture]
            if IsPedComponentVariationValid(PlayerPedId(), category.component, drawable, texture) then SetPedComponentVariation(PlayerPedId(), category.component, drawable, texture, 0) end
        end
    end
end

local function tattooAvailable(tattoo)
    if not tattoo then return false end
    local overlay = tattoo[GetEntityModel(PlayerPedId()) == joaat('mp_m_freemode_01') and 'male' or 'female']
    if not overlay or tattoo.build and GetGameBuildNumber() < tattoo.build then return false end
    local zone = GetPedDecorationZoneFromHashes(joaat(tattoo.collection), joaat(overlay))
    return zone >= 0 and zone <= 5
end

local function tattooCatalog()
    local result = {}
    for _, tattoo in ipairs(Config.Tattoos) do
        if tattooAvailable(tattoo) then
            local item = Appearance.copy(tattoo)
            item.image = ClothingTattoos.image(tattoo)
            if item.labelKey then
                local label = GetLabelText(item.labelKey)
                if label and label ~= 'NULL' and label ~= '' then item.label = label end
            end
            result[#result + 1] = item
        end
    end
    return result
end

local function updateCamera(snap)
    if not camera then return end
    local blend = snap and 1.0 or 1.0 - math.exp(-22.0 * math.min(GetFrameTime(), 0.1))
    angle = (angle + ((cameraGoal.angle - angle + 180.0) % 360.0 - 180.0) * blend) % 360.0
    distance = distance + (cameraGoal.distance - distance) * blend
    elevation = elevation + (cameraGoal.elevation - elevation) * blend
    targetZ = targetZ + (cameraGoal.targetZ - targetZ) * blend
    local coords = GetEntityCoords(PlayerPedId())
    local radians = math.rad(angle)
    local frameX, frameY = math.cos(radians) * distance * 0.065, -math.sin(radians) * distance * 0.065
    SetCamCoord(camera, coords.x + math.sin(radians) * distance + frameX, coords.y + math.cos(radians) * distance + frameY, coords.z + elevation)
    PointCamAtCoord(camera, coords.x + frameX, coords.y + frameY, coords.z + targetZ)
end

local function focusCamera(focus, snap)
    local positions = { head = { 0.85, 0.65, 0.65 }, body = { 2.4, 0.25, 0.2 }, legs = { 1.8, -0.35, -0.4 }, feet = { 1.0, -0.65, -0.8 } }
    local position = positions[focus] or positions.body
    cameraGoal.distance, cameraGoal.elevation, cameraGoal.targetZ = position[1], position[2], position[3]
    if snap then updateCamera(true) end
end

local function release()
    if not sessionPed and not camera then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    if camera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(camera, false)
        camera = nil
    end
    if sessionPed and DoesEntityExist(sessionPed) then
        if previewPose and not IsEntityDead(sessionPed) then
            local taskStatus = GetScriptTaskStatus(sessionPed, joaat('SCRIPT_TASK_STAND_STILL'))
            if taskStatus == 0 or taskStatus == 1 or taskStatus == 2 then ClearPedTasksImmediately(sessionPed) end
        end
        FreezeEntityPosition(sessionPed, wasFrozen or false)
        if savedHeading then SetEntityHeading(sessionPed, savedHeading) end
        if savedWeapon then SetCurrentPedWeapon(sessionPed, savedWeapon, true) end
    end
    if radarVisible ~= nil then DisplayRadar(radarVisible) end
    if hudHidden and Config.HudVisibilityEvent then TriggerEvent(Config.HudVisibilityEvent, true); hudHidden = false end
    SendNUIMessage({ action = 'close' })
    TriggerEvent('px-clothing:visibility', false)
    sessionPed = nil
    previewPose = false
    radarVisible, savedHeading, savedWeapon = nil, nil, nil
end

local function close(cancel)
    if not state or busy then return false end
    if cancel then
        if PlayerPedId() == sessionPed then loadSkin(original); applyTattoos(originalTattoos) end
        TriggerServerEvent('px-clothing:cancel', state.token)
    end
    state, original = nil, nil
    release()
    return true
end

local function textureCount(category, drawable)
    if drawable < 0 then return 1 end
    if category.prop then return math.max(1, GetNumberOfPedPropTextureVariations(PlayerPedId(), category.prop, drawable)) end
    return math.max(1, GetNumberOfPedTextureVariations(PlayerPedId(), category.component, drawable))
end

local function categories()
    local result = {}
    for _, category in ipairs(Config.Categories) do
        local item = Appearance.copy(category)
        item.label = ClothingLocale.t(item.label)
        item.min = category.prop and -1 or 0
        item.max = (category.prop and GetNumberOfPedPropDrawableVariations(PlayerPedId(), category.prop) or GetNumberOfPedDrawableVariations(PlayerPedId(), category.component)) - 1
        result[#result + 1] = item
    end
    return result
end

local function fields()
    local definitions, maxValues = ClothingClient.data()
    local available, result = {}, {}
    for _, definition in ipairs(definitions or {}) do available[definition.name] = definition end
    for key, definition in pairs(Appearance.fields) do
        if definition.tab ~= 'apparel' and available[key] and (not state or state.tabs[definition.tab]) then
            local item = Appearance.copy(definition)
            item.min = math.max(item.min, available[key].min or item.min)
            item.max = math.min(item.max, (maxValues or {})[key] or item.max)
            result[#result + 1] = item
        end
    end
    table.sort(result, function(a, b) return a.key < b.key end)
    return result
end

local function payload()
    return { ok = true, skin = state.skin, tattoos = state.tattoos,
        quote = Appearance.quote(state.baseline, state.skin, state.originalTattoos, state.tattoos), fields = fields() }
end

local function validateClothing(value)
    for _, category in ipairs(categories()) do
        if not Appearance.integer(value[category.key], category.min, category.max) then return false, ClothingLocale.t('This clothing is not available on your game build.') end
        if not Appearance.integer(value[category.texture], 0, textureCount(category, value[category.key]) - 1) then return false, ClothingLocale.t('This texture is not available on your game build.') end
    end
    return true
end

local openingToken
local function openSession(shopId)
    if IsPauseMenuActive() then return end
    local available, dependencyError = ClothingClient.available()
    if not available then notify(dependencyError); return end
    if not uiReady then notify(ClothingLocale.t('The clothing interface is loading. Please try again.'), 'info'); return end
    if not ClothingRuntime.playerReady() then notify(ClothingLocale.t('Your character is still loading. Please try again shortly.'), 'info'); return end
    if not ClothingRuntime.serverReady then notify(ClothingLocale.t('Loading clothing store...'), 'info'); end
    if not ClothingRuntime.waitForService(5000) then
        notify(ClothingLocale.t('The clothing service is still loading. Please try again shortly.'), 'warning')
        return
    end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsPedFalling(ped) then notify(ClothingLocale.t('Stand on foot to use the clothing store.')); return end
    local model = GetEntityModel(ped)
    if model ~= joaat('mp_m_freemode_01') and model ~= joaat('mp_f_freemode_01') then notify(ClothingLocale.t('Clothing requires a freemode character.')); return end
    opening = true
    tattooRevision = tattooRevision + 1
    local result = rpc('open', { shopId = shopId })
    if not result.ok then notify(result.error); return end
    openingToken = result.token
    if ped ~= PlayerPedId() or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then TriggerServerEvent('px-clothing:cancel', result.token); return end
    original, originalTattoos = skin(), Appearance.copy(committedTattoos)
    if original.sex ~= result.skin.sex then TriggerServerEvent('px-clothing:cancel', result.token); notify(ClothingLocale.t('Your character model differs from your saved appearance.')); return end
    sessionPed = ped
    savedHeading, wasFrozen, radarVisible, savedWeapon = GetEntityHeading(ped), IsEntityPositionFrozen(ped), not IsRadarHidden(), GetSelectedPedWeapon(ped)
    loadSkin(result.skin)
    local current = skin()
    local valid, err = validateClothing(current)
    if not valid then loadSkin(original); TriggerServerEvent('px-clothing:cancel', result.token); sessionPed = nil; notify(err); return end
    state = { token = result.token, tabs = result.enabledTabs, skin = current, baseline = Appearance.copy(current), tattoos = result.tattoos, originalTattoos = Appearance.copy(result.tattoos) }
    originalTattoos = Appearance.copy(result.tattoos)
    applyTattoos(state.tattoos)
    if state.tabs.tattoos then state.tattooPreview = true; tattooClothing() end
    ClearPedTasksImmediately(ped)
    ClearPedSecondaryTask(ped)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    FreezeEntityPosition(ped, true)
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    previewPose = true
    TaskStandStill(ped, -1)
    angle = -savedHeading
    cameraGoal.angle = angle
    cameraInput = { sequence = 0, rotate = 0, pan = 0, zoom = 0 }
    camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(camera, 40.0)
    focusCamera(result.service == 'hospital' and 'head' or 'body', true)
    RenderScriptCams(true, false, 0, true, true)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    if Config.HudVisibilityEvent then TriggerEvent(Config.HudVisibilityEvent, false); hudHidden = true end
    SendNUIMessage({ action = 'open', data = {
        skin = current, baseline = state.baseline, tattoos = result.tattoos, balances = result.balances,
        categories = state.tabs.apparel and categories() or {}, fields = fields(), outfits = result.outfits, enabledTabs = state.tabs,
        language = ClothingLocale.language, translations = ClothingLocale.dictionary,
        token = result.token, service = result.service, hairTextures = textureCount(hairCategory, current.hair_1),
        tattooCatalog = state.tabs.tattoos and tattooCatalog() or {}, tattooCategories = ClothingLocale.labels(Config.TattooCategories), catalog = Config.Catalog[current.sex == 0 and 'male' or 'female'],
        prices = Config.Prices, taxRate = Config.TaxRate, quote = payload().quote, images = Config.Images
    } })
    TriggerEvent('px-clothing:visibility', true)
    openingToken = nil
    CreateThread(function()
        while state do
            Wait(0)
            updateCamera()
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()
            DisablePlayerFiring(PlayerId(), true)
            if not busy and (IsEntityDead(PlayerPedId()) or PlayerPedId() ~= sessionPed) then close(true) end
        end
    end)
end

local function abortSession()
    local token = state and state.token or openingToken
    if token then TriggerServerEvent('px-clothing:cancel', token) end
    if original and sessionPed == PlayerPedId() then
        pcall(loadSkin, original)
        pcall(applyTattoos, originalTattoos)
    end
    state, original, openingToken, opening, busy = nil, nil, nil, false, false
    release()
    SendNUIMessage({ action = 'close' })
end

local function open(shopId)
    if state or opening or busy then return end
    opening = true
    local ok = pcall(openSession, shopId)
    opening = false
    if ok and not state then openingToken = nil end
    if not ok then
        abortSession()
        notify(ClothingLocale.t('The clothing menu could not open. Your controls have been restored.'))
    end
end

RegisterNUICallback('uiError', function(_, cb)
    abortSession()
    notify(ClothingLocale.t('The clothing interface could not open. Your controls have been restored.'))
    cb({ ok = true })
end)

ClothingRuntime.canInteract = function()
    return not state and not opening and not busy and not IsPauseMenuActive()
        and not IsEntityDead(PlayerPedId()) and not IsPedInAnyVehicle(PlayerPedId(), false)
end
ClothingRuntime.open = function(shopId) CreateThread(function() open(shopId) end) end

local function nui(name, handler)
    RegisterNUICallback(name, function(data, cb)
        if not state then cb({ ok = false, error = ClothingLocale.t('The clothing menu is closed.') }); return end
        if busy then cb({ ok = false, error = ClothingLocale.t('Your purchase is being saved.') }); return end
        local ok, result = pcall(function() return handler(type(data) == 'table' and data or {}) end)
        cb(ok and (result or { ok = true }) or { ok = false, error = ClothingLocale.t('Unable to apply that change.') })
    end)
end

nui('close', function() close(true); return { ok = true } end)
nui('category', function(data)
    local category = data.id == 'hair' and hairCategory or Appearance.categories[data.id]
    if not category then return { ok = false, error = ClothingLocale.t('Unknown category.') } end
    if not state.tabs[data.id == 'hair' and 'hair' or 'apparel'] then return { ok = false, error = ClothingLocale.t('This service is unavailable here.') } end
    focusCamera(category.focus)
    return { ok = true, textures = textureCount(category, state.skin[category.key]) }
end)
nui('preview', function(data)
    local definition = Appearance.fields[data.key]
    if not definition or not state.tabs[definition.tab] then return { ok = false, error = ClothingLocale.t('This customization is unavailable.') } end
    local nextSkin = Appearance.copy(state.skin)
    if not Appearance.integer(data.value, definition.min, definition.max) then return { ok = false, error = ClothingLocale.t('Invalid selection.') } end
    nextSkin[data.key] = data.value
    local selectedCategory
    for _, category in ipairs(categories()) do
        if data.key == category.key then
            if data.value > category.max then return { ok = false, error = ClothingLocale.t('This item is unavailable.') } end
            nextSkin[category.texture] = 0
            selectedCategory = category
            if category.id == 'torso' then
                local combo = Config.TopCombinations[nextSkin.sex == 0 and 'male' or 'female'][data.value]
                for key, value in pairs(combo or {}) do if Appearance.fields[key] and Appearance.fields[key].tab == 'apparel' then nextSkin[key] = value end end
            end
        elseif data.key == category.texture then selectedCategory = category end
    end
    if data.key == 'hair_1' then
        if data.value >= GetNumberOfPedDrawableVariations(PlayerPedId(), 2) then return { ok = false, error = ClothingLocale.t('This hairstyle is unavailable.') } end
        nextSkin.hair_2 = 0
    end
    if data.key == 'hair_1' or data.key == 'hair_2' then selectedCategory = hairCategory end
    if data.key == 'hair_2' and data.value >= GetNumberOfPedTextureVariations(PlayerPedId(), 2, nextSkin.hair_1) then return { ok = false, error = ClothingLocale.t('This hair texture is unavailable.') } end
    if definition.tab ~= 'apparel' then
        for _, item in ipairs(fields()) do if item.key == data.key and data.value > item.max then return { ok = false, error = ClothingLocale.t('This option is unavailable.') } end end
    end
    local valid, err = validateClothing(nextSkin)
    if not valid then return { ok = false, error = err } end
    state.skin = nextSkin
    loadSkin(nextSkin)
    applyTattoos(state.tattoos)
    local response = payload()
    if selectedCategory then response.textures = textureCount(selectedCategory, nextSkin[selectedCategory.key]) end
    return response
end)
nui('tattoo', function(data)
    if not state.tabs.tattoos then return { ok = false, error = ClothingLocale.t('Visit a tattoo studio for tattoos.') } end
    if not tattooAvailable(ClothingTattoos.byId[data.id]) then return { ok = false, error = ClothingLocale.t('This tattoo is unavailable on your game build.') } end
    local selected, found = {}, false
    for _, id in ipairs(state.tattoos) do if id == data.id then found = true else selected[#selected + 1] = id end end
    if not found then selected[#selected + 1] = data.id end
    local valid = Appearance.tattoos(selected, state.skin.sex)
    if not valid then return { ok = false, error = ClothingLocale.t('This tattoo is unavailable.') } end
    state.tattoos = valid
    applyTattoos(valid)
    return payload()
end)
nui('tattooPreview', function(data)
    if not state.tabs.tattoos then return { ok = false, error = ClothingLocale.t('Visit a tattoo studio for tattoos.') } end
    if data.id == nil then
        state.tattooCategory = nil
        tattooClothing()
        applyTattoos(state.tattoos)
        return { ok = true }
    end
    local tattoo = ClothingTattoos.byId[data.id]
    if not tattooAvailable(tattoo) then return { ok = false, error = ClothingLocale.t('This tattoo is unavailable on your game build.') } end
    local selected, present = Appearance.copy(state.tattoos), false
    for _, id in ipairs(selected) do if id == data.id then present = true end end
    if not present then selected[#selected + 1] = data.id end
    state.tattooCategory = tattoo.category
    local framing = ClothingTattoos.categories[tattoo.category] or ClothingTattoos.categories.torso
    focusCamera(framing.focus)
    cameraGoal.angle = (-savedHeading + framing.angle) % 360
    tattooClothing()
    applyTattoos(selected)
    return { ok = true }
end)
nui('tattooClothing', function()
    if not state.tabs.tattoos then return { ok = false, error = ClothingLocale.t('Visit a tattoo studio for tattoos.') } end
    state.tattooPreview = not state.tattooPreview
    tattooClothing()
    return { ok = true, revealed = state.tattooPreview }
end)
nui('outfit', function(data)
    local token = state.token
    local result = rpc('outfit', { token = token, id = data.id })
    if not state or state.token ~= token then return { ok = false, error = ClothingLocale.t('The menu has closed.') } end
    if not result.ok then return result end
    local nextSkin = Appearance.clothes(state.skin, result.baseline)
    local valid, err = validateClothing(nextSkin)
    if not valid then close(true); notify(err); return { ok = false, error = err } end
    state.baseline = result.baseline
    state.skin = nextSkin
    loadSkin(nextSkin)
    applyTattoos(state.tattoos)
    local response = payload()
    response.baseline = state.baseline
    return response
end)
nui('deleteOutfit', function(data) return rpc('deleteOutfit', { token = state.token, id = data.id }) end)

local function finishPurchase(token, result)
    if not state or token ~= state.token or not result.ok then return end
    busy = false
    loadSkin(result.skin)
    committedTattoos = Appearance.copy(result.tattoos)
    applyTattoos(committedTattoos)
    ClothingClient.committed(result.skin)
    close(false)
    notify(ClothingLocale.t('Appearance saved. Paid $%s.', result.quote.total), 'success')
end
RegisterNetEvent('px-clothing:committed', finishPurchase)

nui('checkout', function(data)
    busy = true
    local token = state.token
    local ok, result = pcall(function()
        return rpc('checkout', { token = token, skin = state.skin, tattoos = state.tattoos, account = data.account, outfitName = data.outfitName })
    end)
    busy = false
    if not ok then return { ok = false, error = ClothingLocale.t('Purchase could not be completed.') } end
    if result.ok then finishPurchase(token, result) end
    return result
end)

nui('camera', function(data)
    if data.token ~= state.token then return end
    if data.focus then focusCamera(data.focus); return end
    if not Appearance.integer(data.sequence, cameraInput.sequence + 1, 2147483647) then return end
    for _, key in ipairs({ 'rotate', 'pan', 'zoom' }) do
        if type(data[key]) ~= 'number' or data[key] ~= data[key] or math.abs(data[key]) > 100000000 then return end
    end
    local rotate, pan, zoom = data.rotate - cameraInput.rotate, data.pan - cameraInput.pan, data.zoom - cameraInput.zoom
    cameraInput = data
    cameraGoal.angle = (cameraGoal.angle + rotate * 0.3) % 360
    if pan ~= 0 then
        cameraGoal.targetZ = math.max(-0.9, math.min(0.9, cameraGoal.targetZ + pan * 0.003))
        cameraGoal.elevation = cameraGoal.targetZ + 0.1
    end
    cameraGoal.distance = math.max(0.55, math.min(4.0, cameraGoal.distance + zoom * 0.0025))
end)

exports('Open', ClothingRuntime.open)
exports('IsOpen', function() return state ~= nil end)
exports('GetTattoos', function() return Appearance.copy(committedTattoos) end)
AddEventHandler('px-clothing:open', ClothingRuntime.open)

local restorePending, tattoosLoaded = true, false
local function restoreTattoos() restorePending = true end
AddEventHandler('px-clothing:playerLoaded', restoreTattoos)
AddEventHandler('playerSpawned', restoreTattoos)
AddEventHandler('skinchanger:modelLoaded', restoreTattoos)
AddEventHandler('px-clothing:playerLogout', function()
    abortSession()
    committedTattoos, tattoosLoaded, restorePending = {}, false, true
end)
CreateThread(function()
    while not ClothingRuntime.stopped do
        if restorePending and not state and not opening and ClothingRuntime.serverReady and ClothingRuntime.playerReady() then
            restorePending = false
            local epoch, ped, revision = ClothingRuntime.epoch, PlayerPedId(), tattooRevision
            local result = tattoosLoaded and { ok = true, tattoos = committedTattoos } or rpc('tattoos')
            if epoch == ClothingRuntime.epoch and revision == tattooRevision and ped == PlayerPedId() and not state and not opening and ClothingRuntime.playerReady() then
                if result.ok then
                    committedTattoos, tattoosLoaded = result.tattoos, true
                    applyTattoos(committedTattoos)
                else restorePending = true end
            else restorePending = true end
        end
        Wait(1000)
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    abortSession()
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)

CreateThread(function()
    if Config.ShowBlips then
        for _, shop in ipairs(Config.Shops) do
            local service = Config.Services[shop.service or 'clothing'] or Config.Services.clothing
            local blip = AddBlipForCoord(shop.x, shop.y, shop.z)
            SetBlipSprite(blip, service.sprite); SetBlipColour(blip, service.color); SetBlipScale(blip, 0.65); SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentString(ClothingLocale.t(shop.label)); EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end)
