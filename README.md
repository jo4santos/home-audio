# Sistema de Áudio Multi-Divisão com Snapcast

Sistema de som sincronizado para toda a casa usando Raspberry Pi 4B, Snapcast e Home Assistant.

## 📋 Visão Geral

Este projeto implementa um sistema de áudio multi-divisão com:
- **Sincronização perfeita** entre todas as divisões
- **Reconexão automática** Bluetooth e WiFi
- **Integração** com Home Assistant + Music Assistant
- **7 divisões** independentes controladas centralmente

### Porquê Snapcast?

**Snapcast** foi escolhido em vez de Squeezelite pelos seguintes motivos:
- ✅ Sincronização de áudio entre divisões em tempo real (latência < 1ms)
- ✅ Reconexão automática após perda de energia
- ✅ Integração nativa com Home Assistant/Music Assistant
- ✅ Protocolo otimizado para redes WiFi
- ✅ Suporte ativo e comunidade grande

**Squeezelite** apresentou problemas de:
- ❌ Sincronização inconsistente entre divisões
- ❌ Falha na reconexão após queda de energia
- ❌ Gestão de WiFi problemática

---

## 🏠 Configuração das Divisões

| Divisão          | IP            | MAC Amplificador  | Hostname              | Player Name            |
|------------------|---------------|-------------------|-----------------------|------------------------|
| Escritório       | 192.168.30.7  | 00:0D:18:B0:67:E8 | rpi-escritorio        | colunas-escritorio     |
| Suite            | 192.168.30.2  | 00:0D:18:B0:67:76 | rpi-suite             | colunas-suite          |
| Cozinha          | 192.168.30.3  | 6A:71:C1:06:D3:2A | rpi-cozinha           | colunas-cozinha        |
| Sala             | 192.168.30.4  | 34:81:F4:F5:E8:AC | rpi-sala              | colunas-sala           |
| WC Suite         | 192.168.30.5  | 00:0D:18:B0:62:43 | rpi-wcsuite           | colunas-wcsuite        |
| Quarto Crianças  | 192.168.30.6  | 00:0D:18:B0:67:C5 | rpi-quartocriancas    | colunas-quartocriancas |
| Quarto Desporto  | 192.168.30.1  | 34:81:F4:F6:88:73 | rpi-quartodesporto    | colunas-quartodesporto |

**Servidor Snapcast**: 192.168.2.100 (Home Assistant)

---

## 🚀 Instalação Rápida

### Pré-requisitos

- SD Card (mínimo 8GB, recomendado 16GB)
- Raspberry Pi Imager instalado
- Acesso SSH ao computador
- Router WiFi 5GHz configurado

### Para uma única divisão

```bash
# 1. Preparar SD Card sem configurações (ver secção detalhada abaixo)
# 2. Inserir SD Card no RPi, ligar monitor e teclado
# 3. Configurar no assistente inicial:
#    - Teclado: Portuguese (Portugal)
#    - User: relvasantos / Password: qwe123asd456

# 4. Configurar com raspi-config:
#    - WiFi Country (PT)
#    - WiFi (SSID e password)
#    - Hostname (ex: rpi-escritorio)
#    - SSH (Enable)
#    - Finish e Reboot

# 5. No teu computador, copiar ficheiros
cd scripts
./deploy.sh escritorio    # substituir pela tua divisão

# 6. Conectar ao RPi e instalar
ssh relvasantos@192.168.30.7    # usar o IP da tua divisão
bash install.sh

# 7. Emparelhar Bluetooth (ver secção detalhada)
# 8. Reiniciar e testar
sudo reboot
```

---

## 📖 Instalação Detalhada

### PASSO 1: Preparar SD Card

1. Abrir **Raspberry Pi Imager**
2. Escolher:
   - **OS**: Raspberry Pi OS Lite (64-bit)
   - **Storage**: O teu SD Card
