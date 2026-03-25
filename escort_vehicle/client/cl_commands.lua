-- client/cl_commands.lua v0.6.5 - コマンド・キーバインド・HUD・デバッグ

-- ============================================================
-- コマンド登録
-- ============================================================

-- ストレッチャー設置 / 回収
RegisterCommand('stretcher_place_toggle', function()
    TogglePlaceStretcher()
end, false)

-- 患者をストレッチャーに乗せる / 降ろす（トグル）
RegisterCommand('stretcher_patient_toggle', function()
    if not HasPermission() then return end
    if not StretcherState.Exists() then return end

    if StretcherState.patient then
        -- 患者がいる → 降ろす
        DebugLog('Removing patient from stretcher: ' .. StretcherState.patient)
        TriggerServerEvent('escort_vehicle:server:removeFromStretcher',
            StretcherState.patient)
        -- FIX #8: サーバー応答を信頼し、ここで状態リセット
        -- サーバーが失敗した場合でもクライアント側のリカバリは
        -- removeFromStretcher のサーバー側エラーログで追跡可能
        StretcherState.patient = nil
        Notify(Config.Notifications.patientRemoved, 'success')
    else
        -- 患者がいない → 乗せる
        local targetId = GetNearbyPatient()
        if not targetId then
            Notify(Config.Notifications.noPatient, 'error')
            return
        end

        DebugLog('Placing patient on stretcher: ' .. targetId)
        TriggerServerEvent('escort_vehicle:server:placeOnStretcher',
            targetId, ObjToNet(StretcherState.object))
        StretcherState.patient = targetId
        Notify(Config.Notifications.patientPlaced, 'success')
    end
end, false)

-- 完全収納
RegisterCommand('stretcher_store', function()
    StoreStretcher()
end, false)

-- ============================================================
-- キーマッピング（プレイヤーが F5 で変更可能）
-- ============================================================

RegisterKeyMapping('stretcher_place_toggle',    'ストレッチャー: 設置/回収',          'keyboard', Config.DefaultKeys.place)
RegisterKeyMapping('stretcher_patient_toggle',  'ストレッチャー: 患者を乗せる/降ろす', 'keyboard', Config.DefaultKeys.interact)
RegisterKeyMapping('stretcher_store',            'ストレッチャー: インベントリ収納',    'keyboard', Config.DefaultKeys.store)

-- ============================================================
-- ヘルプテキスト表示
-- FIX: ~INPUT_xxx~ はGTA固定コントロールでRegisterKeyMappingと連動しない
--      Config.DefaultKeys の実際のキー値を直接表示する
-- ============================================================

local helpText = ('~w~[~y~%s~w~] 設置/回収 | [~y~%s~w~] 患者を乗せる/降ろす | [~y~%s~w~] 収納'):format(
    Config.DefaultKeys.place,
    Config.DefaultKeys.interact,
    Config.DefaultKeys.store
)

CreateThread(function()
    while true do
        if StretcherState.carrying and StretcherState.Exists() then
            -- ストレッチャー持っている間のみ毎フレーム描画
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(helpText)
            EndTextCommandDisplayHelp(0, false, true, -1)
            Wait(0)
        else
            -- 持っていない間は負荷軽減
            Wait(1000)
        end
    end
end)

-- ============================================================
-- サーバーからのイベント（患者のクライアントで実行される）
-- ============================================================

