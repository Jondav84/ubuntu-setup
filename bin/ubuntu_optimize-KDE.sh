#!/usr/bin/env bash
# Ubuntu baseline optimization (KDE Plasma) — bash or zsh compatible
#
# Notes:
# - KDE display layouts are managed by KScreen and stored in: ~/.local/share/kscreen/
# - KDE file indexing is Baloo (balooctl/balooctl6)
#
# Safety:
# - This script makes system changes (firewall, swap, fstab, snap removal).
# - Review before running.

# If invoked via zsh, use sh-like semantics for compatibility.
if [ -n "${ZSH_VERSION-}" ]; then
  emulate -L sh
fi

set -eu
(set -o pipefail) 2>/dev/null || true

LOG_DIR="${HOME}/Projects/Scripts/ubuntu-setup/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/kde_optimize_$(date +%Y-%m-%d_%H%M%S).log"

exec > >(tee -a "${LOG_FILE}") 2>&1

say() { printf '%s\n' "$*"; }

say "=== Ubuntu baseline optimization start (KDE Plasma) ==="
say "Time: $(date -Is)"
say "Host: $(hostnamectl --static 2>/dev/null || hostname)"
say "Kernel: $(uname -r)"
say

# ---- A) Updates + base tooling ----
say "[A] Update system and install baseline packages..."
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
  tree \
  kdeconnect \
  kscreen \
  xdg-desktop-portal xdg-desktop-portal-kde

# ---- B) Enable useful services ----
say
say "[B] Enable useful services..."
sudo systemctl enable --now fstrim.timer 2>/dev/null || true

# ---- C) Graphics/display sanity checks (non-destructive) ----
say
say "[C] Display/graphics status checks..."
systemctl status displaylink-driver --no-pager 2>/dev/null || true
if command -v xrandr >/dev/null 2>&1; then
  xrandr --listmonitors || true
fi

# ---- D) Performance friendly defaults (safe) ----
say
say "[D] Install power profiles support (safe defaults)..."
sudo apt -y install power-profiles-daemon 2>/dev/null || true

# ---- E) Safe cleanup + upgrade status ----
say
say "[E] Safe cleanup + upgrade status..."
sudo apt -y autoremove

say
say "[E] Packages upgradable (if any):"
apt list --upgradable 2>/dev/null || true

say
say "NOTE: If kernel/graphics packages upgraded, reboot is recommended."

# ---- F) KDE monitor layout restore (KScreen) ----
# Expected project layout:
#   ~/Projects/Scripts/ubuntu-setup/config/kscreen/   (directory copied from a known-good system)
say
say "[F] Restore KDE monitor layout (KScreen)..."
KS_SRC="${HOME}/Projects/Scripts/ubuntu-setup/config/kscreen"
KS_DST="${HOME}/.local/share/kscreen"

if [ -d "${KS_SRC}" ]; then
  mkdir -p "${HOME}/.local/share"
  rm -rf "${KS_DST}"
  cp -a "${KS_SRC}" "${KS_DST}"
  say "Applied: ${KS_DST}"
  say "NOTE: Log out/in (or reboot) for changes to fully apply."
else
  say "SKIP: ${KS_SRC} not found"
fi

# ---- G) Responsiveness: set performance profile when AC power is present ----
say
say "[G] Responsiveness power profile..."
if command -v powerprofilesctl >/dev/null 2>&1; then
  if command -v upower >/dev/null 2>&1 && upower -e 2>/dev/null | grep -q BAT; then
    BAT_DEV="$(upower -e 2>/dev/null | grep BAT | head -n 1 || true)"
    if [ -n "${BAT_DEV}" ] && upower -i "${BAT_DEV}" 2>/dev/null | grep -Eqi 'state:\s*(charging|fully-charged)'; then
      sudo powerprofilesctl set performance 2>/dev/null || true
      say "Set profile: performance (on AC)"
    else
      say "Leave profile unchanged (on battery)"
    fi
  else
    sudo powerprofilesctl set performance 2>/dev/null || true
    say "Set profile: performance (no battery detected)"
  fi
else
  say "SKIP: powerprofilesctl not found"
fi