3. Clicar em **WRITE** (não configurar nada nas opções avançadas)
4. Aguardar conclusão
5. Inserir SD Card no Raspberry Pi
6. Ligar teclado, monitor HDMI e à corrente
7. **Aguardar arrancar** (2-3 minutos)

**Ao arrancar, vai aparecer um assistente de configuração:**

1. **Teclado**: Escolher **Portuguese (Portugal)**
2. **Criar utilizador**:
   - Username: `relvasantos`
   - Password: `qwe123asd456`
3. **Fazer login** com as credenciais criadas

---

### PASSO 2: Configurar RPi com raspi-config

Ainda no RPi (com teclado e monitor), executar:

```bash
sudo raspi-config
```

**Configurar pela seguinte ordem:**

1. **5 Localisation Options → L4 WLAN Country**
   - Escolher: **PT Portugal**
   - OK

2. **1 System Options → S1 Wireless LAN**
   - SSID: `RelvaSantos-2025`
   - Password: `qwe123asd456`
   - OK

3. **1 System Options → S4 Hostname**
   - Hostname: `rpi-escritorio` (mudar conforme a divisão)
   - OK

4. **3 Interface Options → I2 SSH**
   - Enable SSH: **Yes**
   - OK

5. **Finish** e escolher **Yes** para reboot

**Aguardar 1-2 minutos** para o RPi reiniciar.

---

### PASSO 3: Testar Conectividade

No teu computador:

```bash
# Testar ping
ping 192.168.30.7    # usar o IP da tua divisão

# Primeira conexão SSH (aceita a chave do host automaticamente)
ssh -o StrictHostKeyChecking=accept-new relvasantos@192.168.30.7
# Password: qwe123asd456

# Sair
exit
```

Se funcionou, continua para o próximo passo!

---

### PASSO 4: Configurar SSH sem Password (Opcional mas Recomendado)

Isto permite conectar aos RPis sem ter de inserir password sempre.

```bash
# No teu computador (executar uma vez)
ssh-keygen -t ed25519 -C "home-audio"
# Pressionar ENTER 3 vezes (sem password)

# Copiar chave SSH para cada RPi
ssh-copy-id relvasantos@192.168.30.7    # Escritório
ssh-copy-id relvasantos@192.168.30.2    # Suite
ssh-copy-id relvasantos@192.168.30.3    # Cozinha
ssh-copy-id relvasantos@192.168.30.4    # Sala
ssh-copy-id relvasantos@192.168.30.5    # WC Suite
ssh-copy-id relvasantos@192.168.30.6    # Quarto Crianças
ssh-copy-id relvasantos@192.168.30.1    # Quarto Desporto

# Testar (não deve pedir password)
ssh relvasantos@192.168.30.7
exit
```

---

### PASSO 5: Copiar Ficheiros para o RPi

Usar o script de deploy para copiar automaticamente os ficheiros certos:

```bash
cd scripts

# Tornar script executável (apenas primeira vez)
chmod +x deploy.sh

# Copiar para uma divisão específica
./deploy.sh escritorio
```

**Ou copiar manualmente:**

```bash
cd scripts

# Copiar para escritório
scp install.sh relvasantos@192.168.30.7:~/
scp ../configs/escritorio.env relvasantos@192.168.30.7:~/config.env

# Copiar para suite
scp install.sh relvasantos@192.168.30.2:~/
scp ../configs/suite.env relvasantos@192.168.30.2:~/config.env

# ... (repetir para outras divisões)
```

---

### PASSO 6: Executar Instalação no RPi

```bash
# Conectar via SSH
ssh relvasantos@192.168.30.7    # usar o IP da tua divisão

# Executar instalação (demora 5-10 minutos)
bash install.sh
```

O script vai:
1. Atualizar o sistema
2. Instalar Snapcast Client
3. Instalar e configurar Bluetooth
4. Instalar PulseAudio
5. Criar scripts de reconexão automática
6. Configurar WiFi watchdog
7. Ativar todos os serviços

---

### PASSO 7: Emparelhar Amplificador Bluetooth

**Importante:** Este passo tem de ser feito manualmente para cada RPi.

