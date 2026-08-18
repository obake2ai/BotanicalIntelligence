#!/usr/bin/env bash
# Sync a generated networks CSV to the whole MANS fleet (hub-side).
#
# Cluster version of the 5-unit ring tool used in the previous deployment:
#   1. discover alive devices (ping sweep 10.0.0.2-110 + repo check)
#   2. cross-check against the cluster map (missing / unmapped units are listed)
#   3. push the CSV to each device as config/networks.csv (.bak + md5 verify)
#   4. --reboot: reboot devices so the autostart service picks the new topology
#      (relaunching main.py without reboot locks StackFlow setup - always reboot)
#
# Runs on the hub PC (needs: bash, ping, sshpass; devices are root/root).
# Usage:
#   bi_set_clusters.sh --map cluster_map_mans.csv --csv networks_mans.csv \
#       [--dry-run] [--reboot] [--force]
set -u

MAP=""
CSV=""
DRY_RUN=0
REBOOT=0
FORCE=0
REPO="/root/dev/CCBT-2025-Parallel-Botanical-Garden-Proto"
SSH_OPTS="-n -o StrictHostKeyChecking=no -o ConnectTimeout=4 -o BatchMode=no"
PASS="root"
STAMP=$(date +%Y%m%d_%H%M%S)

while [ $# -gt 0 ]; do
  case "$1" in
    --map) MAP="$2"; shift 2 ;;
    --csv) CSV="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --reboot) REBOOT=1; shift ;;
    --force) FORCE=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -f "$MAP" ] || { echo "ERROR: cluster map not found: $MAP" >&2; exit 1; }
[ -f "$CSV" ] || { echo "ERROR: networks csv not found: $CSV" >&2; exit 1; }
command -v sshpass >/dev/null || { echo "ERROR: sshpass not installed" >&2; exit 1; }

dssh() { # dssh <ip> <cmd>
  sshpass -p "$PASS" ssh $SSH_OPTS "root@$1" "$2" 2>/dev/null
}
dscp() { # dscp <local> <ip> <remote>
  sshpass -p "$PASS" scp -o StrictHostKeyChecking=no -o ConnectTimeout=4 "$1" "root@$2:$3" 2>/dev/null
}

# --- expected ids from cluster map (skip header, blank lines) ---
MAPPED_IDS=$(awk -F, 'NR>1 && $1 ~ /^[0-9]+$/ {print $1}' "$MAP" | sort -n)
[ -n "$MAPPED_IDS" ] || { echo "ERROR: no ids in cluster map" >&2; exit 1; }

# --- discover alive devices ---
# ping -W is seconds on Linux and milliseconds on macOS (hub may be either).
if [ "$(uname -s)" = "Darwin" ]; then PING_WAIT="1000"; else PING_WAIT="1"; fi

echo "== discovering fleet (10.0.0.2-110) =="
ALIVE=""
for i in $(seq 2 110); do
  ip="10.0.0.$i"
  if ping -c 1 -W "$PING_WAIT" "$ip" >/dev/null 2>&1; then
    if dssh "$ip" "test -d $REPO" ; then
      ALIVE="$ALIVE $i"
      printf "  %s alive\n" "$ip"
    else
      printf "  %s ping OK but no repo (skipped)\n" "$ip"
    fi
  fi
done
ALIVE=$(echo "$ALIVE" | tr ' ' '\n' | grep -v '^$' | sort -n)

# --- cross-check ---
MISSING=$(comm -23 <(echo "$MAPPED_IDS") <(echo "$ALIVE"))
UNMAPPED=$(comm -13 <(echo "$MAPPED_IDS") <(echo "$ALIVE"))
SYNC=$(comm -12 <(echo "$MAPPED_IDS") <(echo "$ALIVE"))

echo "== cross-check =="
echo "  mapped   : $(echo "$MAPPED_IDS" | wc -l | tr -d ' ') ids"
echo "  alive    : $(echo "$ALIVE" | grep -c . ) ids"
[ -n "$MISSING" ]  && echo "  MISSING (in map, not reachable): $(echo $MISSING)"
[ -n "$UNMAPPED" ] && echo "  unmapped (alive, not in map)  : $(echo $UNMAPPED) -> left untouched"
echo "  will sync: $(echo $SYNC)"

if [ -n "$MISSING" ] && [ "$FORCE" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  echo "ERROR: mapped devices unreachable. Fix or rerun with --force." >&2
  exit 1
fi

[ "$DRY_RUN" -eq 1 ] && { echo "(dry-run: no changes)"; exit 0; }

# --- sync ---
LOCAL_MD5=$(md5sum "$CSV" | awk '{print $1}')
echo "== syncing networks.csv (md5 $LOCAL_MD5) =="
FAIL=0
for i in $SYNC; do
  ip="10.0.0.$i"
  dssh "$ip" "cp $REPO/config/networks.csv $REPO/config/networks.csv.bak_mans_$STAMP" \
    || echo "  $ip: WARN backup failed (no existing csv?)"
  if ! dscp "$CSV" "$ip" "$REPO/config/networks.csv"; then
    echo "  $ip: PUSH FAILED"; FAIL=1; continue
  fi
  REMOTE_MD5=$(dssh "$ip" "md5sum $REPO/config/networks.csv" | awk '{print $1}')
  if [ "$REMOTE_MD5" = "$LOCAL_MD5" ]; then
    echo "  $ip: OK"
  else
    echo "  $ip: MD5 MISMATCH (got: $REMOTE_MD5)"; FAIL=1
  fi
done
[ "$FAIL" -eq 1 ] && { echo "ERROR: sync incomplete - do not reboot, investigate first." >&2; exit 1; }

# --- reboot ---
if [ "$REBOOT" -eq 1 ]; then
  echo "== rebooting fleet (autostart service relaunches main.py) =="
  for i in $SYNC; do
    dssh "10.0.0.$i" "reboot" && echo "  10.0.0.$i: reboot sent"
  done
  echo "wait ~90s, then check the monitor for OSC/relay recovery"
else
  echo "done (no reboot). Topology applies after next reboot of each device."
fi
