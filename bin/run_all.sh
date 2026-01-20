#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/2] Running Ubuntu optimization..."
"${BASE_DIR}/bin/ubuntu_optimize.sh"

echo
echo "[2/2] Re-applying GNOME monitor layout (Wayland)..."
MON_SRC="${BASE_DIR}/config/monitors.xml"
MON_DST="${HOME}/.config/monitors.xml"
mkdir -p "${HOME}/.config"
if [[ -f "${MON_SRC}" ]]; then
  cp -f "${MON_SRC}" "${MON_DST}"
  echo "Applied: ${MON_DST}"
  echo "NOTE: Log out/in (or reboot) to fully apply."
else
  echo "SKIP: ${MON_SRC} not found"
fi