1. **Colocar o amplificador em modo de emparelhamento**
   - Consultar o manual do amplificador
   - Geralmente é pressionar um botão por 3-5 segundos

2. **No RPi, iniciar bluetoothctl:**
   ```bash
   sudo bluetoothctl
   ```

3. **Executar comandos (um de cada vez):**
   ```
   power on
   agent on
   default-agent
   scan on
   ```

4. **Aguardar 10-30 segundos** até aparecer algo como:
   ```
   [NEW] Device 00:0D:18:B0:67:E8 Amplificador_Nome
   ```

5. **Quando aparecer, continuar** (substituir pelo MAC correto):
   ```
   scan off
   pair 00:0D:18:B0:67:E8
   trust 00:0D:18:B0:67:E8
   connect 00:0D:18:B0:67:E8
   exit
   ```

6. **Verificar conexão:**
   ```bash
   pactl list short sinks
   ```

   Deves ver algo como:
   ```
   1    bluez_sink.00_0D_18_B0_67_E8.a2dp_sink
   ```

---

### PASSO 8: Iniciar Serviços

```bash
# Iniciar Snapcast Client
sudo systemctl start snapclient

# Iniciar reconexão Bluetooth automática
sudo systemctl start bluetooth-reconnect.timer

# Verificar status
sudo systemctl status snapclient
sudo systemctl status bluetooth-reconnect.timer
```

---

### PASSO 9: Reiniciar e Testar

```bash
# Reiniciar RPi
sudo reboot
```

Aguardar 2-3 minutos, depois testar:

```bash
# Conectar novamente
ssh relvasantos@192.168.30.7

# Verificar Bluetooth
pactl list short sinks

# Ver logs de reconexão
sudo journalctl -u bluetooth-reconnect -f

# Ver logs Snapcast
sudo journalctl -u snapclient -f
```

---

## 🔧 Verificação no Home Assistant

1. Abrir Home Assistant: `http://192.168.2.100:8123`
2. Ir a **Settings → Add-ons**
3. Se não tiveres, instalar: **Snapcast Server**
4. Abrir **Music Assistant**
5. Ir a **Settings → Players**
6. Deves ver todos os players configurados:
   - colunas-escritorio
   - colunas-suite
   - colunas-cozinha
   - etc.

---

## 📁 Estrutura de Ficheiros

```
home-audio/
├── README.md                      # Este ficheiro
├── configs/                       # Configurações por divisão
│   ├── escritorio.env
│   ├── suite.env
│   ├── cozinha.env
│   ├── sala.env
│   ├── wcsuite.env
│   ├── quartocriancas.env
│   └── quartodesporto.env
└── scripts/
    ├── install.sh                 # Script principal de instalação
    └── deploy.sh                  # Script para copiar ficheiros
```

---

## 🔍 Troubleshooting

### Bluetooth não conecta

```bash
# Ver logs de reconexão
sudo journalctl -u bluetooth-reconnect -f

# Ver log do script
sudo tail -f /var/log/bluetooth-reconnect.log

# Forçar reconexão manual
sudo systemctl start bluetooth-reconnect.service

# Verificar se amplificador está paired
bluetoothctl info 00:0D:18:B0:67:E8

# Re-emparelhar se necessário
sudo bluetoothctl
remove 00:0D:18:B0:67:E8
scan on
# ... (repetir processo de emparelhamento)
```

### Snapcast não aparece no Home Assistant

```bash
# Ver logs do Snapcast
sudo journalctl -u snapclient -f

# Verificar configuração
cat /etc/default/snapclient

# Reiniciar serviço
sudo systemctl restart snapclient

# Verificar conectividade com servidor
ping 192.168.2.100
```

### WiFi não reconecta após queda de energia

```bash
# Ver logs do WiFi watchdog
sudo tail -f /var/log/wifi-watchdog.log

# Testar conectividade
ping 192.168.30.1

# Verificar interface WiFi
ip addr show wlan0

# Reiniciar interface manualmente
sudo ip link set wlan0 down
sudo ip link set wlan0 up
```

