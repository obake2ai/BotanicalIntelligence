#!/usr/bin/env bash
# BI 本番プログラムの差し替え (Mac repo → デバイス群、LAN/SSH 越し)。
# MANS 2026: 現場で全台のプログラムを最新化するための標準ツール。
#
# 使い方:
#   bash tools/deploy_bi_program.sh 10.0.0.13 10.0.0.27 ...
#   BI_SSH_PASS=root bash tools/deploy_bi_program.sh $(cat ips.txt)
#
# 同期対象 (device 側で実行に要るものだけ):
#   main.py / pca9685_osc_led_server*.py / bi/ api/ utils/ scripts/ config/
#   audio/ は AE_* と waiting_* のみ / pyproject.toml uv.lock
# 触らないもの: .venv (各機の既存環境) / .git / logs / tmp
#
# ⚠️ config/ と audio/ は Mac 側の標準状態で上書きする = glo 時代の個体別調整
#    (AE_sample 音量など) は消える。MANS は現場で再調整する前提 (意図した初期化)。
#
# 検証: 転送後に device 側で md5 マニフェストを作らせ → pull → ローカルと突き合わせ。
#       .venv がある個体は py_compile (main.py + bi/ + api/) も回す。
# バックアップ: 上書き前に対象コード (audio 除く) を /root/bi_prog_backup_<ts>.tar に退避。
set -uo pipefail

PASS=${BI_SSH_PASS:-root}
CODE=$(cd "$(dirname "$0")/.." && pwd)
TARGET=/root/dev/CCBT-2025-Parallel-Botanical-Garden-Proto
TS=$(date +%Y%m%d_%H%M%S)
TMP=${TMPDIR:-/tmp}/bi_prog_deploy
mkdir -p "$TMP"

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR -o ConnectTimeout=8)
rssh() { sshpass -p "$PASS" ssh "${SSH_OPTS[@]}" "root@$1" "$2"; }
rpull() { sshpass -p "$PASS" scp "${SSH_OPTS[@]}" "root@$1:$2" "$3"; }

