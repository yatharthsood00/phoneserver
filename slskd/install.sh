#!/data/data/com.termux/files/usr/bin/bash
# install.sh — sets up slskd inside proot-distro Debian on Termux (ARM64, no root)
# Run from Termux (not inside proot).
set -e

SLSKD_VERSION="0.25.1"
SLSKD_ZIP="slskd-${SLSKD_VERSION}-linux-arm64.zip"
SLSKD_URL="https://github.com/slskd/slskd/releases/download/${SLSKD_VERSION}/${SLSKD_ZIP}"
SLSKD_INSTALL_DIR="/opt/slskd"
CONFIG_SRC="$(cd "$(dirname "$0")" && pwd)/slskd.yml"

echo "=== slskd install: version $SLSKD_VERSION ==="

# ---- 1. Ensure proot-distro + Debian are available -----------------------
if ! command -v proot-distro &>/dev/null; then
    echo "Installing proot-distro..."
    pkg install -y proot-distro
fi

if ! proot-distro list 2>/dev/null | grep -q "debian.*installed"; then
    echo "Installing Debian proot..."
    proot-distro install debian
fi

# ---- 2. Install dependencies inside Debian --------------------------------
echo "Installing .NET runtime deps inside Debian..."
proot-distro login debian -- bash -lc "
    apt-get update -qq &&
    apt-get install -y --no-install-recommends curl ca-certificates libicu-dev unzip python3 python3-pip 2>&1
"

# Check if bcrypt python module is available for hash generation
proot-distro login debian -- bash -lc "
    pip3 install bcrypt --quiet 2>&1 || true
"

# ---- 3. Download & install slskd binary -----------------------------------
echo "Downloading slskd $SLSKD_VERSION (linux-arm64)..."
proot-distro login debian -- bash -lc "
    mkdir -p $SLSKD_INSTALL_DIR &&
    cd $SLSKD_INSTALL_DIR &&
    if [ -f slskd ]; then
        echo 'slskd binary already present, skipping download'
    else
        curl -L -o slskd.zip '$SLSKD_URL' &&
        unzip -o slskd.zip &&
        rm -f slskd.zip &&
        chmod +x slskd &&
        echo 'slskd installed at $SLSKD_INSTALL_DIR/slskd'
    fi &&
    ./slskd --version
"

# ---- 4. Create download directories (in Termux-accessible storage) --------
echo "Creating download directories..."
mkdir -p /sdcard/Downloads/slsk/incomplete /sdcard/Downloads/slsk/complete
echo "Created /sdcard/Downloads/slsk/{incomplete,complete}"

# ---- 5. Copy config -------------------------------------------------------
echo "Copying slskd.yml into proot..."
# The Termux home is accessible from proot at the same path.
PROOT_CONFIG_DIR="/data/data/com.termux/files/home/storage/internal/server/configs/slskd"
mkdir -p "$PROOT_CONFIG_DIR"
cp "$CONFIG_SRC" "$PROOT_CONFIG_DIR/slskd.yml"
echo "Config copied to $PROOT_CONFIG_DIR/slskd.yml"

# Symlink inside proot so slskd finds it at /opt/slskd/slskd.yml
proot-distro login debian -- bash -lc "
    ln -sf '$PROOT_CONFIG_DIR/slskd.yml' $SLSKD_INSTALL_DIR/slskd.yml
"

# ---- 6. Generate bcrypt hash for web UI password -------------------------
echo ""
echo "--- Web UI password setup ---"
echo "You need to set a bcrypt hash in slskd.yml under web.authentication.password."
echo "Generate one now by running this inside the proot:"
echo ""
echo "  proot-distro login debian -- python3 -c \\"
echo "    \"import bcrypt; print(bcrypt.hashpw(b'YOUR_UI_PASSWORD', bcrypt.gensalt(10)).decode())\""
echo ""
echo "Then replace REPLACE_WITH_BCRYPT_HASH_OF_YOUR_UI_PASSWORD in:"
echo "  $PROOT_CONFIG_DIR/slskd.yml"
echo ""
echo "=== Install complete. ==="
echo "Start manually to test:"
echo "  proot-distro login debian \\"
echo "    --bind /sdcard:/sdcard \\"
echo "    --bind /data/data/com.termux/files/home/storage:/data/data/com.termux/files/home/storage \\"
echo "    -- bash -lc 'cd /opt/slskd && ./slskd --config /opt/slskd/slskd.yml'"
echo ""
echo "Web UI will be at http://<phone-lan-or-tailscale-ip>:5030"
