-- server/sv_patient.lua v0.6.5 - 患者管理（搬送・搭乗）

-- ============================================================
-- 患者をストレッチャーに乗せる
-- ============================================================

RegisterNetEvent('escort_vehicle:server:placeOnStretcher', function(targetPlayerId, stretcherNetId)
    local src = source

    ServerDebugLog('Place on stretcher - Source: ' .. src .. ', Target: ' .. tostring(targetPlayerId))

    if not ServerHasPermission(src) then
        ServerDebugLog('Permission denied')
        return
    end

    if not IsValidPlayer(targetPlayerId) then
        ServerDebugLog('Target player not found: ' .. tostring(targetPlayerId))
        return
    end

    ServerDebugLog('Target player: ' .. GetPlayerName(targetPlayerId))

    -- クライアントに患者搭載を指示
    TriggerClientEvent('escort_vehicle:client:placeOnStretcher', targetPlayerId, stretcherNetId)

    ServerDebugLog('Patient placed on stretcher successfully')
end)

-- ============================================================
-- 患者をストレッチャーから降ろす
-- ============================================================

RegisterNetEvent('escort_vehicle:server:removeFromStretcher', function(targetPlayerId)
    local src = source

    ServerDebugLog('Remove from stretcher - Target: ' .. tostring(targetPlayerId))

    if not ServerHasPermission(src) then return end
    if not IsValidPlayer(targetPlayerId) then return end

    TriggerClientEvent('escort_vehicle:client:removeFromStretcher', targetPlayerId)

    ServerDebugLog('Patient removed from stretcher')
end)

-- ============================================================
-- 患者を車両に乗せる
-- ============================================================

RegisterNetEvent('escort_vehicle:server:putInVehicle', function(targetPlayerId, vehicleNetId, seatIndex)
    local src = source

    ServerDebugLog('Put in vehicle - Target: ' .. tostring(targetPlayerId) .. ', Seat: ' .. tostring(seatIndex))

    if not ServerHasPermission(src) then
        ServerDebugLog('Permission denied')
        return
    end

    if not IsValidPlayer(targetPlayerId) then
        ServerDebugLog('Target player not found')
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then
        ServerDebugLog('Vehicle not found')
        return
    end

    -- クライアントに車両搭乗を指示
    TriggerClientEvent('escort_vehicle:client:putInVehicle', targetPlayerId, vehicleNetId, seatIndex)

    -- FIX #16: ServerNotify 統一関数を使用
    ServerNotify(src, Config.Notifications.patientInVehicle, 'success')

    -- 既存エスコートスクリプトとの連携
    TriggerEvent('police:server:SetPlayerOut', src, targetPlayerId)
    TriggerEvent('ambulance:server:SetPlayerOut', src, targetPlayerId)

    ServerDebugLog('Patient loaded into vehicle')
end)

-- ============================================================
-- 起動ログ
-- ============================================================

ServerDebugLog('========================================')
ServerDebugLog('ESCORT + STRETCHER SERVER v0.6.5 LOADED')
ServerDebugLog('Modules: sv_utils, sv_inventory, sv_patient')
ServerDebugLog('========================================')