# ---- H) Swap optimization (zram + disable disk swapfile) ----
say
say "[H] Swap optimization (zram + disable disk swapfile)..."

# Ensure zram uses 25% of RAM (if zramswap exists)
if [ -f /etc/default/zramswap ]; then
  sudo cp -a /etc/default/zramswap /etc/default/zramswap.bak 2>/dev/null || true
  sudo sed -i 's/^#PERCENT=.*/PERCENT=25/' /etc/default/zramswap
  sudo sed -i 's/^PERCENT=.*/PERCENT=25/' /etc/default/zramswap
  sudo systemctl restart zramswap 2>/dev/null || true
else
  say "SKIP: /etc/default/zramswap not found"
fi

# Disable disk swapfile for responsiveness (keep zram)
if swapon --show 2>/dev/null | awk 'NR>1{print $1}' | grep -qx '/swap.img'; then
  sudo swapoff /swap.img 2>/dev/null || true
fi

# Comment out any active /swap.img entry in /etc/fstab
if grep -qE '^[[:space:]]*/swap\.img[[:space:]]' /etc/fstab 2>/dev/null; then
  sudo cp -a /etc/fstab /etc/fstab.bak 2>/dev/null || true
  sudo sed -i '/^[[:space:]]*\/swap\.img[[:space:]]/ s/^/# /' /etc/fstab
fi

say
say "[H] Final swap state:"
swapon --show 2>/dev/null || true

# ---- I) Security baseline: UFW firewall ----
say
say "[I] Security baseline: UFW..."
sudo apt -y install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo ufw status verbose 2>/dev/null || true

# ---- J) Security baseline: unattended security updates ----
say
say "[J] Security baseline: unattended-upgrades..."
sudo apt -y install unattended-upgrades
sudo systemctl enable --now unattended-upgrades 2>/dev/null || true
systemctl status unattended-upgrades --no-pager 2>/dev/null || true

# ---- K) Security hardening: fail2ban (sshd jail) ----
say
say "[K] Security hardening: fail2ban..."
sudo apt -y install fail2ban
sudo systemctl enable --now fail2ban 2>/dev/null || true

if [ ! -f /etc/fail2ban/jail.local ]; then
  sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi
sudo sed -i '/^\[sshd\]/,/^\[/{s/^enabled[[:space:]]*=.*/enabled = true/}' /etc/fail2ban/jail.local

sudo systemctl restart fail2ban 2>/dev/null || true
sudo fail2ban-client status 2>/dev/null || true

# ---- L) Native-only preference: remove Snap completely ----
say
say "[L] Remove Snap completely (native-only preference)..."

sudo systemctl disable --now snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true

if command -v snap >/dev/null 2>&1; then
  for pass in 1 2 3 4; do
    snaps="$(snap list 2>/dev/null | awk 'NR>1 {print $1}' | sort -u || true)"
    [ -z "${snaps}" ] && break

    printf '%s\n' "${snaps}" | while IFS= read -r s; do
      [ -z "${s}" ] && continue
      [ "${s}" = "snapd" ] && continue
      sudo snap remove --purge "${s}" 2>/dev/null || true
    done
  done

  sudo snap remove --purge snapd 2>/dev/null || true
fi

sudo apt -y purge snapd 2>/dev/null || true
sudo rm -rf "${HOME}/snap" /snap /var/snap /var/lib/snapd 2>/dev/null || true
sudo apt -y autoremove 2>/dev/null || true
hash -r 2>/dev/null || true
command -v snap >/dev/null 2>&1 && say "WARN: snap still present in PATH" || say "OK: snap removed"

# ---- M) Boot optimization: disable NetworkManager wait-online ----
say
say "[M] Boot optimization: disable NetworkManager wait-online..."
sudo systemctl disable --now NetworkManager-wait-online.service 2>/dev/null || true
systemctl status NetworkManager-wait-online.service --no-pager 2>/dev/null || true

# ---- N) Boot optimization: remove plymouth quit-wait delay ----
say
say "[N] Boot optimization: mask plymouth-quit-wait..."
sudo systemctl mask plymouth-quit-wait.service 2>/dev/null || true
systemctl status plymouth-quit-wait.service --no-pager 2>/dev/null || true

