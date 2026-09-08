Config = {}
Config.Framework = 'auto' -- auto, esx, qb or qbox. Auto checks qbx_core before es_extended and qb-core.
Config.AppearanceResource = 'illenium-appearance' -- Required on QB/QBox. ESX uses skinchanger and esx_skin instead.
Config.Locale = 'en'
Config.Translations = {}
Config.VersionCheck = {
    enabled = true,
    repository = 'dot-flex/px-clothing',
    intervalHours = 24,
    timeoutSeconds = 10
}
Config.ServerDistance = 6.0
Config.Target = {
    model = 's_f_y_shop_low',
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    distance = 2.0,
    label = 'Browse clothing',
    icon = 'fa-solid fa-door-open',
    modelTimeout = 10000
}
Config.SessionSeconds = 1800
Config.TaxRate = 0.0
Config.MaxOutfits = 30
Config.ShowBlips = true
Config.Notifications = {
    title = 'Clothing',
    position = 'top',
    duration = 4200
}
Config.HudVisibilityEvent = 'masked-hud:setVisible'
Config.EnabledTabs = { body = true, face = true, overlays = true, hair = true, apparel = true, tattoos = true }
Config.Prices = { body = 250, face = 250, overlays = 50, hair = 75, tattoos = 100 }
Config.Services = {
    clothing = { tabs = { apparel = true, hair = true, overlays = true }, sprite = 73, color = 4 },
    tattoo = { tabs = { tattoos = true }, sprite = 75, color = 1 },
    hospital = { tabs = { body = true, face = true }, sprite = 61, color = 3 }
}
Config.Shops = {
    { label = 'Clothing', x = 72.3, y = -1399.1, z = 29.4 },
    { label = 'Clothing', x = -703.8, y = -152.3, z = 37.4 },
    { label = 'Clothing', x = -167.9, y = -299.0, z = 39.7 },
    { label = 'Clothing', x = 428.7, y = -800.1, z = 29.5 },
    { label = 'Clothing', x = -829.4, y = -1073.7, z = 11.3 },
    { label = 'Clothing', x = -1447.8, y = -242.5, z = 49.8 },
    { label = 'Clothing', x = 11.6, y = 6514.2, z = 31.9 },
    { label = 'Clothing', x = 123.6, y = -219.4, z = 54.6 },
    { label = 'Clothing', x = 1696.3, y = 4829.3, z = 42.1 },
    { label = 'Clothing', x = 618.1, y = 2759.6, z = 42.1 },
    { label = 'Clothing', x = 1190.6, y = 2713.4, z = 38.2 },
    { label = 'Clothing', x = -1193.4, y = -772.3, z = 17.3 },
    { label = 'Clothing', x = -3172.5, y = 1048.1, z = 20.9 },
    { label = 'Clothing', x = -1108.4, y = 2708.9, z = 19.1 }, 
    { label = 'Tattoo Studio', service = 'tattoo', x = 1322.6, y = -1651.9, z = 52.3, heading = 130.0,
        target = { model = 'u_m_y_tattoo_01', label = 'Browse tattoos', icon = 'fa-solid fa-pen-nib', scenario = false } },
    { label = 'Hospital Appearance Clinic', service = 'hospital', x = 288.3579, y = -570.0780, z = 43.1638, heading = 68.8554,
        target = { model = 's_m_m_doctor_01', label = 'Face & body consultation', icon = 'fa-solid fa-user-doctor', scenario = false } },
    { label = 'Tattoo Studio - Vespucci', service = 'tattoo', x = -1153.6, y = -1425.6, z = 4.95, heading = 125.0,
        target = { model = 'u_m_y_tattoo_01', label = 'Browse tattoos', icon = 'fa-solid fa-pen-nib', scenario = false } },
    { label = 'Tattoo Studio - Hawick', service = 'tattoo', x = 322.1, y = 180.4, z = 103.59, heading = 160.0,
        target = { model = 'u_m_y_tattoo_01', label = 'Browse tattoos', icon = 'fa-solid fa-pen-nib', scenario = false } },
    { label = 'Tattoo Studio - Chumash', service = 'tattoo', x = -3170.0, y = 1075.0, z = 20.83, heading = 245.0,
        target = { model = 'u_m_y_tattoo_01', label = 'Browse tattoos', icon = 'fa-solid fa-pen-nib', scenario = false } },
    { label = 'Tattoo Studio - Sandy Shores', service = 'tattoo', x = 1864.6, y = 3747.7, z = 33.03, heading = 25.0,
        target = { model = 'u_m_y_tattoo_01', label = 'Browse tattoos', icon = 'fa-solid fa-pen-nib', scenario = false } },
    { label = 'Tattoo Studio - Paleto Bay', service = 'tattoo', x = -293.7, y = 6200.0, z = 31.49, heading = 225.0,
        target = { model = 'u_m_y_tattoo_01', label = 'Browse tattoos', icon = 'fa-solid fa-pen-nib', scenario = false } }
}

