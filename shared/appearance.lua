Appearance = { fields = {}, categories = {} }

local function field(key, label, tab, min, max)
    Appearance.fields[key] = { key = key, label = ClothingLocale.t(label), tab = tab, min = min, max = max }
end

field('mom', 'Mother', 'body', 0, 45)
field('dad', 'Father', 'body', 0, 44)
field('grandparents', 'Grandparent', 'body', 0, 45)
field('face_md_weight', 'Resemblance', 'body', 0, 100)
field('face_g_weight', 'Grandparent influence', 'body', 0, 100)
field('skin_md_weight', 'Skin tone', 'body', 0, 100)
field('eye_color', 'Eye color', 'body', 0, 31)

local face = {
    { 'nose_1', 'Nose width' }, { 'nose_2', 'Nose height' }, { 'nose_3', 'Nose length' },
    { 'nose_4', 'Nose bridge' }, { 'nose_5', 'Nose tip' }, { 'nose_6', 'Nose shift' },
    { 'eyebrows_5', 'Brow height' }, { 'eyebrows_6', 'Brow depth' },
    { 'cheeks_1', 'Cheekbone height' }, { 'cheeks_2', 'Cheekbone width' }, { 'cheeks_3', 'Cheek fullness' },
    { 'eye_squint', 'Eye opening' }, { 'lip_thickness', 'Lip fullness' },
    { 'jaw_1', 'Jaw width' }, { 'jaw_2', 'Jaw length' }, { 'chin_1', 'Chin height' },
    { 'chin_2', 'Chin length' }, { 'chin_3', 'Chin width' }, { 'chin_4', 'Chin dimple' },
    { 'neck_thickness', 'Neck thickness' }
}
for _, entry in ipairs(face) do field(entry[1], entry[2], 'face', -10, 10) end
field('hair_1', 'Hairstyle', 'hair', 0, 4095)
field('hair_2', 'Hair texture', 'hair', 0, 255)
field('hair_color_1', 'Hair color', 'hair', 0, 63)
field('hair_color_2', 'Highlights', 'hair', 0, 63)
local overlays = {
    { 'blemishes', 'Blemishes', 23 }, { 'beard', 'Facial hair', 28, 'hair', true },
    { 'eyebrows', 'Eyebrows', 33, 'hair', true }, { 'age', 'Ageing', 14 },
    { 'makeup', 'Makeup', 74, 'overlays', true }, { 'blush', 'Blush', 32, 'overlays', true },
    { 'complexion', 'Complexion', 11 }, { 'sun', 'Sun damage', 10 },
    { 'lipstick', 'Lipstick', 9, 'overlays', true }, { 'moles', 'Freckles', 17 },
    { 'chest', 'Chest hair', 16, 'overlays', true }, { 'bodyb', 'Body blemishes', 11 }
}
for _, entry in ipairs(overlays) do
    local tab = entry[4] or 'overlays'
    field(entry[1] .. '_1', entry[2] .. ' style', tab, entry[1] == 'bodyb' and -1 or 0, entry[3])
    field(entry[1] .. '_2', entry[2] .. ' opacity', tab, 0, 10)
    if entry[5] then
        field(entry[1] .. '_3', entry[2] .. ' color', tab, 0, 63)
        if entry[1] ~= 'chest' and entry[1] ~= 'blush' then
            field(entry[1] .. '_4', entry[2] .. ' secondary color', tab, 0, 63)
        end
    end
end
field('bodyb_3', 'Additional body blemishes', 'overlays', -1, 11)
field('bodyb_4', 'Additional blemish opacity', 'overlays', 0, 10)

for _, category in ipairs(Config.Categories) do
    Appearance.categories[category.id] = category
    field(category.key, category.label, 'apparel', category.prop and -1 or 0, 4095)
    field(category.texture, category.label .. ' texture', 'apparel', 0, 255)
end

function Appearance.copy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = Appearance.copy(child) end
    return copy
end

function Appearance.integer(value, min, max)
    return type(value) == 'number' and value == value and value % 1 == 0 and value >= min and value <= max
end