# ---- O) Background noise reduction: disable apport/whoopsie ----
say
say "[O] Disable crash reporting (apport/whoopsie)..."
sudo systemctl disable --now apport.service 2>/dev/null || true
sudo systemctl disable --now whoopsie.path 2>/dev/null || true
sudo systemctl disable --now whoopsie.service 2>/dev/null || true
systemctl status apport.service --no-pager 2>/dev/null || true
systemctl status whoopsie.service --no-pager 2>/dev/null || true

# ---- P) Reduce background activity: disable fwupd auto-refresh timer ----
say
say "[P] Disable fwupd-refresh timer (manual firmware updates)..."
sudo systemctl disable --now fwupd-refresh.timer 2>/dev/null || true
systemctl status fwupd-refresh.timer --no-pager 2>/dev/null || true

# ---- Q) CPU tuning: TLP performance on AC ----
say
say "[Q] CPU tuning: configure TLP for performance on AC..."
sudo apt -y install tlp tlp-rdw
sudo systemctl enable --now tlp 2>/dev/null || true

sudo cp -a /etc/tlp.conf /etc/tlp.conf.bak 2>/dev/null || true
sudo sed -i \
  -e 's/^#\?CPU_SCALING_GOVERNOR_ON_AC=.*/CPU_SCALING_GOVERNOR_ON_AC=performance/' \
  -e 's/^#\?CPU_SCALING_GOVERNOR_ON_BAT=.*/CPU_SCALING_GOVERNOR_ON_BAT=powersave/' \
  -e 's/^#\?CPU_ENERGY_PERF_POLICY_ON_AC=.*/CPU_ENERGY_PERF_POLICY_ON_AC=performance/' \
  -e 's/^#\?CPU_ENERGY_PERF_POLICY_ON_BAT=.*/CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power/' \
  /etc/tlp.conf

sudo tlp start 2>/dev/null || true
sudo tlp-stat -p 2>/dev/null | sed -n '1,40p' || true

# ---- R) Disk optimization: enable noatime on root filesystem ----
say
say "[R] Disk optimization: enable noatime on / ..."
sudo cp /etc/fstab /etc/fstab.bak 2>/dev/null || true

# Only adjust if root is ext4 AND noatime isn't already present on that root line.
if grep -qE '^[[:space:]]*UUID=.*[[:space:]]+/[[:space:]]+ext4[[:space:]]+' /etc/fstab 2>/dev/null \
  && ! grep -qE '^[[:space:]]*UUID=.*[[:space:]]+/[[:space:]]+ext4[[:space:]]+[^#[:space:]]*noatime' /etc/fstab 2>/dev/null; then
  sudo sed -i -E 's/^([[:spac#!/usr/bin/env bash
# Ubuntu baseline optimization (KDE Plasma) — bash or zsh compatible
#
# Notes:
# - KDE display layouts are managed by KScreen and stored in: ~/.local/share/kscreen/
# - KDE file indexing is Baloo (balooctl/balooctl6)
#
# Safety:
# - This script makes system changes (firewall, swap, fstab, snap removal).
# - Review before running.

# If invoked via zsh, use sh-like semantics for compatibility.
if [ -n "${ZSH_VERSION-}" ]; then
  emulate -L sh
fi

set -eu
(set -o pipefail) 2>/dev/null || true

LOG_DIR="${HOME}/Projects/Scripts/ubuntu-setup/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/kde_optimize_$(date +%Y-%m-%d_%H%M%S).log"

exec > >(tee -a "${LOG_FILE}") 2>&1

say() { printf '%s\n' "$*"; }

say "=== Ubuntu baseline optimization start (KDE Plasma) ==="
say "Time: $(date -Is)"
say "Host: $(hostnamectl --static 2>/dev/null || hostname)"
say "Kernel: $(uname -r)"
say

# ---- A) Updates + base tooling ----
say "[A] Update system and install baseline packages..."
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
  tree \
  kdeconnect \
  kscreen \
  xdg-desktop-portal xdg-desktop-portal-kde

# ---- B) Enable useful services ----
say
say "[B] Enable useful services..."
sudo systemctl enable --now fstrim.timer 2>/dev/null || true

