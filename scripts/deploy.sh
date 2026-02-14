#!/bin/bash

# Script para copiar ficheiros de instalação para o RPi
# Uso: ./deploy.sh <divisao> [mac_bluetooth]
# Exemplo: ./deploy.sh escritorio
# Exemplo com MAC: ./deploy.sh teste 00:0D:18:B0:67:E8

if [ -z "$1" ]; then
    echo "Uso: ./deploy.sh <divisao> [mac_bluetooth]"
    echo ""
    echo "Divisões disponíveis:"
    echo "  - escritorio"
    echo "  - suite"
    echo "  - cozinha"
    echo "  - sala"
    echo "  - wcsuite"
    echo "  - quartocriancas"
    echo "  - quartodesporto"
    echo "  - teste"
    echo ""
    echo "Opcional: Especificar MAC Bluetooth"
    echo "  ./deploy.sh teste 00:0D:18:B0:67:E8"
    exit 1
fi

DIVISAO=$1
BT_MAC=$2
CONFIG_FILE="../configs/${DIVISAO}.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERRO: Configuração não encontrada: $CONFIG_FILE"
    exit 1
fi

# Carregar configuração
source "$CONFIG_FILE"

# Se MAC Bluetooth foi fornecido, criar ficheiro temporário com MAC atualizado
if [ -n "$BT_MAC" ]; then
    TEMP_CONFIG="/tmp/config_${DIVISAO}_$$.env"
    sed "s/AMP_MAC=\".*\"/AMP_MAC=\"${BT_MAC}\"/" "$CONFIG_FILE" > "$TEMP_CONFIG"
    CONFIG_TO_COPY="$TEMP_CONFIG"
    echo "MAC Bluetooth: ${BT_MAC} (fornecido como argumento)"
else
    CONFIG_TO_COPY="$CONFIG_FILE"
    echo "MAC Bluetooth: ${AMP_MAC} (do ficheiro de configuração)"
fi

echo "=========================================="
echo "  Deploy para ${DIVISAO}"
echo "=========================================="
echo "User: ${USER}"
echo "IP: ${IP_ADDRESS}"
echo "Hostname: ${HOSTNAME}"
echo ""

# Copiar ficheiros
echo "A copiar ficheiros para ${USER}@${IP_ADDRESS}..."
scp install.sh ${USER}@${IP_ADDRESS}:~/
scp "$CONFIG_TO_COPY" ${USER}@${IP_ADDRESS}:~/config.env

# Limpar ficheiro temporário se foi criado
if [ -n "$BT_MAC" ]; then
    rm -f "$TEMP_CONFIG"
fi

echo ""
echo "✓ Ficheiros copiados com sucesso!"
echo ""
echo "Para instalar, executa:"
echo "  ssh ${USER}@${IP_ADDRESS}"
echo "  bash install.sh"
echo ""
