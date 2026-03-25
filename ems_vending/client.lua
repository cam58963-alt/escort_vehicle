-- ============================================
-- QBox EMS自販機システム - Client Side（修正版）
-- ============================================

local PlayerData = {}

local function GetCurrentPlayerData()
    local success, data = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    return success and data or {}
end

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(100)
    end
    PlayerData = GetCurrentPlayerData()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    PlayerData = data
end)

local spawnedObjs = {}
local spawnedPeds = {}
local machineBlips = {}
local machineStockStates = {}

-- ============================================
-- ユーティリティ関数
-- ============================================
local function IsEMS()
    local data = PlayerData.job and PlayerData or GetCurrentPlayerData()
    return data and data.job and data.job.name == Config.JobName
end

local function GetItemLabel(item)
    local itemData = exports.ox_inventory:Items(item)
    return itemData and itemData.label or item
end

local function FormatMoney(amount)
    local num = tonumber(amount) or 0
    return '$' .. tostring(num):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end

-- ============================================
-- ブリップ制御システム
-- ============================================
--[[
local function UpdateBlipDisplay()
    if not Config.BlipControl or not Config.BlipControl.enabled then return end
    
    local isEMS = IsEMS()
    
    for machineId, blip in pairs(machineBlips) do
        if not DoesBlipExist(blip) then goto continue end
        
        local state = machineStockStates[machineId]
        if not state then goto continue end
        
        local hasStock = state.hasStock
        local emsCount = tonumber(state.emsCount) or 0
        
        if isEMS then
            SetBlipDisplay(blip, 4)
            SetBlipAlpha(blip, 255)
            
            if hasStock then
                if emsCount <= Config.MaxEMSForPublicSale then
                    SetBlipColour(blip, Config.BlipControl.colors.available)
                else
                    SetBlipColour(blip, Config.BlipControl.colors.emsOnly)
                end
            else
                SetBlipColour(blip, Config.BlipControl.colors.outOfStock)
            end
        else
            if hasStock and emsCount <= Config.MaxEMSForPublicSale then
                SetBlipDisplay(blip, 4)
                SetBlipAlpha(blip, 255)
                SetBlipColour(blip, Config.BlipControl.colors.available)
            else
                if Config.BlipControl.hideEmptyForCivilians then
                    SetBlipDisplay(blip, 0)
                else
                    SetBlipAlpha(blip, 0)
                end
            end
        end
        
        ::continue::
    end
end


RegisterNetEvent('vending_ems:client:updateBlips', function(statesTable)
    machineStockStates = statesTable
    UpdateBlipDisplay()
end)

RegisterNetEvent('vending_ems:client:updateSingleBlip', function(machineId, state)
    machineStockStates[machineId] = state
    UpdateBlipDisplay()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    SetTimeout(1000, function()
        PlayerData = GetCurrentPlayerData()
        UpdateBlipDisplay()
    end)
end)
]]
-- ============================================
-- メインメニュー（登録機能削除済み）
-- ============================================
local function OpenVendingMenu(machineId)
    lib.callback('vending_ems:getInfo', false, function(items, emsCount)
        emsCount = tonumber(emsCount) or 0
        
        if not IsEMS() and emsCount > Config.MaxEMSForPublicSale then
            lib.notify({
                type = 'error',
                description = string.format('EMSが%d名勤務中です。EMSにお電話ください', emsCount)
            })
            return
        end
        
        local options = {}
        
        -- 購入メニュー
        table.insert(options, {
            title = '🛒 商品購入',
            description = 'EMSアイテムを購入する',
            icon = 'shopping-cart',
            onSelect = function()
                OpenBuyMenu(machineId, items)
            end
        })
        
        -- EMS専用メニュー
        if IsEMS() then
            -- 補充メニュー（全員利用可能）
            table.insert(options, {
                title = '📦 在庫補充',
                description = 'アイテムを納品して報酬を得る',
                icon = 'truck',
                onSelect = function()
                    OpenSupplyMenu(machineId, items)
                end
            })
    
            -- ★廃棄メニュー（階級制限追加）
            local playerData = GetCurrentPlayerData()
            local playerGrade = playerData.job and playerData.job.grade or {}
            local gradeLevel = 0
    
            -- QBox対応の階級取得
            if type(playerGrade) == 'table' then
                gradeLevel = tonumber(playerGrade.level) or 0
            else
                gradeLevel = tonumber(playerGrade) or 0
            end
    
            local requiredGrade = Config.MinGradeForDiscard or 3
    
            if gradeLevel >= requiredGrade then
                -- 権限ありの場合：廃棄メニュー表示
                table.insert(options, {
                    title = '🗑️ 在庫破棄',
                    description = '不要な在庫を破棄する（管理職権限）',
                    icon = 'trash',
                    onSelect = function()
                        OpenDiscardMenu(machineId, items)
                    end
                })
            else
                -- 権限なしの場合：グレーアウト表示
                table.insert(options, {
                    title = '🔒 在庫破棄',
                    description = string.format('Grade %d以上の権限が必要です（現在: Grade %d）', 
                        requiredGrade, gradeLevel),
                    icon = 'lock',
                    disabled = true
                })
            end
        end
        
        lib.registerContext({
            id = 'ems_vending_main',
            title = '🏥 EMS自動販売機',
            options = options
        })
        
        lib.showContext('ems_vending_main')
    end, machineId)
