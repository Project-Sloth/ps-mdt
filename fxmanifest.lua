fx_version 'cerulean'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
game 'gta5'

name 'ps-mdt'
author "Project Sloth Development Team"
description 'Project Sloth MDT'
version '3.0.0'

ui_page 'web/dist/index.html'

dependencies {
  'ps_lib',
  'oxmysql',
  'ox_lib'
}

shared_scripts {
  'config.lua',
  '@ox_lib/init.lua'
}

client_script {
  'client/**.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/**.lua'
}

files {
  'web/dist/index.html',
  'web/dist/**/*'
}

data_file 'DLC_ITYP_REQUEST' 'stream/ps-mdt.ytyp'

-- Server convars (set in server.cfg):
-- set ps_mdt_fivemanage_key_images "YOUR_FIVEMANAGE_IMAGES_API_KEY"
-- set ps_mdt_fivemanage_key_logs   "YOUR_FIVEMANAGE_LOGS_API_KEY"
convar_category 'PS-MDT' {
  'Settings for ps-mdt resource',
  {
    { 'FiveManage Images API Key', 'ps_mdt_fivemanage_key_images', 'CV_STRING', '' },
    { 'FiveManage Logs API Key',   'ps_mdt_fivemanage_key_logs',   'CV_STRING', '' },
  }
}
