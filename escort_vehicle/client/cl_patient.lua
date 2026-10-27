-- client/cl_patient.lua v0.7.0 - 患者（プレイヤー / 訓練用NPC）の乗せ降ろし
--
-- プレイヤーの患者は本人のクライアントで、訓練用NPC はその NPC を管理している
-- クライアント（エンティティのオーナー）で動かす。どちらもサーバーを経由する。

-- ============================================================
-- ストレッチャーを使う側
-- ============================================================

---@param patient table 患者（GetNearbyPatient / NpcPatientFromPed の戻り値）
---@return boolean 乗せる指示を出したか
function PlacePatientOnStretcher(patient)
    if not patient or not StretcherState.Exists() then return false end

    if StretcherState.patient then
        Notify(Config.Notifications.alreadyHasPatient, 'error')
        return false
    end

    local stretcherNetId = ObjToNet(StretcherState.object)
    DebugLog('Placing patient on stretcher: ' .. DescribePatient(patient))

    if patient.type == 'npc' then
        TriggerServerEvent('escort_vehicle:server:placeNpcOnStretcher', patient.netId, stretcherNetId)
    else
        TriggerServerEvent('escort_vehicle:server:placeOnStretcher', patient.serverId, stretcherNetId)
    end

    StretcherState.patient = patient
    Notify(Config.Notifications.patientPlaced, 'success')
    return true
end

---@param silent boolean|nil true なら通知を出さない
---@return boolean 降ろす指示を出したか
function RemovePatientFromStretcher(silent)
    local patient = StretcherState.patient
    if not patient then return false end

    DebugLog('Removing patient from stretcher: ' .. DescribePatient(patient))

    if patient.type == 'npc' then
        TriggerServerEvent('escort_vehicle:server:removeNpcFromStretcher', patient.netId)
    else
        TriggerServerEvent('escort_vehicle:server:removeFromStretcher', patient.serverId)
    end

    StretcherState.patient = nil
    if not silent then
        Notify(Config.Notifications.patientRemoved, 'success')
    end
    return true
end

---@param vehicle number
---@param seat number
function PutPatientInVehicle(vehicle, seat)
    local patient = StretcherState.patient
    if not patient then return end

    local vehicleNetId = VehToNet(vehicle)
    DebugLog(('Putting patient in vehicle: %s seat=%d'):format(DescribePatient(patient), seat))

    if patient.type == 'npc' then
        TriggerServerEvent('escort_vehicle:server:putNpcInVehicle', patient.netId, vehicleNetId, seat)
        -- NPC はオーナー側でストレッチャーから外すので、
        -- この後の CleanupStretcher で「降ろす」指示を出さないよう先に外しておく
        StretcherState.patient = nil
    else
        TriggerServerEvent('escort_vehicle:server:putInVehicle', patient.serverId, vehicleNetId, seat)
    end
end

-- 乗せている訓練用NPC が消えた（訓練終了・時間切れなど）ら患者を外す
CreateThread(function()
    while true do
        Wait(1000)
        local patient = StretcherState.patient
        if patient and patient.type == 'npc' then
            local exists = NetworkDoesNetworkIdExist(patient.netId)
                and DoesEntityExist(NetworkGetEntityFromNetworkId(patient.netId))
            if not exists then
                DebugLog('NPC patient no longer exists: ' .. DescribePatient(patient))
                StretcherState.patient = nil
                Notify(Config.Notifications.patientGone, 'inform')
            end
        end
    end
end)

-- ============================================================
-- 訓練用NPC のオーナー側（サーバーから呼ばれる）
-- ============================================================

---@param netId number
---@param timeoutMs number
---@return number|nil
local function WaitForNetEntity(netId, timeoutMs)
    local start = GetGameTimer()
    while GetGameTimer() - start < timeoutMs do
        if NetworkDoesNetworkIdExist(netId) then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if entity ~= 0 and DoesEntityExist(entity) then
                return entity
            end
        end
        Wait(100)
    end
    return nil
end

---@param entity number
local function EnsureControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local start = GetGameTimer()
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() - start < 1000 do
        Wait(50)
    end
    return NetworkHasControlOfEntity(entity)
end

RegisterNetEvent('escort_vehicle:client:npcPlaceOnStretcher', function(npcNetId, stretcherNetId)
    local npc = WaitForNetEntity(npcNetId, 3000)
    local stretcher = WaitForNetEntity(stretcherNetId, 5000)
    if not npc or not stretcher then
        DebugLog('NPC or stretcher not found for NPC placement')
        return
    end
    if not EnsureControl(npc) then
        DebugLog('WARNING: no control of NPC ' .. tostring(npcNetId))
    end

    ClearPedTasksImmediately(npc)
    if LoadAnimDict(Config.Stretcher.patientAnim.dict) then
        TaskPlayAnim(
            npc,
            Config.Stretcher.patientAnim.dict,
            Config.Stretcher.patientAnim.name,
            8.0, -8.0, -1, 1, 0, false, false, false
        )
    end

    local offset = Config.Stretcher.patientOffset
    AttachEntityToEntity(
        npc, stretcher, 0,
        offset.x, offset.y, offset.z,
        0.0, 0.0, 0.0,
        false, false, false, false, 2, true
    )
    DebugLog('NPC attached to stretcher: ' .. tostring(npcNetId))
end)

RegisterNetEvent('escort_vehicle:client:npcRemoveFromStretcher', function(npcNetId)
    local npc = WaitForNetEntity(npcNetId, 3000)
    if not npc then return end
    EnsureControl(npc)

    DetachEntity(npc, true, true)
    ClearPedTasksImmediately(npc)
    -- 倒れているアニメーションは ems_npc_rescue 側が戻す
    DebugLog('NPC detached from stretcher: ' .. tostring(npcNetId))
end)

RegisterNetEvent('escort_vehicle:client:npcPutInVehicle', function(npcNetId, vehicleNetId, seatIndex)
    local npc = WaitForNetEntity(npcNetId, 3000)
    local vehicle = WaitForNetEntity(vehicleNetId, 5000)
    if not npc or not vehicle then
        DebugLog('NPC or vehicle not found for NPC transport')
        return
    end
    EnsureControl(npc)

    DetachEntity(npc, true, false)
    ClearPedTasksImmediately(npc)

    if not IsVehicleSeatFree(vehicle, seatIndex) then
        DebugLog('Seat occupied during NPC warp')
        return
    end

    TaskWarpPedIntoVehicle(npc, vehicle, seatIndex)

    local start = GetGameTimer()
    while GetVehiclePedIsIn(npc, false) ~= vehicle and GetGameTimer() - start < 1500 do
        Wait(100)
    end
    if GetVehiclePedIsIn(npc, false) ~= vehicle then
        DebugLog('NPC warp failed, trying SetPedIntoVehicle')
        SetPedIntoVehicle(npc, vehicle, seatIndex)
    else
        DebugLog('NPC warp successful')
    end
end)

DebugLog('cl_patient.lua loaded')
