-- client/main.lua v0.5.0-dev - Complete Feature Integration

-- 状態管理変数
local StretcherObject = nil
local StretcherPatient = nil
local IsCarryingStretcher = false

-- ============================================================
-- ストレッチャー展開関数
-- ============================================================

local function DeployStretcher()
    DebugLog('=== DEPLOYING STRETCHER FROM ITEM ===')
    
    if not HasPermission() then 
        Notify('権限がありません', 'error')
        return false
    end
    
    if StretcherObject and DoesEntityExist(StretcherObject) then
        Notify('既にストレッチャーを展開しています', 'error')
        return false
    end
    
    local playerPed = PlayerPedId()
    
    -- モデル読み込み
    LoadModel(Config.Stretcher.model)
    
    if not HasModelLoaded(Config.Stretcher.model) then
        DebugLog('ERROR: Failed to load stretcher model')
        Notify('ストレッチャーモデルの読み込みに失敗', 'error')
        return false
    end
    
    -- ストレッチャー生成
    local coords = GetEntityCoords(playerPed)
    StretcherObject = CreateObject(Config.Stretcher.model, coords.x, coords.y, coords.z, true, true, false)
    
    if not DoesEntityExist(StretcherObject) then
        DebugLog('ERROR: Failed to create stretcher object')
        Notify('ストレッチャーの生成に失敗', 'error')
        return false
    end
    
    DebugLog('Stretcher object created: ' .. tostring(StretcherObject))
    
    -- 物理設定（車両貫通）
    SetEntityCollision(StretcherObject, false, false)
    SetEntityCompletelyDisableCollision(StretcherObject, false, false)
    SetEntityAsMissionEntity(StretcherObject, true, true)
    
    -- 【ユーザー指定値】プレイヤーにアタッチ
    local offset = Config.Stretcher.carryOffset
    AttachEntityToEntity(
        StretcherObject,
        playerPed,
        GetPedBoneIndex(playerPed, 28422), -- 右手のボーン
        offset.x, offset.y, offset.z,
        offset.rotX, offset.rotY, offset.rotZ,
        false, false, false, false, 2, true
    )
    
    -- アニメーション
    LoadAnimDict(Config.Stretcher.pushAnim.dict)
    TaskPlayAnim(playerPed, Config.Stretcher.pushAnim.dict, Config.Stretcher.pushAnim.name, 8.0, 8.0, -1, 50, 0, false, false, false)
    
    IsCarryingStretcher = true
    
    Notify(Config.Notifications.stretcherDeployed, 'success')
    
    DebugLog('Stretcher deployed successfully with user-specified offset')
    return true
end

-- ============================================================
-- 【重要】ox_inventoryから呼び出されるExport関数（トグル機能）
-- ============================================================

exports('useStretcher', function(data, slot)
    DebugLog('========================================')
    DebugLog('useStretcher Export called from ox_inventory')
    DebugLog('========================================')
    
    -- 【新機能】既に展開している場合は収納（トグル）
    if StretcherObject and DoesEntityExist(StretcherObject) then
        DebugLog('Stretcher already deployed - storing instead')
        
        -- 患者が乗っている場合は収納不可
        if StretcherPatient then
            Notify(Config.Notifications.patientOnStretcher, 'error')
            return false
        end
        
        -- 完全収納処理
        CleanupStretcher()
        Notify(Config.Notifications.stretcherStored, 'success')
        return false
    end
    
    -- 展開処理
    local success = DeployStretcher()
    
    DebugLog('Stretcher deployment result: ' .. tostring(success))
    
    -- falseを返すとアイテムが消費されない（ツール扱い）
    return false
end)

-- ============================================================
-- ストレッチャークリーンアップ・アイテム返却
-- ============================================================

function CleanupStretcher()
    DebugLog('Cleaning up stretcher and returning to inventory')
    
    if StretcherObject and DoesEntityExist(StretcherObject) then
        if IsCarryingStretcher then
            DetachEntity(StretcherObject, true, true)
            ClearPedTasks(PlayerPedId())
        else
            FreezeEntityPosition(StretcherObject, false)
        end
        DeleteObject(StretcherObject)
    end
    
    StretcherObject = nil
    StretcherPatient = nil
    IsCarryingStretcher = false
    
    -- アイテムをインベントリに返却
    TriggerServerEvent('escort_vehicle:server:returnStretcherItem')
end

-- ============================================================
-- キーバインドコマンド（プレイヤーカスタマイズ対応）
-- ============================================================

