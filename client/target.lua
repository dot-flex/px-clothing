local entities, generation, initializing = {}, 0, false

local function cleanup()
    generation = generation + 1
    initializing = false
    for id, entity in pairs(entities) do
        if GetResourceState('ox_target') == 'started' then
            pcall(function() exports.ox_target:removeLocalEntity(entity, { 'px-clothing:shop:' .. id }) end)
        end
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    entities = {}
end

local function setup()
    if initializing or ClothingRuntime.stopped then return end
    initializing = true
    local currentGeneration = generation
    CreateThread(function()
        while GetResourceState('ox_target') ~= 'started' do
            if generation ~= currentGeneration or ClothingRuntime.stopped then return end
            Wait(500)
        end
        for id, shop in ipairs(Config.Shops) do
            if generation ~= currentGeneration or ClothingRuntime.stopped then return end
            if not entities[id] then
                local target = shop.target or {}
                local model = joaat(target.model or Config.Target.model)
                local isObject = target.type == 'object'
                if IsModelInCdimage(model) and IsModelValid(model) and (isObject or IsModelAPed(model)) then
                    RequestModel(model)
                    local deadline = GetGameTimer() + Config.Target.modelTimeout
                    while not HasModelLoaded(model) and GetGameTimer() < deadline and generation == currentGeneration do Wait(50) end
                    if generation ~= currentGeneration or ClothingRuntime.stopped then SetModelAsNoLongerNeeded(model); return end
                    if HasModelLoaded(model) then
                        local x, y, z = target.x or shop.x, target.y or shop.y, target.z or (shop.z - 1.0)
                        local heading = target.heading or shop.heading or 0.0
                        local entity = isObject and CreateObjectNoOffset(model, x, y, z, false, false, false)
                            or CreatePed(4, model, x, y, z, heading, false, false)
                        if entity ~= 0 then
                            entities[id] = entity
                            SetEntityAsMissionEntity(entity, true, true)
                            SetEntityHeading(entity, heading)
                            FreezeEntityPosition(entity, true)
                            SetEntityInvincible(entity, true)
                            if not isObject then
                                SetBlockingOfNonTemporaryEvents(entity, true)
                                local scenario = target.scenario
                                if scenario == nil then scenario = Config.Target.scenario end
                                if scenario then TaskStartScenarioInPlace(entity, scenario, 0, true) end
                            end
                            local ok = pcall(function()
                                exports.ox_target:addLocalEntity(entity, {{
                                    name = 'px-clothing:shop:' .. id,
                                    label = ClothingLocale.t(target.label or Config.Target.label),
                                    icon = target.icon or Config.Target.icon,
                                    distance = target.distance or Config.Target.distance,
                                    canInteract = function() return ClothingRuntime.canInteract() end,
                                    onSelect = function() ClothingRuntime.open(id) end
                                }})
                            end)
                            if not ok then
                                DeleteEntity(entity); entities[id] = nil
                            end
                        end
                    end
                    SetModelAsNoLongerNeeded(model)
                end
            end
        end
        if generation == currentGeneration then initializing = false end
    end)
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'ox_target' or resource == GetCurrentResourceName() then setup() end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() or resource == 'ox_target' then cleanup() end
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == 'ox_target' then cleanup() end
end)
setup()
