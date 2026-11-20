# Raspberry Pi 3.5" Touchscreen Setup for Bookworm

> Native DRM & Wayland driver setup for 3.5" SPI LCD Touchscreens (RS1535 / Waveshare Type A / ILI9486 / ADS7846) on Raspberry Pi OS 12 (Bookworm). Includes touch calibration & Pi Zero debloat optimizations.

---

## Hardware Specifications

* **Screen Model:** RS1535 (REES52 / Waveshare 3.5" RPi LCD Type A compatible)
* **Resolution:** 480 × 320 pixels
* **Display Interface:** SPI (ILI9486 display controller with 16-bit shift register)
* **Touch Controller:** XPT2046 / ADS7846 (resistive touch over SPI CS1, IRQ on GPIO 17)
* **Compatibility:** Raspberry Pi Zero W, Zero 2 W, 3B, 3B+, 4B, 5
* **Tested OS:** Raspberry Pi OS 12 (Bookworm) 32-bit & 64-bit with Desktop (`labwc` Wayland compositor) and Lite

---

## Pinout & Connection Guide

The display module features a **26-pin female header** that mounts directly onto **Pins 1 to 26** of the Raspberry Pi's 40-pin GPIO header:

| Pin No. | Raspberry Pi Pin | Function | Description |
| :--- | :--- | :--- | :--- |
| **1, 17** | 3.3V | 3.3V Power | Positive power supply |
| **2, 4** | 5V | 5V Power | Backlight power supply |
| **6, 9, 14, 20, 25** | GND | Ground | Power ground |
| **11** | GPIO 17 | TP_IRQ | Touch panel interrupt |
| **18** | GPIO 24 | LCD_RS / DC | Display register select (Data/Command) |
| **19** | GPIO 10 | SPI_MOSI | SPI data input (Display & Touch) |
| **21** | GPIO 9 | SPI_MISO | SPI data output (Touch controller) |
| **22** | GPIO 25 | LCD_RST | Display hardware reset |
| **23** | GPIO 11 | SPI_SCLK | SPI clock signal |
| **24** | GPIO 8 | LCD_CS (CE0) | Display chip select |
| **26** | GPIO 7 | TP_CS (CE1) | Touch controller chip select |

> **Alignment note:** Align Pin 1 of the screen with Pin 1 (3.3V) on the Pi (the corner next to the microSD card slot). Pins 27–40 remain unpopulated.

---

## Why Legacy `LCD-show` Scripts Break Bookworm

Older installation scripts (such as `LCD35-show` from GoodTFT or older Waveshare repositories):
1. **Target deprecated paths:** Overwrite `/boot/config.txt` instead of Bookworm's `/boot/firmware/config.txt`.
2. **Break package dependencies:** Force-install old packages that remove `raspberrypi-ui-mods`, `lightdm`, and `raspi-config`.
3. **Assume X11/Openbox:** Modern Raspberry Pi OS Bookworm uses **Wayland (`labwc`)** and the **Linux DRM/KMS subsystem** (`/dev/dri/card*`). Legacy scripts install outdated X11 evdev drivers that leave the screen on a blinking cursor.

### The Modern Bookworm Solution: Native Kernel DRM
Linux 6.x includes the native in-tree DRM driver `drivers/gpu/drm/tiny/ili9486.ko.xz`. When loaded via `dtoverlay=piscreen,drm`:
* It automatically activates 16-bit register transfers for the Waveshare/RS1535 shift register.
* Exposes a native DRM connector (`SPI-1`) that Wayland (`labwc`) recognizes out of the box.
* Automatically configures `ADS7846 Touchscreen` with `libinput`.

---

## Quick Installation

### Option 1: Run setup on the Raspberry Pi directly

Connect to your Pi over SSH and run:

```bash
git clone https://github.com/<your-username>/raspberrypi-3.5-touchscreen-bookworm.git
cd raspberrypi-3.5-touchscreen-bookworm
sudo chmod +x setup.sh scripts/*.sh
sudo ./setup.sh
```

The script will:
1. Backup `/boot/firmware/config.txt`.
2. Enable SPI (`dtparam=spi=on`).
3. Add the native DRM overlay (`dtoverlay=piscreen,drm,speed=18000000,rotate=90`).
4. Configure the Wayland display manager (`kanshi`) to output to `SPI-1` in landscape orientation.
5. Create standard udev rules for the touch controller.
6. Prompt you to reboot.

---

### Option 2: Deploy remotely over SSH from your PC / Mac

Run `deploy_ssh.py` from your workstation:

```bash
python deploy_ssh.py --host 10.138.170.99 --user pi --password pi
```

---

### Option 3: Manual Step-by-Step Configuration

If you prefer to configure manually:

1. **Edit boot configuration:**
   ```bash
   sudo nano /boot/firmware/config.txt
   ```

2. **Ensure these lines are present at the bottom (under `[all]`):**
   ```ini
   dtparam=spi=on
   dtoverlay=piscreen,drm,speed=18000000,rotate=90
   ```

3. **Configure Wayland display profile:**
   ```bash
   mkdir -p ~/.config/kanshi
   cat << 'EOF' > ~/.config/kanshi/config
   profile {
       output SPI-1 enable transform 90
   }
   EOF
   ```

4. **Ensure `labwc` maps touch to `SPI-1`:**
   In `~/.config/labwc/rc.xml`:
   ```xml
   <?xml version="1.0"?>
   <openbox_config xmlns="http://openbox.org/3.4/rc">
       <touch deviceName="ADS7846 Touchscreen" mapToOutput="SPI-1" mouseEmulation="yes"/>
   </openbox_config>
   ```
   *(With `mapToOutput="SPI-1"`, labwc automatically syncs the touch orientation with the screen transform).*

5. **Reboot:**
   ```bash
   sudo reboot
   ```

---

## Display Rotation & Orientation

Use the provided `rotate.sh` script to change orientation on the fly:

```bash
# Landscape (default, pins at bottom)
./scripts/rotate.sh 90

# Inverted Landscape (pins at top)
./scripts/rotate.sh 270

# Portrait
./scripts/rotate.sh 0

# Inverted Portrait
./scripts/rotate.sh 180
```

The change takes effect immediately in your Wayland desktop session and is saved persistently in `~/.config/kanshi/config`.

---

## Touchscreen Calibration & Axis Alignment

Resistive touch screens (ADS7846 / XPT2046) output raw ADC coordinates oriented in portrait mode. When the display is rotated to 90° landscape, the touch axes must be transformed using `libinput`'s calibration matrix.

Use `scripts/calibrate_touch.sh` to align the touch axes:

```bash
# Standard 90° Landscape (default):
sudo ./scripts/calibrate_touch.sh 90

# If horizontal movement is inverted:
sudo ./scripts/calibrate_touch.sh invert-x

# If vertical movement is inverted:
sudo ./scripts/calibrate_touch.sh invert-y

# For 270° Landscape:
sudo ./scripts/calibrate_touch.sh 270
```

This applies the affine matrix directly via `/etc/udev/rules.d/99-touchscreen.rules` and reloads the Wayland session.

---

## Performance & Memory Optimization for Pi Zero W

Raspberry Pi OS is designed for all models (including quad-core Pi 4 and Pi 5 with 4–8 GB RAM). On a **Pi Zero W** (single-core ARMv6, 512 MB RAM), many default background services consume critical CPU cycles and RAM.

Run the optimization script to debloat the system:

```bash
sudo ./scripts/optimize_pi_zero.sh
```

### What this optimizes:
1. **Disables Raspberry Pi Connect & WayVNC:** Frees **~40 MB RAM** and eliminates constant background video encoding.
2. **Removes CUPS Printing Services:** A portable mini display has no need for network printer discovery. Saves **~20 MB RAM**.
3. **Removes ModemManager:** Stops background serial polling for USB cellular dongles.
4. **Disables `apt-daily` background timers:** Prevents background apt checks from spiking the single CPU core to 100%.
5. **Tunes Kernel Swappiness (`vm.swappiness=10`):** Reduces aggressive swapping to the slow MicroSD card, extending SD card lifespan and improving desktop smoothness.
6. **Limits Systemd Journal Size:** Restricts RAM log buffers to 16 MB.

*Result:* Reclaims **~60–80 MB of usable RAM** and significantly reduces background CPU load.

---

## Included Examples

### 480×320 System Monitor (`examples/system_monitor.py`)

A lightweight, dark-mode dashboard tailored specifically for the 3.5" screen:

```bash
python3 examples/system_monitor.py
```

Features:
* Real-time CPU Usage & CPU Temperature
* RAM & Disk storage utilization
* Wi-Fi / IP Address
* System Uptime
* Uses pure Tkinter (no external pip dependencies needed)

---

## Troubleshooting

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| **Solid white screen** | SPI data signal not reaching the panel | 1. Verify screen is seated on Pins 1–26.<br>2. Ensure `dtparam=spi=on` is in `/boot/firmware/config.txt`. |
| **Blinking cursor only** | LightDM desktop session missing | Reinstall UI components: `sudo apt update && sudo apt install -y raspberrypi-ui-mods` then `sudo systemctl restart lightdm`. |
| **Touch inverted / swapped** | Touch axis mismatch with rotation | Edit `~/.config/kanshi/config` or set calibration in `/etc/udev/rules.d/99-ads7846.rules`. |
| **Desktop rendered on HDMI instead of LCD** | Wayland defaulting to external monitor | Ensure `output HDMI-A-1 disable` is set in `~/.config/kanshi/config`. |
