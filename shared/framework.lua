ClothingFramework = {}
local resources = { esx = 'es_extended', qb = 'qb-core', qbox = 'qbx_core' }

function ClothingFramework.name()
    if Config.Framework ~= 'auto' then
        local resource = resources[Config.Framework]
        return resource and GetResourceState(resource) == 'started' and Config.Framework or nil
    end
    for _, name in ipairs({ 'qbox', 'esx', 'qb' }) do
        if GetResourceState(resources[name]) == 'started' then return name end
    end
end

function ClothingFramework.dependency(resource)
    return resource == 'es_extended' or resource == 'qb-core' or resource == 'qbx_core'
        or resource == 'skinchanger' or resource == 'esx_skin' or resource == Config.AppearanceResource
end
