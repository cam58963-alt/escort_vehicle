-- client/utils.lua v0.5.0-dev

-- デバッグログ
function DebugLog(message)
    if Config.Debug then
        print('^3[ESCORT_DEV]^7 ' .. message)
    end
end

-- 権限チェック
function HasPermission()
    if not Config.JobRestriction.enabled then return true end
    
    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    
    if not success or not playerData or not playerData.job then
        return false
    end
    
    local jobName = playerData.job.name
    local isOnDuty = playerData.job.onduty
    
    if not Config.IsJobAllowed(jobName) then
        return false
    end
    
    if not Config.JobRestriction.allowOffDuty and not isOnDuty then
        return false
    end
    
    return true
end

-- 【重要】TK Ambulance Export統合（StateBagフォールバック付き）
function GetTKDragTarget()
    if not Config.TKIntegration.enabled then return nil end
    
    -- 1. Export方式（優先）
    local success, result = pcall(function()
        return exports.tk_ambulancejob:getDragTarget()
    end)
    
    if success and result and result > 0 then
        DebugLog('TK Drag Target (Export): ' .. result)
        return result
    end
    
    -- 2. StateBag方式（フォールバック）
    local myState = LocalPlayer.state
    if myState.dragTarget and myState.dragTarget > 0 then
        DebugLog('TK Drag Target (StateBag): ' .. myState.dragTarget)
        return myState.dragTarget
    end
    
    return nil
end

-- 近くの患者を取得（TK統合）
function GetNearbyPatient()
    -- TKドラッグ対象（最優先）
    local tkTarget = GetTKDragTarget()
    if tkTarget then return tkTarget end
    
    -- 物理的に近いプレイヤー
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closestPlayer = nil
    local closestDistance = Config.Stretcher.patientDistance
    
    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= myPed and DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(myCoords - targetCoords)
            if distance < closestDistance then
                closestDistance = distance
                closestPlayer = player
            end
        end
    end
    
    if closestPlayer then
        return GetPlayerServerId(closestPlayer)
    end
    
    return nil
end

-- 最寄りのストレッチャー対応車両を取得
function GetClosestStretcherVehicle()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closestVehicle = nil
    local closestDistance = Config.Stretcher.interactionDistance
    
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehicleModel = GetEntityModel(vehicle)
            if Config.IsStretcherVehicle(vehicleModel) then
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(myCoords - vehicleCoords)
                if distance < closestDistance then
                    closestDistance = distance
                    closestVehicle = vehicle
                end
            end
        end
    end
    
    return closestVehicle
end

-- アニメーション・モデル読み込み
function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

function LoadModel(model)
    if HasModelLoaded(model) then return end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
end

-- 通知関数
function Notify(message, type, duration)
    exports.qbx_core:Notify(message, type or 'inform', duration or 5000)
end
