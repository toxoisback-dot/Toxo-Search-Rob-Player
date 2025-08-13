fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'ToxoIsHere'
description 'Search/Rob Player Script'
version '1.0.0'

dependencies {
    'ox_inventory',
    'ox_lib'
}

shared_script '@ox_lib/init.lua'
client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}