end

-- ============================================
-- 購入メニュー（複数購入対応版）
-- ============================================
function OpenBuyMenu(machineId, items)
    local options = {}
    
    for item, data in pairs(items) do
        local stock = tonumber(data.stock) or 0
        local price = tonumber(data.salesPrice) or 0
        local disabled = stock <= 0
        
        table.insert(options, {
            title = string.format('%s%s', disabled and '❌ ' or '🛒 ', GetItemLabel(item)),
            description = string.format('単価: %s | 在庫: %d個', FormatMoney(price), stock),
            icon = disabled and 'xmark' or 'shopping-cart',
            disabled = disabled,
            onSelect = function()
                -- 数量入力ダイアログ
                local input = lib.inputDialog('購入数量', {
                    {
                        type = 'number',
                        label = '購入する数量',
                        description = string.format('単価: %s | 最大: %d個', FormatMoney(price), stock),
                        required = true,
                        min = 1,
                        max = stock,
                        default = 1
                    }
                })
                
                if not input or not input[1] then return end
                
                local amount = tonumber(input[1])
                if not amount or amount <= 0 then
                    lib.notify({
                        type = 'error',
                        description = '無効な数量です'
                    })
                    return
                end
                
                -- 合計金額計算
                local totalPrice = price * amount
                
                -- 購入確認ダイアログ
                local confirm = lib.alertDialog({
                    header = '購入確認',
                    content = string.format(
                        '**商品**: %s\n**数量**: %d個\n**単価**: %s\n**合計**: %s\n\n購入しますか？',
                        GetItemLabel(item),
                        amount,
                        FormatMoney(price),
                        FormatMoney(totalPrice)
                    ),
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = '購入する',
                        cancel = 'キャンセル'
                    }
                })
                
                if confirm ~= 'confirm' then return end
                
                -- プログレスバー（数量に応じて時間調整）
                if lib.progressCircle({
                    duration = 2000 + (amount * 300),
                    label = string.format('%d個購入中... (合計: %s)', amount, FormatMoney(totalPrice)),
                    position = 'bottom',
                    useWhileDead = false,
                    canCancel = true,
                    disable = {
                        move = true,
                        car = true,
                        combat = true
                    },
                    anim = {
                        dict = 'anim_casino_a@amb@casino@games@arcadecabinet@maleright',
                        clip = 'insert_coins'
                    }
                }) then
                    TriggerServerEvent('vending_ems:server:buy', machineId, item, amount)
                else
                    lib.notify({
                        type = 'info',
                        description = '購入をキャンセルしました'
                    })
                end
            end
        })
    end
    
    table.insert(options, {
        title = '↩ 戻る',
        icon = 'arrow-left',
        onSelect = function()
            OpenVendingMenu(machineId)
        end
    })
    
    lib.registerContext({
        id = 'ems_vending_buy',
        title = '🛒 商品購入',
        menu = 'ems_vending_main',
        options = options
    })
    
    lib.showContext('ems_vending_buy')
end

-- ============================================
-- 補充メニュー
-- ============================================
function OpenSupplyMenu(machineId, items)
    local options = {}
    
    for item, data in pairs(items) do
        local stock = tonumber(data.stock) or 0
        local reward = tonumber(data.supplyReward) or 0
        
        table.insert(options, {
            title = string.format('📦 %s', GetItemLabel(item)),
            description = string.format('現在在庫: %d個 | 納品報酬: %s/個', stock, FormatMoney(reward)),
            icon = 'box',
            onSelect = function()
                local input = lib.inputDialog('在庫補充', {
                    {
                        type = 'number',
                        label = '納品数量',
                        description = string.format('報酬: %s/個', FormatMoney(reward)),
                        required = true,
                        min = 1,
                        max = 200--1回の補充量上限
                    }
                })
                
                if input and input[1] then
                    local amount = tonumber(input[1])
                    if amount and amount > 0 then
                        if lib.progressCircle({
                            duration = 3000 + (amount * 100),
                            label = string.format('%d個納品中...', amount),
                            position = 'bottom',
                            useWhileDead = false,
                            canCancel = true,
                            disable = { move = true, car = true, combat = true },
                            anim = { dict = 'anim@amb@carmeet@checkout_engine@female_c@trans', clip = 'c_trans_b' }
                        }) then
                            TriggerServerEvent('vending_ems:server:supply', machineId, item, amount)
                        end
                    end
                end
            end
        })
    end
    
    table.insert(options, {
        title = '↩ 戻る',
        icon = 'arrow-left',
        onSelect = function()
            OpenVendingMenu(machineId)
        end
    })
    
    lib.registerContext({
        id = 'ems_vending_supply',
        title = '📦 在庫補充',
        menu = 'ems_vending_main',
        options = options
    })
    
    lib.showContext('ems_vending_supply')
