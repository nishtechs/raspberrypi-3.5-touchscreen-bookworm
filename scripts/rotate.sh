#!/bin/bash
# ==============================================================================
# Utility to rotate the 3.5" display in Wayland / Labwc
# Usage:
#   ./rotate.sh 90    (Landscape - default)
#   ./rotate.sh 270   (Inverted Landscape)
#   ./rotate.sh 0     (Portrait)
#   ./rotate.sh 180   (Inverted Portrait)
# ==============================================================================

ROTATION="${1:-90}"

case "$ROTATION" in
  0|normal)
    TRANSFORM="normal"
    ;;
  90)
    TRANSFORM="90"
    ;;
  180)
    TRANSFORM="180"
    ;;
  270)
    TRANSFORM="270"
    ;;
  *)
    echo "Usage: $0 [0|90|180|270|normal]"
    exit 1
    ;;
esac

echo "[+] Setting display transform to $TRANSFORM..."

# Apply live if Wayland session is active
if [ -n "$WAYLAND_DISPLAY" ] || [ -e "/run/user/$(id -u)/wayland-0" ]; then
  WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" wlr-randr --output SPI-1 --transform "$TRANSFORM" 2>/dev/null || true
fi

# Make persistent in Kanshi config
KANSHI_CONFIG="$HOME/.config/kanshi/config"
mkdir -p "$(dirname "$KANSHI_CONFIG")"
cat << EOF > "$KANSHI_CONFIG"
profile {
    output SPI-1 enable transform $TRANSFORM
}
EOF

# Reload kanshi
pkill -HUP kanshi 2>/dev/null || true

echo "[+] Done. Rotation set to $TRANSFORM."
