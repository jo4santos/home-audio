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
echo "=== 1/7 Atualizar sistema ==="
sudo apt update
sudo apt upgrade -y

echo ""
echo "=== 2/7 Instalar pacotes ==="
sudo apt install -y snapclient bluetooth bluez bluez-tools pulseaudio pulseaudio-module-bluetooth alsa-utils

echo ""
echo "=== 3/7 Configurar Bluetooth ==="
# Adicionar user ao grupo bluetooth (necessário para operações BlueZ sem sessão polkit activa)
sudo usermod -aG bluetooth ${USER}
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
echo "=== 4/7 Configurar Snapcast ==="
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
echo "=== 5/7 Script reconexão Bluetooth ==="
sudo tee /usr/local/bin/bluetooth-reconnect.sh > /dev/null << 'EOFSCRIPT'
#!/bin/bash
AMP_MAC="__AMP_MAC__"
LOG_FILE="/var/log/bluetooth-reconnect.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Exit silencioso se já conectado — o timer corre a cada 15s, não queremos spam no log
if bluetoothctl info "$AMP_MAC" 2>/dev/null | grep -q "Connected: yes"; then
    exit 0
fi

log_msg "Não conectado. A iniciar reconexão..."

# Desbloquear apenas se estiver bloqueado (evita resetar adaptador)
if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
    log_msg "Bluetooth bloqueado. A desbloquear..."
    sudo rfkill unblock bluetooth
    sleep 1
fi

# Ligar apenas se estiver desligado (evita ciclar adaptador)
if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    log_msg "A ligar Bluetooth..."
    bluetoothctl power on > /dev/null 2>&1 || true
    sleep 3
fi

# Verificar se está paired
IS_PAIRED=$(bluetoothctl devices Paired 2>/dev/null | grep -c "$AMP_MAC")

if [ "$IS_PAIRED" -gt 0 ]; then
    # Paired: tentar conectar até 3 vezes (cada uma numa sessão interativa)
    log_msg "Dispositivo paired. A tentar conectar..."
    for attempt in 1 2 3; do
        (
            echo "connect $AMP_MAC"
            sleep 8
            echo "quit"
        ) | bluetoothctl >> "$LOG_FILE" 2>&1
        bluetoothctl info "$AMP_MAC" 2>/dev/null | grep -q "Connected: yes" && break
        [ "$attempt" -lt 3 ] && sleep 2
    done
else
    # Não paired: fluxo completo numa única sessão interativa (igual ao processo manual)
    log_msg "Dispositivo não paired. A fazer scan + pair + trust + connect..."
    (
        echo "scan on"
        sleep 25
        echo "scan off"
        sleep 2
        echo "pair $AMP_MAC"
        sleep 8
        echo "trust $AMP_MAC"
        sleep 2
        echo "connect $AMP_MAC"
        sleep 10
        echo "quit"
    ) | bluetoothctl | tee -a "$LOG_FILE"
fi

# Verificar resultado e configurar sink PulseAudio
sleep 2
if bluetoothctl info "$AMP_MAC" 2>/dev/null | grep -q "Connected: yes"; then
    log_msg "✓ Conectado com sucesso"
    SINK_NAME=$(pactl list short sinks 2>/dev/null | grep bluez | awk '{print $2}' | head -n1)
    [ -n "$SINK_NAME" ] && pactl set-default-sink "$SINK_NAME" 2>/dev/null && log_msg "✓ Sink definido: $SINK_NAME"
else
    log_msg "⚠ Não conectou (amplificador desligado ou fora de alcance)."
fi

exit 0
EOFSCRIPT

sudo sed -i "s/__AMP_MAC__/${AMP_MAC}/g" /usr/local/bin/bluetooth-reconnect.sh
sudo chmod +x /usr/local/bin/bluetooth-reconnect.sh

# Criar ficheiro de log com permissões corretas
sudo touch /var/log/bluetooth-reconnect.log
sudo chown ${USER}:${USER} /var/log/bluetooth-reconnect.log
sudo chmod 644 /var/log/bluetooth-reconnect.log

echo ""
echo "=== 6/7 Acesso SSH do Home Assistant ==="
# Chave do addon SSH (core-ssh) — para acesso manual pelo terminal do addon
HA_PUBKEY_ADDON="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG373a5ihDT/0CyQiBN6W8dk7NY+J1aKv32JLctvx0r0 root@core-ssh"
# Chave do container principal do HA — necessária para shell_command no configuration.yaml
HA_PUBKEY_CONTAINER="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFgbSWq8kU6+UiS9xaFYXx4pEraO5cjOfn3KUmwhYh5K root@homeassistant"

mkdir -p ~/.ssh
chmod 700 ~/.ssh
for KEY in "$HA_PUBKEY_ADDON" "$HA_PUBKEY_CONTAINER"; do
    if ! grep -qF "$KEY" ~/.ssh/authorized_keys 2>/dev/null; then
        echo "$KEY" >> ~/.ssh/authorized_keys
    fi
done
echo "✓ Chaves SSH do Home Assistant adicionadas"
chmod 600 ~/.ssh/authorized_keys

echo "${USER} ALL=(ALL) NOPASSWD: /bin/systemctl start bluetooth-reconnect.service" | sudo tee /etc/sudoers.d/bluetooth-reconnect > /dev/null
sudo chmod 440 /etc/sudoers.d/bluetooth-reconnect
echo "✓ Sudoers configurado para Home Assistant"

echo ""
echo "=== 7/7 Criar serviços ==="

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
    sudo systemctl start bluetooth-reconnect.service
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

# Habilitar linger para que os serviços do utilizador (PulseAudio, etc.)
# sobrevivam sem sessões SSH ativas — essencial para áudio e Bluetooth em idle
sudo loginctl enable-linger ${USER}

echo ""
echo "=========================================="
echo "  ✓ Instalação concluída!"
echo "=========================================="
echo ""
echo "PRÓXIMO PASSO: Emparelhar Bluetooth"
echo "Executar: sudo bluetoothctl"
echo ""