-- ストレッチャー設置/回収
RegisterCommand('stretcher_place_toggle', function()
    if not HasPermission() then return end
    
    if not StretcherObject or not DoesEntityExist(StretcherObject) then
        return -- 誤操作防止
    end
    
    local playerPed = PlayerPedId()
    
    if IsCarryingStretcher then
        -- 設置処理（地面沈み込み完全防止）
        DebugLog('Placing stretcher on ground with anti-clipping')
        
        DetachEntity(StretcherObject, true, true)
        ClearPedTasks(playerPed)
        
        local coords = GetEntityCoords(playerPed)
        local heading = GetEntityHeading(playerPed)
        local forwardX = GetEntityForwardX(playerPed)
        local forwardY = GetEntityForwardY(playerPed)
        
        local distance = Config.Stretcher.placeDistance
        local placeX = coords.x + (forwardX * distance)
        local placeY = coords.y + (forwardY * distance)
        
        -- 地面検出（精密）
        local foundGround, groundZ = GetGroundZFor_3dCoord(placeX, placeY, coords.z + 2.0, false)
        if not foundGround then
            local rayHandle = StartShapeTestRay(
                placeX, placeY, coords.z + 2.0,
                placeX, placeY, coords.z - 5.0,
                1, playerPed, 0
            )
            local _, hit, _, _, hitZ = GetShapeTestResult(rayHandle)
            groundZ = hit and hitZ or (coords.z - 1.0)
        end
        
        local finalZ = groundZ + 0.25  -- 地面から25cm浮かせる
        
        SetEntityCoords(StretcherObject, placeX, placeY, finalZ, false, false, false, true)
        SetEntityHeading(StretcherObject, heading)
        
        -- 物理有効化・完全固定
        SetEntityCollision(StretcherObject, true, true)
        Wait(100)
        PlaceObjectOnGroundProperly(StretcherObject)
        Wait(100)
        FreezeEntityPosition(StretcherObject, true)  -- 完全固定（沈み込み防止）
        
        IsCarryingStretcher = false
        Notify(Config.Notifications.stretcherPlaced, 'success')
        
    else
        -- 回収処理
        DebugLog('Picking up stretcher')
        
        FreezeEntityPosition(StretcherObject, false)
        SetEntityCollision(StretcherObject, false, false)
        
        -- 【ユーザー指定値】で再アタッチ
        local offset = Config.Stretcher.carryOffset
        AttachEntityToEntity(
            StretcherObject, playerPed, GetPedBoneIndex(playerPed, 28422),
            offset.x, offset.y, offset.z,
            offset.rotX, offset.rotY, offset.rotZ,
            false, false, false, false, 2, true
        )
        
        -- アニメーション再開
        LoadAnimDict(Config.Stretcher.pushAnim.dict)
        TaskPlayAnim(playerPed, Config.Stretcher.pushAnim.dict, Config.Stretcher.pushAnim.name, 8.0, 8.0, -1, 50, 0, false, false, false)
        
        IsCarryingStretcher = true
        Notify(Config.Notifications.stretcherPickedUp, 'success')
    end
end, false)

-- 患者をストレッチャーに乗せる（簡易版）
RegisterCommand('stretcher_place_patient', function()
    if not HasPermission() then return end
    
    if not StretcherObject or not DoesEntityExist(StretcherObject) then
        return
    end
    
    if StretcherPatient then
        Notify(Config.Notifications.alreadyHasPatient, 'error')
        return
    end
    
    -- TK統合：近くの患者を自動検索
    local targetId = GetNearbyPatient()
    if not targetId then
        Notify(Config.Notifications.noPatient, 'error')
        return
    end
    
    DebugLog('Placing patient on stretcher: ' .. targetId)
    
    TriggerServerEvent('escort_vehicle:server:placeOnStretcher', targetId, ObjToNet(StretcherObject))
    
    StretcherPatient = targetId
    Notify(Config.Notifications.patientPlaced, 'success')
end, false)

-- 【新機能】完全収納コマンド（車外でも可能）
RegisterCommand('stretcher_store', function()
    if not HasPermission() then return end
    
    if not StretcherObject or not DoesEntityExist(StretcherObject) then
        Notify(Config.Notifications.noStretcher, 'error')
        return
    end
    
    -- 患者が乗っている場合は収納不可
    if StretcherPatient then
        Notify(Config.Notifications.patientOnStretcher, 'error')
        return
    end
    
    DebugLog('Storing stretcher via command')
    CleanupStretcher()
    Notify(Config.Notifications.stretcherStored, 'success')
end, false)

-- キーマッピング（プレイヤーがF5で変更可能）
RegisterKeyMapping('stretcher_place_toggle', 'Stretcher: Place/Pickup', 'keyboard', Config.DefaultKeys.place)
RegisterKeyMapping('stretcher_place_patient', 'Stretcher: Load Patient', 'keyboard', Config.DefaultKeys.interact)
RegisterKeyMapping('stretcher_store', 'Stretcher: Store to Inventory', 'keyboard', Config.DefaultKeys.store)

