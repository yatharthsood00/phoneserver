# Battery‑Aware Smart Plug Controller

## Goal
Integrate a Tapo P110 smart plug controller into the Termux‑based server (`pms`) that turns the plug **ON** when the phone’s battery ≤ 75 % and **OFF** when the battery ≥ 80 %, polling every 2 minutes.

## Approach
1. **Library selection** – Used the `plugp100` library (a fork of PyP100) that works with newer Tapo firmware and is pure Python (though it depends on `cryptography`).
2. **Installation** – Installed `python-cryptography` via Termux’s package manager (`pkg install python-cryptography`), which provides a pre‑compiled binary and avoids the need for Rust toolchain. Then installed `plugp100` and `python‑dotenv` via pip (no extra environment variables needed).
3. **Script** – Wrote `battery_plug_controller.py` that:
   - Loads credentials from a local `.env` file.
   - Polls `termux‑battery‑status` every 120 seconds.
   - Compares battery percentage against thresholds (LOW=75 %, HIGH=80 %).
   - Retrieves the current plug state via `plugp100` and only issues a command when the state needs to change.
   - Logs all actions to `~/battery_plug.log`.
4. **Integration** – Added a new tmux window `battery‑plug` to `start‑services.sh` that runs the controller with unbuffered output (`python3 -u`). The script is placed in `~/storage/internal/server/scripts/` and is executable.

## Key Findings
- The original PyP100 library failed with error `1003` (incorrect request) because the plug’s handshake expects a PEM‑wrapped public key. The `plugp100` library handles this correctly.
- Installing `plugp100` on Termux requires the `ANDROID_API_LEVEL` environment variable to be set (e.g., `36`) so that `maturin` can build the `cryptography` wheel.
- The `plugp100` library uses an async API; the controller uses `asyncio.run()` to run the async functions.
- The controller is state‑aware: it checks the plug’s current state before sending a command, preventing unnecessary writes and allowing the script to be restarted at any time.

## Current Status
- The battery‑plug controller is running in a dedicated tmux window (`battery‑plug`) within the `server` session.
- The plug is currently **OFF** because the battery is at 100 % (≥ 80 %).
- The controller logs to `~/battery_plug.log` and will automatically adjust the plug state when the battery crosses the thresholds.
- The `start‑services.sh` script now includes the battery‑plug window and will start the controller on every boot.

## Files
- `battery_plug_controller.py` – The main controller script (placed on the phone).
- `.env` – Credentials and plug IP (already on the phone).
- `start-services.sh` – Updated with the battery‑plug window (both local and remote copies).
