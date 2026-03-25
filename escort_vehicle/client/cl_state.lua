-- client/cl_state.lua v0.6.5 - 共有状態管理
-- 他モジュールから参照されるグローバル状態変数

StretcherState = {
    object   = nil,   -- ストレッチャーのエンティティ
    patient  = nil,   -- 乗っている患者の Server ID
    carrying = false, -- プレイヤーが持っているか
}

--- ストレッチャーが存在するか
---@return boolean
function StretcherState.Exists()
    return StretcherState.object ~= nil
        and DoesEntityExist(StretcherState.object)
end

--- 状態をリセット
function StretcherState.Reset()
    StretcherState.object   = nil
    StretcherState.patient  = nil
    StretcherState.carrying = false
end

DebugLog('cl_state.lua loaded')
