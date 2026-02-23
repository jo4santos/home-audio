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

# Sair se modo manual activo (utilizador desemparelhou intencionalmente via HA)
[ -f "/var/lib/bluetooth-reconnect/manual-mode" ] && exit 0

# Actuar apenas se BT sink existe e não está a reproduzir áudio
if pactl list short sinks 2>/dev/null | grep -q "bluez" && \
   ! pactl list short sinks 2>/dev/null | grep "bluez" | grep -q "RUNNING"; then
    sink=$(pactl list short sinks 2>/dev/null | grep bluez | awk '{print $2}')
    # 2s de silêncio: 44100 Hz × 2 canais × 2 bytes × 2s = 352800 bytes
    dd if=/dev/zero bs=352800 count=1 2>/dev/null | \
        paplay --raw --format=s16le --rate=44100 --channels=2 --device="$sink" 2>/dev/null || true
fi
exit 0
SCRIPT

sudo chmod +x /usr/local/bin/bluetooth-keepalive.sh

sudo tee /etc/systemd/system/bluetooth-keepalive.service > /dev/null << EOF
[Unit]
Description=Bluetooth Amplifier Keep-Alive (silence pulse)
After=pulseaudio.service

[Service]
Type=oneshot
User=$(id -un)
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="PULSE_RUNTIME_PATH=/run/user/1000/pulse/"
ExecStart=/usr/local/bin/bluetooth-keepalive.sh
EOF

sudo tee /etc/systemd/system/bluetooth-keepalive.timer > /dev/null << 'TIMER'
[Unit]
Description=Bluetooth Keep-Alive Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=10min
Unit=bluetooth-keepalive.service

[Install]
WantedBy=timers.target
TIMER

sudo systemctl daemon-reload
sudo systemctl enable --now bluetooth-keepalive.timer

echo "✓ bluetooth-keepalive instalado e activo"
echo "  Intervalo: 10 em 10 minutos"
echo "  Ver logs: sudo journalctl -u bluetooth-keepalive -f"
