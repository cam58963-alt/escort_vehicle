-- client/cl_vehicle.lua v0.6.5 - 車両乗車時の自動搬送処理

local isProcessingVehicleEntry = false
local lastProcessedTime = 0  -- FIX #11: 二重発火防止用タイムスタンプ
local DEBOUNCE_MS = 2000     -- 同じ乗車イベントを2秒間無視

-- ============================================================
-- 車両乗車検出 → ストレッチャー＆患者の自動処理
-- ============================================================

local function ProcessVehicleEntry()
    -- FIX #11: 二重発火防止（baseevents + gameEventTriggered）
    local now = GetGameTimer()
    if isProcessingVehicleEntry or (now - lastProcessedTime) < DEBOUNCE_MS then
        return
    end
    isProcessingVehicleEntry = true
    lastProcessedTime = now

    local playerPed = PlayerPedId()

    -- ストレッチャーを持っていなければ何もしない（早期リターン）
    if not StretcherState.Exists() then
        isProcessingVehicleEntry = false
        return
    end

    -- 車両乗車確認（同期待ち）
    local vehicle   = 0
    local attempts  = 0
    local maxAttempts = 25

    while attempts < maxAttempts do
        if IsPedInAnyVehicle(playerPed, false) then
            vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle ~= 0 then break end
        end
        Wait(100)
        attempts = attempts + 1
    end

    if vehicle == 0 then
        isProcessingVehicleEntry = false
        return
    end

    -- 座席確認（運転席 -1 / 助手席 0 のみ処理）
    local mySeat = nil
    for i = -1, 0 do
        if GetPedInVehicleSeat(vehicle, i) == playerPed then
            mySeat = i
            break
        end
    end

    if mySeat == nil then
        -- 後部座席等 → 処理しない
        isProcessingVehicleEntry = false
        return
    end

    -- ストレッチャー処理（車両種別を問わず全車両で実行）
    DebugLog('Processing stretcher on vehicle entry')

    local vehicleModel = GetEntityModel(vehicle)

    if StretcherState.patient then
        -- 患者がいる → 車両に搬送（後部座席から優先）
        -- FIX #3: GetVehicleModelNumberOfSeats は座席総数を返す（運転席含む）
        -- FiveM の座席インデックス: -1=運転席, 0=助手席, 1=後部左, 2=後部右, ...
        -- 乗客座席は 0 ～ (totalSeats - 2) の範囲
        local totalSeats = GetVehicleModelNumberOfSeats(vehicleModel)
        local maxPassengerIndex = totalSeats - 2  -- 最後の乗客座席インデックス
        local freeSeat = nil

        for seatIndex = maxPassengerIndex, 0, -1 do
            if IsVehicleSeatFree(vehicle, seatIndex) then
                freeSeat = seatIndex
                break
            end
        end

        if freeSeat then
            DebugLog('Transporting patient to vehicle seat: ' .. freeSeat)

            TriggerServerEvent('escort_vehicle:server:putInVehicle',
                StretcherState.patient, VehToNet(vehicle), freeSeat)

            -- FIX #7: patient は CleanupStretcher 内でデタッチされる
            CleanupStretcher()
            Notify(Config.Notifications.patientInVehicle, 'success')
        else
            Notify(Config.Notifications.noFreeSeats, 'error')
        end
    else
        -- 患者なし → ストレッチャーのみ収納
        DebugLog('Storing empty stretcher on vehicle entry')
        CleanupStretcher()
        Notify(Config.Notifications.stretcherStored, 'success')
    end

    isProcessingVehicleEntry = false
end

-- ============================================================
-- イベントハンドラ
-- ============================================================

AddEventHandler('baseevents:enteredVehicle', function(vehicle, seat, displayName, netId)
    ProcessVehicleEntry()
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkPlayerEnteredVehicle' then
        ProcessVehicleEntry()
    end
end)

DebugLog('cl_vehicle.lua loaded')
