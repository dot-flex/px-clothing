ClothingIllenium = {}
local face = {
    nose_1 = 'noseWidth', nose_2 = 'nosePeakHigh', nose_3 = 'nosePeakSize', nose_4 = 'noseBoneHigh', nose_5 = 'nosePeakLowering', nose_6 = 'noseBoneTwist',
    eyebrows_5 = 'eyeBrownHigh', eyebrows_6 = 'eyeBrownForward', cheeks_1 = 'cheeksBoneHigh', cheeks_2 = 'cheeksBoneWidth', cheeks_3 = 'cheeksWidth',
    eye_squint = 'eyesOpening', lip_thickness = 'lipsThickness', jaw_1 = 'jawBoneWidth', jaw_2 = 'jawBoneBackSize', chin_1 = 'chinBoneLowering',
    chin_2 = 'chinBoneLenght', chin_3 = 'chinBoneSize', chin_4 = 'chinHole', neck_thickness = 'neckThickness'
}
ClothingIllenium.overlays = {
    { 'blemishes', 'blemishes' }, { 'beard', 'beard' }, { 'eyebrows', 'eyebrows' }, { 'age', 'ageing' }, { 'makeup', 'makeUp' },
    { 'blush', 'blush' }, { 'complexion', 'complexion' }, { 'sun', 'sunDamage' }, { 'lipstick', 'lipstick' },
    { 'moles', 'moleAndFreckles' }, { 'chest', 'chestHair' }, { 'bodyb', 'bodyBlemishes' }
}
local blend = { mom = 'shapeFirst', dad = 'shapeSecond', grandparents = 'shapeThird', face_md_weight = 'shapeMix', skin_md_weight = 'skinMix', face_g_weight = 'thirdMix' }
local hair = { hair_1 = 'style', hair_2 = 'texture', hair_color_1 = 'color', hair_color_2 = 'highlight' }

function ClothingIllenium.supported(key)
    return key ~= 'bodyb_3' and key ~= 'bodyb_4'
end

function ClothingIllenium.decode(raw)
    if type(raw) ~= 'table' or type(raw.components) ~= 'table' or type(raw.headBlend) ~= 'table' or type(raw.hair) ~= 'table' then return end
    local sex = raw.model == 'mp_m_freemode_01' and 0 or raw.model == 'mp_f_freemode_01' and 1
    if sex == false then return end
    local result = { sex = sex, _appearance = Appearance.copy(raw) }
    local function put(key, value, scale)
        if type(value) ~= 'number' or value ~= value then return end
        local definition = Appearance.fields[key]
        if definition then result[key] = math.max(definition.min, math.min(definition.max, math.floor(value * (scale or 1) + 0.5))) end
    end
    for key, name in pairs(blend) do put(key, raw.headBlend[name], name:find('Mix') and 100 or 1) end
    for key, name in pairs(face) do put(key, (raw.faceFeatures or {})[name], 10) end
    for key, name in pairs(hair) do put(key, raw.hair[name]) end
    put('eye_color', raw.eyeColor)
    for _, mapping in ipairs(ClothingIllenium.overlays) do
        local overlay = (raw.headOverlays or {})[mapping[2]] or {}
        put(mapping[1] .. '_1', overlay.style == 255 and (mapping[1] == 'bodyb' and -1 or 0) or overlay.style)
        put(mapping[1] .. '_2', overlay.style == 255 and 0 or overlay.opacity, 10)
        put(mapping[1] .. '_3', overlay.color)
        if mapping[1] ~= 'bodyb' then put(mapping[1] .. '_4', overlay.secondColor) end
    end
    for _, category in ipairs(Config.Categories) do
        for _, item in ipairs(category.prop and raw.props or raw.components) do
            if (category.prop and item.prop_id or item.component_id) == (category.prop or category.component) then
                put(category.key, item.drawable)
                put(category.texture, math.max(0, item.texture or 0))
                break
            end
        end
    end
    return Appearance.normalize(result)
