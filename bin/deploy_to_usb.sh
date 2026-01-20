#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./deploy_to_usb.sh /media/$USER/TOOLSTICK
#
# Copies this ubuntu-setup folder onto your USB toolkit.

if [[ $# -ne 1 ]]; then
  echo "ERROR: Provide the USB mount path."
  echo "Example: $0 /media/$USER/IT_TOOLKIT"
  exit 1
fi

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
USB_MOUNT="$1"
DST_DIR="${USB_MOUNT}/ubuntu-setup"

if [[ ! -d "${USB_MOUNT}" ]]; then
  echo "ERROR: Mount path does not exist: ${USB_MOUNT}"
  exit 1
fi

mkdir -p "${DST_DIR}"
rsync -av --delete "${BASE_DIR}/" "${DST_DIR}/"

echo "Deployed to: ${DST_DIR}"
echo "Run on fresh install:"
echo "  ${DST_DIR}/bin/run_all.sh"
