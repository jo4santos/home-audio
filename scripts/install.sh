#!/bin/bash
set -e

# Carregar configuração
if [ -f "./config.env" ]; then
    source ./config.env
else
    echo "ERRO: Ficheiro config.env não encontrado!"
    echo "Copia o ficheiro de configuração da tua divisão para config.env"
    exit 1
fi

echo "=========================================="
echo "  Instalação Snapcast Client"
echo "=========================================="
echo ""
echo "Hostname: $HOSTNAME"
echo "IP: $IP_ADDRESS"
echo "Servidor: $SNAPSERVER_IP"
echo "Amplificador: $AMP_MAC"
echo "Player: $PLAYER_NAME"
echo ""
read -p "Confirma esta configuração? (s/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Instalação cancelada."
    exit 1
fi

echo ""
echo "=== 1/6 Atualizar sistema ==="
sudo apt update
sudo apt upgrade -y

echo ""
echo "=== 2/6 Instalar pacotes ==="
sudo apt install -y snapclient bluetooth bluez bluez-tools pulseaudio pulseaudio-module-bluetooth alsa-utils

echo ""
echo "=== 3/6 Configurar Bluetooth ==="
sudo tee /etc/bluetooth/main.conf > /dev/null << EOF
[General]
Enable=Source,Sink,Media,Socket
AutoEnable=true
FastConnectable=true
ReconnectAttempts=7
ReconnectIntervals=1,2,4,8,16,32,64

[Policy]
AutoConnect=true
ReconnectUUIDs=0000110b-0000-1000-8000-00805f9b34fb
EOF

# Desbloquear Bluetooth
sudo rfkill unblock bluetooth

sudo systemctl restart bluetooth
sleep 2

echo ""
echo "=== 4/6 Configurar Snapcast ==="
sudo tee /etc/default/snapclient > /dev/null << EOF
SNAPCLIENT_OPTS="-h ${SNAPSERVER_IP} --hostID ${PLAYER_NAME} -s pulse"
START_SNAPCLIENT=true
EOF

# Configurar serviço Snapclient para correr como user (necessário para aceder PulseAudio)
sudo mkdir -p /etc/systemd/system/snapclient.service.d
sudo tee /etc/systemd/system/snapclient.service.d/override.conf > /dev/null << EOF
[Service]
User=${USER}
Group=${USER}
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="PULSE_RUNTIME_PATH=/run/user/1000/pulse/"
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
ExecStartPre=/bin/sleep 10
EOF

sudo systemctl daemon-reload
sudo systemctl enable snapclient

echo ""
echo "=== 5/6 Script reconexão Bluetooth ==="
sudo tee /usr/local/bin/bluetooth-reconnect.sh > /dev/null << 'EOFSCRIPT'
#!/bin/bash
AMP_MAC="__AMP_MAC__"
MAX_ATTEMPTS=40
RETRY_INTERVAL=1
LOG_FILE="/var/log/bluetooth-reconnect.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Desbloquear Bluetooth (caso esteja bloqueado)
sudo rfkill unblock bluetooth
sleep 1

# Garantir que o Bluetooth está ligado
log_msg "A ligar Bluetooth..."
for i in {1..5}; do
    if bluetoothctl power on > /dev/null 2>&1; then
        log_msg "✓ Bluetooth ligado"
        break
    fi
    log_msg "Tentativa $i/5 de ligar Bluetooth..."
    sleep 2
done

# Aguardar Bluetooth ficar pronto
sleep 3

# Verificar se dispositivo está paired
IS_PAIRED=$(bluetoothctl devices Paired 2>/dev/null | grep -c "$AMP_MAC")

if [ "$IS_PAIRED" -eq 0 ]; then
    log_msg "⚠ Dispositivo não está paired. A fazer scan para initial pairing..."

    # Tentar fazer scan e pair (apenas se dispositivo não estiver paired)
    echo -e "scan on" | bluetoothctl > /dev/null 2>&1 &
    sleep 15

    DEVICE_FOUND=$(bluetoothctl devices 2>/dev/null | grep -c "$AMP_MAC")
    echo -e "scan off" | bluetoothctl > /dev/null 2>&1

    if [ "$DEVICE_FOUND" -gt 0 ]; then
        log_msg "✓ Dispositivo encontrado. A fazer pairing inicial..."
        echo -e "pair $AMP_MAC\ntrust $AMP_MAC\nquit" | bluetoothctl > /dev/null 2>&1
        sleep 3
        log_msg "Pairing inicial completo. A tentar conectar..."
    else
        log_msg "⚠ Dispositivo não encontrado. Amplificador pode estar desligado. Tenta novamente em 15s."
        exit 0
    fi
