fx_version 'cerulean'
game 'gta5'

author 'otonashi'
description 'ストレッチャーシステム'
version '0.6.5'

shared_script 'config.lua'

client_scripts {
    'client/cl_utils.lua',       -- ユーティリティ（最初に読み込み）
    'client/cl_state.lua',       -- 共有状態管理
    'client/cl_stretcher.lua',   -- ストレッチャー展開・設置・回収
    'client/cl_vehicle.lua',     -- 車両乗車処理
    'client/cl_target.lua',      -- ox_target 統合
    'client/cl_commands.lua',    -- コマンド・キーバインド・HUD・イベント
}

server_scripts {
    'server/sv_utils.lua',       -- サーバーユーティリティ
    'server/sv_inventory.lua',   -- インベントリ管理
    'server/sv_patient.lua',     -- 患者管理
}

dependencies {
    'qbx_core',
    'ox_target',
    'ox_inventory',
}

lua54 'yes'
