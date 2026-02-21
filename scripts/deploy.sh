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

# Gerar snippet de configuração para o Home Assistant
HA_SNIPPETS_DIR="../ha-snippets"
mkdir -p "$HA_SNIPPETS_DIR"

# Nome legível da divisão (capitalizar primeira letra, compatível com bash 3+)
ROOM_LABEL=$(echo "$DIVISAO" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')

cat > "${HA_SNIPPETS_DIR}/${DIVISAO}.yaml" << EOF
# ============================================================
# Home Assistant — Dashboard card: ${ROOM_LABEL}
# Gerado por: ./deploy.sh ${DIVISAO}
# Data: $(date '+%Y-%m-%d')
# ============================================================
# Requer os scripts bt_pair e bt_unpair em configuration.yaml
# (ver ha-snippets/configuration.yaml — adicionar uma única vez).
# Cole este YAML no editor Lovelace (Add Card → Manual).
# ============================================================

type: grid
cards:
  - type: heading
    icon: mdi:cast-audio
    heading: ${ROOM_LABEL}
    heading_style: title
  - type: tile
    entity: input_boolean.bt_${DIVISAO}
    name: Controlador
    icon: mdi:speaker-bluetooth
    vertical: false
    tap_action:
      action: none
    icon_tap_action:
      action: none
    features_position: bottom
    grid_options:
      columns: full
  - type: tile
    entity: input_boolean.bt_${DIVISAO}
    name: Emparelhar
    icon: mdi:bluetooth-connect
    color: blue
    show_entity_picture: false
    hide_state: true
    vertical: false
    tap_action:
      action: call-service
      service: script.bt_pair
      data:
        divisao: ${DIVISAO}
    icon_tap_action:
      action: none
    features_position: bottom
  - type: tile
    entity: input_boolean.bt_${DIVISAO}
    name: Esquecer
    icon: mdi:bluetooth-off
    color: blue
    show_entity_picture: false
    hide_state: true
    vertical: false
    tap_action:
      action: call-service
      service: script.bt_unpair
      data:
        divisao: ${DIVISAO}
    icon_tap_action:
      action: none
    features_position: bottom
  - type: custom:mini-media-player
    entity: media_player.${PLAYER_NAME//-/_}
    group: false
    volume_stateless: false
    artwork: full-cover-fit
    source: icon
    sound_mode: full
    info: short
EOF

echo "✓ Snippet HA gerado: ${HA_SNIPPETS_DIR}/${DIVISAO}.yaml"
echo ""
echo "Para instalar, executa:"
echo "  ssh ${USER}@${IP_ADDRESS}"
echo "  bash install.sh"
echo ""
