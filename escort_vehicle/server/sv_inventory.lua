-- server/sv_inventory.lua v0.6.5 - インベントリ管理
--
-- ストレッチャーはトグル方式（return false）のため
-- アイテムは常にインベントリに1個残る。
-- AddItem / RemoveItem は不要。
--
-- このファイルは将来のインベントリ連携拡張用に残しておく。

ServerDebugLog('sv_inventory.lua loaded (toggle mode - no item manipulation)')