fi

# Tentar conectar ao dispositivo paired
log_msg "A tentar conectar ao amplificador (até 60 tentativas)..."
attempt=0
while [ $attempt -lt $MAX_ATTEMPTS ]; do
    # Verificar se já está conectado
    if bluetoothctl info "$AMP_MAC" 2>/dev/null | grep -q "Connected: yes"; then
        log_msg "✓ Amplificador conectado (tentativa $((attempt+1)))"

        # Aguardar um pouco para PulseAudio processar
        sleep 3

        # Tentar configurar sink (não crítico se falhar)
        SINK_NAME=$(pactl list short sinks 2>/dev/null | grep bluez | awk '{print $2}' | head -n1)
        if [ -n "$SINK_NAME" ]; then
            if pactl set-default-sink "$SINK_NAME" 2>/dev/null; then
                log_msg "✓ Sink Bluetooth definido: $SINK_NAME"
            fi
        fi
        exit 0
    fi

    # Tentar conectar usando sessão interativa bluetoothctl (como o utilizador faz manualmente)
    if [ $((attempt % 10)) -eq 0 ]; then
        log_msg "Tentativa $((attempt+1))/$MAX_ATTEMPTS de conectar"
    fi
    echo -e "connect $AMP_MAC\nquit" | bluetoothctl > /dev/null 2>&1
    sleep $RETRY_INTERVAL
    ((attempt++))
done

log_msg "⚠ Não conseguiu conectar após $MAX_ATTEMPTS tentativas. Timer vai tentar novamente em 15s."
exit 0
EOFSCRIPT

sudo sed -i "s/__AMP_MAC__/${AMP_MAC}/g" /usr/local/bin/bluetooth-reconnect.sh
sudo chmod +x /usr/local/bin/bluetooth-reconnect.sh

# Criar ficheiro de log com permissões corretas
sudo touch /var/log/bluetooth-reconnect.log
sudo chown ${USER}:${USER} /var/log/bluetooth-reconnect.log
sudo chmod 644 /var/log/bluetooth-reconnect.log

echo ""
echo "=== 6/6 Criar serviços ==="

sudo tee /etc/systemd/system/bluetooth-reconnect.service > /dev/null << EOF
[Unit]
Description=Bluetooth Amplifier Auto-Reconnect
After=bluetooth.service pulseaudio.service sound.target network-online.target
Wants=bluetooth.service pulseaudio.service
Requires=bluetooth.service

[Service]
Type=oneshot
User=${USER}
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
ExecStartPre=/bin/sleep 5
ExecStart=/usr/local/bin/bluetooth-reconnect.sh
Restart=on-failure
RestartSec=10
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/bluetooth-reconnect.timer > /dev/null << EOF
[Unit]
Description=Check Bluetooth connection periodically
After=bluetooth.service

[Timer]
OnBootSec=15s
OnUnitActiveSec=15s
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

sudo tee /usr/local/bin/wifi-watchdog.sh > /dev/null << 'EOF'
#!/bin/bash
GATEWAY="192.168.30.1"
LOG_FILE="/var/log/wifi-watchdog.log"

if ! ping -c 2 -W 3 "$GATEWAY" > /dev/null 2>&1; then
    echo "$(date): WiFi sem conectividade, a reiniciar wlan0..." >> "$LOG_FILE"
    sudo ip link set wlan0 down
    sleep 5
    sudo ip link set wlan0 up
    sleep 10
    systemctl start bluetooth-reconnect.service
fi
EOF

sudo chmod +x /usr/local/bin/wifi-watchdog.sh

# Criar ficheiro de log do WiFi watchdog com permissões corretas
sudo touch /var/log/wifi-watchdog.log
sudo chown ${USER}:${USER} /var/log/wifi-watchdog.log
sudo chmod 644 /var/log/wifi-watchdog.log

(crontab -l 2>/dev/null | grep -v wifi-watchdog; echo "*/2 * * * * /usr/local/bin/wifi-watchdog.sh") | crontab -

sudo systemctl daemon-reload
sudo systemctl enable bluetooth-reconnect.service
sudo systemctl enable bluetooth-reconnect.timer

mkdir -p ~/.config/systemd/user
systemctl --user enable pulseaudio.service
systemctl --user start pulseaudio.service

echo ""
echo "=========================================="
echo "  ✓ Instalação concluída!"
echo "=========================================="
echo ""
echo "PRÓXIMO PASSO: Emparelhar Bluetooth"
echo "Executar: sudo bluetoothctl"
echo ""
