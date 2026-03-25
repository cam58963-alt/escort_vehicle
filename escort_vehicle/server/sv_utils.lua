-- server/sv_utils.lua v0.6.5 - サーバーユーティリティ

local QBX = exports.qbx_core

function ServerDebugLog(message)
    if Config.Debug then
        print('^2[ESCORT_SERVER]^7 ' .. tostring(message))
    end
end

---@param src number プレイヤーの Source ID
---@return boolean 権限があるか
function ServerHasPermission(src)
    if not Config.JobRestriction.enabled then return true end

    local success, player = pcall(function()
        return QBX:GetPlayer(src)
    end)

    if not success or not player or not player.PlayerData or not player.PlayerData.job then
        return false
    end

    local playerJob = player.PlayerData.job.name
    local isOnDuty  = player.PlayerData.job.onduty

    if not Config.IsJobAllowed(playerJob) then return false end
    if not Config.JobRestriction.allowOffDuty and not isOnDuty then return false end

    return true
end

-- FIX #12: IsValidPlayer を強化 - GetPlayerPing で接続確認
---@param targetPlayerId number
---@return boolean プレイヤーが有効か
function IsValidPlayer(targetPlayerId)
    if not targetPlayerId or targetPlayerId == 0 then return false end
    local name = GetPlayerName(targetPlayerId)
    if not name then return false end
    -- GetPlayerPing は接続中プレイヤーのみ有効値を返す（切断中は 0 or nil）
    local ping = GetPlayerPing(targetPlayerId)
    return ping ~= nil and ping > 0
end

--- サーバーからクライアントへ通知を送信
-- FIX #16: サーバー側からの通知を統一関数化
---@param src number プレイヤーの Source ID
---@param message string 通知メッセージ
---@param type string 通知タイプ（'success', 'error', 'inform'）
function ServerNotify(src, message, type)
    TriggerClientEvent('qbx_core:Notify', src, message, type or 'inform')
end

ServerDebugLog('sv_utils.lua loaded')
