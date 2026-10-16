#!/bin/bash
# Android box provisioning script
#
# Usage:
#   ./provision.sh 192.168.1.50 [192.168.1.51 ...]     provision one or more boxes by IP
#   ./provision.sh --csv customers.csv                  provision every box listed in a CSV
#
# Requirements: adb on PATH (see README.md), box on the same network with
# ADB debugging enabled, and your APKs dropped into the apks/ folder.

set -u
cd "$(dirname "$0")"

# ===== EDIT THESE FOR YOUR SETUP ============================================
# Package name of your main IPTV app, used for the launch test at the end.
# Find it after the first install with:  adb shell pm list packages | grep -i <name>
#   TiviMate = ar.tvplayer.tv    IPTV Smarters Pro = com.nst.iptvsmarterstvbox
MAIN_APP_PACKAGE="ar.tvplayer.tv"

# Keep the screen awake forever (most IPTV boxes want this). Set to 0 to skip.
SET_NEVER_SLEEP=1
# ============================================================================

PORT=5555
PASS=()
FAIL=()

provision_box() {
  local IP="$1" NAME="${2:-}"
  local BOX="$IP:$PORT"
  echo ""
  echo "=== Provisioning $BOX ${NAME:+($NAME)} ==="

  adb connect "$BOX" | grep -q "connected" || { echo "!! Cannot reach $IP - is ADB debugging on and the box on this network?"; FAIL+=("$IP"); return; }

  # Wait for the device to be authorized (the box shows an Allow prompt on first contact)
  local STATE
  STATE=$(adb -s "$BOX" get-state 2>/dev/null)
  if [ "$STATE" != "device" ]; then
    echo ">> Waiting for you to accept the 'Allow USB debugging' prompt on the TV (60s)..."
    for _ in $(seq 1 30); do
      sleep 2
      STATE=$(adb -s "$BOX" get-state 2>/dev/null)
      [ "$STATE" = "device" ] && break
    done
    [ "$STATE" = "device" ] || { echo "!! $IP never authorized - accept the prompt and re-run."; FAIL+=("$IP"); return; }
  fi

  # 1. Install every APK in the kit (-r = reinstall ok, safe to re-run).
  #    APKs captured as pkg.split0.apk/pkg.split1.apk are one app in several
  #    pieces and get installed together with install-multiple.
  local APK OK=1 BASE
  shopt -s nullglob
  local -A GROUPS=()
  for APK in apks/*.apk; do
    BASE=$(basename "$APK" .apk); BASE=${BASE%.split[0-9]*}
    GROUPS[$BASE]+="$APK"$'\n'
  done
  shopt -u nullglob
  for BASE in "${!GROUPS[@]}"; do
    mapfile -t FILES <<< "${GROUPS[$BASE]%$'\n'}"
    if [ "${#FILES[@]}" -gt 1 ]; then
      echo ">> Installing $BASE (${#FILES[@]} split APKs) ..."
      adb -s "$BOX" install-multiple -r "${FILES[@]}" || { echo "!! Install failed: $BASE"; OK=0; }
    else
      echo ">> Installing ${FILES[0]##*/} ..."
      adb -s "$BOX" install -r "${FILES[0]}" || { echo "!! Install failed: ${FILES[0]}"; OK=0; }
    fi
  done

  # 2. Settings
  if [ "$SET_NEVER_SLEEP" = "1" ]; then
    adb -s "$BOX" shell settings put system screen_off_timeout 2147483647
  fi

  # 3. Push any config files (playlists, backups, etc.) from configs/
  local CFG
  shopt -s nullglob
  for CFG in configs/*; do
    [ -f "$CFG" ] || continue
    echo ">> Pushing ${CFG##*/} to /sdcard/Download/ ..."
    adb -s "$BOX" push "$CFG" /sdcard/Download/ || OK=0
  done
  shopt -u nullglob

  # 4. Launch test of the main app
  if [ -n "$MAIN_APP_PACKAGE" ]; then
    echo ">> Launch test: $MAIN_APP_PACKAGE"
    adb -s "$BOX" shell monkey -p "$MAIN_APP_PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
      && echo ">> App launched OK" \
      || { echo "!! App did not launch - check the package name at the top of this script"; OK=0; }
  fi

  adb disconnect "$BOX" >/dev/null
  if [ "$OK" = "1" ]; then PASS+=("$IP"); echo "=== $IP DONE ==="; else FAIL+=("$IP"); echo "=== $IP FINISHED WITH ERRORS ==="; fi
}

# ----- main -----------------------------------------------------------------
command -v adb >/dev/null || { echo "adb not found - see README.md step 1"; exit 1; }

if [ "${1:-}" = "--csv" ]; then
  CSV="${2:?usage: ./provision.sh --csv customers.csv}"
  [ -f "$CSV" ] || { echo "CSV not found: $CSV"; exit 1; }
  # CSV columns: name,ip  (header line is skipped; extra columns ignored)
  while IFS=, read -r NAME IP _; do
    [ "$NAME" = "name" ] && continue           # skip header
    [ -z "${IP//[[:space:]]/}" ] && continue   # skip blank lines
    provision_box "$(echo "$IP" | tr -d '[:space:]')" "$NAME"
  done < "$CSV"
elif [ $# -ge 1 ]; then
  for IP in "$@"; do provision_box "$IP"; done
else
  echo "Usage: ./provision.sh <ip> [<ip> ...]   or   ./provision.sh --csv customers.csv"
  exit 1
fi

echo ""
echo "================ SUMMARY ================"
echo "OK (${#PASS[@]}):     ${PASS[*]:-none}"
echo "FAILED (${#FAIL[@]}): ${FAIL[*]:-none}"
