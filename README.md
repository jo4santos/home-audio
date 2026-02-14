# Instalação Snapcast Client - Escritório (192.168.30.7)

## PASSOS A SEGUIR

### PASSO 1: Preparar SD Card

1. Abrir Raspberry Pi Imager
2. OS: Raspberry Pi OS Lite (64-bit)
3. Storage: Escolher o teu SD Card
4. Clicar no ícone ⚙️ (engrenagem) para configurações:
   • Enable SSH (Use password authentication)
   • Set username and password
     - Username: pi
     - Password: qwe123asd456
   • Configure wireless LAN
     - SSID: RelvaSantos-2025
     - Password: qwe123asd456
     - Country: PT
   • Set locale settings
     - Time zone: Europe/Lisbon
     - Keyboard: pt
   • Set hostname: rpi-escritorio
5. Clicar em WRITE
6. Quando terminar, colocar SD card no RPi e ligar à corrente
7. Esperar 2-3 minutos para o RPi arrancar

---

### PASSO 2: Conectar ao RPi via SSH

No teu computador:

ping 192.168.30.7

ssh pi@192.168.30.7

Password: qwe123asd456

---

### PASSO 3: Criar Script de Instalação

No teu computador, cria um ficheiro chamado install.sh com este conteúdo:

========== INÍCIO DO FICHEIRO install.sh ==========

#!/bin/bash
set -e

# CONFIGURAÇÃO ESCRITÓRIO
SNAPSERVER_IP="192.168.2.100"
AMP_MAC="00:0D:18:B0:67:E8"
PLAYER_NAME="colunas-escritorio"

echo "=========================================="
echo "  Instalação Escritório"
echo "=========================================="
echo ""
echo "Servidor: $SNAPSERVER_IP"
echo "Amplificador: $AMP_MAC"
echo "Player: $PLAYER_NAME"
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

sudo systemctl restart bluetooth
sleep 2

echo ""
echo "=== 4/6 Configurar Snapcast ==="
sudo tee /etc/default/snapclient > /dev/null << EOF
SNAPCLIENT_OPTS="-h ${SNAPSERVER_IP} --hostID ${PLAYER_NAME}"
START_SNAPCLIENT=true
EOF

sudo systemctl enable snapclient

echo ""
echo "=== 5/6 Script reconexão Bluetooth ==="
sudo tee /usr/local/bin/bluetooth-reconnect.sh > /dev/null << 'EOFSCRIPT'
#!/bin/bash
AMP_MAC="__AMP_MAC__"
MAX_ATTEMPTS=60
RETRY_INTERVAL=1
LOG_FILE="/var/log/bluetooth-reconnect.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

bluetoothctl power on > /dev/null 2>&1
sleep 1

attempt=0
while [ $attempt -lt $MAX_ATTEMPTS ]; do
    if bluetoothctl info "$AMP_MAC" 2>/dev/null | grep -q "Connected: yes"; then
        log_msg "✓ Amplificador conectado"
        sleep 3
        SINK_NAME=$(pactl list short sinks | grep bluez | awk '{print $2}' | head -n1)
        if [ -n "$SINK_NAME" ]; then
            pactl set-default-sink "$SINK_NAME"
            log_msg "✓ Sink Bluetooth definido: $SINK_NAME"
        fi
        exit 0
    fi
    
    log_msg "Tentativa $((attempt+1))/$MAX_ATTEMPTS"
    bluetoothctl connect "$AMP_MAC" > /dev/null 2>&1
    sleep $RETRY_INTERVAL
    ((attempt++))
done

log_msg "✗ Falha ao conectar"
exit 1
EOFSCRIPT

sudo sed -i "s/__AMP_MAC__/${AMP_MAC}/g" /usr/local/bin/bluetooth-reconnect.sh
sudo chmod +x /usr/local/bin/bluetooth-reconnect.sh

echo ""
echo "=== 6/6 Criar serviços ==="

sudo tee /etc/systemd/system/bluetooth-reconnect.service > /dev/null << EOF
[Unit]
Description=Bluetooth Amplifier Auto-Reconnect
After=bluetooth.service pulseaudio.service
Requires=bluetooth.service

[Service]
Type=oneshot
User=pi
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
ExecStart=/usr/local/bin/bluetooth-reconnect.sh
RemainAfterExit=yes
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/bluetooth-reconnect.timer > /dev/null << EOF
[Unit]
Description=Check Bluetooth connection periodically

