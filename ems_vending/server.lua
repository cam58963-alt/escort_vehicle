-- ============================================
-- QBox EMS自販機システム - Server Side（エラー修正版）
-- ============================================

local QBCore
pcall(function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

-- ============================================
-- デバッグシステム
-- ============================================
local function DebugPrint(category, ...)
    if Config.Debug then
        print(string.format('[EMS_VENDING:%s] %s', category, table.concat({...}, ' ')))
    end
end

-- ============================================
-- プレイヤー取得（QBox対応）
-- ============================================
local function GetPlayer(source)
    if QBCore then
        local success, player = pcall(function()
            return QBCore.Functions.GetPlayer(source)
        end)
        if success and player then return player end
    end
    
    local success2, player2 = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    if success2 and player2 then return player2 end
    
    DebugPrint('ERROR', 'Failed to get player:', source)
    return nil
end

-- ============================================
-- EMS勤務人数カウント
-- ============================================
-- ============================================
-- EMS勤務人数カウント（QBox最適化版）
-- ============================================
local function GetJobCount(jobName)
    -- QBox公式API（最優先・最高精度）
    local success, count = pcall(function()
        return exports.qbx_core:GetDutyCountJob(jobName)
    end)
    
    if success and count then
        DebugPrint('JOB_COUNT', string.format('QBox API: %d on-duty %s', count, jobName))
        return count
    end
    
    -- フォールバック: 万が一QBox APIが失敗した場合のみ
    DebugPrint('JOB_COUNT', 'QBox API failed, using manual count')
    
    local manualCount = 0
    local players = GetPlayers()
    
    for _, src in ipairs(players) do
        local player = GetPlayer(tonumber(src))
        
        if player and player.PlayerData then
            local job = player.PlayerData.job
            
            -- 厳密チェック: onduty が明示的に true の場合のみ
            if job and job.name == jobName and job.onduty == true then
                manualCount = manualCount + 1
            end
        end
    end
    
    return manualCount
end



-- ============================================
-- EMS金庫操作
-- ============================================
local function UpdateEMSBank(amount, operation)
    if amount <= 0 then return false end
    local delta = (operation == 'add') and amount or -amount
    
    local affected = MySQL.update.await(
        'UPDATE bank_accounts_new SET amount = amount + ? WHERE id = ?',
        {delta, Config.BankAccountId}
    )
    return affected and affected > 0
end

local function GetEMSBankBalance()
    local balance = MySQL.scalar.await(
        'SELECT amount FROM bank_accounts_new WHERE id = ?',
        {Config.BankAccountId}
    )
    return tonumber(balance) or 0
end

-- ============================================
-- データベースヘルパー
-- ============================================
local function FetchOrCreateRow(machineId, item)
    local row = MySQL.single.await(
        'SELECT * FROM vending_ems WHERE machine_id = ? AND item = ?',
        {machineId, item}
    )
    
    if not row then
        local basePrice = Config.EMSBasePrices[item] or 0
        local insertId = MySQL.insert.await(
            'INSERT INTO vending_ems (machine_id, item, stock, base_price) VALUES (?, ?, 0, ?)',
            {machineId, item, basePrice}
        )
        if insertId then
            row = {
                machine_id = machineId,
                item = item,
                stock = 0,
                base_price = basePrice
            }
        end
    end
    return row
end

-- ============================================
-- ブリップ状態管理（修正版）
-- ============================================
local function GetMachineStockStatus(machineId)
    local result = MySQL.single.await(
        'SELECT SUM(stock) as total_stock FROM vending_ems WHERE machine_id = ?',
        {machineId}
    )
    
    -- 型変換を確実に実行してエラーを防ぐ
    local totalStock = tonumber(result and result.total_stock) or 0
    
    DebugPrint('BLIP_CHECK', string.format('Machine %s: stock=%d', machineId, totalStock))
    
    return {
        hasStock = totalStock > 0,
        totalStock = totalStock
    }
end

local function UpdateMachineBlip(machineId)
    if not Config.BlipControl or not Config.BlipControl.enabled then return end
    
    local emsCount = GetJobCount(Config.JobName)
    local stockStatus = GetMachineStockStatus(machineId)
    
    TriggerClientEvent('vending_ems:client:updateSingleBlip', -1, machineId, {
        hasStock = stockStatus.hasStock,
        totalStock = stockStatus.totalStock,
        emsCount = emsCount
    })
end

local function UpdateAllBlipStates()
    if not Config.BlipControl or not Config.BlipControl.enabled then return end
    
    local emsCount = GetJobCount(Config.JobName)
    local machineStates = {}
    
    for _, machine in ipairs(Config.Machines) do
        local stockStatus = GetMachineStockStatus(machine.id)
        machineStates[machine.id] = {
            hasStock = stockStatus.hasStock,
            totalStock = stockStatus.totalStock,
            emsCount = emsCount
        }
    end
    
    TriggerClientEvent('vending_ems:client:updateBlips', -1, machineStates)
end

-- 定期更新スレッド
CreateThread(function()
    if not Config.BlipControl or not Config.BlipControl.enabled then return end
    while true do
        Wait(Config.BlipControl.updateInterval or 30000)
        UpdateAllBlipStates()
    end
end)

-- ============================================
-- コールバック
-- ============================================
lib.callback.register('vending_ems:getInfo', function(source, machineId)
    local items = {}
    local emsCount = GetJobCount(Config.JobName)
    
    for item, basePrice in pairs(Config.EMSBasePrices) do
        local row = FetchOrCreateRow(machineId, item)
        if row then
            items[item] = {
                stock = tonumber(row.stock) or 0,
                basePrice = basePrice,
                salesPrice = math.floor(basePrice * Config.SalesPriceRate),
                supplyReward = math.floor(basePrice * Config.SupplyPayoutRate)
            }
        end
    end
    
    return items, emsCount
end)

lib.callback.register('vending_ems:canBuy', function(source, machineId, item)
    local Player = GetPlayer(source)
    if not Player then return false, 0 end
    
    local row = FetchOrCreateRow(machineId, item)
    if not row or (tonumber(row.stock) or 0) <= 0 then return false, 0 end
    
    local price = math.floor((Config.EMSBasePrices[item] or 0) * Config.SalesPriceRate)
    local playerCash = Player.Functions.GetMoney('cash')
    
    return playerCash >= price, price
end)

-- ============================================
-- イベント：在庫補充
-- ============================================
RegisterNetEvent('vending_ems:server:supply', function(machineId, item, amount)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return end
    
    amount = tonumber(amount) or 0
    if amount <= 0 then
        lib.notify(src, { type = 'error', description = '無効な数量です' })
        return
    end
    
    local row = FetchOrCreateRow(machineId, item)
    if not row then return end
    
    local currentStock = tonumber(row.stock) or 0
    if currentStock + amount > Config.ItemLimit then
        lib.notify(src, { type = 'error', description = '在庫上限を超えています' })
        return
    end
    
    local basePrice = Config.EMSBasePrices[item] or 0
    local totalReward = math.floor(basePrice * Config.SupplyPayoutRate) * amount
    
    if GetEMSBankBalance() < totalReward then
        lib.notify(src, { type = 'error', description = 'EMS金庫の残高が不足しています' })
        return
    end
    
    if not exports.ox_inventory:RemoveItem(src, item, amount) then
        lib.notify(src, { type = 'error', description = 'アイテムが足りません' })
        return
    end
    
    local updated = MySQL.update.await(
        'UPDATE vending_ems SET stock = stock + ? WHERE machine_id = ? AND item = ?',
        {amount, machineId, item}
    )
    
    if not updated or updated == 0 then
        exports.ox_inventory:AddItem(src, item, amount)
        lib.notify(src, { type = 'error', description = 'データベースエラーが発生しました' })
        return
    end
    
    if UpdateEMSBank(totalReward, 'remove') then
        Player.Functions.AddMoney('cash', totalReward)
        lib.notify(src, {
            type = 'success',
            description = string.format('%d個納品完了（報酬: $%s）', amount,
                tostring(totalReward):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
        })
        UpdateMachineBlip(machineId)
    else
        -- ロールバック処理
        MySQL.update.await(
            'UPDATE vending_ems SET stock = stock - ? WHERE machine_id = ? AND item = ?',
            {amount, machineId, item}
        )
        exports.ox_inventory:AddItem(src, item, amount)
        lib.notify(src, { type = 'error', description = '金庫操作に失敗しました' })
    end
end)

-- ============================================
-- イベント：商品購入（複数購入対応版）
-- ============================================
RegisterNetEvent('vending_ems:server:buy', function(machineId, item, amount)
    local src = source
    local Player = GetPlayer(src)
    if not Player then return end
    
    -- 数量バリデーション
    amount = tonumber(amount) or 1
    if amount <= 0 then
        lib.notify(src, { type = 'error', description = '無効な数量です' })
        return
    end
    
    local playerJob = Player.PlayerData.job.name
    local isEMS = playerJob == Config.JobName
    
    -- EMS人数制限チェック（市民のみ）
    if not isEMS then
        local emsCount = GetJobCount(Config.JobName)
        if emsCount > Config.MaxEMSForPublicSale then
            lib.notify(src, {
                type = 'error',
                description = string.format('EMSが%d名勤務中です。119番にお電話ください', emsCount)
            })
            return
        end
    end
    
    -- 在庫確認
    local row = FetchOrCreateRow(machineId, item)
    local currentStock = tonumber(row and row.stock) or 0
    
    if currentStock <= 0 then
        lib.notify(src, { type = 'error', description = '在庫がありません' })
        return
    end
    
    -- 在庫不足の場合は購入可能な最大数に自動調整
    if amount > currentStock then
        lib.notify(src, {
            type = 'info',
            description = string.format('在庫が%d個しかないため、%d個購入します', currentStock, currentStock)
        })
        amount = currentStock
    end
    
    -- 価格計算
    local basePrice = Config.EMSBasePrices[item] or 0
    local unitPrice = math.floor(basePrice * Config.SalesPriceRate)
    local totalPrice = unitPrice * amount
    
    DebugPrint('BUY', string.format('Player %s buying %d x %s for $%d total', 
        GetPlayerName(src), amount, item, totalPrice))
    
    -- 支払い処理
    if not Player.Functions.RemoveMoney('cash', totalPrice) then
        lib.notify(src, {
            type = 'error',
            description = string.format('現金が足りません（必要: %s）',
                tostring(totalPrice):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
        })
        return
    end
    
    -- アイテム付与
    local added = exports.ox_inventory:AddItem(src, item, amount)
    if not added then
        -- 失敗時は返金
        Player.Functions.AddMoney('cash', totalPrice)
        lib.notify(src, { type = 'error', description = 'インベントリがいっぱいです' })
        DebugPrint('BUY', 'Inventory full, refunded player')
        return
    end
    
    -- 在庫減少
    local updated = MySQL.update.await(
        'UPDATE vending_ems SET stock = stock - ?, last_purchase = NOW() WHERE machine_id = ? AND item = ?',
        {amount, machineId, item}
    )
    
    if not updated or updated == 0 then
        -- ロールバック：アイテム削除 & 返金
        exports.ox_inventory:RemoveItem(src, item, amount)
        Player.Functions.AddMoney('cash', totalPrice)
        lib.notify(src, { type = 'error', description = 'データベースエラーが発生しました' })
        DebugPrint('BUY', 'Database error, full rollback completed')
        return
    end
    
    -- EMS金庫に売上入金
    local bankSuccess = UpdateEMSBank(totalPrice, 'add')
    
    -- 成功通知
    lib.notify(src, {
        type = 'success',
        description = string.format('%d個購入完了（合計: %s）', amount,
            tostring(totalPrice):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
    })
    
    DebugPrint('BUY', string.format('Purchase completed: %d x %s, total: $%d, bank: %s', 
        amount, item, totalPrice, bankSuccess and 'OK' or 'FAILED'))
    
    -- ブリップ更新
    UpdateMachineBlip(machineId)
end)


-- ============================================
-- イベント：在庫破棄（階級制限版）
-- ============================================
RegisterNetEvent('vending_ems:server:discard', function(machineId, item, amount)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return end
    
    -- ★階級チェック追加
    local playerGrade = Player.PlayerData.job.grade
    local gradeLevel = 0
    
    -- QBox対応の階級取得（複数パターン対応）
    if type(playerGrade) == 'table' then
        gradeLevel = tonumber(playerGrade.level) or 0
    else
        gradeLevel = tonumber(playerGrade) or 0
    end
    
    local requiredGrade = Config.MinGradeForDiscard or 3
    
    if gradeLevel < requiredGrade then
        lib.notify(src, {
            type = 'error',
            description = string.format('この操作にはGrade %d以上の権限が必要です（現在: Grade %d）', 
                requiredGrade, gradeLevel)
        })
        DebugPrint('DISCARD', string.format('Permission denied: %s (Grade %d < %d)', 
            GetPlayerName(src), gradeLevel, requiredGrade))
        return
    end
    
    -- 以下は既存のロジック
    local row = FetchOrCreateRow(machineId, item)
    amount = tonumber(amount) or 0
    local currentStock = tonumber(row and row.stock) or 0
    
    if not row or amount <= 0 or amount > currentStock then
        lib.notify(src, { type = 'error', description = '無効な数量です' })
        return
    end
    
    DebugPrint('DISCARD', string.format('Grade %d user %s discarding %d %s from %s', 
        gradeLevel, GetPlayerName(src), amount, item, machineId))
    
    if amount == currentStock then
        MySQL.query.await(
            'DELETE FROM vending_ems WHERE machine_id = ? AND item = ?',
            {machineId, item}
        )
        lib.notify(src, { type = 'success', description = '全在庫を破棄し、登録を削除しました' })
    else
        MySQL.update.await(
            'UPDATE vending_ems SET stock = stock - ? WHERE machine_id = ? AND item = ?',
            {amount, machineId, item}
        )
        lib.notify(src, {
            type = 'success',
            description = string.format('%d個破棄しました（残り: %d個）', amount, currentStock - amount)
        })
    end
    
    UpdateMachineBlip(machineId)
end)

-- ============================================
-- システム初期化
-- ============================================
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Wait(2000)
        local balance = GetEMSBankBalance()
        DebugPrint('^2[EMS Vending System] Successfully started^0')
        DebugPrint('^3[EMS Vending System] Current Balance: $' .. tostring(balance) .. '^0')
        
        if Config.BlipControl and Config.BlipControl.enabled then
            UpdateAllBlipStates()
            DebugPrint('^3[EMS Vending System] Blip control system activated^0')
        end
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    Wait(2000)
    UpdateAllBlipStates()
end)

-- server.lua に一時追加
RegisterCommand('emscount', function(source)
    local count = GetJobCount('ambulance')
    print(string.format('Current EMS on-duty: %d', count))
    TriggerClientEvent('chat:addMessage', source, {
        args = {'System', string.format('勤務中EMS: %d名', count)}
    })
end, false)
