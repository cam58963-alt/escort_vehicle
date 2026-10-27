# escort_vehicle — ストレッチャーシステム

FiveM（QBox）向けの救急隊用ストレッチャースクリプトです。
ストレッチャーを展開して押して運び、患者を乗せ、車両に乗り込むだけで患者を後部座席へ搬送できます。

- バージョン: 0.7.0
- 作者: otonashi
- フレームワーク: [qbx_core](https://github.com/Qbox-project/qbx_core)

## 主な機能

- **アイテムから展開 / 収納**: `stretcher` アイテムを使うとストレッチャーを展開し、もう一度使うと収納します（アイテムは消費されません）
- **押して運ぶ**: 展開したストレッチャーをプレイヤーが押して移動。ドア開閉などでアニメーションが外れても自動で戻ります
- **設置 / 回収**: 正面の地面にストレッチャーを置き、再び持ち上げることができます
- **患者を乗せる / 降ろす**: 近くのプレイヤーをストレッチャーに寝かせたり降ろしたりできます
- **訓練用NPC 対応**: [ems_npc_rescue](https://github.com/cam58963-alt/ems_npc_rescue) の訓練用NPC も、プレイヤーと同じようにストレッチャーに乗せて車に積めます
- **車両への自動搬送**: ストレッチャーを持ったまま車両の運転席か助手席に乗ると（車種は問いません）、
  - 患者が乗っていれば、空いている席（後ろの席から優先）に患者を乗せます
  - 患者がいなければ、ストレッチャーだけを収納します
- **ox_target 対応**: ストレッチャー本体やプレイヤーを狙って各操作をメニューから実行できます
- **ジョブ制限**: 既定では勤務中の `ambulance` ジョブのみ使用できます

## 必要なリソース

| リソース | 用途 |
| --- | --- |
| `qbx_core` | ジョブ判定・通知 |
| `ox_target` | ターゲットメニュー |
| `ox_inventory` | ストレッチャーアイテム |
| `baseevents`（任意） | 車両乗車の検出（なくても `gameEventTriggered` で検出します） |

## インストール

1. `escort_vehicle` フォルダをサーバーの `resources` に配置します。
   > アイテムの export 名（`escort_vehicle.useStretcher`）と合わせるため、フォルダ名は `escort_vehicle` のままにしてください。

2. `server.cfg` に追記します（依存リソースより後に読み込む）。

   ```cfg
   ensure qbx_core
   ensure ox_inventory
   ensure ox_target
   ensure escort_vehicle
   ```

3. `ox_inventory/data/items.lua` にアイテムを追加します。

   ```lua
   ['stretcher'] = {
       label = 'ストレッチャー',
       weight = 5000,
       stack = false,
       close = true,
       description = '救急搬送用のストレッチャー',
       client = {
           export = 'escort_vehicle.useStretcher',
       },
   },
   ```

4. 救急隊員に `stretcher` アイテムを配布します（ショップ・ジョブ倉庫など）。

## 使い方

1. インベントリから **ストレッチャー** を使用して展開します。
2. 以下のキー（または ox_target メニュー）で操作します。

| 既定キー | 操作 | コマンド |
| --- | --- | --- |
| `G` | ストレッチャーを設置 / 回収 | `stretcher_place_toggle` |
| `E` | 近くの患者を乗せる / 降ろす | `stretcher_patient_toggle` |
| `X` | ストレッチャーをインベントリに収納 | `stretcher_store` |

キーは各プレイヤーが ESC → 設定 → キー割り当て → FiveM から変更できます。
ストレッチャーを持っている間は画面左上に操作ガイドが表示されます。

3. 患者を乗せたまま、ストレッチャーを持って車両の運転席か助手席に乗り込むと、患者が後部座席に移ります。車種の制限はありません。

### ox_target メニュー

- **ストレッチャー本体**（設置中）: 患者を乗せる / 患者を降ろす / インベントリに収納
- **他のプレイヤー**: ストレッチャーに乗せる（ストレッチャー展開中のみ）
- **訓練用NPC**: ストレッチャーに乗せる（ストレッチャー展開中のみ）

### 訓練用NPC（ems_npc_rescue）

`isRescueMissionNPC` StateBag が付いた NPC は、プレイヤーの患者と同じ操作で扱えます。

- `E` キー / ストレッチャーの「患者を乗せる」: 近くのプレイヤーと訓練用NPC のうち、一番近い方を乗せます
- NPC を乗せたまま運転席か助手席に乗ると、NPC が後ろの席に移ります。訓練を始めた人が同じ車に乗って病院へ向かえば、訓練を完了できます
- NPC はその NPC を出したプレイヤーのクライアントで動かします（サーバーが中継します）
- 訓練が終わって NPC が消えると、ストレッチャーは空に戻ります
- 席が埋まっていたなどで車に乗せられなかったときは、NPC を車のそばに降ろして「患者を車両に乗せられませんでした」と知らせます。もう一度ストレッチャーを出して乗せ直してください
- ems_npc_rescue で「ストレッチャー必須」にした現場では、cam_souziki の掃除機は使えません

### 注意点

- 患者が乗っている間は収納できません。先に降ろしてください。
- 患者の自動搬送は運転席・助手席に乗ったときだけ動きます。後部座席では動きません。
- 空いている席がない場合は「車両に空きがありません」と表示され、搬送されません。

## 設定（`config.lua`）

| 項目 | 説明 | 既定値 |
| --- | --- | --- |
| `Config.Debug` | デバッグログとデバッグコマンドを有効にする | `false` |
| `Config.JobRestriction.enabled` | ジョブ制限を使う | `true` |
| `Config.JobRestriction.allowedJobs` | 使用できるジョブ | `{ 'ambulance' }` |
| `Config.JobRestriction.allowOffDuty` | 勤務外でも使えるようにする | `false` |
| `Config.Stretcher.itemName` | アイテム名 | `'stretcher'` |
| `Config.Stretcher.model` | ストレッチャーのプロップ | `` `prop_stretcher` `` |
| `Config.Stretcher.carryOffset` | 押すときのストレッチャー位置・角度 | `y = -1.1, z = -0.5, rotX = 15.0` |
| `Config.Stretcher.interactionDistance` | 車両の検索範囲（m）※現在は使われていません | `10.0` |
| `Config.Stretcher.placeDistance` | 設置位置（プレイヤー前方 m） | `2.0` |
| `Config.Stretcher.patientDistance` | 患者の検索範囲（m） | `3.0` |
| `Config.Stretcher.pushAnim` | 押すときのアニメーション | `anim@heists@box_carry@` / `idle` |
| `Config.Stretcher.patientAnim` | 患者が寝ているアニメーション | `anim@gangops@morgue@table@` / `body_search` |
| `Config.Stretcher.patientOffset` | ストレッチャー上の患者位置 | `z = 1.05` |
| `Config.RescueNPC.enabled` | 訓練用NPC をストレッチャーで運べるようにする | `true` |
| `Config.RescueNPC.stateKey` | 訓練用NPC を見分ける StateBag のキー | `'isRescueMissionNPC'` |
| `Config.RescueNPC.maxDistance` | サーバーで確認する、プレイヤーと NPC の最大距離（m） | `15.0` |
| `Config.DefaultKeys` | 既定キー | `G` / `E` / `X` |
| `Config.Notifications` | 通知メッセージ | 日本語メッセージ一式 |

### よくある調整

- **患者がストレッチャーに埋まる / 浮く** → `patientOffset.z` を上げ下げしてください。
- **他のジョブにも使わせたい** → `allowedJobs` に追加します（例: `{ 'ambulance', 'doctor' }`）。

## デバッグ

`Config.Debug = true` にすると F8 コンソールとサーバーコンソールにログが出て、以下のコマンドが使えます。

| コマンド | 内容 |
| --- | --- |
| `/teststretcher` | アイテムなしでストレッチャーを展開 |
| `/escortstatus` | ストレッチャーの状態（展開・保持・患者・権限・座標）を表示 |

本番環境では `false` に戻してください。

## 他スクリプトとの連携

患者を車両に乗せたとき、サーバー側で以下のイベントを発火します。既存のエスコート処理（連行状態の解除など）と連携できます。

```lua
TriggerEvent('police:server:SetPlayerOut', src, targetPlayerId)
TriggerEvent('ambulance:server:SetPlayerOut', src, targetPlayerId)
```

### ネットイベント一覧

| イベント | 方向 | 内容 |
| --- | --- | --- |
| `escort_vehicle:server:placeOnStretcher` | クライアント → サーバー | 患者をストレッチャーに乗せる |
| `escort_vehicle:server:removeFromStretcher` | クライアント → サーバー | 患者を降ろす |
| `escort_vehicle:server:putInVehicle` | クライアント → サーバー | 患者を車両に乗せる |
| `escort_vehicle:client:placeOnStretcher` | サーバー → 患者 | ストレッチャーにアタッチ |
| `escort_vehicle:client:removeFromStretcher` | サーバー → 患者 | ストレッチャーから外す |
| `escort_vehicle:client:putInVehicle` | サーバー → 患者 | 指定座席にワープ |
| `escort_vehicle:server:placeNpcOnStretcher` | クライアント → サーバー | 訓練用NPC をストレッチャーに乗せる |
| `escort_vehicle:server:removeNpcFromStretcher` | クライアント → サーバー | 訓練用NPC を降ろす |
| `escort_vehicle:server:putNpcInVehicle` | クライアント → サーバー | 訓練用NPC を車両に乗せる |
| `escort_vehicle:client:npcPlaceOnStretcher` | サーバー → NPC のオーナー | NPC をストレッチャーにアタッチ |
| `escort_vehicle:client:npcRemoveFromStretcher` | サーバー → NPC のオーナー | NPC をストレッチャーから外す |
| `escort_vehicle:client:npcPutInVehicle` | サーバー → NPC のオーナー | NPC を指定座席にワープ |
| `escort_vehicle:server:npcTransportFailed` | NPC のオーナー → サーバー | 車に乗せられなかったことを、ストレッチャーを使った人に知らせる |

サーバー側のイベントはすべてジョブ権限と対象プレイヤーの接続をチェックしてから処理します。
訓練用NPC のイベントは、ジョブ権限・NPC の StateBag・プレイヤーとの距離をチェックします。

## ファイル構成

```
escort_vehicle/
├── fxmanifest.lua
├── config.lua               設定
├── client/
│   ├── cl_utils.lua         共通関数（権限・通知・読み込み・患者/車両検索）
│   ├── cl_state.lua         ストレッチャーの状態管理
│   ├── cl_patient.lua       患者（プレイヤー / 訓練用NPC）の乗せ降ろし
│   ├── cl_stretcher.lua     展開・設置・回収・収納、アイテム export
│   ├── cl_vehicle.lua       車両乗車時の自動搬送
│   ├── cl_target.lua        ox_target 連携
│   └── cl_commands.lua      コマンド・キー割り当て・操作ガイド・患者側イベント
└── server/
    ├── sv_utils.lua         権限チェック・プレイヤー確認・通知
    ├── sv_inventory.lua     インベントリ（現在は処理なし・拡張用）
    └── sv_patient.lua       患者の乗せ降ろし・車両搬送
```