-- ============================================================
-- OX Target統合（車外回収機能追加）
-- ============================================================

CreateThread(function()
    if not exports.ox_target then
        DebugLog('WARNING: ox_target not found')
        return
    end
    
    DebugLog('Setting up ox_target with store functionality...')
    
    -- ストレッチャープロップへのターゲット
    exports.ox_target:addModel(Config.Stretcher.model, {
        {
            label = '患者を乗せる',
            icon = 'fa-solid fa-user-plus',
            distance = 2.5,
            canInteract = function()
                return HasPermission() and not IsCarryingStretcher and not StretcherPatient
            end,
            onSelect = function()
                local targetId = GetNearbyPatient()
                if targetId then
                    TriggerServerEvent('escort_vehicle:server:placeOnStretcher', targetId, ObjToNet(StretcherObject))
                    StretcherPatient = targetId
                    Notify(Config.Notifications.patientPlaced, 'success')
                else
                    Notify(Config.Notifications.noPatient, 'error')
                end
            end
        },
        {
            label = '患者を降ろす',
            icon = 'fa-solid fa-user-minus',
            distance = 2.5,
            canInteract = function()
                return HasPermission() and StretcherPatient ~= nil
            end,
            onSelect = function()
                TriggerServerEvent('escort_vehicle:server:removeFromStretcher', StretcherPatient)
                StretcherPatient = nil
                Notify(Config.Notifications.patientRemoved, 'success')
            end
        },
        {
            -- 【新機能】ターゲットで直接収納
            label = 'インベントリに収納',
            icon = 'fa-solid fa-box-archive',
            distance = 2.5,
            canInteract = function()
                return HasPermission() and not IsCarryingStretcher and not StretcherPatient
            end,
            onSelect = function()
                DebugLog('Storing stretcher via ox_target')
                CleanupStretcher()
                Notify(Config.Notifications.stretcherStored, 'success')
            end
        }
    })
    
    -- プレイヤーへのターゲット（即座にストレッチャーに乗せる）
    exports.ox_target:addGlobalPlayer({
        {
            label = 'ストレッチャーに乗せる',
            icon = 'fa-solid fa-bed-pulse',
            distance = 3.0,
            canInteract = function()
                return HasPermission() and StretcherObject and DoesEntityExist(StretcherObject) and not StretcherPatient
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(data.entity)
                if targetId then
                    TriggerServerEvent('escort_vehicle:server:placeOnStretcher', targetId, ObjToNet(StretcherObject))
                    StretcherPatient = targetId
                    Notify(Config.Notifications.patientPlaced, 'success')
                end
            end
        }
    })
    
    DebugLog('OX Target integration complete with store functionality')
end)

-- ============================================================
-- 車両乗車処理（自動搬送・アイテム返却）
-- ============================================================

local isProcessingVehicleEntry = false

local function ProcessVehicleEntry()
    if isProcessingVehicleEntry then return end
    isProcessingVehicleEntry = true
    
    local playerPed = PlayerPedId()
    
    -- 車両乗車確認（同期待ち）
    local attempts = 0
    local maxAttempts = 25
    local vehicle = 0
    
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
    
    -- 座席確認（運転席・助手席のみ）
    local seat = -2
    for i = -1, 1 do
        if GetPedInVehicleSeat(vehicle, i) == playerPed then
            seat = i
            break
        end
    end
    
    if seat ~= -1 and seat ~= 0 then
        isProcessingVehicleEntry = false
        return
    end
    
    -- ストレッチャー対応車両か確認
    local vehicleModel = GetEntityModel(vehicle)
    if not Config.IsStretcherVehicle(vehicleModel) then
        isProcessingVehicleEntry = false
        return
    end
    
    -- ストレッチャー処理
    if StretcherObject and DoesEntityExist(StretcherObject) then
        DebugLog('Processing stretcher in vehicle entry')
        
        if StretcherPatient then
            -- 患者がいる場合：車両に搬送
            local maxSeats = GetVehicleModelNumberOfSeats(vehicleModel)
            local freeSeat = nil
            
            for seatIndex = 0, maxSeats - 1 do
                if IsVehicleSeatFree(vehicle, seatIndex) then
                    freeSeat = seatIndex
                    break
                end
            end
            
            if freeSeat then
                DebugLog('Transporting patient to vehicle seat: ' .. freeSeat)
                
                TriggerServerEvent('escort_vehicle:server:putInVehicle', 
                    StretcherPatient, VehToNet(vehicle), freeSeat)
                
                -- ストレッチャー削除・アイテム返却
                CleanupStretcher()
                
                Notify(Config.Notifications.patientInVehicle, 'success')
            else
                Notify('車両に空きがありません', 'error')
            end
        else
            -- 患者がいない場合：ストレッチャーのみ収納
            DebugLog('Storing empty stretcher')
            CleanupStretcher()
            Notify(Config.Notifications.stretcherStored, 'success')
        end
    end
    
    isProcessingVehicleEntry = false
