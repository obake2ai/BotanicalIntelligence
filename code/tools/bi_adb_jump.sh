#!/usr/bin/env bash
# Set up the adb jump bridge for the BI monitor.
#
# Fallback for when the monitor PC has no working ethernet adapter: one fleet
# device is plugged in over USB (adb) and acts as an SSH jump host into the
# wired 10.0.0.x segment. The monitor then runs with BI_JUMP_PORT set, which
# routes every device SSH through this bridge (see monitor/app.py).
#
# Usage: bi_adb_jump.sh [local_port]   (default 2299)
set -u
PORT="${1:-2299}"

command -v adb >/dev/null || { echo "ERROR: adb not found" >&2; exit 1; }
adb start-server >/dev/null 2>&1

N=$(adb devices | awk 'NR>1 && $2=="device"{c++} END{print c+0}')
if [ "$N" -ne 1 ]; then
  echo "ERROR: need exactly 1 adb device, found $N" >&2
  echo "  (all M5Stacks share the serial 'axera-ax620e' so adb -s cannot" >&2
  echo "   distinguish them - plug in only the jump device)" >&2
  exit 1
fi

adb forward --remove "tcp:$PORT" >/dev/null 2>&1
adb forward "tcp:$PORT" tcp:22 || exit 1

HOST=$(adb shell hostname </dev/null 2>/dev/null | tr -d '\r')
ETH=$(adb shell "ip -4 addr show eth0 2>/dev/null | grep -o 'inet [0-9.]*'" </dev/null 2>/dev/null | tr -d '\r' | awk '{print $2}')

echo "jump bridge ready: localhost:$PORT -> $HOST (eth0: ${ETH:-none})"
echo
echo "start the monitor with:"
echo "  BI_SSH_PASS=root BI_NODE_COUNT=110 BI_JUMP_PORT=$PORT ./.venv/bin/python app.py"
