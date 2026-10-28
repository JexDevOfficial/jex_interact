fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'jex_interact'
author 'Jex'
version '1.0.0'
description 'Hold a key, pick what you want, let go.'

client_scripts {
    'config.lua',
    'client/init.lua',
    'client/registry.lua',
    'client/scan.lua',
    'client/render.lua',
    'client/api.lua',
    'client/compat/ox_target.lua',
    'client/dev.lua',
}
