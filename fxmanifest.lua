fx_version 'cerulean'
game 'gta5'

author 'Flawws, Flakey, Idris and the Project Sloth team'
description 'EchoRP MDT Rewrite for QBCore'
version '2.3.9'

lua54 'yes'

shared_scripts {
    'shared/*.lua',
    'bridge/shared.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/**/*server.lua',
    'server/utils.lua',
    'server/dbm.lua',
    'server/main.lua'
}
client_scripts{
    'client/main.lua',
    'bridge/**/*client.lua',
    'client/cl_impound.lua',
    'client/cl_mugshot.lua'
} 

ui_page 'ui/dashboard.html'

files {
    'ui/img/*.png',
    'ui/img/*.webp',
    'ui/dashboard.html',
    'ui/app.js',
    'ui/style.css',
}
