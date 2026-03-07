#!/bin/bash
# Atualiza a chave SSH do Home Assistant em todos os RPis e no install.sh
# Uso: ./update-ha-key.sh "ssh-ed25519 AAAA... root@homeassistant"
#
# Obter a chave actual do HA: Developer Tools → Actions → shell_command.get_ssh_pubkey

set -e

NEW_KEY="${1}"

if [ -z "$NEW_KEY" ]; then
    echo "Uso: $0 \"ssh-ed25519 AAAA... root@homeassistant\""
    echo ""
    echo "Obter a chave actual do HA:"
    echo "  Developer Tools → Actions → shell_command.get_ssh_pubkey"
    exit 1
fi

if [[ "$NEW_KEY" != ssh-ed25519\ * ]]; then
    echo "ERRO: chave inválida. Deve começar com 'ssh-ed25519'"
    exit 1
fi

RPIS=(
    "relvasantos@192.168.30.1"
    "relvasantos@192.168.30.2"
    "relvasantos@192.168.30.3"
    "relvasantos@192.168.30.4"
    "relvasantos@192.168.30.5"
    "relvasantos@192.168.30.6"
    "relvasantos@192.168.30.7"
)

echo "Nova chave: ${NEW_KEY:0:40}..."
echo ""

# Atualizar authorized_keys em cada RPi
for target in "${RPIS[@]}"; do
    echo -n "$target: "
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$target" bash << EOF
# Remover qualquer chave root@homeassistant existente e adicionar a nova
sed -i '/root@homeassistant$/d' ~/.ssh/authorized_keys
echo "${NEW_KEY}" >> ~/.ssh/authorized_keys
echo OK
EOF
done

echo ""

# Atualizar HA_PUBKEY_CONTAINER no install.sh
INSTALL_SH="$(dirname "$0")/install.sh"
OLD_LINE=$(grep 'HA_PUBKEY_CONTAINER=' "$INSTALL_SH")
NEW_LINE="HA_PUBKEY_CONTAINER=\"${NEW_KEY}\""

if [ "$OLD_LINE" = "$NEW_LINE" ]; then
    echo "install.sh já tem a chave correcta — sem alterações."
else
    sed -i.bak "s|HA_PUBKEY_CONTAINER=.*|HA_PUBKEY_CONTAINER=\"${NEW_KEY}\"|" "$INSTALL_SH"
    rm -f "${INSTALL_SH}.bak"
    echo "✓ install.sh atualizado"
fi

echo ""
echo "Feito. Faz commit das alterações ao install.sh:"
echo "  git add scripts/install.sh && git commit -m 'Update HA SSH public key'"
