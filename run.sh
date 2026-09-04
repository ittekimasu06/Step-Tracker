#!/usr/bin/env bash
# Runs the Steptrack Flutter app on a connected phone, pointed at the local
# backend (see backend/run.sh) via your machine's LAN IP.
#
# Usage:
#   bash run.sh                 # auto-detects the device and LAN IP
#   bash run.sh -d SOME_DEVICE  # override the device, or pass any other
#                                # flutter-run flag - extra args are forwarded
set -euo pipefail

# Same gotcha as backend/run.sh: a stock Windows PATH can resolve `bash` to
# WSL's bash.exe instead of Git Bash's. flutter/adb are installed on the
# Windows PATH, not WSL's, so this would fail with "flutter: command not
# found" there. Run from Git Bash instead - e.g. from PowerShell:
#   & "C:\Program Files\Git\bin\bash.exe" run.sh
if uname -r 2>/dev/null | grep -qi microsoft; then
  echo "This is WSL, not Git Bash - flutter/adb aren't on WSL's PATH." >&2
  echo "Run this from Git Bash instead, e.g. from PowerShell:" >&2
  echo '  & "C:\Program Files\Git\bin\bash.exe" run.sh' >&2
  exit 1
fi

cd "$(dirname "$0")"

# Pick the first non-loopback, non-link-local IPv4 address - works whether
# you're on Wi-Fi or Ethernet, and stays correct if your IP changes later.
LAN_IP=$(powershell.exe -NoProfile -Command \
  "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \$_.IPAddress -notlike '127.*' -and \$_.IPAddress -notlike '169.254.*' -and \$_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL' } | Select-Object -First 1 -ExpandProperty IPAddress)" \
  2>/dev/null | tr -d '\r')

if [ -z "$LAN_IP" ]; then
  echo "Could not determine a LAN IP address. Is Wi-Fi/Ethernet connected?" >&2
  exit 1
fi

DEVICE_ARGS=()
if [[ "${1:-}" != "-d" ]]; then
  # No explicit -d passed - auto-detect the first physical (mobile) device.
  MOBILE_LINE=$(flutter devices 2>/dev/null | grep '(mobile)' | head -n1 || true)
  if [ -z "$MOBILE_LINE" ]; then
    echo "No mobile device found. Plug in your phone (and accept the" >&2
    echo "'Allow USB debugging' prompt on it), then try again - or pass" >&2
    echo "-d <device-id> yourself once 'flutter devices' shows it." >&2
    exit 1
  fi
  DEVICE_ID=$(echo "$MOBILE_LINE" | awk -F'•' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
  DEVICE_NAME=$(echo "$MOBILE_LINE" | awk -F'•' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' | sed 's/ (mobile)$//')
  DEVICE_ARGS=(-d "$DEVICE_ID")
  echo "Using device: $DEVICE_NAME ($DEVICE_ID)"
fi

echo "Backend at: http://$LAN_IP:8080/api"
exec flutter run "${DEVICE_ARGS[@]}" \
  --dart-define-from-file=env.json \
  --dart-define=API_BASE_URL="http://$LAN_IP:8080/api" \
  "$@"
