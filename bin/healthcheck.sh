#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${BASE_DIR}/logs"

mkdir -p "${LOG_DIR}"

TS="$(date -u +%Y-%m-%dT%H%M%SZ)"

OUT="${LOG_DIR}/healthcheck_${TS}.json"


json_escape() {
  # Reads stdin, outputs a JSON-safe string (without surrounding quotes)
  python3 -c 'import json,sys; s=sys.stdin.read(); print(json.dumps(s)[1:-1])'
}


cmd_or_empty() {
  local cmd="$1"
  if eval "${cmd}" >/dev/null 2>&1; then
    eval "${cmd}" 2>&1 || true
  else
    echo ""
  fi
}

cmd_or_na() {
  local cmd="$1"
  local out=""
  out="$(eval "${cmd}" 2>&1)" || { echo "N/A"; return; }
  [[ -n "${out}" ]] && echo "${out}" || echo "N/A"
}

# Collect info (strings)
HOSTNAME="$(hostnamectl --static 2>/dev/null || hostname)"
OS_RELEASE="$(cmd_or_na "lsb_release -ds")"
KERNEL="$(uname -r)"
UPTIME="$(uptime -p 2>/dev/null || true)"
BOOT_TIME="$(cmd_or_na "uptime -s")"

MOUNTS_ROOT="$(findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS / 2>/dev/null || true)"
SWAP="$(swapon --show 2>/dev/null || true)"

UFW_STATUS="$(cmd_or_empty "sudo ufw status verbose")"
FAIL2BAN_STATUS="$(cmd_or_empty "sudo fail2ban-client status")"
TLP_STATUS="$(cmd_or_empty "sudo tlp-stat -s")"
TLP_CPU="$(cmd_or_empty "sudo tlp-stat -p | sed -n '1,90p'")"

LISTENING="$(cmd_or_na "sudo ss -tulpen | head -n 200")"

# Snap should be absent in your current design; report if present.
SNAP_PATH="$(command -v snap 2>/dev/null || true)"
SNAP_LIST="$(cmd_or_empty "snap list")"

# Updates pending
UPGRADABLE="$(cmd_or_empty "apt list --upgradable 2>/dev/null")"

# Timers (top 40)
TIMERS="$(cmd_or_empty "systemctl list-timers --all --no-pager | head -n 40")"

# Services you're actively tuning/hardening
SERVICES=(
  "ufw"
  "fail2ban"
  "zramswap"
  "tlp"
  "unattended-upgrades"
  "displaylink-driver"
  "NetworkManager-wait-online"
  "fwupd-refresh.timer"
  "avahi-daemon"
)

service_status_block() {
  local name="$1"
  # Try both service and timer/socket names
  systemctl status "${name}" --no-pager 2>/dev/null || true
}

SERVICES_STATUS="$(
  for s in "${SERVICES[@]}"; do
    echo "### ${s}"
    service_status_block "${s}"
    echo
  done
)"

# NVMe SMART health if availabe
SMART_NVME="$(cmd_or_empty "sudo smartctl -H /dev/nvme0n1")"

# User-scope status (telemetry/indexing)
USER_UNITS="$(cmd_or_empty "systemctl --user list-unit-files --state=enabled")"
UBUNTU_REPORT="$(cmd_or_empty "systemctl --user status ubuntu-report.path --no-pager")"
TRACKER_MINER="$(cmd_or_empty "systemctl --user status tracker-miner-fs-3.service --no-pager")"

# Write JSON
{
  echo "{"
  echo "  \"timestamp_utc\": \"${TS}\","
  echo "  \"hostname\": \"${HOSTNAME}\","
  echo "  \"os_release\": \"${OS_RELEASE}\" ,"
  echo "  \"kernel\": \"${KERNEL}\","
  echo "  \"uptime\": \"${UPTIME}\","
  echo "  \"boot-time\": \"${BOOT_TIME}\","
  echo "  \"root_mount\": \"$(printf '%s' "${MOUNTS_ROOT}" | json_escape)\","
  echo "  \"swap\": \"$(printf '%s' "${SWAP}" | json_escape)\","
  echo "  \"snap_path\": \"$(printf '%s' "${SNAP_PATH}" | json_escape)\","
  echo "  \"snap_list\": \"$(printf '%s' "${SNAP_LIST}" | json_escape)\","
  echo "  \"ufw_status\": \"$(printf '%s' "${UFW_STATUS}" | json_escape)\","
  echo "  \"fail2ban_status\": \"$(printf '%s' "${FAIL2BAN_STATUS}" | json_escape)\","
  echo "  \"tlp_status\": \"$(printf '%s' "${TLP_STATUS}" | json_escape)\","
  echo "  \"tlp_cpu\": \"$(printf '%s' "${TLP_CPU}" | json_escape)\","
  echo "  \"listening\": \"$(printf '%s' "${LISTENING}" | json_escape)\","
  echo "  \"upgradable\": \"$(printf '%s' "${UPGRADABLE}" | json_escape)\","
  echo "  \"timers\": \"$(printf '%s' "${TIMERS}" | json_escape)\","
  echo "  \"services_status\": \"$(printf '%s' "${SERVICES_STATUS}" | json_escape)\","
  echo "  \"smart_nvme\": \"$(printf '%s' "${SMART_NVME}" | json_escape)\","
  echo "  \"user_enabled_units\": \"$(printf '%s' "${USER_UNITS}" | json_escape)\","
  echo "  \"ubuntu_report_user\": \"$(printf '%s' "${UBUNTU_REPORT}" | json_escape)\","
  echo "  \"tracker_miner_user\": \"$(printf '%s' "${TRACKER_MINER}" | json_escape)\""
  echo "}"
} > "${OUT}"

echo "OK: wrote ${OUT}"