### RPi não responde após reboot

1. Aguardar 3-5 minutos (primeira boot pode demorar)
2. Verificar LED de atividade no RPi
3. Conectar monitor HDMI e teclado USB para diagnóstico
4. Verificar se SD Card está bem inserido
5. Tentar re-flash do SD Card

### Erro "Host key verification failed"

Se obtiveres este erro ao conectar via SSH:

```bash
# Remover entrada antiga do known_hosts
ssh-keygen -R 192.168.30.7

# Conectar novamente aceitando nova chave
ssh -o StrictHostKeyChecking=accept-new relvasantos@192.168.30.7
```

### Áudio dessincronizado entre divisões

```bash
# Verificar latência no Home Assistant
# Music Assistant → Settings → Players → (player) → Settings

# Ajustar buffer do Snapcast (se necessário)
sudo nano /etc/default/snapclient
# Adicionar: SNAPCLIENT_OPTS="-h 192.168.2.100 --hostID nome --latency 100"

# Reiniciar
sudo systemctl restart snapclient
```

---

## 🛠️ Comandos Úteis

### Gestão de Serviços

```bash
# Ver status de todos os serviços
sudo systemctl status snapclient
sudo systemctl status bluetooth-reconnect.service
sudo systemctl status bluetooth-reconnect.timer

# Reiniciar serviços
sudo systemctl restart snapclient
sudo systemctl restart bluetooth-reconnect.service

# Ver logs em tempo real
sudo journalctl -u snapclient -f
sudo journalctl -u bluetooth-reconnect -f
```

### Bluetooth

```bash
# Verificar dispositivos paired
bluetoothctl paired-devices

# Info detalhada do amplificador
bluetoothctl info 00:0D:18:B0:67:E8

# Conectar manualmente
bluetoothctl connect 00:0D:18:B0:67:E8

# Desconectar
bluetoothctl disconnect 00:0D:18:B0:67:E8
```

### PulseAudio

```bash
# Listar sinks disponíveis
pactl list short sinks

# Definir sink default
pactl set-default-sink bluez_sink.00_0D_18_B0_67_E8.a2dp_sink

# Volume
pactl set-sink-volume @DEFAULT_SINK@ 80%
pactl set-sink-mute @DEFAULT_SINK@ 0
```

### Rede

```bash
# Ver endereço IP
hostname -I

# Testar conectividade
ping 192.168.30.1          # Gateway
ping 192.168.2.100         # Snapcast Server

# Ver status WiFi
iwconfig wlan0

# Reiniciar interface WiFi
sudo ip link set wlan0 down
sudo ip link set wlan0 up
```

---

## 🔄 Instalar Múltiplas Divisões

Para instalar em todas as 7 divisões de forma eficiente:

### Opção 1: Instalação Sequencial (Recomendado)

```bash
# Preparar todas as SD Cards (processo manual em cada)
# Configurar cada RPi com raspi-config (WiFi, hostname, SSH)
# Aguardar todos estarem online

# Primeira conexão a cada RPi (aceitar host keys)
ssh -o StrictHostKeyChecking=accept-new relvasantos@192.168.30.7 "exit"
ssh -o StrictHostKeyChecking=accept-new relvasantos@192.168.30.2 "exit"
ssh -o StrictHostKeyChecking=accept-new relvasantos@192.168.30.3 "exit"
ssh -o StrictHostKeyChecking=accept-new relvasantos@192.168.30.4 "exit"
ssh -o StrictHostKeyChecking=accept-new relvasantos@192.168.30.5 "exit"
ssh -o StrictHostKeyChecking=accept-new relvasantos@192.168.30.6 "exit"
ssh -o StrictHostKeyChecking=accept-new relvasantos@192.168.30.1 "exit"

# Configurar SSH sem password
ssh-copy-id relvasantos@192.168.30.7
ssh-copy-id relvasantos@192.168.30.2
ssh-copy-id relvasantos@192.168.30.3
ssh-copy-id relvasantos@192.168.30.4
ssh-copy-id relvasantos@192.168.30.5
ssh-copy-id relvasantos@192.168.30.6
ssh-copy-id relvasantos@192.168.30.1

# Copiar e instalar em cada um
cd scripts
for divisao in escritorio suite cozinha sala wcsuite quartocriancas quartodesporto; do
    ./deploy.sh $divisao
done

# Agora conectar a cada um e executar
ssh relvasantos@192.168.30.7 "bash install.sh"
ssh relvasantos@192.168.30.2 "bash install.sh"
# ... etc
```

