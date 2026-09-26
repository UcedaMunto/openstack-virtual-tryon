#!/usr/bin/env bash
# gen-cloud-init.sh: genera <nodo>-user-data y <nodo>-meta-data en
# kubernetes/cloud-init a partir de la plantilla cloud-init/user-data.tmpl,
# sustituyendo __HOSTNAME__ por el nombre del nodo y __SSH_PUBLIC_KEY__ por
# el contenido real de una clave publica SSH.
#
# Asi la clave vive solo en el archivo .pub (fuente de verdad) y la
# estructura comun del cloud-init vive solo en user-data.tmpl, en vez de
# mantener 6 copias casi identicas a mano (k8-master, k8-worker1-4,
# ceph-admin).
#
# Uso:
#   scripts/gen-cloud-init.sh [ruta_clave_publica] [nodo ...]
#
# Ejemplos:
#   scripts/gen-cloud-init.sh
#   scripts/gen-cloud-init.sh ~/.ssh/id_ed25519.pub
#   scripts/gen-cloud-init.sh ~/.ssh/id_ed25519.pub k8-worker4

set -euo pipefail

# --no-iso: no regenera los seed.iso (solo user-data y meta-data)
GEN_ISO=1
if [[ "${1:-}" == "--no-iso" ]]; then
    GEN_ISO=0
    shift
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CLOUD_INIT_DIR="$PROJECT_DIR/cloud-init"
TEMPLATE="$CLOUD_INIT_DIR/user-data.tmpl"

PUBKEY_PATH="${1:-$HOME/.ssh/id_ed25519.pub}"
[[ $# -gt 0 ]] && shift

# Nodos del laboratorio si no se pasan explicitamente por argumento
NODES=("$@")
if [[ "${#NODES[@]}" -eq 0 ]]; then
    NODES=(k8-master k8-worker1 k8-worker2 k8-worker3 k8-worker4 ceph-admin)
fi

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

for NODE in "${NODES[@]}"; do
    USER_DATA="$CLOUD_INIT_DIR/${NODE}-user-data"
    META_DATA="$CLOUD_INIT_DIR/${NODE}-meta-data"

    sed -e "s|__HOSTNAME__|$NODE|g" -e "s|__SSH_PUBLIC_KEY__|$ESCAPED_KEY|" \
        "$TEMPLATE" > "$USER_DATA"

    cat > "$META_DATA" <<EOF
instance-id: $NODE
local-hostname: $NODE
EOF

    echo "Generado: $USER_DATA"
    echo "Generado: $META_DATA (clave desde $PUBKEY_PATH)"

    # Empaqueta user-data + meta-data en un seed.iso que cloud-init monta en el primer arranque
    if [[ "$GEN_ISO" -eq 1 ]]; then
        SEED_ISO="$CLOUD_INIT_DIR/${NODE}-seed.iso"
        if command -v cloud-localds >/dev/null 2>&1; then
            cloud-localds "$SEED_ISO" "$USER_DATA" "$META_DATA"
            echo "Generado: $SEED_ISO"
        else
            echo "AVISO: cloud-localds no encontrado; no se genero $SEED_ISO (instalar cloud-image-utils)" >&2
        fi
    fi
done