[ $# -ge 1 ] || { echo "usage: deploy_bi_program.sh <ip> [<ip> ...]"; exit 1; }
[ -f "$CODE/main.py" ] || { echo "ERROR: $CODE/main.py が無い"; exit 1; }

# --- 転送 tar を 1 回だけ作る (全台共通) ---
# COPYFILE_DISABLE=1: macOS の ._* (AppleDouble) を混入させない
# audio は AE_*/waiting_* のみを引数展開で渡す (bsdtar の -T は member 引数と併用すると
# リストが展開されず audio が丸ごと欠落する事故が起きた 2026-08-19)
PAYLOAD="$TMP/payload.tar"
# config/networks.csv はサイトごとのトポロジー (bi_set_clusters.sh が管理) なので配らない。
# 2026-08-19: これを配って 101 の bench networks を CCBT 版で潰した事故の再発防止
( cd "$CODE" && export COPYFILE_DISABLE=1 && \
  tar cf "$PAYLOAD" --exclude 'config/networks.csv' --exclude 'config/._networks.csv' \
    main.py pca9685_osc_led_server.py pca9685_osc_led_server_v2.py \
    pyproject.toml uv.lock app bi api utils scripts config \
    $(find audio -maxdepth 1 \( -name 'AE_*' -o -name 'waiting_*' \)) )
[ -s "$PAYLOAD" ] || { echo "ERROR: payload 作成失敗"; exit 1; }
tar tf "$PAYLOAD" | grep -q '^audio/' || { echo "ERROR: audio/ が payload に入っていない"; exit 1; }

# ローカル md5 マニフェスト (tar の中身と同一集合)
( cd "$CODE" && tar tf "$PAYLOAD" | grep -v '/$' | while read -r f; do
    [ -f "$f" ] && md5 -r "$f"; done | sort -k2 ) > "$TMP/local.md5"
N_FILES=$(wc -l < "$TMP/local.md5" | tr -d ' ')
echo "payload: $N_FILES files, $(du -h "$PAYLOAD" | cut -f1)"

declare -a RESULTS=()

for IP in "$@"; do
  echo "=============================================="
  echo "== $IP"
  T="$TMP/$IP"; mkdir -p "$T"

  if ! rssh "$IP" "echo ALIVE" | grep -q ALIVE; then
    echo "  SKIP: SSH 不達"; RESULTS+=("$IP SKIP(ssh不達)"); continue
  fi
  if ! rssh "$IP" "ls -d $TARGET" >/dev/null 2>&1; then
    echo "  SKIP: repo が無い個体 ($TARGET)"; RESULTS+=("$IP SKIP(repo無し)"); continue
  fi
  if [ "${FORCE:-0}" != "1" ] && rssh "$IP" "pgrep -f 'python3.*main\.py' >/dev/null && echo BUSY" | grep -q BUSY; then
    echo "  SKIP: main.py 稼働中 (停止してから差し替え)"; RESULTS+=("$IP SKIP(main.py稼働中)"); continue
  fi

  echo "  1. 退避 (audio 除くコード → /root/bi_prog_backup_$TS.tar)"
  # 旧 repo に巨大ファイルが残っている個体がある (101 の scripts/ に 3.7GB のモデル残骸の前例)。
  # 対象が 300MB を超える個体はバックアップを飛ばす (復元経路は各機 git + Mac 正本)
  BK_MB=$(rssh "$IP" "cd $TARGET && du -sm -c main.py app bi api utils scripts config 2>/dev/null | tail -1 | awk '{print \$1}'" | tr -dc '0-9')
  if [ -n "$BK_MB" ] && [ "$BK_MB" -gt 300 ]; then
    echo "  WARN: 対象 ${BK_MB}MB > 300MB のためバックアップをスキップ (大物の所在を du で確認のこと)"
  else
    rssh "$IP" "cd $TARGET && tar cf /root/bi_prog_backup_$TS.tar \
      main.py pca9685_osc_led_server*.py bi api utils scripts config 2>/dev/null; echo BK_RC=\$?" | tail -1
  fi

  echo "  2. 転送 + 展開"
  if ! sshpass -p "$PASS" ssh "${SSH_OPTS[@]}" "root@$IP" "tar xf - -C $TARGET" < "$PAYLOAD"; then
    echo "  FAIL: 転送"; RESULTS+=("$IP FAIL(転送)"); continue
  fi

  echo "  3. md5 照合 ($N_FILES files)"
  rssh "$IP" "cd $TARGET && tar tf /dev/null >/dev/null 2>&1; \
    while read -r h f; do md5sum \"\$f\"; done < /dev/null; \
    find main.py pca9685_osc_led_server.py pca9685_osc_led_server_v2.py \
      pyproject.toml uv.lock app bi api utils scripts config audio -type f \
      \( -path 'audio/*' -a ! -name 'AE_*' -a ! -name 'waiting_*' -prune \) -o -type f -print \
      2>/dev/null | sort | xargs md5sum > /tmp/prog.md5 2>/dev/null; echo MD5_DONE" | tail -1
  rpull "$IP" /tmp/prog.md5 "$T/prog.md5" || { RESULTS+=("$IP FAIL(md5取得)"); continue; }
  MISMATCH=$(python3 - "$TMP/local.md5" "$T/prog.md5" <<'PY'
import sys
local = {}
for line in open(sys.argv[1]):
    h, f = line.strip().split(None, 1)
    local[f] = h
remote = {}
for line in open(sys.argv[2]):
    h, f = line.strip().split(None, 1)
    remote[f.lstrip('./')] = h
bad = [f for f, h in local.items() if remote.get(f) != h]
print(len(bad))
for f in bad[:5]:
    print(f"    MISMATCH {f}", file=sys.stderr)
PY
)
  if [ "$MISMATCH" != "0" ]; then
    echo "  FAIL: md5 不一致 $MISMATCH 件"; RESULTS+=("$IP FAIL(md5 $MISMATCH件)"); continue
  fi
  echo "  md5 全一致"

  echo "  4. py_compile (venv がある個体のみ)"
  if rssh "$IP" "ls $TARGET/.venv/bin/python3" >/dev/null 2>&1; then
    if rssh "$IP" "cd $TARGET && .venv/bin/python3 -m py_compile main.py app/*.py bi/*.py api/*.py utils/*.py 2>&1; echo PC_RC=\$?" | tail -1 | grep -q 'PC_RC=0'; then
      echo "  py_compile OK"
    else
      echo "  FAIL: py_compile"; RESULTS+=("$IP FAIL(py_compile)"); continue
    fi
  else
    echo "  (venv 無し → スキップ)"
  fi

  RESULTS+=("$IP OK")
done

echo "=============================================="
echo "== まとめ"
for r in "${RESULTS[@]}"; do echo "  $r"; done
case " ${RESULTS[*]} " in *FAIL*) exit 1;; esac
