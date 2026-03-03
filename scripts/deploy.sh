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

# Gerar snippet de configuração para o Home Assistant
HA_SNIPPETS_DIR="../ha-snippets"
mkdir -p "$HA_SNIPPETS_DIR"

# Nome legível da divisão
case "$DIVISAO" in
  escritorio)    ROOM_LABEL="Escritório" ;;
  suite)         ROOM_LABEL="Suite" ;;
  cozinha)       ROOM_LABEL="Cozinha" ;;
  sala)          ROOM_LABEL="Sala" ;;
  wcsuite)       ROOM_LABEL="WC Suite" ;;
  quartocriancas) ROOM_LABEL="Quarto Crianças" ;;
  quartodesporto) ROOM_LABEL="Quarto Desporto" ;;
  *)             ROOM_LABEL=$(echo "$DIVISAO" | awk '{print toupper(substr($0,1,1)) substr($0,2)}') ;;
esac

cat > "${HA_SNIPPETS_DIR}/${DIVISAO}.yaml" << EOF
type: grid
cards:
  - type: heading
    icon: mdi:cast-audio
    heading: ${ROOM_LABEL}
    heading_style: title
  - type: tile
    entity: ${SWITCH_ENTITY}
    name: Controlador
    icon: mdi:speaker-bluetooth
    vertical: false
    tap_action:
      action: call-service
      service: switch.turn_on
      target:
        entity_id: ${SWITCH_ENTITY}
    icon_tap_action:
      action: none
    features_position: bottom
    visibility:
      - condition: state
        entity: ${SWITCH_ENTITY}
        state: "off"
  - type: tile
    entity: ${SWITCH_ENTITY}
    name: Controlador
    icon: mdi:speaker-bluetooth
    vertical: false
    tap_action:
      action: call-service
      service: switch.turn_off
      target:
        entity_id: ${SWITCH_ENTITY}
      confirmation:
        text: "Confirmar: desligar o controlador?"
    icon_tap_action:
      action: none
    features_position: bottom
    visibility:
      - condition: state
        entity: ${SWITCH_ENTITY}
        state: "on"
  - type: custom:bubble-card
    card_type: media-player
    entity: media_player.colunas_${DIVISAO}
    name: ${ROOM_LABEL}
    icon: mdi:cast-audio
    cover_background: true
    button_action:
      tap_action:
        action: more-info
    sub_button:
      main:
        - entity: ${SWITCH_ENTITY}
          icon: mdi:raspberry-pi
          show_icon: true
          show_state: false
          tap_action:
            action: toggle
        - entity: binary_sensor.bt_${DIVISAO}
          icon: mdi:bluetooth-off
          show_icon: true
          show_state: false
          tap_action:
            action: call-service
            service: script.bt_pair_${DIVISAO}
          visibility:
            - condition: state
              entity: binary_sensor.bt_${DIVISAO}
              state: "off"
            - condition: state
              entity: script.bt_pair_${DIVISAO}
              state: "off"
        - entity: script.bt_pair_${DIVISAO}
          icon: mdi:bluetooth-connect
          show_icon: true
          show_state: false
          tap_action:
            action: none
          visibility:
            - condition: state
              entity: script.bt_pair_${DIVISAO}
              state: "on"
        - entity: binary_sensor.bt_${DIVISAO}
          icon: mdi:bluetooth
          show_icon: true
          show_state: false
          tap_action:
            action: call-service
            service: script.bt_unpair_${DIVISAO}
            confirmation:
              text: "Confirmar: esquecer o amplificador Bluetooth?"
          visibility:
            - condition: state
              entity: binary_sensor.bt_${DIVISAO}
              state: "on"
            - condition: state
              entity: script.bt_pair_${DIVISAO}
              state: "off"
            - condition: state
              entity: script.bt_unpair_${DIVISAO}
              state: "off"
        - entity: script.bt_unpair_${DIVISAO}
          icon: mdi:bluetooth-off
          show_icon: true
          show_state: false
          tap_action:
            action: none
          visibility:
            - condition: state
              entity: script.bt_unpair_${DIVISAO}
              state: "on"
    visibility:
      - condition: state
        entity: ${SWITCH_ENTITY}
        state: "on"
EOF

echo "✓ Snippet HA gerado: ${HA_SNIPPETS_DIR}/${DIVISAO}.yaml"
echo ""
echo "Para instalar, executa:"
echo "  ssh ${USER}@${IP_ADDRESS}"
echo "  bash install.sh"
echo ""
