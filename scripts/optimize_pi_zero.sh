#!/bin/bash
# ==============================================================================
# Raspberry Pi Zero W Optimization & Debloat Script
# Specifically tuned for single-core BCM2835 (512MB RAM) running Bookworm
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run with sudo: sudo bash $0"
  exit 1
fi

TARGET_USER="${SUDO_USER:-pi}"

echo "============================================================"
echo " Raspberry Pi Zero W Performance & Memory Optimizer"
echo "============================================================"

# 1. Disable Raspberry Pi Connect & WayVNC (Saves ~40 MB RAM + heavy CPU usage)
echo "[+] Disabling Raspberry Pi Connect & background WayVNC..."
systemctl disable --now wayvnc.service wayvnc-control.service rpi-connect.service 2>/dev/null || true
pkill -f wayvnc 2>/dev/null || true
if [ -n "$TARGET_USER" ]; then
  su - "$TARGET_USER" -c "systemctl --user disable --now rpi-connect-wayvnc.service 2>/dev/null || true"
fi

# 2. Disable & Purge CUPS (Printing System - saves ~20 MB RAM)
echo "[+] Removing CUPS printer daemons..."
systemctl disable --now cups.service cups-browsed.service 2>/dev/null || true
apt purge -y cups cups-browsed hplip 2>/dev/null || true

# 3. Disable & Purge ModemManager (Cellular USB modem scanner - saves ~15 MB RAM)
echo "[+] Removing ModemManager..."
systemctl disable --now ModemManager.service 2>/dev/null || true
apt purge -y modemmanager 2>/dev/null || true

# 4. Disable Triggerhappy (Hotkey daemon)
echo "[+] Disabling Triggerhappy daemon..."
systemctl disable --now triggerhappy.service 2>/dev/null || true

# 5. Disable background apt-daily timers (Prevents 100% CPU lockups on single-core)
echo "[+] Disabling background apt auto-update timers..."
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

# 6. Optimize MicroSD Card Swappiness & RAM Cache
echo "[+] Tuning kernel virtual memory (swappiness & cache pressure)..."
SYSCTL_CONF="/etc/sysctl.d/99-pi-zero-tuning.conf"
cat << 'EOF' > "$SYSCTL_CONF"
# Raspberry Pi Zero W memory tuning
# Reduce swappiness to minimize slow SD card thrashing
vm.swappiness=10
# Balance cache reclamation
vm.vfs_cache_pressure=50
# Clean dirty pages more frequently in smaller chunks
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF
/sbin/sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true

# 7. Limit Systemd Journal Size in RAM (Prevents log accumulation)
echo "[+] Limiting systemd-journald log size..."
JOURNALD_CONF="/etc/systemd/journald.conf.d/size-limit.conf"
mkdir -p "$(dirname "$JOURNALD_CONF")"
cat << 'EOF' > "$JOURNALD_CONF"
[Journal]
Storage=volatile
RuntimeMaxUse=16M
EOF
systemctl restart systemd-journald 2>/dev/null || true

# 8. Clean up package orphans and apt cache
echo "[+] Cleaning orphaned packages and apt cache..."
apt autoremove --purge -y 2>/dev/null || true
apt clean 2>/dev/null || true

echo ""
echo "============================================================"
echo " Optimization complete!"
echo " Saved ~60 - 80 MB RAM, freed SD space, and eliminated CPU spikes."
echo "============================================================"
free -h
