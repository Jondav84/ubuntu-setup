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

# ---- H) Swap optimization (zram + disable disk swapfile) ----
echo
echo "[H] Swap optimization (zram + disable disk swapfile)..."

# Ensure zram uses 25% of RAM
if [[ -f /etc/default/zramswap ]]; then
  sudo sed -i.bak 's/^#PERCENT=.*/PERCENT=25/' /etc/default/zramswap
  sudo sed -i.bak 's/^PERCENT=.*/PERCENT=25/' /etc/default/zramswap
  sudo systemctl restart zramswap || true
else
  echo "SKIP: /etc/default/zramswap not found"
fi

# Disable disk swapfile for responsiveness (keep zram)
if swapon --show | awk '{print $1}' | grep -qx '/swap.img'; then
  sudo swapoff /swap.img || true
fi

# Comment out any active /swap.img entry in /etc/fstab (handles leading whitespace)
if grep -qE '^[[:space:]]*/swap\.img[[:space:]]' /etc/fstab; then
  sudo sed -i.bak '/^[[:space:]]*\/swap\.img[[:space:]]/ s/^/# /' /etc/fstab
fi

# Report final swap state
swapon --show || true

# ---- I) Security baseline: UFW firewall ----
echo
echo "[I] Security baseline: UFW..."
sudo apt -y install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo ufw status verbose || true


# ---- J) Security baseline: unattended security updates ----
echo
echo "[J] Security baseline: unattended-upgrades..."
sudo apt -y install unattended-upgrades
sudo systemctl enable --now unattended-upgrades || true
systemctl status unattended-upgrades --no-pager || true

# ---- K) Security hardening: fail2ban (sshd jail) ----
echo
echo "[K] Security hardening: fail2ban..."
sudo apt -y install fail2ban
sudo systemctl enable --now fail2ban || true

# Enable sshd jail
if [[ ! -f /etc/fail2ban/jail.local ]]; then
  sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi
sudo sed -i '/^\[sshd\]/,/^\[/{s/^enabled\s*=.*/enabled = true/}' /etc/fail2ban/jail.local

sudo systemctl restart fail2ban || true
sudo fail2ban-client status || true

# ---- M) Boot optimization disable NetworkManager wait online ----
echo
echo "[M] Boot optimization: disable NetworkManager wait-online..."
sudo systemctl disable --now NetworkManager-wait-online.service || true
systemctl status NetworkManager-wait-online.service --no-pager || true

# ---- N) Boot optimization: remove plymouth quit-wait delay ----
echo
echo "[N] Boot optimization: mask plymouth-quit-wait..."
sudo systemctl mask plymouth-quit-wait.service || true
systemctl status plymouth-quit-wait.service --no-pager || true

# ---- O) Background noise reduction: disable apport/whoopsie ----
echo
echo "[O] Disable crash reporting (apport/whoopsie)..."
sudo systemctl disable --now apport.service || true
sudo systemctl disable --now whoopsie.path || true
sudo systemctl disable --now whoopsie.service || true
systemctl status apport.service --no-pager || true
systemctl status whoopsie.service --no-pager || true

# ---- L) Native-only preference: remove Snap completely ----
echo
echo "[L] Remove Snap completely (native-only preference)..."

# 1) Stop/disable snapd systemd units (safe even if not present)
sudo systemctl disable --now snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true

# 2) If snap CLI exists, remove all installed snaps (apps + bases), then snapd itself
if command -v snap >/dev/null 2>&1; then
  # Remove everything except snapd first (dependency-safe by repeated passes)
  for pass in 1 2 3 4; do
    mapfile -t snaps < <(snap list 2>/dev/null | awk 'NR>1 {print $1}' | sort -u || true)
    # If list is empty, break
    [[ ${#snaps[@]} -eq 0 ]] && break

    for s in "${snaps[@]}"; do
      [[ "${s}" == "snapd" ]] && continue
      sudo snap remove --purge "${s}" 2>/dev/null || true
    done
  done

  # Now remove snapd snap last
  sudo snap remove --purge snapd 2>/dev/null || true
fi

# 3) Purge the Debian package (may also remove transitional firefox/thunderbird snap stubs)
sudo apt -y purge snapd 2>/dev/null || true

# 4) Remove leftovers (safe even if already deleted)
sudo rm -rf "${HOME}/snap" /snap /var/snap /var/lib/snapd 2>/dev/null || true

# 5) Cleanup + clear shell command cache
sudo apt -y autoremove 2>/dev/null || true
hash -r 2>/dev/null || true

# 6) Verification (non-fatal)
command -v snap >/dev/null 2>&1 && echo "WARN: snap still present in PATH" || echo "OK: snap removed"

# ---- P) Reduce background activity: disable fwupd auto-refresh timer ----
echo
echo "[P] disable fwupd-refresh-timer (manual firmware updates)..."
sudo systemctl disable --now fwupd-refresh.timer || true
systemctl status fwupd-refresh.timer --no-pager || true
