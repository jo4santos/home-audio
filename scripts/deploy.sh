#!/bin/bash

# Script para copiar ficheiros de instalação para o RPi
# Uso: ./deploy.sh <divisao>
# Exemplo: ./deploy.sh escritorio

if [ -z "$1" ]; then
    echo "Uso: ./deploy.sh <divisao>"
    echo ""
    echo "Divisões disponíveis:"
    echo "  - escritorio"
    echo "  - suite"
    echo "  - cozinha"
    echo "  - sala"
    echo "  - wcsuite"
    echo "  - quartocriancas"
    echo "  - quartodesporto"
    exit 1
fi

DIVISAO=$1
CONFIG_FILE="../configs/${DIVISAO}.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERRO: Configuração não encontrada: $CONFIG_FILE"
    exit 1
fi

# Carregar IP do ficheiro de configuração
source "$CONFIG_FILE"

echo "=========================================="
echo "  Deploy para ${DIVISAO}"
echo "=========================================="
echo "IP: ${IP_ADDRESS}"
echo "Hostname: ${HOSTNAME}"
echo ""

# Copiar ficheiros
echo "A copiar ficheiros para pi@${IP_ADDRESS}..."
scp install.sh pi@${IP_ADDRESS}:~/
scp "$CONFIG_FILE" pi@${IP_ADDRESS}:~/config.env

echo ""
echo "✓ Ficheiros copiados com sucesso!"
echo ""
echo "Para instalar, executa:"
echo "  ssh pi@${IP_ADDRESS}"
echo "  bash install.sh"
echo ""
