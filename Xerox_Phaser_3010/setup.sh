#!/bin/bash
set -e

# Configuration
PRINTER_NAME="Xerox_Phaser_3010"
# Try to detect printer URI automatically
PRINTER_URI=$(lpinfo -v | grep -i 'xerox.*3010' | head -n 1 | awk '{print $2}')
if [ -z "$PRINTER_URI" ]; then
    # Fallback to a generic USB URI if detection fails (user might need to adjust serial)
    PRINTER_URI="usb://Xerox/Phaser%203010?serial=3178009191"
fi

PPD_FILE="/usr/share/ppd/foo2zjs/Xerox-Phaser_3010.ppd"

echo "Starting Printer Setup..."

# 1. Install Dependencies
echo "Installing packages..."
sudo apt-get update
sudo apt-get install -y cups printer-driver-foo2zjs python3-pip git

# 2. Add User to lpadmin
sudo usermod -a -G lpadmin $USER

# 3. Configure Printer
echo "Configuring CUPS..."
# Find PPD if not hardcoded
if [ ! -f "$PPD_FILE" ]; then
    PPD_FILE=$(lpinfo -m | grep -i 'xerox.*3010' | head -n 1 | awk '{print $1}')
fi

if [ -z "$PPD_FILE" ]; then
    echo "Error: PPD file not found!"
    exit 1
fi

# Add Printer
# Note: PageSize=A4 is CRITICAL for this printer to avoid red light error
sudo lpadmin -p "$PRINTER_NAME" -v "$PRINTER_URI" -E -m "$PPD_FILE" -o PageSize=A4
sudo lpadmin -d "$PRINTER_NAME"
sudo cupsenable "$PRINTER_NAME"
sudo cupsaccept "$PRINTER_NAME"

echo "Printer $PRINTER_NAME configured with A4 size."
echo "Setup Complete!"
