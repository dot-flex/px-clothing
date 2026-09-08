local notificationIcons = {
    info = 'circle-info', success = 'circle-check', warning = 'triangle-exclamation', error = 'circle-xmark'
}
local lastMessage, lastType, lastTime

function ClothingNotify(message, kind)
    if type(message) ~= 'string' or message == '' then return false end
    kind = notificationIcons[kind] and kind or 'error'
    message = ClothingLocale.t(message):sub(1, 500)
    local now = GetGameTimer()
    if message == lastMessage and kind == lastType and lastTime and now - lastTime < 1000 then return true end
    local settings = Config.Notifications
    local ok = pcall(function()
        exports.ox_lib:notify({
            id = 'px-clothing:' .. kind .. ':' .. message,
            title = ClothingLocale.t(settings.title),
            description = message,
            type = kind,
            duration = settings.duration,
            position = settings.position,
            icon = notificationIcons[kind]
        })
    end)
    if ok then lastMessage, lastType, lastTime = message, kind, now end
    return ok
end

RegisterNUICallback('notify', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = false }); return end
    cb({ ok = ClothingNotify(data.message, data.type) })
end)
