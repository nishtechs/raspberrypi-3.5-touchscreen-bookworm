#!/bin/bash
# ==============================================================================
# RS1535 / Waveshare 3.5" SPI LCD Setup Script for Raspberry Pi OS 12 (Bookworm)
# Hardware: 3.5inch 480x320 SPI LCD (ILI9486 + ADS7846/XPT2046 Touch)
# Supported OS: Raspberry Pi OS 12 (Bookworm) with Desktop (labwc/Wayland) or Lite
# ==============================================================================

set -e

CONFIG_FILE="/boot/firmware/config.txt"
[ ! -f "$CONFIG_FILE" ] && CONFIG_FILE="/boot/config.txt"

echo "============================================================"
echo " RS1535 / Waveshare 3.5\" SPI LCD Installer (Bookworm/DRM)"
echo "============================================================"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run as root or with sudo:"
  echo "    sudo bash $0"
  exit 1
fi

TARGET_USER="${SUDO_USER:-pi}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

echo "[+] Target user: $TARGET_USER ($TARGET_HOME)"
echo "[+] Boot config: $CONFIG_FILE"

# 1. Backup configuration file
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
echo "[+] Creating backup at $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

# 2. Configure /boot/firmware/config.txt
echo "[+] Updating boot configuration..."

# Ensure SPI is enabled
if grep -q "^dtparam=spi=" "$CONFIG_FILE"; then
  sed -i 's/^dtparam=spi=.*/dtparam=spi=on/' "$CONFIG_FILE"
else
  echo "dtparam=spi=on" >> "$CONFIG_FILE"
fi

# Remove old/conflicting third-party overlays if present
sed -i '/dtoverlay=waveshare35a/d' "$CONFIG_FILE"
sed -i '/dtoverlay=piscreen/d' "$CONFIG_FILE"

# Append native in-tree DRM piscreen overlay
cat << 'EOF' >> "$CONFIG_FILE"

# --- 3.5inch SPI LCD (RS1535 / Waveshare 3.5) Native DRM Driver ---
dtoverlay=piscreen,drm,speed=18000000,rotate=90
EOF

echo "[+] Boot config updated with native DRM overlay."

# 3. Configure Wayland compositor (kanshi) for persistent landscape rotation
if [ -n "$TARGET_HOME" ] && [ -d "$TARGET_HOME" ]; then
  KANSHI_DIR="$TARGET_HOME/.config/kanshi"
  mkdir -p "$KANSHI_DIR"
  cat << 'EOF' > "$KANSHI_DIR/config"
profile {
    output SPI-1 enable transform 90
}
EOF
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"
  echo "[+] Kanshi display profile configured (output SPI-1, transform 90)."

  # Ensure labwc maps ADS7846 touch directly to SPI-1
  LABWC_DIR="$TARGET_HOME/.config/labwc"
  mkdir -p "$LABWC_DIR"
  if [ ! -f "$LABWC_DIR/rc.xml" ] || ! grep -q "ADS7846 Touchscreen" "$LABWC_DIR/rc.xml"; then
    cat << 'EOF' > "$LABWC_DIR/rc.xml"
<?xml version="1.0"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
	<touch deviceName="ADS7846 Touchscreen" mapToOutput="SPI-1" mouseEmulation="yes"/>
</openbox_config>
EOF
    chown -R "$TARGET_USER:$TARGET_USER" "$LABWC_DIR"
    echo "[+] labwc touch mapping configured (mapToOutput SPI-1)."
  fi
fi

# Clean up any legacy/conflicting udev calibration rules
rm -f /etc/udev/rules.d/99-touchscreen.rules /etc/udev/rules.d/99-ads7846.rules 2>/dev/null || true
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger -s input 2>/dev/null || true

echo ""
echo "============================================================"
echo " Configuration complete!"
echo " The display is configured using the native Linux DRM driver."
echo " A reboot is required to activate the display."
echo "============================================================"
echo ""
read -p "Would you like to reboot now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "[+] Rebooting..."
  reboot
fi
