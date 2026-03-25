-- client/cl_target.lua v0.6.5 - ox_target 統合

CreateThread(function()
    if not exports.ox_target then
        DebugLog('WARNING: ox_target not found')
        return
    end

    DebugLog('Setting up ox_target integration...')

    -- ============================================================
    -- ストレッチャープロップへのターゲット
    -- ============================================================

    exports.ox_target:addModel(Config.Stretcher.model, {
        -- 患者を乗せる
        {
            label = '患者を乗せる',
            icon  = 'fa-solid fa-user-plus',
            distance = 2.5,
            canInteract = function()
                return HasPermission()
                    and not StretcherState.carrying
                    and not StretcherState.patient
            end,
            onSelect = function()
                local targetId = GetNearbyPatient()
                if not targetId then
                    Notify(Config.Notifications.noPatient, 'error')
                    return
                end
                if not StretcherState.Exists() then return end

                TriggerServerEvent('escort_vehicle:server:placeOnStretcher',
                    targetId, ObjToNet(StretcherState.object))
                StretcherState.patient = targetId
                Notify(Config.Notifications.patientPlaced, 'success')
            end,
        },
        -- 患者を降ろす
        {
            label = '患者を降ろす',
            icon  = 'fa-solid fa-user-minus',
            distance = 2.5,
            canInteract = function()
                return HasPermission() and StretcherState.patient ~= nil
            end,
            onSelect = function()
                TriggerServerEvent('escort_vehicle:server:removeFromStretcher',
                    StretcherState.patient)
                StretcherState.patient = nil
                Notify(Config.Notifications.patientRemoved, 'success')
            end,
        },
        -- インベントリに収納
        {
            label = 'インベントリに収納',
            icon  = 'fa-solid fa-box-archive',
            distance = 2.5,
            canInteract = function()
                return HasPermission()
                    and not StretcherState.carrying
                    and not StretcherState.patient
            end,
            onSelect = function()
                DebugLog('Storing stretcher via ox_target')
                CleanupStretcher()
                Notify(Config.Notifications.stretcherStored, 'success')
            end,
        },
    })

    -- ============================================================
    -- プレイヤーターゲット（直接ストレッチャーに乗せる）
    -- FIX: data.entity は Ped エンティティなので
    --      NetworkGetPlayerIndexFromPed → GetPlayerServerId で変換する
    -- ============================================================

    exports.ox_target:addGlobalPlayer({
        {
            label = 'ストレッチャーに乗せる',
            icon  = 'fa-solid fa-bed-pulse',
            distance = 3.0,
            canInteract = function()
                return HasPermission()
                    and StretcherState.Exists()
                    and not StretcherState.patient
            end,
            onSelect = function(data)
                -- data.entity = ターゲットの Ped エンティティ
                local ped = data.entity
                if not ped or not DoesEntityExist(ped) then
                    DebugLog('ERROR: target ped does not exist')
                    return
                end

                local playerIndex = NetworkGetPlayerIndexFromPed(ped)
                if playerIndex == -1 then
                    DebugLog('ERROR: could not get player index from ped')
                    Notify(Config.Notifications.noPatient, 'error')
                    return
                end

                local targetId = GetPlayerServerId(playerIndex)
                if not targetId or targetId == 0 then
                    DebugLog('ERROR: GetPlayerServerId returned 0')
                    Notify(Config.Notifications.noPatient, 'error')
                    return
                end

                if not StretcherState.Exists() then return end

                DebugLog('Placing player on stretcher via ox_target - ServerId: ' .. targetId)
                TriggerServerEvent('escort_vehicle:server:placeOnStretcher',
                    targetId, ObjToNet(StretcherState.object))
                StretcherState.patient = targetId
                Notify(Config.Notifications.patientPlaced, 'success')
            end,
        },
    })

    DebugLog('ox_target integration complete')
end)

DebugLog('cl_target.lua loaded')