end

-- ============================================
-- 破棄メニュー
-- ============================================
function OpenDiscardMenu(machineId, items)
    local options = {}
    local hasStock = false
    
    for item, data in pairs(items) do
        local stock = tonumber(data.stock) or 0
        if stock > 0 then
            hasStock = true
            table.insert(options, {
                title = string.format('🗑️ %s', GetItemLabel(item)),
                description = string.format('現在在庫: %d個', stock),
                icon = 'trash',
                onSelect = function()
                    local input = lib.inputDialog('在庫破棄', {
                        {
                            type = 'number',
                            label = '破棄数量',
                            description = string.format('最大: %d個', stock),
                            required = true,
                            min = 1,
                            max = stock
                        }
                    })
                    
                    if input and input[1] then
                        local amount = tonumber(input[1])
                        if amount and amount > 0 and amount <= stock then
                            TriggerServerEvent('vending_ems:server:discard', machineId, item, amount)
                        end
                    end
                end
            })
        end
    end
    
    if not hasStock then
        lib.notify({
            type = 'error',
            description = '破棄できる在庫がありません'
        })
        return
    end
    
    table.insert(options, {
        title = '↩ 戻る',
        icon = 'arrow-left',
        onSelect = function()
            OpenVendingMenu(machineId)
        end
    })
    
    lib.registerContext({
        id = 'ems_vending_discard',
        title = '🗑️ 在庫破棄',
        menu = 'ems_vending_main',
        options = options
    })
    
    lib.showContext('ems_vending_discard')
end

-- ============================================
-- オブジェクト生成関数（既存と同じ）
-- ============================================
local function LoadPedModel(model)
    local modelHash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(modelHash) then return false end
    
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end
    return HasModelLoaded(modelHash)
end

--[[
local function CreateMachineBlip(cfg)
    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipColour(blip, Config.BlipControl and Config.BlipControl.colors.available or 2)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.name)
    EndTextCommandSetBlipName(blip)
    
    machineBlips[cfg.id] = blip
    return blip
end
]]

local function SpawnMachine(cfg)
    --CreateMachineBlip(cfg)
    
    if cfg.type == 'ped' then
        if not LoadPedModel(cfg.model) then return end
        
        local hash = type(cfg.model) == 'string' and joaat(cfg.model) or cfg.model
        local ped = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, true)
        
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedDiesWhenInjured(ped, false)
        SetPedCanPlayAmbientAnims(ped, true)
        SetPedCanRagdollFromPlayerImpact(ped, false)
        SetEntityCanBeDamaged(ped, false)
        
        if cfg.scenario then
            TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
        end
        
        spawnedPeds[cfg.id] = ped
        
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'ems_vending_ped_' .. cfg.id,
                label = string.format('💬 %s', cfg.label or 'EMS担当者と話す'),
                icon = 'fa-solid fa-comments',
                distance = 2.5,
                onSelect = function()
                    OpenVendingMenu(cfg.id)
                end
            }
        })
        
        SetModelAsNoLongerNeeded(hash)
    else
        local hash = type(cfg.object) == 'string' and joaat(cfg.object) or tonumber(cfg.object)
        lib.requestModel(hash, 10000)
        
        local obj = CreateObject(hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, false, false, false)
        SetEntityHeading(obj, cfg.coords.w)
        FreezeEntityPosition(obj, true)
        SetEntityInvincible(obj, true)
        
        spawnedObjs[cfg.id] = obj
        
        exports.ox_target:addLocalEntity(obj, {
            {
                name = 'ems_vending_prop_' .. cfg.id,
                label = string.format('🏥 %s', cfg.label or 'EMS自販機を使用'),
                icon = 'fa-solid fa-briefcase-medical',
                distance = 2.5,
                onSelect = function()
                    OpenVendingMenu(cfg.id)
                end
            }
        })
    end
end

-- ============================================
-- 初期化処理
-- ============================================
local function InitAllMachines()
    for _, obj in pairs(spawnedObjs) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, blip in pairs(machineBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    
    spawnedObjs = {}
    spawnedPeds = {}
    machineBlips = {}
    machineStockStates = {}
    
    for _, cfg in ipairs(Config.Machines) do
        SpawnMachine(cfg)
    end
end

-- ============================================
-- イベントハンドラー
-- ============================================
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    PlayerData = GetCurrentPlayerData()
    InitAllMachines()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Wait(1000)
        InitAllMachines()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    for _, obj in pairs(spawnedObjs) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, blip in pairs(machineBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
