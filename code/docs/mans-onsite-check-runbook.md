# MANS 現地テスト / 全台チェック 手順書 (モニター起動 + alien TTS チェック)

対象: 8/20 現地テスト (10台) / 8/21 全台チェック @AE (約50台)。
モニター PC = 岸さん MacBook Pro + AX88179A USB-C LAN アダプタ (8/19 検証済み)。

**8/19 深夜更新**: 101 で本番プログラム一巡 (待機音→信号→生成→**alien 声**発話) を実機確認済み。
TTS は config 化され、**差し替え後の本体の声 = alien (α=0.7) が既定**になった。
1台あたりの本番化手順 = §4 モデル配布 → §4.5 プログラム差し替え → reboot → §5 RUN。

---

## 0. 持ち物

- MacBook Pro + **AX88179A アダプタ** + PD 充電器
- LAN ハブ + LAN ケーブル (台数分 + Mac 用 1 本)
- iPhone (テザリング用 — モニターの SSH ターミナル / RUN 進捗表示は CDN 読みのため、
  ネットが無いと使えない。Wi-Fi テザリング + 有線 LAN は両立できる)
- (任意) USB-C ケーブル — IP が立たない個体の adb 救済用

## 1. 物理接続

1. デバイスを電源に接続 (本番電源。USB-adb は切れて SSH のみになる)
2. 全デバイスの LAN をハブへ
3. Mac もアダプタ経由で同じハブへ

**開梱 1 台目だけ先に確認** (CCBT static IP / device-id の残存が未確認のため):

```
sshpass -p root ssh -o StrictHostKeyChecking=no root@10.0.0.<ID> \
  'cat /etc/network/interfaces; cat /etc/ccbt-device-id 2>/dev/null'
```

ID = 各機に焼き付いた IP 末尾。1 台目が想定どおり 10.0.0.X で立てば以降は流れ作業。

## 2. Mac の有線 IP

```
ifconfig en16 | grep 'inet '        # 10.0.0.200 が出れば OK
```

出なければ:

```
networksetup -setmanual "AX88179A" 10.0.0.200 255.255.255.0 ""
```

(アダプタを変えるとサービス名が変わる。`networksetup -listallhardwareports` で確認)

## 3. モニターアプリ起動

```
cd /Users/d21143/CODES/BotanicalIntelligence/code/monitor
BI_SSH_PASS=root BI_CLUSTER_MAP=/nonexistent ./.venv/bin/python app.py
```

→ http://localhost:5050

- **現場のノードは自動では表示されない**。cluster_map_mans.csv は現状ベンチ 2 台 (99/101) のみ。
  現場では: ①`BI_CLUSTER_MAP=/nonexistent` の CCBT 10×10 フォールバック (ID 1〜100 全表示) で
  01 SYSTEM ping から生存 ID を発見 → ②CSV に実 ID を追記して再起動、の 2 段階
- device99/101 も見たい時は `BI_NODE_COUNT=110` を追加 (⚠️cluster_map の読込も
  NODE_COUNT で範囲制限されるため、101 を出すには必須)
- チェック順: 01 SYSTEM (ping) → 02 LED → 03 SOUND → 必要に応じ 99 RUN
- ⚠️ 03 SOUND 用の bi_check_*.wav はデバイス側に無い前提 (正= `~/Downloads/bi_audio_check/`)。
  alien 発話チェック (下記 5) が音経路の確認を兼ねるので、無くても致命ではない

## 4. alien TTS (α=0.7) の配布

新しい meloTTS は焼成 1 回で全台共通。配置済みは device99 / 101 のみなので、
現地の各台へ LAN 越しに配布する (1 台あたり約 86MB・数十秒):

```
cd /Users/d21143/CODES/melotts-alien-v0
bash scripts/deploy_alien_lan.sh 10.0.0.13 10.0.0.27 ...   # 生きている IP を列挙
```

- 既存 melotts-ja-jp には一切触れない (追加のみ)。md5 クロス照合 + 既存不変チェック内蔵
- 空き 150MB 未満の個体は自動 SKIP (root 95% 使用の前例あり)。SKIP された個体は個別相談
- **8/19 に device99 で完走検証済み** (md5 全一致)

## 4.5 プログラム差し替え (本番化: 待機音→信号→生成→alien 発話)

Mac repo の現行プログラム (TTS=alien config 済み) を各台へ:

```
cd /Users/d21143/CODES/BotanicalIntelligence/code
bash tools/deploy_bi_program.sh 10.0.0.13 10.0.0.27 ...
```

