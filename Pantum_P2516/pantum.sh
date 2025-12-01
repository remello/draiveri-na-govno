#!/bin/bash
set -e

# ==========================================
# Pantum P2516 Setup Workflow (Box64)
# ==========================================
# This script automates the installation of Pantum P2516 drivers on Raspberry Pi (ARM64)
# using Box64 to emulate the x86_64 driver binaries.
#
# Prerequisites:
# - Raspberry Pi OS (64-bit) / Debian 12+
# - Internet connection
# - 'pantum_driver_v99.deb' in the same directory (or standard path)

# Configuration
DRIVER_DEB="./pantum_driver_v99.deb"
PRINTER_NAME="Pantum_P2516"
INSTALL_DIR="/opt/pantum-x86"
# Default URI (will be overwritten if auto-detected)
PRINTER_URI="usb://Pantum/P2500W%20Series?serial=0000000000"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check for root
if [ "$EUID" -ne 0 ]; then
  error "Please run as root (sudo ./pantum.sh)"
fi

# Check for Driver Package
if [ ! -f "$DRIVER_DEB" ]; then
    log "Driver package not found locally. Attempting download from GitHub..."
    # Download from the user's repo
    GITHUB_URL="https://github.com/remello/draiveri-na-govno/raw/main/pantum_driver_v99.deb"
    if wget -q --show-progress "$GITHUB_URL" -O "$DRIVER_DEB"; then
        log "Driver downloaded successfully."
    else
        error "Failed to download driver from $GITHUB_URL. Please check your internet connection or URL."
    fi
fi

log "Starting Pantum P2516 Setup..."

# 1. Install Dependencies & Box64
log "Checking dependencies..."
apt-get update -qq
apt-get install -y -qq cups usbutils wget curl binutils

if ! command -v box64 &> /dev/null; then
    log "Installing Box64..."
    if apt-cache search box64 | grep -q box64; then
        apt-get install -y -qq box64
    else
        warn "Box64 not in repo. Adding Ryan Fortner's repo..."
        wget -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor | tee /usr/share/keyrings/box64-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/box64-archive-keyring.gpg] https://ryanfortner.github.io/box64-debs/ ./" > /etc/apt/sources.list.d/box64.list
        apt-get update -qq
        apt-get install -y -qq box64
    fi
else
    log "Box64 is already installed."
fi

# 2. Prepare x86 Environment
log "Preparing x86 environment at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR/usr/lib"
mkdir -p "$INSTALL_DIR/lib64"
mkdir -p "$INSTALL_DIR/usr/share/cups/model/Pantum"
mkdir -p "$INSTALL_DIR/usr/lib/cups/filter"

# 3. Extract Driver
log "Extracting driver from $DRIVER_DEB..."
TEMP_DIR=$(mktemp -d)
dpkg-deb -x "$DRIVER_DEB" "$TEMP_DIR"

# Copy Resources
cp -r "$TEMP_DIR/usr/share/cups/model/Pantum/"*.ppd "$INSTALL_DIR/usr/share/cups/model/Pantum/"
cp "$TEMP_DIR/usr/lib/cups/filter/pt2500Filter" "$INSTALL_DIR/usr/lib/cups/filter/"

# Copy proprietary library
if [ -f "$TEMP_DIR/opt/pantum/lib/CMSlib/libGDIPrintCMSLib-amd64.so" ]; then
    cp "$TEMP_DIR/opt/pantum/lib/CMSlib/libGDIPrintCMSLib-amd64.so" "$INSTALL_DIR/usr/lib/"
elif [ -f "$TEMP_DIR/usr/lib/libGDIPrintCMSLib-amd64.so" ]; then
    cp "$TEMP_DIR/usr/lib/libGDIPrintCMSLib-amd64.so" "$INSTALL_DIR/usr/lib/"
else
    warn "libGDIPrintCMSLib-amd64.so not found. Printing might fail."
fi

rm -rf "$TEMP_DIR"

