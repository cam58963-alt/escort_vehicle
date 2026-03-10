fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Escort & Stretcher System - Complete Feature Edition'
version '0.5.0-dev'  -- 開発段階適切バージョン

shared_script 'config.lua'

client_scripts {
    'client/utils.lua',
    'client/main.lua'
}

server_script 'server/main.lua'

-- Export宣言を削除（client側で定義）
-- exports { 'useStretcher' } ← 削除

dependencies {
    'qbx_core',
    'ox_target',
    'ox_inventory',
    'tk_ambulancejob'
}

lua54 'yes'
