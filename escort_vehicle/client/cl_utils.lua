-- client/cl_utils.lua v0.7.0 - ユーティリティ関数

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
-- 患者検索（近くのプレイヤー / 訓練用NPC）
-- 患者は { type = 'player', serverId = n } か { type = 'npc', netId = n } で表す
-- ============================================================

---@param ped number
---@return boolean 訓練用NPC（ems_npc_rescue）か
function IsRescueNpc(ped)
    if not Config.RescueNPC or not Config.RescueNPC.enabled then return false end
    if not ped or ped == 0 or not DoesEntityExist(ped) or IsPedAPlayer(ped) then return false end
    local state = Entity(ped).state
    return state ~= nil and state[Config.RescueNPC.stateKey] == true
end

---@param ped number 訓練用NPC の Ped
---@return table|nil 患者
function NpcPatientFromPed(ped)
    if not IsRescueNpc(ped) or not NetworkGetEntityIsNetworked(ped) then return nil end
    local netId = NetworkGetNetworkIdFromEntity(ped)
    if not netId or netId == 0 then return nil end
    return { type = 'npc', netId = netId }
end

---@param ped number
---@return boolean ストレッチャーに乗せられる状態か（車に乗っていない・何かに乗っていない）
function IsNpcFreeForStretcher(ped)
    return not IsPedInAnyVehicle(ped, false) and not IsEntityAttached(ped)
end

---@param patient table|nil
---@return string ログ用の表示
function DescribePatient(patient)
    if not patient then return 'none' end
    if patient.type == 'npc' then return 'npc:' .. tostring(patient.netId) end
    return 'player:' .. tostring(patient.serverId)
end

---@return table|nil 最も近い患者
function GetNearbyPatient()
    local myPed    = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closest  = nil
    local closestDistance = Config.Stretcher.patientDistance

    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= myPed and DoesEntityExist(targetPed) then
            local dist = #(myCoords - GetEntityCoords(targetPed))
            if dist < closestDistance then
                local serverId = GetPlayerServerId(player)
                if serverId and serverId > 0 then
                    closestDistance = dist
                    closest = { type = 'player', serverId = serverId }
                end
            end
        end
    end

    -- 訓練用NPC
    if Config.RescueNPC and Config.RescueNPC.enabled then
        for _, ped in ipairs(GetGamePool('CPed')) do
            if IsRescueNpc(ped) and IsNpcFreeForStretcher(ped) then
                local dist = #(myCoords - GetEntityCoords(ped))
                if dist < closestDistance then
                    local patient = NpcPatientFromPed(ped)
                    if patient then
                        closestDistance = dist
                        closest = patient
                    end
                end
            end
        end
    end

    return closest
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
