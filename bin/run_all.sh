#!/usr/bin/env bash
set -euo pipefail

echo "[1/2] Running Ubuntu optimization..."
"${HOME}/Projects/Scripts/ubuntu-setup/bin/ubuntu_optimize.sh"

echo
echo "[2/2] Re-applying GNOME monitor layout (Wayland)..."
MON_SRC="${HOME}/Projects/Scripts/ubuntu-setup/config/monitors.xml"
MON_DST="${HOME}/.config/monitors.xml"
mkdir -p "${HOME}/.config"
if [[ -f "${MON_SRC}" ]]; then
  cp -f "${MON_SRC}" "${MON_DST}"
  echo "Applied: ${MON_DST}"
  echo "NOTE: Log out/in (or reboot) to fully apply."
else
  echo "SKIP: ${MON_SRC} not found"
fi
