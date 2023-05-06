fx_version 'cerulean'
game 'gta5'

description 'Circuit Breaker Minigame but in Lua, original source: https://github.com/TimothyDexter/FiveM-CircuitBreakerMinigame'
repository 'https://github.com/BerkieBb/CircuitBreakerMinigame_lua'

client_scripts {
    'init.lua',
    'globals.lua',
    'map.lua',
    'portlights.lua',
    'helper.lua',
    'generic.lua',
    'cursor.lua',
    'circuit.lua'
}

files {
    'class.lua'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'