# ---- C) Graphics/display sanity checks (non-destructive) ----
say
say "[C] Display/graphics status checks..."
systemctl status displaylink-driver --no-pager 2>/dev/null || true
if command -v xrandr >/dev/null 2>&1; then
  xrandr --listmonitors || true
fi

# ---- D) Performance friendly defaults (safe) ----
say
say "[D] Install power profiles support (safe defaults)..."
sudo apt -y install power-profiles-daemon 2>/dev/null || true

# ---- E) Safe cleanup + upgrade status ----
say
say "[E] Safe cleanup + upgrade status..."
sudo apt -y autoremove

say
say "[E] Packages upgradable (if any):"
apt list --upgradable 2>/dev/null || true

say
say "NOTE: If kernel/graphics packages upgraded, reboot is recommended."

# ---- F) KDE monitor layout restore (KScreen) ----
# Expected project layout:
#   ~/Projects/Scripts/ubuntu-setup/config/kscreen/   (directory copied from a known-good system)
say
say "[F] Restore KDE monitor layout (KScreen)..."
KS_SRC="${HOME}/Projects/Scripts/ubuntu-setup/config/kscreen"
KS_DST="${HOME}/.local/share/kscreen"

if [ -d "${KS_SRC}" ]; then
  mkdir -p "${HOME}/.local/share"
  rm -rf "${KS_DST}"
  cp -a "${KS_SRC}" "${KS_DST}"
  say "Applied: ${KS_DST}"
  say "NOTE: Log out/in (or reboot) for changes to fully apply."
else
  say "SKIP: ${KS_SRC} not found"
fi

# ---- G) Responsiveness: set performance profile when AC power is present ----
say
say "[G] Responsiveness power profile..."
if command -v powerprofilesctl >/dev/null 2>&1; then
  if command -v upower >/dev/null 2>&1 && upower -e 2>/dev/null | grep -q BAT; then
    BAT_DEV="$(upower -e 2>/dev/null | grep BAT | head -n 1 || true)"
    if [ -n "${BAT_DEV}" ] && upower -i "${BAT_DEV}" 2>/dev/null | grep -Eqi 'state:\s*(charging|fully-charged)'; then
      sudo powerprofilesctl set performance 2>/dev/null || true
      say "Set profile: performance (on AC)"
    else
      say "Leave profile unchanged (on battery)"
    fi
  else
    sudo powerprofilesctl set performance 2>/dev/null || true
    say "Set profile: performance (no battery detected)"
  fi
else
  say "SKIP: powerprofilesctl not found"
fi

# ---- H) Swap optimization (zram + disable disk swapfile) ----
say
say "[H] Swap optimization (zram + disable disk swapfile)..."

# Ensure zram uses 25% of RAM (if zramswap exists)
if [ -f /etc/default/zramswap ]; then
  sudo cp -a /etc/default/zramswap /etc/default/zramswap.bak 2>/dev/null || true
  sudo sed -i 's/^#PERCENT=.*/PERCENT=25/' /etc/default/zramswap
  sudo sed -i 's/^PERCENT=.*/PERCENT=25/' /etc/default/zramswap
  sudo systemctl restart zramswap 2>/dev/null || true
else
  say "SKIP: /etc/default/zramswap not found"
fi

# Disable disk swapfile for responsiveness (keep zram)
if swapon --show 2>/dev/null | awk 'NR>1{print $1}' | grep -qx '/swap.img'; then
  sudo swapoff /swap.img 2>/dev/null || true
fi

# Comment out any active /swap.img entry in /etc/fstab
if grep -qE '^[[:space:]]*/swap\.img[[:space:]]' /etc/fstab 2>/dev/null; then
  sudo cp -a /etc/fstab /etc/fstab.bak 2>/dev/null || true
  sudo sed -i '/^[[:space:]]*\/swap\.img[[:space:]]/ s/^/# /' /etc/fstab
fi

say
say "[H] Final swap state:"
swapon --show 2>/dev/null || true

# ---- I) Security baseline: UFW firewall ----
say
say "[I] Security baseline: UFW..."
sudo apt -y install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo ufw status verbose 2>/dev/null || true

