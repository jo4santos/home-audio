# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an infrastructure/ops project — no application code to build or test. It consists of shell scripts and config files used to provision Raspberry Pi 4B nodes as Snapcast audio clients for a whole-home audio system.

**Stack:** Raspberry Pi OS Lite (64-bit), Snapcast, PulseAudio, BlueZ, Home Assistant + Music Assistant

## Key Scripts

All scripts run **from the `scripts/` directory**:

```bash
# Deploy config + install.sh to a specific RPi
cd scripts
./deploy.sh <divisao>              # e.g., ./deploy.sh escritorio
./deploy.sh <divisao> <MAC>        # override Bluetooth MAC

# Install on all RPis (requires SSH key auth, RPis online)
./install-all.sh

# Run install on the RPi itself (after deploy)
bash install.sh                    # must have config.env in same dir
```

## Architecture

### Provisioning Flow

1. `configs/<divisao>.env` — per-room config (IP, hostname, BT MAC, player name)
2. `scripts/deploy.sh` — copies `install.sh` + correct config as `config.env` to the RPi via `scp`
3. `scripts/install.sh` — runs **on the RPi**, installs packages and writes all systemd units/scripts

### What `install.sh` Installs on Each RPi

- **Snapclient** (`snapclient`) — connects to Snapcast server at `192.168.2.100`, uses PulseAudio sink, identifies itself by `PLAYER_NAME`; runs as the user (not root) to access PulseAudio; waits 10s before starting
- **`/usr/local/bin/bluetooth-reconnect.sh`** — checks if already connected (exits early), does initial pairing if unpaired, then tries to connect up to 40 times
- **`bluetooth-reconnect.timer`** — systemd timer: first run 15s after boot, then every 15s indefinitely
- **`/usr/local/bin/wifi-watchdog.sh`** — pings gateway `192.168.30.1`, restarts `wlan0` if unreachable, then triggers `bluetooth-reconnect.service`; runs via cron every 2 minutes

### Room-to-IP Mapping

| Room | IP | Hostname |
|---|---|---|
| Escritório | 192.168.30.7 | rpi-escritorio |
| Suite | 192.168.30.2 | rpi-suite |
| Cozinha | 192.168.30.3 | rpi-cozinha |
| Sala | 192.168.30.4 | rpi-sala |
| WC Suite | 192.168.30.5 | rpi-wcsuite |
| Quarto Crianças | 192.168.30.6 | rpi-quartocriancas |
| Quarto Desporto | 192.168.30.1 | rpi-quartodesporto |

Snapcast server (Home Assistant): `192.168.2.100`

## Config File Format

Each `configs/<divisao>.env` exports: `USER`, `PASSWORD`, `HOSTNAME`, `IP_ADDRESS`, `AMP_MAC`, `PLAYER_NAME`, `SNAPSERVER_IP`, `WIFI_SSID`, `WIFI_PASSWORD`. Use `configs/exemplo.env` as the template for new rooms.

## Debugging on RPi

```bash
# Service status
sudo systemctl status snapclient
sudo systemctl status bluetooth-reconnect.timer

# Live logs
sudo journalctl -u bluetooth-reconnect -f
sudo journalctl -u snapclient -f
sudo tail -f /var/log/bluetooth-reconnect.log
sudo tail -f /var/log/wifi-watchdog.log

# Check Bluetooth sink
pactl list short sinks | grep bluez

# Manual reconnect
sudo systemctl start bluetooth-reconnect.service
```

## Important Constraints

- **Bluetooth pairing must be done manually** on each RPi — it cannot be automated by `install.sh`
- `install.sh` uses `set -e` — any failed command aborts the install
- The `bluetooth-reconnect.sh` script is written to `/usr/local/bin/` with the `AMP_MAC` placeholder substituted by `sed` during install
- Snapclient runs as the regular user (not root) so it can access the PulseAudio session at `XDG_RUNTIME_DIR=/run/user/1000`
- `install-all.sh` must be run from `scripts/` (it calls `./deploy.sh` relatively)
