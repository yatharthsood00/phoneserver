#!/data/data/com.termux/files/usr/bin/bash
# Downloads Navidrome ARM64 binary and installs to ~/.local/bin
# Requires proot: pkg install proot
set -e

VERSION="0.61.2"
URL="https://github.com/navidrome/navidrome/releases/download/v${VERSION}/navidrome_${VERSION}_linux_arm64.tar.gz"
INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/storage/internal/server/configs/navidrome"

echo "Installing proot (needed to bypass Android seccomp)..."
pkg install -y proot

echo "Downloading Navidrome v${VERSION} ARM64..."
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR/data"
curl -L -o "$HOME/navidrome.tar.gz" "$URL"
tar -xzf "$HOME/navidrome.tar.gz" -C "$INSTALL_DIR" navidrome
chmod +x "$INSTALL_DIR/navidrome"
rm "$HOME/navidrome.tar.gz"

echo "Copying config..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/navidrome.toml" "$CONFIG_DIR/navidrome.toml"

echo "Done. Run with: proot navidrome --configfile $CONFIG_DIR/navidrome.toml"
echo "Web UI will be at http://<phone-ip>:4533"
echo "Create your admin account on first visit."
