#!/bin/bash
# ==============================================================================
# Touchscreen Calibration & Axis Alignment Utility for ADS7846 on Bookworm/Wayland
# Usage:
#   sudo ./calibrate_touch.sh 90         (Standard Landscape 90° - default)
#   sudo ./calibrate_touch.sh 270        (Landscape 270°)
#   sudo ./calibrate_touch.sh invert-x   (Landscape 90° with inverted X)
#   sudo ./calibrate_touch.sh invert-y   (Landscape 90° with inverted Y)
#   sudo ./calibrate_touch.sh portrait   (Portrait 0°)
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run with sudo: sudo bash $0 [option]"
  exit 1
fi

MODE="${1:-90}"

case "$MODE" in
  90|landscape)
    MATRIX="0 1 0 -1 0 1"
    DESC="Landscape 90° (Clockwise)"
    ;;
  270)
    MATRIX="0 -1 1 1 0 0"
    DESC="Landscape 270° (Counter-clockwise)"
    ;;
  invert-x)
    MATRIX="0 -1 1 -1 0 1"
    DESC="Landscape 90° with X-Axis Inverted"
    ;;
  invert-y)
    MATRIX="0 1 0 1 0 0"
    DESC="Landscape 90° with Y-Axis Inverted"
    ;;
  swap)
    MATRIX="1 0 0 0 1 0"
    DESC="Raw / Identity (Portrait 0°)"
    ;;
  180)
    MATRIX="-1 0 1 0 -1 1"
    DESC="Inverted Portrait 180°"
    ;;
  *)
    echo "Usage: sudo $0 [90 | 270 | invert-x | invert-y | swap | 180]"
    exit 1
    ;;
esac

echo "[+] Applying touch calibration matrix: $DESC"
echo "    Matrix: \"$MATRIX\""

# Write udev rule
cat << EOF > /etc/udev/rules.d/99-touchscreen.rules
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="ADS7846 Touchscreen", ENV{LIBINPUT_CALIBRATION_MATRIX}="$MATRIX"
EOF

# Trigger udev to update device properties
udevadm control --reload-rules
udevadm trigger -s input

# Restart lightdm to reload input device properties in Wayland
systemctl restart lightdm

echo "[+] Calibration applied successfully and Wayland session reloaded."
