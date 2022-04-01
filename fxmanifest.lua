fx_version 'cerulean'
game 'gta5'

author 'Flawws, Flakey, Idris and the Project Sloth team'
description 'EchoRP MDT Rewrite for QBCore'
version '0.9.9'

lua54 'yes'

shared_script 'shared/config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils.lua',
    'server/dbm.lua',
    'server/main.lua'
}
client_scripts{
    'client/main.lua',
    'client/cl_impound.lua'
} 

ui_page 'ui/dashboard.html'

files {
    'ui/img/sasp_badge.png',
    'ui/img/ems_badge.png',
    'ui/img/court.png',
    'ui/img/warrant_pfp.png',
    'ui/img/profile_pic.png',
    'ui/img/not-found.jpg',
    'ui/img/male.png',
    'ui/img/female.png',
    'ui/dashboard.html',
    'ui/dmv.html',
    'ui/bolos.html',
    'ui/incidents.html',
    'ui/penalcode.html',
    'ui/reports.html',
    'ui/warrants.html',
    'ui/app.js',
    'ui/style.css',
}