ClothingTattoos = { byId = {}, categories = {} }
local catalog = json.decode(LoadResourceFile(GetCurrentResourceName(), 'data/tattoos.json'))
local positions = {}
for index, tattoo in ipairs(catalog) do positions[tattoo.id] = index end
for _, tattoo in ipairs(Config.Tattoos) do
    local index = positions[tattoo.id] or #catalog + 1
    catalog[index] = tattoo
    positions[tattoo.id] = index
end
Config.Tattoos = catalog
for _, tattoo in ipairs(catalog) do ClothingTattoos.byId[tattoo.id] = tattoo end
for _, category in ipairs(Config.TattooCategories) do ClothingTattoos.categories[category.id] = category end

function ClothingTattoos.id(id, sex)
    if id == 'beach_back' then return sex == 0 and 'mpbeach_overlays:mp_bea_m_back_000' or 'mpbeach_overlays:mp_bea_f_back_000' end
    if id == 'beach_chest' then return sex == 0 and 'mpbeach_overlays:mp_bea_m_chest_000' or 'mpbeach_overlays:mp_bea_f_chest_000' end
    return id
end

function ClothingTattoos.image(tattoo)
    local settings = Config.TattooImages
    if type(settings) ~= 'table' or settings.enabled == false then return nil end
    local image = tattoo.image
    if type(image) == 'string' then return image end
    if type(image) ~= 'table' or type(settings.sources) ~= 'table' then return nil end
    local template = settings.sources[image.source]
    if type(template) ~= 'string' or not template:match('^https://') then return nil end
    local valid = true
    local url = template:gsub('{([%w_]+)}', function(key)
        local value = image[key]
        if type(value) ~= 'string' or not value:match('^[%w_./%-]+$') or value:find('..', 1, true) then
            valid = false
            return ''
        end
        return value
    end)
    if not valid or url:find('[%s{}]') then return nil end
    return url
end
