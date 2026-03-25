-- config.lua v0.6.5
Config = {}
Config.Debug = false  -- 開発中はtrue、本番ではfalse
Config.Version = '0.6.5'

-- Job制限設定
Config.JobRestriction = {
    enabled = true,
    allowedJobs = { 'ambulance' },
    allowOffDuty = false,
}

-- ストレッチャー設定
Config.Stretcher = {
    -- OX Inventory統合
    itemName = 'stretcher',
    itemLabel = 'ストレッチャー',
    itemWeight = 5000,
    
    -- プロップ設定
    model = `prop_stretcher`,
    
    -- 【ユーザー指定値】持つ位置の微調整
    carryOffset = {
        x = 0.0,    -- 中央
        y = -1.1,   -- 後方1.1m（押してる感じ）
        z = -0.5,   -- 腰の高さ
        rotX = 15.0, -- X軸15度傾斜
        rotY = 0.0,
        rotZ = 0.0, -- プレイヤーと同じ向き
    },
    
    -- 対応車両
    vehicles = {
        [`ambulance`] = true,
        [`emsnspeedo`] = true,
    },
    
    -- 距離設定（範囲拡大）
    interactionDistance = 10.0,  -- 車両判定範囲拡大
    placeDistance = 2.0,
    patientDistance = 3.0,
    
    -- アニメーション
    pushAnim = { dict = 'anim@heists@box_carry@', name = 'idle' },
    patientAnim = { dict = 'anim@gangops@morgue@table@', name = 'body_search' },
    patientOffset = {
        x = 0.0,   -- 左右（＋で右、－で左）
        y = 0.0,   -- 前後（＋で前、－で後ろ）
        z = 1.05,   -- 高さ（＋で上、－で下）← 埋まる場合はここを上げる
    },
}

-- キーバインド設定（プレイヤーがF5で変更可能）
Config.DefaultKeys = {
    place = 'G',      -- 設置/回収
    interact = 'E',   -- 患者を乗せる
    store = 'X',      -- 完全収納（新機能）
}

-- 通知メッセージ
Config.Notifications = {
    stretcherDeployed = 'ストレッチャーを展開しました',
    stretcherPlaced = 'ストレッチャーを設置しました',
    stretcherPickedUp = 'ストレッチャーを持ちました',
    stretcherStored = 'ストレッチャーを収納しました',
    patientPlaced = '患者をストレッチャーに乗せました',
    patientRemoved = '患者をストレッチャーから降ろしました',
    patientInVehicle = '患者を車両に搬送しました',
    noStretcher = 'ストレッチャーを持っていません',
    noPatient = '近くに患者がいません',
    alreadyHasPatient = '既に患者が乗っています',
    patientOnStretcher = '患者が乗っているため収納できません',
    inventoryFull = 'インベントリがいっぱいです',
    noFreeSeats = '車両に空きがありません',
}

-- ヘルパー関数
function Config.IsJobAllowed(jobName)
    if not Config.JobRestriction.enabled then return true end
    if not jobName then return false end
    jobName = string.lower(jobName)
    for _, allowedJob in ipairs(Config.JobRestriction.allowedJobs) do
        if string.lower(allowedJob) == jobName then return true end
    end
    return false
end

function Config.IsStretcherVehicle(vehicleModel)
    return Config.Stretcher.vehicles[vehicleModel] == true
end