function Appearance.normalize(skin)
    local result = Appearance.copy(skin)
    for key in pairs(Appearance.fields) do
        if result[key] == nil then result[key] = 0 end
    end
    for _, key in ipairs({ 'face_md_weight', 'skin_md_weight' }) do if skin[key] == nil then result[key] = 50 end end
    for _, key in ipairs({ 'bodyb_1', 'bodyb_3' }) do if skin[key] == nil then result[key] = -1 end end
    for _, category in ipairs(Config.Categories) do
        if category.prop and skin[category.key] == nil then result[category.key] = -1 end
    end
    return result
end

function Appearance.shopTabs(shop)
    local service = Config.Services[shop.service or 'clothing']
    local tabs = {}
    for tab, enabled in pairs(Config.EnabledTabs) do tabs[tab] = enabled == true and service ~= nil and service.tabs[tab] == true end
    return tabs
end

function Appearance.sanitize(skin, baseline, tabs)
    if type(skin) ~= 'table' or type(baseline) ~= 'table' then return nil, ClothingLocale.t('Invalid appearance.') end
    if skin.sex ~= baseline.sex then return nil, ClothingLocale.t('Changing character model is not supported.') end
    local result = Appearance.copy(baseline)
    for key, definition in pairs(Appearance.fields) do
        local value = skin[key]
        if value ~= nil then
            if not Appearance.integer(value, definition.min, definition.max) then return nil, ClothingLocale.t('Invalid %s.', definition.label) end
            if not (tabs or Config.EnabledTabs)[definition.tab] and value ~= baseline[key] then return nil, ClothingLocale.t('This customization is unavailable at this location.') end
            result[key] = value
        end
    end
    return result
end

function Appearance.tattoos(value, sex)
    if type(value) ~= 'table' or #value > #Config.Tattoos then return nil end
    local seen, result = {}, {}
    for key, id in pairs(value) do
        if not Appearance.integer(key, 1, #value) or type(id) ~= 'string' then return nil end
        id = ClothingTattoos.id(id, sex)
        local tattoo = ClothingTattoos.byId[id]
        if not tattoo or not tattoo[sex == 0 and 'male' or 'female'] or seen[id] then return nil end
        seen[id] = true
        result[#result + 1] = id
    end
    table.sort(result)
    return result
end

function Appearance.quote(base, skin, oldTattoos, tattoos)
    local subtotal, lines, changedTabs = 0, {}, {}
    local function add(label, amount)
        subtotal = subtotal + amount
        lines[#lines + 1] = { label = label, amount = amount }
    end
    for _, category in ipairs(Config.Categories) do
        if base[category.key] ~= skin[category.key] or base[category.texture] ~= skin[category.texture] then add(ClothingLocale.t(category.label), category.price) end
    end
    for key, definition in pairs(Appearance.fields) do
        if definition.tab ~= 'apparel' and base[key] ~= skin[key] then changedTabs[definition.tab] = true end
    end
    for _, tab in ipairs({ 'body', 'face', 'overlays', 'hair' }) do
        if changedTabs[tab] then
            local labels = { body = ClothingLocale.t('Face & body'), face = ClothingLocale.t('Face adjustments'), overlays = ClothingLocale.t('Overlays'), hair = ClothingLocale.t('Hair') }
            add(labels[tab], Config.Prices[tab] or 0)
        end
    end
    local owned = {}
    for _, id in ipairs(oldTattoos or {}) do owned[id] = true end
    local selected = {}
    for _, id in ipairs(tattoos or {}) do selected[id] = true end
    for _, tattoo in ipairs(Config.Tattoos) do
        if selected[tattoo.id] and not owned[tattoo.id] then add(tattoo.label, tattoo.price or Config.Prices.tattoos) end
    end
    local tax = math.floor(subtotal * Config.TaxRate + 0.5)
    return { subtotal = subtotal, tax = tax, total = subtotal + tax, lines = lines }
end

function Appearance.clothes(skin, outfit)
    local result = Appearance.copy(skin)
    for _, category in ipairs(Config.Categories) do
        for _, key in ipairs({ category.key, category.texture }) do
            if outfit[key] ~= nil then result[key] = outfit[key] end
        end
    end
    return result
end