### Opção 2: Script Automatizado

Criar um ficheiro `install-all.sh`:

```bash
#!/bin/bash

DIVISIONS=(
    "escritorio:192.168.30.7"
    "suite:192.168.30.2"
    "cozinha:192.168.30.3"
    "sala:192.168.30.4"
    "wcsuite:192.168.30.5"
    "quartocriancas:192.168.30.6"
    "quartodesporto:192.168.30.1"
)

for div in "${DIVISIONS[@]}"; do
    NAME="${div%%:*}"
    IP="${div##*:}"

    echo "=== Instalando $NAME ($IP) ==="

    # Deploy
    cd scripts
    ./deploy.sh $NAME
    cd ..

    # Instalar remotamente
    ssh relvasantos@$IP "bash install.sh"

    echo "✓ $NAME concluído!"
    echo ""
done

echo "=========================================="
echo "  Todas as instalações concluídas!"
echo "=========================================="
echo ""
echo "PRÓXIMO PASSO: Emparelhar Bluetooth em cada RPi"
```

**Nota:** O emparelhamento Bluetooth tem de ser feito manualmente em cada RPi.

---

## 📝 Notas Importantes

### Reconexão Bluetooth
- O script tenta reconectar durante 60 segundos (tempo suficiente para o amplificador entrar em modo pairing)
- Timer verifica conexão de 2 em 2 minutos
- Se a conexão falhar, o script tenta novamente automaticamente

### WiFi Watchdog
- Verifica conectividade de 2 em 2 minutos
- Reinicia interface wlan0 se não conseguir ping ao gateway
- Força reconexão Bluetooth após reiniciar WiFi

### Snapcast
- Cliente conecta automaticamente ao servidor (192.168.2.100)
- Sincronização é automática (< 1ms entre divisões)
- Se servidor não estiver disponível, cliente aguarda e reconecta

### Segurança
- Password WiFi e SSH estão nos ficheiros de configuração
- **Recomendação:** Mudar passwords após instalação
- Considerar usar chaves SSH em vez de password

---

## 🆘 Suporte

### Logs Importantes

```bash
# Bluetooth
sudo journalctl -u bluetooth-reconnect -f
sudo tail -f /var/log/bluetooth-reconnect.log

# Snapcast
sudo journalctl -u snapclient -f

# WiFi Watchdog
sudo tail -f /var/log/wifi-watchdog.log

# Sistema
sudo journalctl -xe
dmesg | tail -50
```

### Reset Completo

Se algo correr muito mal:

```bash
# No RPi
sudo systemctl stop snapclient
sudo systemctl stop bluetooth-reconnect.timer
sudo systemctl stop bluetooth-reconnect.service

# Re-executar instalação
bash install.sh

# Re-emparelhar Bluetooth
sudo bluetoothctl
# ... (processo completo)
```

### Re-flash SD Card

Se o RPi não arrancar ou tiver problemas graves:
1. Inserir SD Card no computador
2. Abrir Raspberry Pi Imager
3. Repetir Passo 1 (Preparar SD Card)
4. Repetir todos os passos de instalação

---

## 📚 Recursos

- [Snapcast GitHub](https://github.com/badaix/snapcast)
- [Music Assistant](https://music-assistant.io/)
- [Home Assistant](https://www.home-assistant.io/)
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/)

---

**Versão**: 2.0
**Última atualização**: 2026-02-14
**Autor**: José Santos
