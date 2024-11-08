fx_version 'cerulean'
game 'gta5'
lua54 'on'

author 'Glades'
description 'Bundle Nest event for HRS Zombies'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'spawn.lua'  
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/CircleZone.lua',
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}

dependencies {
    'qb-core',
    'PolyZone',
    'ox_lib',
    'hrs_zombies_V2'
}
