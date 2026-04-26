#!/data/data/com.termux/files/usr/bin/python3
"""
Battery‑aware controller for Tapo P110 smart plug using plugp100 library.
Turns the plug ON when battery <= 75%, OFF when battery >= 80%.
Polls battery every 2 minutes.
"""
import asyncio
import json
import subprocess
import time
import os
import sys
from dotenv import load_dotenv
from plugp100.common.credentials import AuthCredential
from plugp100.new.device_factory import connect, DeviceConnectConfiguration
from plugp100.new.components.on_off_component import OnOffComponent

# Load environment variables from .env file in the same directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(SCRIPT_DIR, '.env'))

TP_LINK_EMAIL = os.getenv('TP_LINK_EMAIL')
TP_LINK_PASS = os.getenv('TP_LINK_PASS')
IP_ADDRESS = os.getenv('IP_ADDRESS')

if not all([TP_LINK_EMAIL, TP_LINK_PASS, IP_ADDRESS]):
    print('Missing TP_LINK_EMAIL, TP_LINK_PASS, or IP_ADDRESS in .env')
    sys.exit(1)

# Battery thresholds
LOW_BATTERY = 75
HIGH_BATTERY = 80

# Polling interval in seconds (2 minutes)
POLL_INTERVAL = 120

def get_battery_percentage():
    """Return battery percentage using termux-battery-status."""
    try:
        result = subprocess.run(['termux-battery-status'], capture_output=True, text=True, check=True)
        data = json.loads(result.stdout)
        return data.get('percentage', -1)
    except Exception as e:
        print(f'Error getting battery status: {e}')
        return -1

async def get_plug_state(device):
    """Return True if plug is ON, False if OFF, None on error."""
    try:
        await device.update()
        on_off = device.get_component(OnOffComponent)
        if on_off:
            return on_off.device_on
        else:
            # fallback maybe device has device_on attribute
            return getattr(device, 'device_on', None)
    except Exception as e:
        print(f'Error getting plug state: {e}')
        return None

async def set_plug_state(device, state):
    """Turn plug ON (True) or OFF (False)."""
    try:
        on_off = device.get_component(OnOffComponent)
        if on_off:
            if state:
                await on_off.turn_on()
            else:
                await on_off.turn_off()
        else:
            if state:
                await device.turn_on()
            else:
                await device.turn_off()
        print(f'Plug turned {"ON" if state else "OFF"}')
        return True
    except Exception as e:
        print(f'Error setting plug state: {e}')
        if '403' in str(e) or 'FORBIDDEN' in str(e):
            print('Third‑Party Compatibility likely disabled.')
        return False

async def main():
    credentials = AuthCredential(TP_LINK_EMAIL, TP_LINK_PASS)
    config = DeviceConnectConfiguration(
        host=IP_ADDRESS,
        credentials=credentials,
    )
    print('Connecting to plug...')
    try:
        device = await connect(config)
        print('Connected to plug')
    except Exception as e:
        print(f'Failed to connect to plug: {e}')
        return
    
    last_state = None  # None = unknown, True = ON, False = OFF
    print('Starting battery‑plug controller (poll every {}s)'.format(POLL_INTERVAL))
    print('Thresholds: <= {}% → ON, >= {}% → OFF'.format(LOW_BATTERY, HIGH_BATTERY))
    
    while True:
        battery = get_battery_percentage()
        if battery == -1:
            print('Skipping cycle due to battery read error')
            await asyncio.sleep(POLL_INTERVAL)
            continue
        
        print('Battery: {}%'.format(battery))
        
        # Determine desired state
        if battery <= LOW_BATTERY:
            desired_state = True  # ON
        elif battery >= HIGH_BATTERY:
            desired_state = False  # OFF
        else:
            desired_state = None  # no change
        
        if desired_state is not None:
            current_state = await get_plug_state(device)
            if current_state is None:
                print('Could not get plug state, skipping')
            elif current_state != desired_state:
                print(f'Plug state mismatch (current {"ON" if current_state else "OFF"}, desired {"ON" if desired_state else "OFF"})')
                success = await set_plug_state(device, desired_state)
                if success:
                    last_state = desired_state
            else:
                print(f'Plug already {"ON" if current_state else "OFF"} (no change)')
        else:
            print('Battery between {}% and {}% → no change'.format(LOW_BATTERY, HIGH_BATTERY))
        
        await asyncio.sleep(POLL_INTERVAL)

if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print('\nExiting')
        sys.exit(0)