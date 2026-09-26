#!/usr/bin/env bash
# =============================================================================
# 08-kolla-bootstrap.sh — bootstrap-servers + prechecks de Kolla-Ansible
# -----------------------------------------------------------------------------
#  Requiere: 07-kolla-config.sh (inventario + globals.yml + passwords).
#  Prepara los nodos (deps de Docker SDK, etc.) y valida prerrequisitos.
#  NO despliega OpenStack todavía (eso es el paso siguiente: deploy).
#  Idempotente.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

KOLLA_BIN="$KOLLA_VENV/bin/kolla-ansible"
INV="/etc/kolla/multinode"

# kolla-ansible invoca `ansible-playbook` por PATH; debe usar el del venv.
export PATH="$KOLLA_VENV/bin:$PATH"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

log "kolla-ansible bootstrap-servers"
$KOLLA_BIN bootstrap-servers -i "$INV" 2>&1 | tee "$LOG_DIR/bootstrap-servers.log"

log "kolla-ansible prechecks"
$KOLLA_BIN prechecks -i "$INV" 2>&1 | tee "$LOG_DIR/prechecks.log"

log "Bootstrap + prechecks completados (ver logs/ y errores en docs/ERRORES-Y-PERCANCES.md)"
