fx_version 'cerulean'
game 'gta5'

author 'Masked'
description 'px-clothing - ESX, QBCore and QBox clothing, appearance and wardrobe'
version '1.0.0'

dependencies { 'oxmysql', 'ox_lib', 'ox_target', '/onesync' }
shared_scripts { 'config.lua', 'locales/en.lua', 'locales/sr.lua', 'locales/de.lua', 'locales/es.lua', 'locales/fr.lua', 'shared/locale.lua', 'shared/tattoos.lua', 'shared/appearance.lua', 'shared/framework.lua', 'shared/illenium.lua' }
client_scripts { 'client/notifications.lua', 'client/bridge.lua', 'client/runtime.lua', 'client/main.lua', 'client/target.lua' }
server_scripts { 'server/protection.lua', 'server/version.lua', '@oxmysql/lib/MySQL.lua', 'server/bridge.lua', 'server/main.lua' }
ui_page 'web/index.html'
files { 'data/tattoos.json', 'web/index.html', 'web/style.css', 'web/app.js', 'web/model.js', 'web/icons.js', 'web/thumbnails.js', 'web/tattoos.js', 'web/locale.js', 'web/assets/**/*' }
