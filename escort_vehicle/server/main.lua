-- server/main.lua v0.5.0-dev
local QBX = exports.qbx_core

local function DebugLog(message)
    if Config.Debug then
        print('^2[ESCORT_SERVER]^7 ' .. message)
    end
end

local function HasPermission(src)
    if not Config.JobRestriction.enabled then return true end
    
    local success, player = pcall(function()
        return QBX:GetPlayer(src)
    end)
    
    if not success or not player or not player.PlayerData or not player.PlayerData.job then
        return false
    end
    
    local playerJob = player.PlayerData.job.name
    local isOnDuty = player.PlayerData.job.onduty
    
    if not Config.IsJobAllowed(playerJob) then return false end
    if not Config.JobRestriction.allowOffDuty and not isOnDuty then return false end
    
    return true
end

-- ストレッチャーアイテムをインベントリに返却
RegisterNetEvent('escort_vehicle:server:returnStretcherItem', function()
    local src = source
    
    DebugLog('Returning stretcher item to inventory - Player: ' .. src)
    
    -- ox_inventory統合（エラーハンドリング付き）
    local success, result = pcall(function()
        if exports.ox_inventory:CanCarryItem(src, Config.Stretcher.itemName, 1) then
            return exports.ox_inventory:AddItem(src, Config.Stretcher.itemName, 1)
        end
        return false
    end)
    
    if success and result then
        DebugLog('Stretcher item returned successfully')
        TriggerClientEvent('qbx_core:Notify', src, 'ストレッチャーをインベントリに収納しました', 'success')
    else
        DebugLog('Failed to return stretcher item - inventory full or error')
        TriggerClientEvent('qbx_core:Notify', src, Config.Notifications.inventoryFull, 'error')
    end
end)

-- 患者をストレッチャーに乗せる
RegisterNetEvent('escort_vehicle:server:placeOnStretcher', function(targetPlayerId, stretcherNetId)
    local src = source
    
    DebugLog('Place on stretcher request - Target: ' .. tostring(targetPlayerId))
    
    if not HasPermission(src) then
        DebugLog('Permission denied')
        return
    end
    
    local targetName = GetPlayerName(targetPlayerId)
    if not targetPlayerId or not targetName then
        DebugLog('Target player not found')
        return
    end
    
    DebugLog('Target player: ' .. targetName)
    
    -- クライアントに患者搭載を指示
    TriggerClientEvent('escort_vehicle:client:placeOnStretcher', targetPlayerId, stretcherNetId)
    
    -- TK Ambulanceのドラッグ状態を解除
    pcall(function()
        exports.tk_ambulancejob:stopDragging(src, targetPlayerId)
    end)
    
    DebugLog('Patient placed on stretcher successfully')
end)

-- 患者をストレッチャーから降ろす
RegisterNetEvent('escort_vehicle:server:removeFromStretcher', function(targetPlayerId)
    local src = source
    
    DebugLog('Remove from stretcher request - Target: ' .. tostring(targetPlayerId))
    
    if not HasPermission(src) then return end
    
    local targetName = GetPlayerName(targetPlayerId)
    if not targetPlayerId or not targetName then return end
    
    TriggerClientEvent('escort_vehicle:client:removeFromStretcher', targetPlayerId)
    
    DebugLog('Patient removed from stretcher successfully')
end)

-- 患者を車両に乗せる
RegisterNetEvent('escort_vehicle:server:putInVehicle', function(targetPlayerId, vehicleNetId, seatIndex)
    local src = source
    
    DebugLog('Put in vehicle request - Target: ' .. targetPlayerId .. ', Seat: ' .. seatIndex)
    
    if not HasPermission(src) then
        DebugLog('Permission denied')
        return
    end
    
    local targetName = GetPlayerName(targetPlayerId)
    if not targetPlayerId or not targetName then
        DebugLog('Target player not found')
        return
    end
    
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then
        DebugLog('Vehicle not found')
        return
    end
    
    -- クライアントに車両搭乗を指示
    TriggerClientEvent('escort_vehicle:client:putInVehicle', targetPlayerId, vehicleNetId, seatIndex)
    TriggerClientEvent('qbx_core:Notify', src, Config.Notifications.patientInVehicle, 'success')
    
    -- 既存エスコートスクリプトとの連携
    TriggerEvent('police:server:SetPlayerOut', src, targetPlayerId)
    TriggerEvent('ambulance:server:SetPlayerOut', src, targetPlayerId)
    
    -- TK統合
    pcall(function()
        exports.tk_ambulancejob:stopDragging(src, targetPlayerId)
    end)
    
    DebugLog('Patient loaded into vehicle successfully')
end)

DebugLog('========================================')
DebugLog('ESCORT + STRETCHER SERVER v0.5.0-dev LOADED')
DebugLog('Features: Item return, TK integration, Enhanced error handling')
DebugLog('========================================')