# ---- J) Security baseline: unattended security updates ----
say
say "[J] Security baseline: unattended-upgrades..."
sudo apt -y install unattended-upgrades
sudo systemctl enable --now unattended-upgrades 2>/dev/null || true
systemctl status unattended-upgrades --no-pager 2>/dev/null || true

# ---- K) Security hardening: fail2ban (sshd jail) ----
say
say "[K] Security hardening: fail2ban..."
sudo apt -y install fail2ban
sudo systemctl enable --now fail2ban 2>/dev/null || true

if [ ! -f /etc/fail2ban/jail.local ]; then
  sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi
sudo sed -i '/^\[sshd\]/,/^\[/{s/^enabled[[:space:]]*=.*/enabled = true/}' /etc/fail2ban/jail.local

sudo systemctl restart fail2ban 2>/dev/null || true
sudo fail2ban-client status 2>/dev/null || true

# ---- L) Native-only preference: remove Snap completely ----
say
say "[L] Remove Snap completely (native-only preference)..."

sudo systemctl disable --now snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true

if command -v snap >/dev/null 2>&1; then
  for pass in 1 2 3 4; do
    snaps="$(snap list 2>/dev/null | awk 'NR>1 {print $1}' | sort -u || true)"
    [ -z "${snaps}" ] && break

    printf '%s\n' "${snaps}" | while IFS= read -r s; do
      [ -z "${s}" ] && continue
      [ "${s}" = "snapd" ] && continue
      sudo snap remove --purge "${s}" 2>/dev/null || true
    done
  done

  sudo snap remove --purge snapd 2>/dev/null || true
fi

sudo apt -y purge snapd 2>/dev/null || true
sudo rm -rf "${HOME}/snap" /snap /var/snap /var/lib/snapd 2>/dev/null || true
sudo apt -y autoremove 2>/dev/null || true
hash -r 2>/dev/null || true
command -v snap >/dev/null 2>&1 && say "WARN: snap still present in PATH" || say "OK: snap removed"

# ---- M) Boot optimization: disable NetworkManager wait-online ----
say
say "[M] Boot optimization: disable NetworkManager wait-online..."
sudo systemctl disable --now NetworkManager-wait-online.service 2>/dev/null || true
systemctl status NetworkManager-wait-online.service --no-pager 2>/dev/null || true

# ---- N) Boot optimization: remove plymouth quit-wait delay ----
say
say "[N] Boot optimization: mask plymouth-quit-wait..."
sudo systemctl mask plymouth-quit-wait.service 2>/dev/null || true
systemctl status plymouth-quit-wait.service --no-pager 2>/dev/null || true

# ---- O) Background noise reduction: disable apport/whoopsie ----
say
say "[O] Disable crash reporting (apport/whoopsie)..."
sudo systemctl disable --now apport.service 2>/dev/null || true
sudo systemctl disable --now whoopsie.path 2>/dev/null || true
sudo systemctl disable --now whoopsie.service 2>/dev/null || true
systemctl status apport.service --no-pager 2>/dev/null || true
systemctl status whoopsie.service --no-pager 2>/dev/null || true

# ---- P) Reduce background activity: disable fwupd auto-refresh timer ----
say
say "[P] Disable fwupd-refresh timer (manual firmware updates)..."
sudo systemctl disable --now fwupd-refresh.timer 2>/dev/null || true
systemctl status fwupd-refresh.timer --no-pager 2>/dev/null || true

# ---- Q) CPU tuning: TLP performance on AC ----
say
say "[Q] CPU tuning: configure TLP for performance on AC..."
sudo apt -y install tlp tlp-rdw
sudo systemctl enable --now tlp 2>/dev/null || true

sudo cp -a /etc/tlp.conf /etc/tlp.conf.bak 2>/dev/null || true
sudo sed -i \
  -e 's/^#\?CPU_SCALING_GOVERNOR_ON_AC=.*/CPU_SCALING_GOVERNOR_ON_AC=performance/' \
  -e 's/^#\?CPU_SCALING_GOVERNOR_ON_BAT=.*/CPU_SCALING_GOVERNOR_ON_BAT=powersave/' \
  -e 's/^#\?CPU_ENERGY_PERF_POLICY_ON_AC=.*/CPU_ENERGY_PERF_POLICY_ON_AC=performance/' \
  -e 's/^#\?CPU_ENERGY_PERF_POLICY_ON_BAT=.*/CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power/' \
  /etc/tlp.conf