RegisterNetEvent('escort_vehicle:client:placeOnStretcher', function(stretcherNetId)
    local playerPed = PlayerPedId()

    -- FIX #4: NetToObj で同期待ち（患者側クライアントでストレッチャーが未同期の可能性）
    local stretcher = nil
    local syncAttempts = 0
    while syncAttempts < 50 do
        stretcher = NetToObj(stretcherNetId)
        if stretcher and stretcher ~= 0 and DoesEntityExist(stretcher) then
            break
        end
        Wait(100)
        syncAttempts = syncAttempts + 1
    end

    if not stretcher or not DoesEntityExist(stretcher) then
        DebugLog('Stretcher not found for patient placement (NetId: ' .. tostring(stretcherNetId) .. ')')
        return
    end

    if not LoadAnimDict(Config.Stretcher.patientAnim.dict) then return end
    ClearPedTasks(playerPed)
    ClearPedTasksImmediately(playerPed)

    TaskPlayAnim(
        playerPed,
        Config.Stretcher.patientAnim.dict,
        Config.Stretcher.patientAnim.name,
        8.0, -8.0, -1, 1, 0, false, false, false
    )

    local offset = Config.Stretcher.patientOffset
    AttachEntityToEntity(
        playerPed, stretcher, 0,
        offset.x, offset.y, offset.z,
        0.0, 0.0, 0.0,
        false, false, false, false, 2, true
    )

    DebugLog('Patient attached to stretcher')
end)

RegisterNetEvent('escort_vehicle:client:removeFromStretcher', function()
    local playerPed = PlayerPedId()
    DetachEntity(playerPed, true, true)
    ClearPedTasks(playerPed)
    ClearPedTasksImmediately(playerPed)
    DebugLog('Patient detached from stretcher')
end)

RegisterNetEvent('escort_vehicle:client:putInVehicle', function(vehicleNetId, seatIndex)
    local playerPed = PlayerPedId()
    DebugLog('Received putInVehicle command')

    -- まず現在のアタッチメント解除（ストレッチャーから外す）
    DetachEntity(playerPed, true, false)
    ClearPedTasks(playerPed)
    ClearPedTasksImmediately(playerPed)

    -- 車両同期待ち（タイムアウト付き）
    local vehicle = nil
    local timeout = 0

    while timeout < 50 do
        vehicle = NetToVeh(vehicleNetId)
        if vehicle and DoesEntityExist(vehicle) then
            DebugLog('Vehicle synchronized')
            break
        end
        Wait(100)
        timeout = timeout + 1
    end

    if not vehicle or not DoesEntityExist(vehicle) then
        DebugLog('Vehicle sync failed')
        return
    end

    Wait(500)

    -- 座席最終確認
    if not IsVehicleSeatFree(vehicle, seatIndex) then
        DebugLog('Seat occupied during warp')
        return
    end

    -- 車両搭乗
    DebugLog('Executing TaskWarpPedIntoVehicle')
    TaskWarpPedIntoVehicle(playerPed, vehicle, seatIndex)

    -- 結果確認・代替手段
    Wait(1000)
    if GetVehiclePedIsIn(playerPed, false) ~= vehicle then
        DebugLog('Warp failed, trying SetPedIntoVehicle')
        SetPedIntoVehicle(playerPed, vehicle, seatIndex)
    else
        DebugLog('Warp successful')
    end
end)

-- ============================================================
-- デバッグコマンド
-- ============================================================

if Config.Debug then
    RegisterCommand('teststretcher', function()
        DebugLog('Manual stretcher deployment test')
        DeployStretcher()
    end, false)

    RegisterCommand('escortstatus', function()
        DebugLog('========================================')
        DebugLog('STATUS CHECK v0.6.5')
        DebugLog('Has Stretcher: ' .. tostring(StretcherState.object ~= nil))
        DebugLog('Is Carrying: '   .. tostring(StretcherState.carrying))
        DebugLog('Patient: '       .. tostring(StretcherState.patient))
        DebugLog('Has Permission: ' .. tostring(HasPermission()))

        if StretcherState.Exists() then
            local c = GetEntityCoords(StretcherState.object)
            DebugLog(('Stretcher Pos: %.2f, %.2f, %.2f'):format(c.x, c.y, c.z))
            DebugLog('Frozen: ' .. tostring(IsEntityPositionFrozen(StretcherState.object)))
        end

        DebugLog('========================================')
    end, false)
end

-- ============================================================
-- 起動ログ
-- ============================================================

DebugLog('========================================')
DebugLog('ESCORT + STRETCHER SYSTEM v0.6.5 LOADED')
DebugLog('Modules: cl_utils, cl_state, cl_stretcher, cl_vehicle, cl_target, cl_commands')
DebugLog('========================================')
