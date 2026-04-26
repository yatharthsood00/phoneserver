#!/data/data/com.termux/files/usr/bin/bash
# Sets up nicotine+ (Soulseek headless) from nico.env credentials
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../ nico.env"
CONFIG_DIR="$HOME/storage/internal/server/configs/nicotine"
CONFIG_FILE="$CONFIG_DIR/config"

echo "Installing dependencies..."
pkg install -y pygobject
pip3 install --upgrade nicotine-plus

echo "Creating config..."
mkdir -p "$CONFIG_DIR"
mkdir -p /sdcard/Downloads/nicotine /sdcard/Downloads/nicotine-incomplete

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: $ENV_FILE not found. Create it with SOULSEEK_USER and SOULSEEK_PASSWORD."
    exit 1
fi

source "$ENV_FILE"

cat > "$CONFIG_FILE" <<EOF
[server]
login = $SOULSEEK_USER
passw = $SOULSEEK_PASSWORD
server = ('server.slsknet.org', 2242)
portrange = (2234, 2239)
upnp = False

[transfers]
shared = [('Music', '/data/data/com.termux/files/home/storage/sdcard/Music')]
downloaddir = /sdcard/Downloads/nicotine
incompletedir = /sdcard/Downloads/nicotine-incomplete
uploadslots = 5
friendsonly = False
buddysharestrustedonly = False

[logging]
debug = False
EOF

echo "Config written to $CONFIG_FILE"
echo "Run: nicotine --headless --config $CONFIG_FILE"
