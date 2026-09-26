#!/usr/bin/env bash
# gen-user-data.sh: genera cloud-init/<nodo>/user-data a partir de
# cloud-init/<nodo>/user-data.tmpl, sustituyendo el marcador
# __SSH_PUBLIC_KEY__ por el contenido real de una clave publica SSH.
#
# Asi la clave vive solo en el archivo .pub (fuente de verdad) y no hay que
# pegarla a mano dentro de cada user-data del laboratorio OpenStack-Ansible.
#
# Uso:
#   scripts/gen-user-data.sh <nodo> [ruta_clave_publica]
#
# Ejemplo:
#   scripts/gen-user-data.sh os-controller ~/.ssh/openstack_lab.pub

set -euo pipefail

NODE="${1:?Uso: $0 <nodo> [ruta_clave_publica]}"
PUBKEY_PATH="${2:-$HOME/.ssh/openstack_lab.pub}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
NODE_DIR="$REPO_DIR/cloud-init/$NODE"
TEMPLATE="$NODE_DIR/user-data.tmpl"
OUTPUT="$NODE_DIR/user-data"

if [[ ! -f "$TEMPLATE" ]]; then
    echo "No existe la plantilla: $TEMPLATE" >&2
    exit 1
fi

if [[ ! -f "$PUBKEY_PATH" ]]; then
    echo "No existe la clave publica: $PUBKEY_PATH" >&2
    exit 1
fi

PUBKEY_CONTENT="$(cat "$PUBKEY_PATH")"

# Escapa '&', '/' y '\' para que sed no los interprete al reemplazar
ESCAPED_KEY="$(printf '%s' "$PUBKEY_CONTENT" | sed -e 's/[&/\]/\\&/g')"

sed "s|__SSH_PUBLIC_KEY__|$ESCAPED_KEY|" "$TEMPLATE" > "$OUTPUT"

echo "Generado: $OUTPUT (clave desde $PUBKEY_PATH)"
