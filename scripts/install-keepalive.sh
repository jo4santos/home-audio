#!/bin/bash
set -e

# Instala o bluetooth-keepalive no RPi actual
# Seguro para RPis já configurados — não reinstala tudo
# Não requer config.env — detecta o sink BT dinamicamente
#
# Uso: bash install-keepalive.sh
# (ou executado automaticamente pelo deploy.sh)

echo "=== A instalar bluetooth-keepalive ==="

sudo tee /usr/local/bin/bluetooth-keepalive.sh > /dev/null << 'SCRIPT'
#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/1000
export PULSE_RUNTIME_PATH=/run/user/1000/pulse/

# Sair se modo manual activo (utilizador desemparelhou intencionalmente via HA)
[ -f "/var/lib/bluetooth-reconnect/manual-mode" ] && exit 0

SINK=$(pactl list short sinks 2>/dev/null | grep bluez | awk '{print $2}' | head -n1)
[ -z "$SINK" ] && exit 0

# Stream contínua de silêncio: mantém A2DP STARTED, sem AVDTP SUSPEND/START
dd if=/dev/zero bs=4096 2>/dev/null | \
    paplay --raw --format=s16le --rate=44100 --channels=2 \
           --device="$SINK" --stream-name="bt-keepalive" 2>/dev/null
SCRIPT

sudo chmod +x /usr/local/bin/bluetooth-keepalive.sh

sudo tee /etc/systemd/system/bluetooth-keepalive.service > /dev/null << EOF
[Unit]
Description=Bluetooth Amplifier Keep-Alive (continuous silence stream)
After=pulseaudio.service

[Service]
Type=simple
User=$(id -un)
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="PULSE_RUNTIME_PATH=/run/user/1000/pulse/"
ExecStart=/usr/local/bin/bluetooth-keepalive.sh
Restart=always
RestartSec=15s

[Install]
WantedBy=multi-user.target
EOF

# Migração: desactivar timer antigo se existir
sudo systemctl disable --now bluetooth-keepalive.timer 2>/dev/null || true
sudo rm -f /etc/systemd/system/bluetooth-keepalive.timer

sudo systemctl daemon-reload
sudo systemctl enable bluetooth-keepalive.service
sudo systemctl restart bluetooth-keepalive.service

echo "✓ bluetooth-keepalive instalado e activo"
echo "  Modo: stream contínua de silêncio (sem timer)"
echo "  Ver logs: sudo journalctl -u bluetooth-keepalive -f"
