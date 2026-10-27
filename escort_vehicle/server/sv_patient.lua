-- server/sv_patient.lua v0.7.0 - 患者管理（搬送・搭乗）

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
-- 訓練用NPC（ems_npc_rescue）
-- NPC はオーナーのクライアントでしか動かせないので、オーナーに処理を頼む
-- ============================================================

---@param src number 操作したプレイヤー
---@param npcNetId number
---@return number|nil owner NPC のオーナーの Source ID
local function GetRescueNpcOwner(src, npcNetId)
    if not Config.RescueNPC or not Config.RescueNPC.enabled then return nil end

    npcNetId = tonumber(npcNetId)
    if not npcNetId then return nil end

    local npc = NetworkGetEntityFromNetworkId(npcNetId)
    if not npc or npc == 0 or not DoesEntityExist(npc) then
        ServerDebugLog('Rescue NPC not found: ' .. tostring(npcNetId))
        return nil
    end
    if GetEntityType(npc) ~= 1 or IsPedAPlayer(npc) then return nil end
    if not Entity(npc).state[Config.RescueNPC.stateKey] then
        ServerDebugLog('Entity is not a rescue NPC: ' .. tostring(npcNetId))
        return nil
    end

    local srcPed = GetPlayerPed(src)
    if not srcPed or srcPed == 0 then return nil end
    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(npc))
    if dist > Config.RescueNPC.maxDistance then
        ServerDebugLog(('Rescue NPC too far: %.1fm'):format(dist))
        return nil
    end

    local owner = NetworkGetEntityOwner(npc)
    if not owner or owner <= 0 then return nil end
    return owner
end

RegisterNetEvent('escort_vehicle:server:placeNpcOnStretcher', function(npcNetId, stretcherNetId)
    local src = source
    if not ServerHasPermission(src) then return end

    local owner = GetRescueNpcOwner(src, npcNetId)
    if not owner then return end

    local stretcher = NetworkGetEntityFromNetworkId(tonumber(stretcherNetId) or 0)
    if not stretcher or stretcher == 0 or not DoesEntityExist(stretcher) then
        ServerDebugLog('Stretcher not found: ' .. tostring(stretcherNetId))
        return
    end

    TriggerClientEvent('escort_vehicle:client:npcPlaceOnStretcher', owner, npcNetId, stretcherNetId)
    ServerDebugLog(('Rescue NPC %s placed on stretcher (owner=%d)'):format(tostring(npcNetId), owner))
end)

RegisterNetEvent('escort_vehicle:server:removeNpcFromStretcher', function(npcNetId)
    local src = source
    if not ServerHasPermission(src) then return end

    local owner = GetRescueNpcOwner(src, npcNetId)
    if not owner then return end

    TriggerClientEvent('escort_vehicle:client:npcRemoveFromStretcher', owner, npcNetId)
    ServerDebugLog(('Rescue NPC %s removed from stretcher'):format(tostring(npcNetId)))
end)

RegisterNetEvent('escort_vehicle:server:putNpcInVehicle', function(npcNetId, vehicleNetId, seatIndex)
    local src = source
    if not ServerHasPermission(src) then return end

    local owner = GetRescueNpcOwner(src, npcNetId)
    if not owner then return end

    local vehicle = NetworkGetEntityFromNetworkId(tonumber(vehicleNetId) or 0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        ServerDebugLog('Vehicle not found')
        return
    end

    seatIndex = tonumber(seatIndex)
    if not seatIndex then return end

    TriggerClientEvent('escort_vehicle:client:npcPutInVehicle', owner, npcNetId, vehicleNetId, seatIndex)
    ServerNotify(src, Config.Notifications.patientInVehicle, 'success')
    ServerDebugLog(('Rescue NPC %s loaded into vehicle seat %d'):format(tostring(npcNetId), seatIndex))
end)

-- ============================================================
-- 起動ログ
-- ============================================================

ServerDebugLog('========================================')
ServerDebugLog('ESCORT + STRETCHER SERVER v0.7.0 LOADED')
ServerDebugLog('Modules: sv_utils, sv_inventory, sv_patient')
ServerDebugLog('========================================')
