#!/usr/bin/env bash
set -euo pipefail
LOG_DIR="${HOME}/Projects/Scripts/ubuntu-setup/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/ubuntu_optimize_$(date +%Y-%m-%d_%H%M%S).log"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=== Ubuntu baseline optimization start ==="
echo "Time: $(date -Is)"
echo "Host: $(hostnamectl --static 2>/dev/null || hostname)"
echo "Kernel: $(uname -r)"
echo

# ---- A) Updates + base tooling ----
echo "[A] Update system and install baseline packages..."
sudo apt update
sudo apt -y upgrade
sudo apt -y install \
  git curl wget unzip zip ca-certificates gnupg \
  build-essential pkg-config make cmake \
  python3 python3-pip python3-venv pipx \
  sqlite3 \
  htop iotop iftop \
  lm-sensors smartmontools \
  network-manager \
  fonts-firacode \
  gnome-tweaks gnome-shell-extension-manager tree

# ---- B) Enable useful Services ----
echo
echo "[B] Enable useful services..."
sudo systemctl enable --now fstrim.timer || true

# ---- C) Graphics/display sanity checks (non-destructive) ----
echo
echo "[C] Display/graphics status checks..."
systemctl status displaylink-driver --no-pager || true
command -v xrandr >/dev/null 2>&1 && xrandr --listmonitors || true

# ---- D) Performance friendly defaults (safe) ----
echo
echo "[D] install tuned power profiles (safe defaults)..."
sudo apt -y install power-profiles-daemon || true

echo
echo "=== Done ==="
echo "Log: ${LOG_FILE}"

# ---- E) Safe cleanup + upgrade status ----
echo
echo "[E] Safe cleanup + upgrade status..."
sudo apt -y autoremove

echo
echo "[E] Packages held back (if any):"
apt list --upgradable 2>/dev/null || true

echo
echo "NOTE: If kernel/graphics packages upgraded, reboot is recommended."


# ---- F) GNOME Wayland monitor layout restore (monitors.xml) ----
echo
echo "[F] Restore GNOME monitor layout (Wayland)..."
MON_SRC="${HOME}/Projects/Scripts/ubuntu-setup/config/monitors.xml"
MON_DST="${HOME}/.config/monitors.xml"

if [[ -f "${MON_SRC}" ]]; then
  mkdir -p "${HOME}/.config"
  cp -f "${MON_SRC}" "${MON_DST}"
  echo "Applied: ${MON_DST}"
  echo "NOTE: You must log out and log back in (or reboot) for changes to fully apply."
else
  echo "SKIP: ${MON_SRC} not found"
fi

# ---- G) Responsiveness: set performance profile when AC power is present ----
echo
echo "[G] Responsiveness power profile..."
if command -v powerprofilesctl >/dev/null 2>&1; then
  if command -v upower >/dev/null 2>&1 && upower -e | grep -q BAT; then
    # If we can detect battery device, also detect if we're on AC
    if upower -i "$(upower -e | grep BAT | head -n 1)" | grep -Eqi "state:\s*(charging|fully-charged)"; then
      sudo powerprofilesctl set performance || true
      echo "Set profile: performance (on AC)"
    else
      echo "Leave profile unchanged (on battery)"
    fi
  else
    # No battery info; default to performance for desktops/unknown
    sudo powerprofilesctl set performance || true
    echo "Set profile: performance (no battery detected)"
  fi
else
  echo "SKIP: powerprofilesctl not found"
fi

# ---- H) zram swap tuning (responsiveness) ----
echo
echo "[H] zram swap tuning..."
if [[ -f /etc/default/zramswap ]]; then
  sudo sed -i.bak 's/^#PERCENT=.*/PERCENT=25/' /etc/default/zramswap
  sudo sed -i.bak 's/^PERCENT=.*/PERCENT=25/' /etc/default/zramswap
  sudo systemctl restart zramswap || true
  swapon --show || true
else
  echo "SKIP: /etc/default/zramswap not found"
fi

# ---- I) Security baseline: UFW firewall ----
echo
echo "[I] Security baseline: UFW..."
sudo apt -y install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo ufw status verbose || true
