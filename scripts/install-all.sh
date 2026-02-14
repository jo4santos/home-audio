#!/bin/bash

# Script para instalar em todas as divisões automaticamente
# Uso: ./install-all.sh

set -e

DIVISIONS=(
    "escritorio:192.168.30.7"
    "suite:192.168.30.2"
    "cozinha:192.168.30.3"
    "sala:192.168.30.4"
    "wcsuite:192.168.30.5"
    "quartocriancas:192.168.30.6"
    "quartodesporto:192.168.30.1"
)

echo "=========================================="
echo "  Instalação Automática - Todas Divisões"
echo "=========================================="
echo ""
echo "Divisões a instalar:"
for div in "${DIVISIONS[@]}"; do
    NAME="${div%%:*}"
    IP="${div##*:}"
    echo "  - $NAME ($IP)"
done
echo ""
read -p "Continuar com a instalação? (s/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Instalação cancelada."
    exit 1
fi

echo ""
echo "NOTA: Este script vai:"
echo "  1. Copiar ficheiros para cada RPi"
echo "  2. Executar instalação remotamente"
echo "  3. O emparelhamento Bluetooth tem de ser feito manualmente depois"
echo ""
read -p "Pressiona ENTER para continuar..."
echo ""

SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_DIVISIONS=()

for div in "${DIVISIONS[@]}"; do
    NAME="${div%%:*}"
    IP="${div##*:}"

    echo ""
    echo "=========================================="
    echo "  Instalando: $NAME ($IP)"
    echo "=========================================="

    # Verificar se RPi está acessível
    if ! ping -c 1 -W 2 "$IP" > /dev/null 2>&1; then
        echo "✗ ERRO: $NAME não responde (IP: $IP)"
        echo "  Verifica se o RPi está ligado e conectado à rede"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_DIVISIONS+=("$NAME ($IP) - não responde")
        continue
    fi

    # Deploy ficheiros
    echo "→ A copiar ficheiros..."
    if ./deploy.sh "$NAME" > /dev/null 2>&1; then
        echo "✓ Ficheiros copiados"
    else
        echo "✗ ERRO ao copiar ficheiros para $NAME"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_DIVISIONS+=("$NAME ($IP) - erro ao copiar ficheiros")
        continue
    fi

    # Instalar remotamente
    echo "→ A executar instalação (demora 5-10 minutos)..."
    if ssh -o ConnectTimeout=10 pi@"$IP" "bash install.sh" > /tmp/install-${NAME}.log 2>&1; then
        echo "✓ Instalação concluída"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "✗ ERRO durante instalação"
        echo "  Ver log: /tmp/install-${NAME}.log"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_DIVISIONS+=("$NAME ($IP) - erro durante instalação")
    fi
done

echo ""
echo "=========================================="
echo "  Resumo da Instalação"
echo "=========================================="
echo "Sucesso: $SUCCESS_COUNT"
echo "Falhas:  $FAILED_COUNT"
echo ""

if [ $FAILED_COUNT -gt 0 ]; then
    echo "Divisões com falhas:"
    for failed in "${FAILED_DIVISIONS[@]}"; do
        echo "  ✗ $failed"
    done
    echo ""
fi

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "=========================================="
    echo "  PRÓXIMOS PASSOS"
    echo "=========================================="
    echo ""
    echo "1. Emparelhar Bluetooth em cada RPi:"
    echo "   Para cada divisão instalada com sucesso, executar:"
    echo ""

    for div in "${DIVISIONS[@]}"; do
        NAME="${div%%:*}"
        IP="${div##*:}"

        # Verificar se esta divisão foi instalada com sucesso
        SKIP=false
        for failed in "${FAILED_DIVISIONS[@]}"; do
            if [[ "$failed" == "$NAME"* ]]; then
                SKIP=true
                break
            fi
        done

        if [ "$SKIP" = false ]; then
            echo "   ssh pi@$IP"
            echo "   sudo bluetoothctl"
            echo "   # power on → agent on → scan on → pair → trust → connect"
            echo ""
        fi
    done

    echo "2. Verificar no Home Assistant:"
    echo "   http://192.168.2.100:8123"
    echo "   Music Assistant → Settings → Players"
    echo ""
fi

echo "=========================================="
echo ""
