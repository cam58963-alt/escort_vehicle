fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'otonashi'
description 'EMS自販機'
version '2.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
}
