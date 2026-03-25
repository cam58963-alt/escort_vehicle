-- client/cl_utils.lua v0.6.5 - ユーティリティ関数

local LOAD_TIMEOUT_MS = 5000  -- モデル/アニメーション読み込みの最大待ち時間

-- ============================================================
-- デバッグ
-- ============================================================

function DebugLog(message)
    if Config.Debug then
        print('^3[ESCORT_DEV]^7 ' .. tostring(message))
    end
end

-- ============================================================
-- 権限チェック
-- ============================================================

function HasPermission()
    if not Config.JobRestriction.enabled then return true end

    local success, playerData = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)

    if not success or not playerData or not playerData.job then
        return false
    end

    local jobName  = playerData.job.name
    local isOnDuty = playerData.job.onduty

    if not Config.IsJobAllowed(jobName) then
        return false
    end

    if not Config.JobRestriction.allowOffDuty and not isOnDuty then
        return false
    end

    return true
end

-- ============================================================
-- 通知
-- ============================================================

function Notify(message, type, duration)
    exports.qbx_core:Notify(message, type or 'inform', duration or 5000)
end

-- ============================================================
-- アセット読み込み（タイムアウト付き）
-- ============================================================

---@param dict string アニメーション辞書名
---@return boolean 読み込み成功したか
function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local elapsed = 0
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        elapsed = elapsed + 10
        if elapsed >= LOAD_TIMEOUT_MS then
            DebugLog('ERROR: AnimDict load timeout: ' .. dict)
            return false
        end
    end
    return true
end

---@param model number|string モデルハッシュまたは名前
---@return boolean 読み込み成功したか
function LoadModel(model)
    if HasModelLoaded(model) then return true end

    RequestModel(model)
    local elapsed = 0
    while not HasModelLoaded(model) do
        Wait(10)
        elapsed = elapsed + 10
        if elapsed >= LOAD_TIMEOUT_MS then
            DebugLog('ERROR: Model load timeout: ' .. tostring(model))
            return false
        end
    end
    return true
end

-- ============================================================
-- 患者検索（近くのプレイヤー）
-- ============================================================

---@return number|nil 最も近い患者の Server ID
function GetNearbyPatient()
    local myPed    = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closestPlayer   = nil
    local closestDistance  = Config.Stretcher.patientDistance

    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= myPed and DoesEntityExist(targetPed) then
            local dist = #(myCoords - GetEntityCoords(targetPed))
            if dist < closestDistance then
                closestDistance = dist
                closestPlayer  = player
            end
        end
    end

    if closestPlayer then
        local serverId = GetPlayerServerId(closestPlayer)
        if serverId and serverId > 0 then
            return serverId
        end
    end

    return nil
end

-- ============================================================
-- 車両検索
-- ============================================================

---@return number|nil 最も近い車両のエンティティ（車両種別制限なし）
function GetClosestStretcherVehicle()
    local myPed    = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closestVehicle  = nil
    local closestDistance  = Config.Stretcher.interactionDistance

    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local dist = #(myCoords - GetEntityCoords(vehicle))
            if dist < closestDistance then
                closestDistance = dist
                closestVehicle  = vehicle
            end
        end
    end

    return closestVehicle
end

DebugLog('cl_utils.lua loaded')