end

function ClothingIllenium.encode(skin)
    local raw = Appearance.copy(skin._appearance)
    local base = ClothingIllenium.decode(raw)
    if not base then return end
    local function changed(key) return skin[key] ~= nil and skin[key] ~= base[key] end
    raw.faceFeatures, raw.headOverlays, raw.props = raw.faceFeatures or {}, raw.headOverlays or {}, raw.props or {}
    for key, name in pairs(blend) do
        if changed(key) then
            raw.headBlend[name] = skin[key] / (name:find('Mix') and 100 or 1)
            if key == 'mom' then raw.headBlend.skinFirst = skin[key]
            elseif key == 'dad' then raw.headBlend.skinSecond = skin[key]
            elseif key == 'grandparents' then raw.headBlend.skinThird = skin[key] end
        end
    end
    for key, name in pairs(face) do if changed(key) then raw.faceFeatures[name] = skin[key] / 10 end end
    for key, name in pairs(hair) do if changed(key) then raw.hair[name] = skin[key] end end
    if changed('eye_color') then raw.eyeColor = skin.eye_color end
    for _, mapping in ipairs(ClothingIllenium.overlays) do
        local overlay = raw.headOverlays[mapping[2]] or { style = 0, opacity = 0, color = 0, secondColor = 0 }
        for suffix, name in ipairs({ 'style', 'opacity', 'color', 'secondColor' }) do
            local key = mapping[1] .. '_' .. suffix
            if ClothingIllenium.supported(key) and changed(key) then overlay[name] = skin[key] / (suffix == 2 and 10 or 1) end
        end
        if overlay.style == -1 then overlay.style = 255 end
        raw.headOverlays[mapping[2]] = overlay
    end
    for _, category in ipairs(Config.Categories) do
        if changed(category.key) or changed(category.texture) then
            local entries, idKey, id = category.prop and raw.props or raw.components, category.prop and 'prop_id' or 'component_id', category.prop or category.component
            local found
            for _, item in ipairs(entries) do if item[idKey] == id then found = item; break end end
            if not found then found = { [idKey] = id }; entries[#entries + 1] = found end
            found.drawable, found.texture = skin[category.key], skin[category.texture]
        end
    end
    if changed('hair_1') or changed('hair_2') then
        for _, item in ipairs(raw.components) do if item.component_id == 2 then item.drawable, item.texture = skin.hair_1, skin.hair_2 end end
    end
    return raw
end

function ClothingIllenium.tattoos(existing, selected)
    local result = {}
    for zone, entries in pairs(existing or {}) do
        result[zone] = {}
        for _, tattoo in ipairs(entries) do
            local owned = type(tattoo.name) == 'string' and (tattoo.name:sub(1, 12) == 'px-clothing:' or tattoo.name:sub(1, 17) == 'nopixel-clothing:')
            if not owned then result[zone][#result[zone] + 1] = Appearance.copy(tattoo) end
        end
    end
    local zones = { Torso = 'ZONE_TORSO', Head = 'ZONE_HEAD', ['Left arm'] = 'ZONE_LEFT_ARM', ['Right arm'] = 'ZONE_RIGHT_ARM', ['Left leg'] = 'ZONE_LEFT_LEG', ['Right leg'] = 'ZONE_RIGHT_LEG' }
    for _, id in ipairs(selected or {}) do
        local tattoo = ClothingTattoos.byId[id]
        if tattoo then
            local zone = zones[tattoo.zone] or (tattoo.zone and tattoo.zone:match('^ZONE_') and tattoo.zone) or 'ZONE_TORSO'
            result[zone] = result[zone] or {}
            result[zone][#result[zone] + 1] = { name = 'px-clothing:' .. tattoo.id, label = tattoo.label, collection = tattoo.collection, hashMale = tattoo.male or '', hashFemale = tattoo.female or '', zone = zone, opacity = 1.0 }
        end
    end
    return result
end
