# Raspberry Pi Print Server

Automated printer setup and management tools for Raspberry Pi.

## Features

- **Pantum P2516 Driver**: Automated installation using Box64 emulation for x86 drivers on ARM64
- **Wi-Fi Hotspot Manager**: Configure Wi-Fi via web interface when no internet connection is available
- **Print Bot**: Telegram bot for remote printer management

---

## Pantum P2516 Driver Installation

### Quick Install

The easiest way to install the Pantum P2516 driver on your Raspberry Pi:

**Option 1: Download the script**
```bash
# Download and run directly from GitHub
curl -sSL https://raw.githubusercontent.com/remello/draiveri-na-govno/main/Pantum_P2516/pantum.sh | sudo bash
```

**Option 2: Copy from your computer**
```bash
# 1. Copy the installer to your Raspberry Pi
scp Pantum_P2516/pantum.sh relo@rpi1.local:~/

# 2. SSH into your Raspberry Pi and run the installer
ssh relo@rpi1.local "sudo bash pantum.sh"
```

Replace `relo@rpi1.local` with your Raspberry Pi's username and hostname/IP address.

### What It Does

The bundled installer (`Pantum_P2516/pantum.sh`):
- Installs Box64 for x86 emulation
- Extracts and configures the Pantum P2516 driver
- Downloads required x86 libraries (libcups, glibc, etc.)
- Applies USB fix to prevent connection flapping (`usblp` module unbinding)
- Configures CUPS with the printer

### Hardware Requirements

- Raspberry Pi 3/4/5 with 64-bit OS (ARM64)
- Raspberry Pi OS Bookworm (Debian 12) or newer
- USB connection to Pantum P2516 printer

### Troubleshooting

**USB Connection Issues**: If the printer repeatedly connects/disconnects, ensure the `usblp` kernel module is not interfering:

```bash
# Unload usblp module
sudo modprobe -r usblp

# Verify printer is detected
lsusb | grep Pantum
```

The installer includes a udev rule to automatically prevent this issue.

**Test Printing**:

```bash
# Print a test page
lp -d Pantum_P2516 /usr/share/cups/data/testprint

# Check printer status
lpstat -p Pantum_P2516
```

---

## Wi-Fi Hotspot Manager

Automatically creates a Wi-Fi hotspot when no internet connection is detected, allowing configuration via web interface.

See `install_wifi_system.sh` for setup instructions.

---

## Print Bot

Telegram bot for remote printer management and monitoring.

See `print_bot.py` for configuration.

---

## Development

Repository: [github.com/remello/draiveri-na-govno](https://github.com/remello/draiveri-na-govno)

### Project Structure

```
.
├── Pantum_P2516/
│   └── pantum.sh                # Self-contained bundled installer (recommended)
├── setup_pantum.sh              # Alternative installer (requires external .deb)
├── Xerox_Phaser_3010/           # Xerox printer drivers
└── README.md                    # Installation guide
```

---

## License

MIT License - feel free to use and modify for your own projects.
