#!/bin/bash
# Waiting-audio fallback (MANS 2026).
#
# Runs as a systemd service from boot. Plays the same two waiting-audio layers
# as the BI program (base AE_* ambient loop, gapless + waiting_* voices at
# random intervals) whenever main.py is NOT running:
#   - device boots but the program was never started      -> ambient plays
#   - the program crashes mid-exhibition                  -> ambient resumes
#   - the program is running                              -> this script stays
#     silent (checks every POLL seconds, kills its players within ~2s of
#     main.py appearing), so audio is never doubled.
#
# main.py detection: cmdline ending in "python3 main.py" (the tmux wrapper and
# tee lines end differently, so they never match).
set -u

D=/root/dev/CCBT-2025-Parallel-Botanical-Garden-Proto
AUD=$D/audio
DEV=${BI_PLAYBACK_DEVICE:-plug:dmixer}
SR=48000
CH=2
POLL=2
OV_MIN=20
OV_MAX=60
MAIN_PAT='python3 main\.py$'

main_alive() { pgrep -f "$MAIN_PAT" >/dev/null 2>&1; }

# --- base material: prefer wav; build one from mp3 if needed ---------------
base_wav=$(ls "$AUD"/AE_*.wav 2>/dev/null | head -1)
if [ -z "$base_wav" ]; then
  mp3=$(ls "$AUD"/AE_*.mp3 2>/dev/null | head -1)
  if [ -n "$mp3" ] && command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -loglevel error -i "$mp3" -ar $SR -ac $CH -sample_fmt s16 \
      "${mp3%.mp3}.wav" && base_wav="${mp3%.mp3}.wav"
  fi
fi

# raw PCM for the gapless cat-loop (same trick as ccbt-audio-keepalive)
base_raw=""
if [ -n "$base_wav" ] && command -v ffmpeg >/dev/null 2>&1; then
  raw="${base_wav%.wav}.raw"
  if [ ! -s "$raw" ] || [ "$base_wav" -nt "$raw" ]; then
    ffmpeg -y -loglevel error -i "$base_wav" -f s16le -acodec pcm_s16le \
      -ar $SR -ac $CH "$raw" || raw=""
  fi
  base_raw=$raw
fi

base_pid=""
overlay_pid=""

start_players() {
  if [ -n "$base_raw" ]; then
    setsid bash -c "while :; do cat '$base_raw'; done \
      | aplay -D '$DEV' -t raw -f S16_LE -r $SR -c $CH -q -" &
    base_pid=$!
  elif [ -n "$base_wav" ]; then
    # ffmpeg-less emergency path: per-file loop (has a small gap, still audio)
    setsid bash -c "while :; do aplay -D '$DEV' -q '$base_wav' || sleep 2; done" &
    base_pid=$!
  fi
  setsid bash -c '
    AUD="'"$AUD"'"; DEV="'"$DEV"'"
    while :; do
      sleep $(( '"$OV_MIN"' + RANDOM % ('"$OV_MAX"' - '"$OV_MIN"' + 1) ))
      files=("$AUD"/waiting_*.wav)
      [ -e "${files[0]}" ] || continue
      f=${files[RANDOM % ${#files[@]}]}
      aplay -D "$DEV" -q "$f" || sleep 2
    done' &
  overlay_pid=$!
}

stop_players() {
  for pid in "$base_pid" "$overlay_pid"; do
    [ -n "$pid" ] && kill -TERM -- -"$pid" 2>/dev/null
  done
  sleep 0.3
  for pid in "$base_pid" "$overlay_pid"; do
    [ -n "$pid" ] && kill -KILL -- -"$pid" 2>/dev/null
  done
  base_pid=""
  overlay_pid=""
}

trap 'stop_players; exit 0' TERM INT

playing=0
while :; do
  if main_alive; then
    if [ $playing -eq 1 ]; then
      echo "main.py detected -> fallback audio suppressed"
      stop_players
      playing=0
    fi
  else
    if [ $playing -eq 0 ]; then
      echo "main.py absent -> fallback audio playing"
      start_players
      playing=1
    fi
  fi
  sleep $POLL
done