end

-- ============================================================
-- イベント検出
-- ============================================================

AddEventHandler('baseevents:enteredVehicle', function(vehicle, seat, displayName, netId)
    ProcessVehicleEntry()
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkPlayerEnteredVehicle' then
        ProcessVehicleEntry()
    end
end)

-- ============================================================
-- サーバーからのイベント
-- ============================================================

RegisterNetEvent('escort_vehicle:client:placeOnStretcher', function(stretcherNetId)
    local playerPed = PlayerPedId()
    local stretcher = NetToObj(stretcherNetId)
    
    if not DoesEntityExist(stretcher) then
        DebugLog('Stretcher not found for patient placement')
        return
    end
    
    LoadAnimDict(Config.Stretcher.patientAnim.dict)
    ClearPedTasks(playerPed)
    ClearPedTasksImmediately(playerPed)
    
    TaskPlayAnim(playerPed, Config.Stretcher.patientAnim.dict, Config.Stretcher.patientAnim.name, 8.0, -8.0, -1, 1, 0, false, false, false)
    
    local offset = Config.Stretcher.patientOffset
    AttachEntityToEntity(playerPed, stretcher, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    
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
    
    -- 車両同期待ち
    local vehicle = nil
    local timeout = 0
    
    while timeout < 50 do
        vehicle = NetToVeh(vehicleNetId)
        if DoesEntityExist(vehicle) then
            DebugLog('Vehicle synchronized')
            break
        end
        Wait(100)
        timeout = timeout + 1
    end
    
    if not DoesEntityExist(vehicle) then
        DebugLog('Vehicle sync failed')
        return
    end
    
    -- 全アタッチメント・タスク解除
    DetachEntity(playerPed, true, false)
    ClearPedTasks(playerPed)
    ClearPedTasksImmediately(playerPed)
    Wait(500)
    
    -- 座席最終確認
    if not IsVehicleSeatFree(vehicle, seatIndex) then
        DebugLog('Seat occupied during warp')
        return
    end
    
    -- 車両搭乗実行
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
-- ヘルプテキスト表示（GTAコントロール表示）
-- ============================================================

CreateThread(function()
    while true do
        Wait(0)
        
        if IsCarryingStretcher and StretcherObject and DoesEntityExist(StretcherObject) then
            BeginTextCommandDisplayHelp('STRING')
            -- GTAの標準コントロール表示を使用（プレイヤーのキー設定に自動対応）
            AddTextComponentSubstringPlayerName('~INPUT_DETONATE~ 設置/回収 | ~INPUT_PICKUP~ 患者を乗せる | ~INPUT_VEH_HORN~ 収納')
            EndTextCommandDisplayHelp(0, false, true, -1)
        else
            Wait(500)
        end
    end
end)

-- ============================================================
-- デバッグコマンド
-- ============================================================

RegisterCommand('teststretcher', function()
    DebugLog('Manual stretcher deployment test')
    DeployStretcher()
end, false)

RegisterCommand('escortstatus', function()
    DebugLog('========================================')
    DebugLog('STATUS CHECK v0.5.0-dev')
    DebugLog('Has Stretcher: ' .. tostring(StretcherObject ~= nil))
    DebugLog('Is Carrying: ' .. tostring(IsCarryingStretcher))
    DebugLog('Stretcher Patient: ' .. tostring(StretcherPatient))
    DebugLog('TK Drag Target: ' .. tostring(GetTKDragTarget()))
    DebugLog('Has Permission: ' .. tostring(HasPermission()))
    
    if StretcherObject and DoesEntityExist(StretcherObject) then
        local coords = GetEntityCoords(StretcherObject)
        DebugLog('Stretcher Position: ' .. coords.x .. ', ' .. coords.y .. ', ' .. coords.z)
        DebugLog('Stretcher Frozen: ' .. tostring(IsEntityPositionFrozen(StretcherObject)))
    end
    
    DebugLog('========================================')
end, false)

DebugLog('========================================')
DebugLog('ESCORT + STRETCHER SYSTEM v0.5.0-dev LOADED')
DebugLog('NEW FEATURES:')
DebugLog('- Store stretcher outside vehicle (3 methods)')
DebugLog('- Item toggle functionality (deploy/store)')
DebugLog('- Enhanced ox_target integration')
DebugLog('- User-specified carry offset applied')
DebugLog('- TK Export integration with StateBag fallback')
DebugLog('========================================')