Config.Categories = {
    { id = 'torso', label = 'Tops', group = 'clothing', icon = 'jacket', key = 'torso_1', texture = 'torso_2', component = 11, price = 100, focus = 'body' },
    { id = 'pants', label = 'Pants', group = 'clothing', icon = 'pants', key = 'pants_1', texture = 'pants_2', component = 4, price = 75, focus = 'legs' },
    { id = 'shoes', label = 'Shoes', group = 'clothing', icon = 'shoe', key = 'shoes_1', texture = 'shoes_2', component = 6, price = 50, focus = 'feet' },
    { id = 'undershirts', label = 'Undershirts', group = 'clothing', icon = 'undershirt', key = 'tshirt_1', texture = 'tshirt_2', component = 8, price = 50, focus = 'body' },
    { id = 'arms', label = 'Arms / gloves', group = 'hands', icon = 'hand', key = 'arms', texture = 'arms_2', component = 3, price = 0, focus = 'body' },
    { id = 'neckwear', label = 'Neckwear', group = 'upper', icon = 'chain', key = 'chain_1', texture = 'chain_2', component = 7, price = 40, focus = 'body' },
    { id = 'vests', label = 'Vests', group = 'upper', icon = 'vest', key = 'bproof_1', texture = 'bproof_2', component = 9, price = 100, focus = 'body' },
    { id = 'bags', label = 'Bags', group = 'upper', icon = 'bag', key = 'bags_1', texture = 'bags_2', component = 5, price = 60, focus = 'body' },
    { id = 'decals', label = 'Decals', group = 'upper', icon = 'grid', key = 'decals_1', texture = 'decals_2', component = 10, price = 20, focus = 'body' },
    { id = 'watches', label = 'Watches', group = 'hands', icon = 'watch', key = 'watches_1', texture = 'watches_2', prop = 6, price = 75, focus = 'body' },
    { id = 'bracelets', label = 'Bracelets', group = 'hands', icon = 'bracelet', key = 'bracelets_1', texture = 'bracelets_2', prop = 7, price = 40, focus = 'body' },
    { id = 'hats', label = 'Hats', group = 'head', icon = 'hat', key = 'helmet_1', texture = 'helmet_2', prop = 0, price = 35, focus = 'head' },
    { id = 'glasses', label = 'Glasses', group = 'head', icon = 'glasses', key = 'glasses_1', texture = 'glasses_2', prop = 1, price = 30, focus = 'head' },
    { id = 'ears', label = 'Earrings', group = 'head', icon = 'ears', key = 'ears_1', texture = 'ears_2', prop = 2, price = 25, focus = 'head' },
    { id = 'masks', label = 'Masks', group = 'head', icon = 'mask', key = 'mask_1', texture = 'mask_2', component = 1, price = 40, focus = 'head' }
}

Config.Images = {
    enabled = true,
    urlTemplate = 'https://cloth.reizen.one/{gender}/{part}/trimmed/{drawable}_{texture}.webp'
}
Config.TattooImages = {
    enabled = true,
    sources = {
        gtahash = 'https://cdn.gtahash.com/tattoos/{name}/{name}.webp',
        nation = 'https://raw.githubusercontent.com/Kary-Dev-tools/Nations_imagems/main/nation_tattoos/{path}'
    }
}
Config.Catalog = { male = {}, female = {} }

Config.TopCombinations = { male = {}, female = {} }

Config.TattooPreview = {
    male = { torso_1 = 15, torso_2 = 0, tshirt_1 = 15, tshirt_2 = 0, arms = 15, arms_2 = 0 },
    female = { torso_1 = 15, torso_2 = 0, tshirt_1 = 15, tshirt_2 = 0, arms = 15, arms_2 = 0 }
}
Config.TattooLegPreview = {
    male = { pants_1 = 14, pants_2 = 0, shoes_1 = 34, shoes_2 = 0 },
    female = { pants_1 = 15, pants_2 = 0, shoes_1 = 35, shoes_2 = 0 }
}
Config.Tattoos = {}
Config.TattooCategories = {
    { id = 'left_arm', label = 'Left arm', icon = 'hand-point-left', focus = 'body', angle = 65 },
    { id = 'right_arm', label = 'Right arm', icon = 'hand-point-right', focus = 'body', angle = -65 },
    { id = 'left_leg', label = 'Left leg', icon = 'left-long', focus = 'legs', angle = 55 },
    { id = 'right_leg', label = 'Right leg', icon = 'right-long', focus = 'legs', angle = -55 },
    { id = 'chest', label = 'Chest', icon = 'heart-pulse', focus = 'body', angle = 0 },
    { id = 'back', label = 'Back', icon = 'person-arrow-down-to-line', focus = 'body', angle = 180 },
    { id = 'head', label = 'Head / face', icon = 'user', focus = 'head', angle = 0 },
    { id = 'neck', label = 'Neck', icon = 'user-tag', focus = 'head', angle = 80 },
    { id = 'torso', label = 'Torso', icon = 'person-rays', focus = 'body', angle = 0 },
    { id = 'feet', label = 'Feet', icon = 'socks', focus = 'feet', angle = 0 }
}
