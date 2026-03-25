-- client/cl_stretcher.lua v0.6.5 - ストレッチャーの展開・設置・回収・クリーンアップ

-- ============================================================
-- ストレッチャーをプレイヤーにアタッチする共通処理
-- ============================================================

---@param ped number プレイヤーの Ped
---@param obj number ストレッチャーのエンティティ
local function AttachStretcherToPed(ped, obj)
    local offset = Config.Stretcher.carryOffset
    AttachEntityToEntity(
        obj, ped,
        GetPedBoneIndex(ped, 28422), -- 右手ボーン
        offset.x, offset.y, offset.z,
        offset.rotX, offset.rotY, offset.rotZ,
        false, false, false, false, 2, true
    )
end

---@param ped number
local function PlayPushAnim(ped)
    if not LoadAnimDict(Config.Stretcher.pushAnim.dict) then return end
    TaskPlayAnim(
        ped,
        Config.Stretcher.pushAnim.dict,
        Config.Stretcher.pushAnim.name,
        8.0, 8.0, -1, 50, 0, false, false, false
    )
end

-- ============================================================
-- ストレッチャー展開
-- ============================================================

---@return boolean 成功したか
function DeployStretcher()
    DebugLog('=== DEPLOYING STRETCHER FROM ITEM ===')

    if not HasPermission() then
        Notify('権限がありません', 'error')
        return false
    end

    if StretcherState.Exists() then
        Notify('既にストレッチャーを展開しています', 'error')
        return false
    end

    -- モデル読み込み（タイムアウト付き）
    if not LoadModel(Config.Stretcher.model) then
        DebugLog('ERROR: Failed to load stretcher model')
        Notify('ストレッチャーモデルの読み込みに失敗', 'error')
        return false
    end

    local playerPed = PlayerPedId()
    local coords    = GetEntityCoords(playerPed)

    -- オブジェクト生成
    local obj = CreateObject(Config.Stretcher.model, coords.x, coords.y, coords.z, true, true, false)

    if not DoesEntityExist(obj) then
        DebugLog('ERROR: Failed to create stretcher object')
        Notify('ストレッチャーの生成に失敗', 'error')
        return false
    end

    DebugLog('Stretcher object created: ' .. tostring(obj))

    -- 物理設定
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCollision(obj, false, false)

    -- FIX #5: ネットワーク同期を安定させる
    -- NetworkRegisterEntityAsNetworked して NetId を確保
    if NetworkGetEntityIsNetworked(obj) then
        local netId = ObjToNet(obj)
        DebugLog('Stretcher NetId: ' .. tostring(netId))
    end

    -- プレイヤーにアタッチ
    AttachStretcherToPed(playerPed, obj)
    PlayPushAnim(playerPed)

    -- 状態更新
    StretcherState.object   = obj
    StretcherState.carrying = true

    Notify(Config.Notifications.stretcherDeployed, 'success')
    DebugLog('Stretcher deployed successfully')
    return true
end

-- ============================================================
-- クリーンアップ（削除＆アイテム返却）
-- FIX #6: 患者がアタッチされている場合は先にデタッチする
-- ============================================================

function CleanupStretcher()
    DebugLog('Cleaning up stretcher object')

    -- FIX #6: 患者がストレッチャーにアタッチされていたら先にデタッチ
    if StretcherState.patient then
        DebugLog('Patient still on stretcher during cleanup - requesting detach')
        TriggerServerEvent('escort_vehicle:server:removeFromStretcher', StretcherState.patient)
        StretcherState.patient = nil
    end

    if StretcherState.Exists() then
        local obj = StretcherState.object
        if StretcherState.carrying then
            DetachEntity(obj, true, true)
            ClearPedTasks(PlayerPedId())
        else
            FreezeEntityPosition(obj, false)
        end
        DeleteObject(obj)
    end

    StretcherState.Reset()

    -- アイテムはトグル方式（return false）なので
    -- インベントリに常に1個残っている。AddItem/RemoveItem は不要
end

-- ============================================================
-- 設置 / 回収 トグル
-- ============================================================