[Timer]
OnBootSec=30s
OnUnitActiveSec=2min

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
echo ""

========== FIM DO FICHEIRO install.sh ==========

---

### PASSO 4: Enviar Script para o RPi

No teu computador:

chmod +x install.sh

scp install.sh pi@192.168.30.7:~/

Password: qwe123asd456

---

### PASSO 5: Executar Instalação no RPi

Conectar ao RPi:

ssh pi@192.168.30.7

Executar o script (demora 5-10 minutos):

bash install.sh

---

### PASSO 6: Emparelhar Amplificador Bluetooth

Ainda ligado ao RPi via SSH:

1. Colocar o amplificador em modo de emparelhamento (consultar manual)

2. Executar:

sudo bluetoothctl

3. Dentro do bluetoothctl, digitar estes comandos um a um:

power on
agent on
default-agent
scan on

4. Aguardar aparecer (10-30 segundos):

[NEW] Device 00:0D:18:B0:67:E8 Nome_Do_Amplificador

5. Quando aparecer, continuar:

scan off
pair 00:0D:18:B0:67:E8
trust 00:0D:18:B0:67:E8
connect 00:0D:18:B0:67:E8
exit

---

### PASSO 7: Iniciar Serviços

Ainda no RPi:

sudo systemctl start snapclient

sudo systemctl start bluetooth-reconnect.timer

Verificar que tudo está a funcionar:

pactl list short sinks

Deves ver algo como:
1    bluez_sink.00_0D_18_B0_67_E8.a2dp_sink

---

### PASSO 8: Reiniciar e Testar

sudo reboot

Espera 2 minutos, depois testa:

ssh pi@192.168.30.7

pactl list short sinks

---

## VERIFICAR NO HOME ASSISTANT

1. Abrir Home Assistant: http://192.168.2.100:8123
2. Ir a Settings → Add-ons → Snapcast Server
3. Se não tiveres, instalar o add-on "Snapcast Server"
4. Abrir Music Assistant
5. Ir a Settings → Players
6. Deves ver aparecer: colunas-escritorio

---

## RESUMO RÁPIDO DOS COMANDOS

NO TEU COMPUTADOR:
1. Criar ficheiro install.sh (copiar conteúdo acima)
2. chmod +x install.sh
3. scp install.sh pi@192.168.30.7:~/

CONECTAR AO RPI:
4. ssh pi@192.168.30.7

NO RPI:
5. bash install.sh

EMPARELHAR BLUETOOTH:
6. sudo bluetoothctl
   power on
   agent on
   scan on
   (aguardar ver 00:0D:18:B0:67:E8)
   scan off
   pair 00:0D:18:B0:67:E8
   trust 00:0D:18:B0:67:E8
   connect 00:0D:18:B0:67:E8
   exit

INICIAR:
7. sudo systemctl start snapclient
8. sudo systemctl start bluetooth-reconnect.timer

REINICIAR:
9. sudo reboot

---

## SE ALGO CORRER MAL

Ver logs Bluetooth:
sudo journalctl -u bluetooth-reconnect -f

Ver logs Snapcast:
sudo journalctl -u snapclient -f

Forçar reconexão Bluetooth:
sudo systemctl start bluetooth-reconnect.service

Verificar se amplificador está paired:
bluetoothctl info 00:0D:18:B0:67:E8

---

## TABELA DE CONFIGURAÇÃO PARA OUTRAS DIVISÕES

Divisão          | IP              | MAC Coluna         | Player Name
----------------|-----------------|-------------------|-------------------------
Escritório      | 192.168.30.7    | 00:0D:18:B0:67:E8 | colunas-escritorio
Suite           | 192.168.30.2    | 00:0D:18:B0:67:76 | colunas-suite
Cozinha         | 192.168.30.3    | 6A:71:C1:06:D3:2A | colunas-cozinha
Sala            | 192.168.30.4    | 34:81:F4:F5:E8:AC | colunas-sala
WC Suite        | 192.168.30.5    | 00:0D:18:B0:62:43 | colunas-wcsuite
Quarto Crianças | 192.168.30.6    | 00:0D:18:B0:67:C5 | colunas-quartocriancas
Quarto Desporto | 192.168.30.1    | 34:81:F4:F6:88:73 | colunas-quartodesporto

Para instalar noutras divisões, mudar no ficheiro install.sh:
- AMP_MAC (MAC da coluna dessa divisão)
- PLAYER_NAME (nome do player)

SNAPSERVER_IP é sempre: 192.168.2.100
