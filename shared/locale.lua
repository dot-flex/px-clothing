ClothingLocale = {}
local language = ClothingLocales[Config.Locale] and Config.Locale or 'en'
local dictionary = {}
for key, value in pairs(ClothingLocales.en) do dictionary[key] = value end
for key, value in pairs(ClothingLocales[language]) do dictionary[key] = value end
for key, value in pairs((Config.Translations or {})[language] or {}) do
    if type(key) == 'string' and type(value) == 'string' then dictionary[key] = value end
end
ClothingLocale.language = language
ClothingLocale.dictionary = dictionary
function ClothingLocale.t(key, ...)
    local text = dictionary[key] or key
    if select('#', ...) == 0 then return text end
    local ok, result = pcall(string.format, text, ...)
    if ok then return result end
    ok, result = pcall(string.format, ClothingLocales.en[key] or key, ...)
    return ok and result or key
end
function ClothingLocale.labels(entries)
    local result = {}
    for index, entry in ipairs(entries) do
        local item = {}
        for key, value in pairs(entry) do item[key] = key == 'label' and ClothingLocale.t(value) or value end
        result[index] = item
    end
    return result
end