---@return boolean 処理を実行したか
function TogglePlaceStretcher()
    if not HasPermission() then return false end
    if not StretcherState.Exists() then return false end

    local playerPed = PlayerPedId()

    if StretcherState.carrying then
        -- === 設置処理 ===
        DebugLog('Placing stretcher on ground')

        local obj = StretcherState.object
        DetachEntity(obj, true, true)
        ClearPedTasks(playerPed)

        local coords   = GetEntityCoords(playerPed)
        local heading   = GetEntityHeading(playerPed)
        local fwdX      = GetEntityForwardX(playerPed)
        local fwdY      = GetEntityForwardY(playerPed)
        local distance  = Config.Stretcher.placeDistance

        local placeX = coords.x + (fwdX * distance)
        local placeY = coords.y + (fwdY * distance)

        -- 地面検出（精密）
        local foundGround, groundZ = GetGroundZFor_3dCoord(placeX, placeY, coords.z + 2.0, false)

        -- FIX #10: groundZ が 0.0 の場合も無効として扱う
        if not foundGround or groundZ < 1.0 then
            local rayHandle = StartShapeTestRay(
                placeX, placeY, coords.z + 2.0,
                placeX, placeY, coords.z - 5.0,
                1, playerPed, 0
            )
            -- FIX: GetShapeTestResult は (retval, hit, endCoords, surfaceNormal, entityHit) を返す
            local _, hit, endCoords = GetShapeTestResult(rayHandle)
            if hit == 1 and endCoords and endCoords.z > 1.0 then
                groundZ = endCoords.z
            else
                groundZ = coords.z - 1.0
            end
        end

        local finalZ = groundZ + 0.25 -- 地面から25cm浮かせる

        SetEntityCoords(obj, placeX, placeY, finalZ, false, false, false, true)
        SetEntityHeading(obj, heading)

        -- 物理有効化・完全固定
        SetEntityCollision(obj, true, true)
        Wait(100)
        PlaceObjectOnGroundProperly(obj)
        Wait(100)
        FreezeEntityPosition(obj, true)

        StretcherState.carrying = false
        Notify(Config.Notifications.stretcherPlaced, 'success')
    else
        -- === 回収処理 ===
        DebugLog('Picking up stretcher')

        local obj = StretcherState.object
        FreezeEntityPosition(obj, false)
        SetEntityCollision(obj, false, false)

        AttachStretcherToPed(playerPed, obj)
        PlayPushAnim(playerPed)

        StretcherState.carrying = true
        Notify(Config.Notifications.stretcherPickedUp, 'success')
    end

    return true
end

-- ============================================================
-- 完全収納（アイテムに戻す）
-- ============================================================

---@return boolean 収納成功したか
function StoreStretcher()
    if not HasPermission() then return false end

    if not StretcherState.Exists() then
        Notify(Config.Notifications.noStretcher, 'error')
        return false
    end

    if StretcherState.patient then
        Notify(Config.Notifications.patientOnStretcher, 'error')
        return false
    end

    DebugLog('Storing stretcher')
    CleanupStretcher()
    Notify(Config.Notifications.stretcherStored, 'success')
    return true
end

-- ============================================================
-- ox_inventory Export（トグル機能）
-- ============================================================

exports('useStretcher', function(data, slot)
    DebugLog('========================================')
    DebugLog('useStretcher Export called from ox_inventory')
    DebugLog('========================================')

    -- 既に展開中 → 収納（トグル）
    if StretcherState.Exists() then
        DebugLog('Stretcher already deployed - storing instead')

        if StretcherState.patient then
            Notify(Config.Notifications.patientOnStretcher, 'error')
            return false
        end

        CleanupStretcher()
        Notify(Config.Notifications.stretcherStored, 'success')
        return false
    end

    -- 展開処理
    local success = DeployStretcher()
    DebugLog('Stretcher deployment result: ' .. tostring(success))

    -- false を返す = ox_inventory にアイテム消費させない（トグル方式）
    return false
end)

-- ============================================================
-- アニメーション監視スレッド
-- ドア開閉・鍵使用などで pushAnim が解除された場合に自動再適用
-- ============================================================

local ANIM_CHECK_INTERVAL = 200  -- ms（負荷と反応速度のバランス）
local pushAnimDict = Config.Stretcher.pushAnim.dict
local pushAnimName = Config.Stretcher.pushAnim.name

CreateThread(function()
    while true do
        if StretcherState.carrying and StretcherState.Exists() then
            local ped = PlayerPedId()

            -- pushAnim が再生中でなければ再適用
            if not IsEntityPlayingAnim(ped, pushAnimDict, pushAnimName, 3) then
                DebugLog('pushAnim interrupted - reapplying')
                PlayPushAnim(ped)

                -- アタッチも念のため再適用（ボーンズレ防止）
                if not IsEntityAttachedToEntity(StretcherState.object, ped) then
                    DebugLog('Stretcher detached - reattaching')
                    AttachStretcherToPed(ped, StretcherState.object)
                end
            end

            Wait(ANIM_CHECK_INTERVAL)
        else
            Wait(1000)
        end
    end
end)

DebugLog('cl_stretcher.lua loaded')
