#!/bin/bash
set -e

# Configuration
# Path to the Driver package (uploaded separately)
DRIVER_DEB="./pantum_driver_v99.deb"
PRINTER_NAME="Pantum_P2516"
INSTALL_DIR="/opt/pantum-x86"

echo "Starting Pantum P2516 Setup (Box64 Emulation)..."

# 1. Install Box64
echo "Installing Box64..."
if ! command -v box64 &> /dev/null; then
    echo "Box64 not found. Installing..."
    if apt-cache search box64 | grep -q box64; then
        sudo apt-get install -y box64
    else
        echo "Adding Box64 repository..."
        wget https://ryanfortner.github.io/box64-debs/box64.list -O /etc/apt/sources.list.d/box64.list
        wget -O- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/box64-archive-keyring.gpg
        sudo apt-get update
        sudo apt-get install -y box64
    fi
else
    echo "Box64 is already installed."
fi

# 2. Prepare Installation Directory
echo "Preparing x86 environment at $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR/usr/lib"
sudo mkdir -p "$INSTALL_DIR/lib64"
sudo mkdir -p "$INSTALL_DIR/usr/share/cups/model/Pantum"
sudo mkdir -p "$INSTALL_DIR/usr/lib/cups/filter"

# 3. Extract Driver
if [ -f "$DRIVER_DEB" ]; then
    echo "Extracting driver from $DRIVER_DEB..."
    mkdir -p temp_extract
    dpkg-deb -x "$DRIVER_DEB" temp_extract
    
    # Copy Resources
    echo "Copying PPDs and Filter..."
    sudo cp -r temp_extract/usr/share/cups/model/Pantum/*.ppd "$INSTALL_DIR/usr/share/cups/model/Pantum/"
    sudo cp temp_extract/usr/lib/cups/filter/pt2500Filter "$INSTALL_DIR/usr/lib/cups/filter/"
    
    # Copy proprietary library
    LIB_CMS=""
    if [ -f "temp_extract/opt/pantum/lib/CMSlib/libGDIPrintCMSLib-amd64.so" ]; then
        LIB_CMS="temp_extract/opt/pantum/lib/CMSlib/libGDIPrintCMSLib-amd64.so"
    elif [ -f "temp_extract/usr/lib/libGDIPrintCMSLib-amd64.so" ]; then
        LIB_CMS="temp_extract/usr/lib/libGDIPrintCMSLib-amd64.so"
    fi
    
    if [ ! -z "$LIB_CMS" ]; then
        sudo cp "$LIB_CMS" "$INSTALL_DIR/usr/lib/"
        # FIX: Create hardcoded path expected by the binary
        echo "Fixing hardcoded CMS library path..."
        sudo mkdir -p /opt/pantum/lib/CMSlib/
        sudo cp "$LIB_CMS" /opt/pantum/lib/CMSlib/
    else
        echo "Warning: libGDIPrintCMSLib-amd64.so not found. Printing might fail."
    fi
    
    # Cleanup
    rm -rf temp_extract
else
    echo "Error: Driver file $DRIVER_DEB not found!"
    exit 1
fi

# 4. Download x86 Libraries (Debian Bookworm amd64)
# Only download if not already present to save time on re-runs
if [ ! -f "$INSTALL_DIR/usr/lib/libc.so.6" ]; then
    echo "Downloading minimal x86 libraries..."
    mkdir -p x86_libs
    cd x86_libs

    download_latest() {
        PKG_NAME=$1
        BASE_URL=$2
        PATTERN=$3
        
        echo "Finding latest $PKG_NAME..."
        FILENAME=$(curl -s "$BASE_URL" | grep -o "$PATTERN" | sort -u | sort -V | tail -n 1)
        
        if [ -z "$FILENAME" ]; then
            echo "Error: Could not find package for $PKG_NAME pattern $PATTERN"
            exit 1
        fi
        
        FULL_URL="${BASE_URL}${FILENAME}"
        echo "Downloading $FILENAME..."
        wget -q "$FULL_URL" -O pkg.deb
        dpkg-deb -x pkg.deb .
        rm pkg.deb
    }

    POOL_MAIN="http://ftp.debian.org/debian/pool/main"

    # Core libs
    download_latest "libc6" "$POOL_MAIN/g/glibc/" 'libc6_[^"<>]*_amd64.deb'
    download_latest "libcups2" "$POOL_MAIN/c/cups/" 'libcups2_[^"<>]*_amd64.deb'
    download_latest "libcupsimage2" "$POOL_MAIN/c/cups/" 'libcupsimage2_[^"<>]*_amd64.deb'

    # Dependencies
    download_latest "libgssapi-krb5-2" "$POOL_MAIN/k/krb5/" 'libgssapi-krb5-2_1.20[^"<>]*_amd64.deb'
    download_latest "libkrb5-3" "$POOL_MAIN/k/krb5/" 'libkrb5-3_1.20[^"<>]*_amd64.deb'
    download_latest "libk5crypto3" "$POOL_MAIN/k/krb5/" 'libk5crypto3_1.20[^"<>]*_amd64.deb'
    download_latest "libcom-err2" "$POOL_MAIN/e/e2fsprogs/" 'libcom-err2_1.47[^"<>]*_amd64.deb'
    download_latest "libgnutls30" "$POOL_MAIN/g/gnutls28/" 'libgnutls30_3.7[^"<>]*_amd64.deb'
    download_latest "libavahi-client3" "$POOL_MAIN/a/avahi/" 'libavahi-client3_0.8[^"<>]*_amd64.deb'
    download_latest "libavahi-common3" "$POOL_MAIN/a/avahi/" 'libavahi-common3_0.8[^"<>]*_amd64.deb'
    download_latest "libkrb5support0" "$POOL_MAIN/k/krb5/" 'libkrb5support0_1.20[^"<>]*_amd64.deb'
    download_latest "libkeyutils1" "$POOL_MAIN/k/keyutils/" 'libkeyutils1_1.6[^"<>]*_amd64.deb'
    download_latest "libdbus-1-3" "$POOL_MAIN/d/dbus/" 'libdbus-1-3_1.14[^"<>]*_amd64.deb'
    download_latest "libp11-kit0" "$POOL_MAIN/p/p11-kit/" 'libp11-kit0_[^"<>]*_amd64.deb'
    download_latest "libtasn1-6" "$POOL_MAIN/libt/libtasn1-6/" 'libtasn1-6_[^"<>]*_amd64.deb'
    download_latest "libnettle8" "$POOL_MAIN/n/nettle/" 'libnettle8_[^"<>]*_amd64.deb'
    download_latest "libhogweed6" "$POOL_MAIN/n/nettle/" 'libhogweed6_[^"<>]*_amd64.deb'
    download_latest "libidn2-0" "$POOL_MAIN/libi/libidn2/" 'libidn2-0_[^"<>]*_amd64.deb'
    download_latest "libunistring5" "$POOL_MAIN/libu/libunistring/" 'libunistring5_[^"<>]*_amd64.deb'
    download_latest "libgmp10" "$POOL_MAIN/g/gmp/" 'libgmp10_[^"<>]*_amd64.deb'
    download_latest "libsystemd0" "$POOL_MAIN/s/systemd/" 'libsystemd0_[^"<>]*_amd64.deb'
    download_latest "liblzma5" "$POOL_MAIN/x/xz-utils/" 'liblzma5_[^"<>]*_amd64.deb'
    download_latest "libzstd1" "$POOL_MAIN/libz/libzstd/" 'libzstd1_[^"<>]*_amd64.deb'
    download_latest "libcap2" "$POOL_MAIN/libc/libcap2/" 'libcap2_[^"<>]*_amd64.deb'
    download_latest "libgcrypt20" "$POOL_MAIN/libg/libgcrypt20/" 'libgcrypt20_[^"<>]*_amd64.deb'
    download_latest "libgpg-error0" "$POOL_MAIN/libg/libgpg-error/" 'libgpg-error0_[^"<>]*_amd64.deb'
    download_latest "libffi8" "$POOL_MAIN/libf/libffi/" 'libffi8_[^"<>]*_amd64.deb'
    download_latest "libmount1" "$POOL_MAIN/u/util-linux/" 'libmount1_[^"<>]*_amd64.deb'
    download_latest "libblkid1" "$POOL_MAIN/u/util-linux/" 'libblkid1_[^"<>]*_amd64.deb'
    download_latest "libselinux1" "$POOL_MAIN/libs/libselinux/" 'libselinux1_[^"<>]*_amd64.deb'
    download_latest "libpcre2-8-0" "$POOL_MAIN/p/pcre2/" 'libpcre2-8-0_[^"<>]*_amd64.deb'
    download_latest "libstdc++6" "$POOL_MAIN/g/gcc-12/" 'libstdc++6_12[^"<>]*_amd64.deb'

    # Copy libs to install dir
    echo "Installing x86 libraries..."
    find . -name "*.so*" -exec sudo cp -L -f {} "$INSTALL_DIR/usr/lib/" \;

    # Ensure loader is in the right place
    LOADER=$(find . -name "ld-linux-x86-64.so.2" -type f | head -n 1)
    if [ ! -z "$LOADER" ]; then
        sudo cp -f "$LOADER" "$INSTALL_DIR/lib64/"
    else
        echo "Error: Loader ld-linux-x86-64.so.2 not found!"
        exit 1
    fi

    cd ..
    rm -rf x86_libs
else
    echo "x86 libraries already installed. Skipping download."
fi

# 5. Create Wrapper Script
echo "Creating CUPS Filter Wrapper..."
# Note: PPD expects pt2510Filter, but driver provides pt2500Filter.
# We use pt2510Filter as the wrapper name to match PPD.
WRAPPER="/usr/lib/cups/filter/pt2510Filter"

BOX64_PATH=$(command -v box64)
cat <<EOF | sudo tee "$WRAPPER"
#!/bin/bash
# Box64 Wrapper for Pantum x86 Driver
export LD_LIBRARY_PATH=$INSTALL_DIR/usr/lib:$INSTALL_DIR/usr/lib/x86_64-linux-gnu
export BOX64_LD_LIBRARY_PATH=$INSTALL_DIR/usr/lib:$INSTALL_DIR/usr/lib/x86_64-linux-gnu
# FIX: Preload libcups.so.2 to fix missing symbols in libcupsimage
export BOX64_LD_PRELOAD=$INSTALL_DIR/usr/lib/libcups.so.2
# Execs the binary using box64
exec $BOX64_PATH $INSTALL_DIR/usr/lib/cups/filter/pt2500Filter "\$@"
EOF

sudo chmod +x "$WRAPPER"

# 6. Install PPD
echo "Installing PPD..."
sudo mkdir -p /usr/share/cups/model/Pantum
sudo cp "$INSTALL_DIR/usr/share/cups/model/Pantum/Pantum P2510 Series.ppd" /usr/share/cups/model/Pantum/

# 7. Fix USB Flapping (Udev Rule)
echo "Applying USB Flapping Fix (Udev)..."
# Unbind usblp from Pantum printer to prevent conflict
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="232b", ATTR{idProduct}=="1724", DRIVER=="usblp", RUN+="/bin/sh -c '\''echo -n $kernel > /sys/bus/usb/drivers/usblp/unbind'\''"' | sudo tee /etc/udev/rules.d/99-pantum-no-usblp.rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# 8. Configure Printer
echo "Configuring CUPS..."
# Use generic URI to allow printer swapping without reconfiguration
DETECTED_URI="usb://Pantum/P2510%20series"

echo "Using Generic URI: $DETECTED_URI"

sudo /usr/sbin/lpadmin -p "$PRINTER_NAME" -E -v "$DETECTED_URI" -P "/usr/share/cups/model/Pantum/Pantum P2510 Series.ppd" -o printer-is-shared=false
sudo lpadmin -d "$PRINTER_NAME"
sudo cupsenable "$PRINTER_NAME"
sudo cupsaccept "$PRINTER_NAME"

echo "Setup Complete!"
echo "Printer: $PRINTER_NAME"
echo "URI: $DETECTED_URI"
echo "Test with: lp -d $PRINTER_NAME /usr/share/cups/data/testprint"