sudo tlp start 2>/dev/null || true
sudo tlp-stat -p 2>/dev/null | sed -n '1,40p' || true

# ---- R) Disk optimization: enable noatime on root filesystem ----
say
say "[R] Disk optimization: enable noatime on / ..."
sudo cp /etc/fstab /etc/fstab.bak 2>/dev/null || true

# Only adjust if root is ext4 AND noatime isn't already present on that root line.
if grep -qE '^[[:space:]]*UUID=.*[[:space:]]+/[[:space:]]+ext4[[:space:]]+' /etc/fstab 2>/dev/null \
  && ! grep -qE '^[[:space:]]*UUID=.*[[:space:]]+/[[:space:]]+ext4[[:space:]]+[^#[:space:]]*noatime' /etc/fstab 2>/dev/null; then
  sudo sed -i -E 's/^([[:space:]]*UUID=.*[[:space:]]+\/[[:space:]]+ext4[[:space:]]+)([^[:space:]]+)/\1\2,noatime/' /etc/fstab
fi

sudo systemctl daemon-reload 2>/dev/null || true
sudo mount -o remount / 2>/dev/null || true
findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS / 2>/dev/null || true

# ---- S) UFW hardening: block mDNS multicast ----
say
say "[S] UFW hardening: block mDNS multicast..."
sudo ufw deny in proto udp to 224.0.0.251 port 5353 comment "Block mDNS multicast" 2>/dev/null || true
sudo ufw deny in proto udp to ff02::fb port 5353 comment "Block mDNS multicast IPv6" 2>/dev/null || true
sudo ufw status numbered 2>/dev/null || true

# ---- T) KDE responsiveness: disable ubuntu-report + Baloo indexing ----
say
say "[T] KDE responsiveness: disable ubuntu-report + Baloo indexing..."

# ubuntu-report (user service)
systemctl --user mask ubuntu-report.path ubuntu-report.service 2>/dev/null || true

# Baloo file indexer
if command -v balooctl6 >/dev/null 2>&1; then
  balooctl6 disable 2>/dev/null || true
  balooctl6 status 2>/dev/null || true
elif command -v balooctl >/dev/null 2>&1; then
  balooctl disable 2>/dev/null || true
  balooctl status 2>/dev/null || true
else
  say "SKIP: balooctl not found"
fi

say
say "=== Done ==="
say "Log: ${LOG_FILE}"
e:]]*UUID=.*[[:space:]]+\/[[:space:]]+ext4[[:space:]]+)([^[:space:]]+)/\1\2,noatime/' /etc/fstab
fi

sudo systemctl daemon-reload 2>/dev/null || true
sudo mount -o remount / 2>/dev/null || true
findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS / 2>/dev/null || true

# ---- S) UFW hardening: block mDNS multicast ----
say
say "[S] UFW hardening: block mDNS multicast..."
sudo ufw deny in proto udp to 224.0.0.251 port 5353 comment "Block mDNS multicast" 2>/dev/null || true
sudo ufw deny in proto udp to ff02::fb port 5353 comment "Block mDNS multicast IPv6" 2>/dev/null || true
sudo ufw status numbered 2>/dev/null || true

# ---- T) KDE responsiveness: disable ubuntu-report + Baloo indexing ----
say
say "[T] KDE responsiveness: disable ubuntu-report + Baloo indexing..."

# ubuntu-report (user service)
systemctl --user mask ubuntu-report.path ubuntu-report.service 2>/dev/null || true

# Baloo file indexer
if command -v balooctl6 >/dev/null 2>&1; then
  balooctl6 disable 2>/dev/null || true
  balooctl6 status 2>/dev/null || true
elif command -v balooctl >/dev/null 2>&1; then
  balooctl disable 2>/dev/null || true
  balooctl status 2>/dev/null || true
else
  say "SKIP: balooctl not found"
fi

say
say "=== Done ==="
say "Log: ${LOG_FILE}"