- md5 全一致 + py_compile まで自動検証。**8/19 に 101 で本番ループ一巡まで実証済み**
- config/networks.csv は配らない (トポロジーは bi_set_clusters.sh 管理)。config.json と
  audio/ は Mac 標準で上書き (glo 個体別調整は消える = 意図した初期化)
- ⚠️ **順序: §4 の alien モデル配布が先** (無いと TTS が alien を見つけられない)
- 差し替え後は **reboot** (llm-openai-api が alien mode を認識 + StackFlow クリーン化)
- 起動は §5 の monitor RUN → SEND TEST で本番ループ確認 (101 実証と同じ流れ)
- 言語: 現行 main.py の末尾桁 dict はほぼ en 既定 (ja はコメントアウト)。全台 ja に
  するなら差し替え前に dict を 1 行編集

## 5. alien TTS 発話チェック (デバイス単体の合成確認)

各台が **自分の番号を新しい声で名乗る**。StackFlow (:10001) 直叩きなので
サービス・BI 本体は無改変:

```
bash scripts/check_alien_lan.sh 10.0.0.13 10.0.0.27 ...
```

- 合成 → スピーカー再生 (aplay plug:dmixer) → wav を Mac へ回収
  (`/Users/Shared/bi-sound-v0-data/field_checks/<ID>_alien.wav`)
- **初回の推論は数分かかることがある** (timeout 500s)。2 回目からは速い
- main.py 稼働中の個体は自動 SKIP (kill すると StackFlow がロックする地雷のため)。
  その個体は reboot してから再実行
- 台本差し替え: `TEXT="こんばんは" bash scripts/check_alien_lan.sh ...`
- 音量: 再生は各機の現行 tinymix 設定のまま (勝手に変えない)

## 6. device101 (スピーカー内蔵機) のベンチ確認

- ✅ **8/19 一気通貫確認済み** (合成 → スピーカー再生、岸さん耳確認)。static IP は
  `/etc/network/interfaces` で永続化済み (101 に NetworkManager は無い。
  bak= `interfaces.bak_20260819`)。挿すだけで 10.0.0.101 で立つ
- 101 は aplay 無し → check_alien_lan.sh が自動で tinyplay 経路に切替
  (DAC MUTE 解除 + ステレオ化 + GAIN 45 + `LD_LIBRARY_PATH=/opt/usr/lib` を内蔵)
- ⚠️ 101 は m5stack-LLM 系で本番 50 台 (海の森/CCBT 系 = aplay + 外部アンプ) とは
  再生経路が違う。**声とモデルの確認には十分だが、本番の音経路の代表は device99 側**

## 7. トラブルシューティング

| 症状 | 対処 |
|---|---|
| 合成が無応答 / setup ハング | 該当機を reboot (サービス単体再起動では戻らない) |
| `task full (-21)` | 前回のユニット残り。`--release melotts.1000` か reboot |
| tinyplay 完走するのに音が出ない | DAC MUTE が自動で On に戻る仕様。鳴らす直前に解除 (スクリプトは対応済み) |
| SSH ターミナル / RUN 進捗が真っ白 | CDN 未達 (ネット無し)。iPhone テザリングを Wi-Fi に繋ぐ |
| ping 不達の個体 | IP 未設定の可能性。USB-C + adb で `ip addr` 確認 → `/etc/network/interfaces` を static 化 (要バックアップ) |
| scp/ssh で host key エラー | スクリプトは known_hosts 無視設定済み。手動時は `-o UserKnownHostsFile=/dev/null` |

## 8. 現在の状態 (8/19 深夜時点)

- **TTS config 化は完了** (`config.json stack_flow_tts.model` = melotts-alien-x1-a07)。
  §4.5 の差し替えを当てた台は **BI 本体の声が alien** になる (101 で耳確認済み)
- 旧 melotts-ja-jp に戻すには config.json の `stack_flow_tts.model` を null にして再配布
- 101 固有の地雷 (再発時用): main.py を kill した後の再起動は reboot 経由が確実
  (StackFlow の Setup LLM がハングする)。boot 毎に tinymix (DAC MUTE 0 / GAIN 45) 再設定。
  LED の PCA9685 リトライログは LED ハット非搭載機では無害
- 待機音が「CCBT と違う」のは glo で入った mixed 仕様 (AE_ 常時 + waiting_ 声を random 重ね)。
  MANS の音設計としてどうするかは現地実聴で判断
