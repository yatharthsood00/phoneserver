#!/data/data/com.termux/files/usr/bin/bash

LOG_FILE="/sdcard/start-services.log"
exec > "$LOG_FILE" 2>&1

echo "=== start-services.sh started at $(date) ==="

export PREFIX="/data/data/com.termux/files/usr"
export PATH="$HOME/.local/bin:$PREFIX/bin:$PREFIX/local/bin:$PATH"

sleep 5
termux-wake-lock 2>/dev/null && echo "Wakelock acquired" || echo "termux-wake-lock failed"

# Setup bind mounts for movie-linked directory
MOVIE_LINKED_BASE="$HOME/storage/internal/server/movie-linked"
mkdir -p "$MOVIE_LINKED_BASE/new_downloads" "$MOVIE_LINKED_BASE/sdcard_downloads"

# Source directories
SRC_NEW="$HOME/storage/internal/server/new_downloads"
SRC_SDCARD="$HOME/storage/sdcard/downloads"

# Function to bind mount if not already mounted
bind_mount() {
    local src="$1"
    local dst="$2"
    if su -c "mount | grep -q \"$dst\""; then
        echo "Already mounted: $dst"
    else
        su -c "mount --bind \"$src\" \"$dst\"" && echo "Mounted $src -> $dst"
    fi
}

bind_mount "$SRC_NEW" "$MOVIE_LINKED_BASE/new_downloads"
bind_mount "$SRC_SDCARD" "$MOVIE_LINKED_BASE/sdcard_downloads"

COPYPARTY=$(command -v copyparty)
ARIA2C=$(command -v aria2c)
MINIDLNAD=$(command -v minidlnad)
SSHD=$(command -v sshd)

echo "Found: copyparty=$COPYPARTY, aria2c=$ARIA2C, minidlnad=$MINIDLNAD, sshd=$SSHD"

if [ -z "$COPYPARTY" ] && [ -x "$HOME/.local/bin/copyparty" ]; then
    COPYPARTY="$HOME/.local/bin/copyparty"
fi

if [ -z "$COPYPARTY" ] || [ -z "$ARIA2C" ] || [ -z "$SSHD" ]; then
    echo "ERROR: Missing required commands"
    exit 1
fi

# Ensure aria2 session directory exists
ARIA2_SESSION_DIR="$HOME/storage/internal/server/configs/aria2/session"
mkdir -p "$ARIA2_SESSION_DIR"
touch "$ARIA2_SESSION_DIR/aria2.session"

tmux kill-session -t server 2>/dev/null
echo "Killed old tmux session"

tmux new-session -d -s server -n aria2 \
    "$ARIA2C --conf-path ~/storage/internal/server/configs/aria2/aria2.conf 2>&1 | tee ~/aria2c.log; echo 'aria2c exited. Press Enter...'; read"
echo "Started aria2c"

tmux new-window -t server -n copyparty \
    "$COPYPARTY -c ~/storage/internal/server/configs/copyparty/config-copyparty.conf 2>&1 | tee ~/copyparty.log; echo 'copyparty exited. Press Enter...'; read"
echo "Started copyparty"

if [ -n "$MINIDLNAD" ]; then
    tmux new-window -t server -n minidlna \
        "$MINIDLNAD -f ~/storage/internal/server/configs/minidlna/minidlna.conf 2>&1 | tee ~/minidlna.log; echo 'minidlna exited. Press Enter...'; read"
    echo "Started minidlna"
else
    echo "WARNING: minidlnad not found"
fi

# Generate host keys if missing
ssh-keygen -A 2>/dev/null
pkill -x sshd 2>/dev/null
sleep 1
$SSHD
sleep 2
if pgrep -x "sshd" >/dev/null; then
    echo "sshd started successfully (PID: $(pgrep -x sshd))"
else
    echo "WARNING: sshd may have failed"
fi


# slskd Soulseek daemon (headless, web UI on port 5030)
# slskd has no native UPnP, so map the listen port manually on each boot
upnpc -a 192.168.68.111 45551 45551 TCP 2>&1 | grep -E 'redirected|error|Error' || true
SLSKD_CONFIG="$HOME/storage/internal/server/configs/slskd/slskd.yml"
SDCARD_PATH=$(readlink -f "$HOME/storage/sdcard")
if proot-distro list 2>/dev/null | grep -q "debian.*installed"; then
    tmux new-window -t server -n slskd \
        "proot-distro login debian \
            --bind /storage/emulated/0:/mnt/internal \
            --bind $SDCARD_PATH:/mnt/sdcard \
            -- bash -lc 'mkdir -p /mnt/internal/Downloads/slsk/incomplete /mnt/internal/Downloads/slsk/complete && cd /opt/slskd && DOTNET_GCHeapHardLimit=134217728 ./slskd --config /data/data/com.termux/files/home/storage/internal/server/configs/slskd/slskd.yml 2>&1 | tee /mnt/internal/slskd.log'; echo 'slskd exited. Press Enter...'; read"
    echo "Started slskd (Soulseek) — web UI at http://<phone-ip>:5030"
else
    echo "WARNING: proot-distro Debian not installed, skipping slskd"
fi

# Battery plug controller
BATTERY_CONTROLLER="$HOME/storage/internal/server/scripts/battery_plug_controller.py"
if [ -f "$BATTERY_CONTROLLER" ]; then
    tmux new-window -t server -n battery-plug \
        "python3 -u $BATTERY_CONTROLLER 2>&1 | tee ~/battery_plug.log; echo 'battery_plug exited. Press Enter...'; read"
    echo "Started battery_plug controller"
else
    echo "WARNING: battery_plug controller not found"
fi

# Llama.cpp local AI server
LLAMA_MODEL="$HOME/ollama-models/LFM2-350M-Q4_K_M.gguf"
LLAMA_SERVER=$(command -v llama-server)
if [ -n "$LLAMA_SERVER" ] && [ -f "$LLAMA_MODEL" ]; then
    tmux new-window -t server -n llama \
        "$LLAMA_SERVER -m $LLAMA_MODEL -c 4096 -t 4 --host 0.0.0.0 --port 8081 --temp 0.3 --min-p 0.15 --repeat-penalty 1.05 2>&1 | tee ~/llama.log; echo 'llama_server exited. Press Enter...'; read"
    echo "Started llama-server on port 8081"
else
    echo "WARNING: llama-server or model not found"
fi
# Navidrome music server (requires proot to bypass Android seccomp)
NAVIDROME=$(command -v navidrome)
NAVIDROME_CONFIG="$HOME/storage/internal/server/configs/navidrome/navidrome.toml"
if [ -n "$NAVIDROME" ] && [ -f "$NAVIDROME_CONFIG" ]; then
    tmux new-window -t server -n navidrome \
        "proot navidrome --configfile $NAVIDROME_CONFIG 2>&1 | tee ~/navidrome.log; echo 'navidrome exited. Press Enter...'; read"
    echo "Started navidrome on port 4533"
else
    echo "WARNING: navidrome or config not found, skipping"
fi

echo "=== start-services.sh finished at $(date) ==="