# 4. Download x86 Libraries (Idempotent)
log "Checking x86 libraries..."
# Only download if directory is empty or missing specific libs
if [ ! -f "$INSTALL_DIR/usr/lib/libc.so.6" ]; then
    log "Downloading x86 libraries (Debian Bookworm)..."
    mkdir -p x86_libs
    cd x86_libs

    download_latest() {
        PKG_NAME=$1
        BASE_URL=$2
        PATTERN=$3
        FILENAME=$(curl -s "$BASE_URL" | grep -o "$PATTERN" | sort -u | sort -V | tail -n 1)
        if [ -z "$FILENAME" ]; then error "Package $PKG_NAME not found!"; fi
        wget -q "${BASE_URL}${FILENAME}" -O pkg.deb
        dpkg-deb -x pkg.deb .
        rm pkg.deb
    }

    POOL_MAIN="http://ftp.debian.org/debian/pool/main"
    
    # List of packages
    download_latest "libc6" "$POOL_MAIN/g/glibc/" 'libc6_[^"<>]*_amd64.deb'
    download_latest "libcups2" "$POOL_MAIN/c/cups/" 'libcups2_[^"<>]*_amd64.deb'
    download_latest "libcupsimage2" "$POOL_MAIN/c/cups/" 'libcupsimage2_[^"<>]*_amd64.deb'
    download_latest "libstdc++6" "$POOL_MAIN/g/gcc-12/" 'libstdc++6_12[^"<>]*_amd64.deb'
    # ... (Add other dependencies if strictly needed, keeping it minimal for now based on success)
    # Adding the ones we confirmed were needed
    download_latest "libgnutls30" "$POOL_MAIN/g/gnutls28/" 'libgnutls30_3.7[^"<>]*_amd64.deb'
    download_latest "libgmp10" "$POOL_MAIN/g/gmp/" 'libgmp10_[^"<>]*_amd64.deb'
    download_latest "libhogweed6" "$POOL_MAIN/n/nettle/" 'libhogweed6_[^"<>]*_amd64.deb'
    download_latest "libnettle8" "$POOL_MAIN/n/nettle/" 'libnettle8_[^"<>]*_amd64.deb'
    download_latest "libidn2-0" "$POOL_MAIN/libi/libidn2/" 'libidn2-0_[^"<>]*_amd64.deb'
    download_latest "libunistring5" "$POOL_MAIN/libu/libunistring/" 'libunistring5_[^"<>]*_amd64.deb'
    download_latest "libtasn1-6" "$POOL_MAIN/libt/libtasn1-6/" 'libtasn1-6_[^"<>]*_amd64.deb'
    download_latest "libp11-kit0" "$POOL_MAIN/p/p11-kit/" 'libp11-kit0_[^"<>]*_amd64.deb'
    download_latest "libffi8" "$POOL_MAIN/libf/libffi/" 'libffi8_[^"<>]*_amd64.deb'
    
    # Install
    find . -name "*.so*" -exec cp -L -f {} "$INSTALL_DIR/usr/lib/" \;
    
    LOADER=$(find . -name "ld-linux-x86-64.so.2" -type f | head -n 1)
    if [ ! -z "$LOADER" ]; then cp -f "$LOADER" "$INSTALL_DIR/lib64/"; fi
    
    cd ..
    rm -rf x86_libs
else
    log "x86 libraries appear to be installed. Skipping download."
fi

# 5. Create Wrapper
log "Configuring CUPS filter wrapper..."
WRAPPER="/usr/lib/cups/filter/pt2500Filter"
BOX64_PATH=$(command -v box64)

cat <<EOF > "$WRAPPER"
#!/bin/bash
# Box64 Wrapper for Pantum x86 Driver
export LD_LIBRARY_PATH=$INSTALL_DIR/usr/lib:$INSTALL_DIR/usr/lib/x86_64-linux-gnu
export BOX64_LD_LIBRARY_PATH=$INSTALL_DIR/usr/lib:$INSTALL_DIR/usr/lib/x86_64-linux-gnu
export BOX64_LD_PRELOAD=$INSTALL_DIR/usr/lib/libcups.so.2
exec $BOX64_PATH $INSTALL_DIR/usr/lib/cups/filter/pt2500Filter "\$@"
EOF
chmod +x "$WRAPPER"

# 6. Install PPD & Fix Symlinks
log "Installing PPD and fixing symlinks..."
mkdir -p /usr/share/cups/model/Pantum
cp "$INSTALL_DIR/usr/share/cups/model/Pantum/Pantum P2510 Series.ppd" /usr/share/cups/model/Pantum/
# Fix for PPD expecting pt2510Filter
ln -sf "$INSTALL_DIR/usr/lib/cups/filter/pt2500Filter" "$INSTALL_DIR/usr/lib/cups/filter/pt2510Filter"

# 7. Configure CUPS
log "Configuring CUPS..."
# Auto-detect URI
DETECTED_URI=$(lpinfo -v 2>/dev/null | grep -i 'pantum' | head -n 1 | awk '{print $2}')
if [ ! -z "$DETECTED_URI" ]; then
    log "Detected Printer URI: $DETECTED_URI"
    PRINTER_URI="$DETECTED_URI"
else
    warn "Printer not detected via USB/Network! Using default URI: $PRINTER_URI"
fi

lpadmin -p "$PRINTER_NAME" -E -v "$PRINTER_URI" -P "/usr/share/cups/model/Pantum/Pantum P2510 Series.ppd" -o printer-is-shared=false
lpadmin -d "$PRINTER_NAME"
cupsenable "$PRINTER_NAME"
cupsaccept "$PRINTER_NAME"

log "Setup Complete! Printer '$PRINTER_NAME' is ready."
