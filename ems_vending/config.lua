Config = {}

-- ============================================
-- デバッグ設定
-- ============================================
Config.Debug = false

-- ============================================
-- EMS基本設定
-- ============================================
Config.JobName = 'ambulance'
Config.BankAccountId = 'ambulance'
Config.MaxEMSForPublicSale = 1
-- ★追加: 廃棄権限設定
Config.MinGradeForDiscard = 4  -- Grade 3以上のみ廃棄可能
-- ============================================
-- ブリップ動的制御設定
-- ============================================
Config.BlipControl = {
    enabled = true,
    updateInterval = 30000,
    hideEmptyForCivilians = true,
    
    colors = {
        available = 2,      -- 緑：購入可能
        emsOnly = 3,        -- 青：EMS専用時間
        outOfStock = 1,     -- 赤：在庫切れ（EMS向け）
        offline = 4         -- グレー：システム停止時
    }
}

-- ============================================
-- 経済システム設定
-- ============================================
Config.SupplyPayoutRate = 0.7
Config.SalesPriceRate = 1.5

Config.EMSBasePrices = {
    ['ems_bandage'] = 5000,
    ['ifak'] = 10000,
    ['adrenaline_syringe'] = 50000
}

Config.ItemLimit = 5000

-- ============================================
-- 設置場所設定
-- ============================================
Config.Machines = {
    -- 石川病院 - 自販機
    {
        id = 'ems_ishikawa_main',
        type = 'prop',                      -- 自販機タイプ
        object = 'prop_vend_snak_01',       -- ✅ objectキー使用
        coords = vector4(1128.16, -1563.04, 35.03, 180.00),
        label = '石川病院 - 自販機'
    },
    
    -- 石川病院 - 受付販売担当
    {
        id = 'ems_ishikawa_receptionist',
        type = 'ped',                       -- NPCタイプ
        model = 's_f_y_scrubs_01',         -- ✅ modelキー使用
        coords = vector4(1127.51, -1534.1, 35.03, 288.32),
        label = '石川病院 - 受付販売担当',
        scenario = 'WORLD_HUMAN_CLIPBOARD'
    },
    
    -- 朝霧クリニック - 自販機
    {
        id = 'ems_kirishina_main',
        type = 'prop',                      -- 自販機タイプ
        object = 'prop_vend_snak_01',       -- ✅ objectキーに修正
        coords = vec4(-247.81, 6329.60, 32.43, 134.60),
        label = '朝霧クリニック - 自販機'
    }
}

-- ============================================
-- 利用可能なモデル一覧
-- ============================================
--[[
【自販機モデル】
- prop_vend_snak_01      スナック自販機
- prop_vend_soda_01      コーラ自販機  
- prop_vend_soda_02      緑の自販機
- prop_vend_water_01     水自販機
- prop_vend_coffe_01     コーヒー自販機

【医療関係NPCモデル】
- s_f_y_scrubs_01        看護師（女性）
- s_m_m_paramedic_01     救急隊員（男性）
- s_m_m_doctor_01        医師（男性）
- u_m_y_paramedic_01     若い救急隊員

【NPCシナリオ】
- WORLD_HUMAN_CLIPBOARD           クリップボード確認
- WORLD_HUMAN_STAND_IMPATIENT     待機姿勢
- WORLD_HUMAN_AA_COFFEE           コーヒー飲み
- WORLD_HUMAN_GUARD_STAND         警備姿勢
- nil                             通常立ち姿
]]

-- ============================================
-- Blip設定
-- ============================================
Config.Blip = {
    sprite = 153,     -- 医療十字アイコン
    scale = 0.7,
    name = 'EMS販売所'
}
