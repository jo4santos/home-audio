#!/bin/bash
set -e

# Instala o bluetooth-keepalive (AVRCP) no RPi actual
# Seguro para RPis já configurados — não reinstala tudo
# Requer AMP_MAC como argumento: bash install-keepalive.sh <AMP_MAC>
#
# Uso: bash install-keepalive.sh 00:0D:18:B0:67:E8
# (ou executado automaticamente pelo deploy.sh)

AMP_MAC="${1:?Uso: bash install-keepalive.sh <AMP_MAC>}"

echo "=== A instalar bluetooth-keepalive (AVRCP) ==="

sudo tee /usr/local/bin/bluetooth-keepalive.sh > /dev/null << 'SCRIPT'
#!/bin/bash
# AVRCP keepalive: envia comando de controlo BT a cada 3min para prevenir auto-off
# Não envia áudio — o sink mantém-se SUSPENDED
export XDG_RUNTIME_DIR=/run/user/1000

AMP_MAC="__AMP_MAC__"
DEV_PATH="/org/bluez/hci0/dev_$(echo "$AMP_MAC" | tr ':' '_')"

while true; do
    if [ ! -f "/var/lib/bluetooth-reconnect/manual-mode" ]; then
        if pactl list short sinks 2>/dev/null | grep -q bluez; then
            dbus-send --system --dest=org.bluez "$DEV_PATH" \
                org.bluez.MediaControl1.Pause 2>/dev/null
        fi
    fi
    sleep 180
done
SCRIPT

sudo sed -i "s/__AMP_MAC__/${AMP_MAC}/g" /usr/local/bin/bluetooth-keepalive.sh
sudo chmod +x /usr/local/bin/bluetooth-keepalive.sh

sudo tee /etc/systemd/system/bluetooth-keepalive.service > /dev/null << EOF
[Unit]
Description=Bluetooth Amplifier Keep-Alive (AVRCP)
After=bluetooth.service

[Service]
Type=simple
User=$(id -un)
Environment="XDG_RUNTIME_DIR=/run/user/1000"
ExecStart=/usr/local/bin/bluetooth-keepalive.sh
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now bluetooth-keepalive.service

echo "✓ bluetooth-keepalive (AVRCP) instalado e activo"
echo "  Intervalo: 3 minutos, sem áudio"
echo "  Ver logs: sudo journalctl -u bluetooth-keepalive -f"
