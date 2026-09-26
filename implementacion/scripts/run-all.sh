#!/usr/bin/env bash
# =============================================================================
# run-all.sh — Ejecuta TODA la secuencia de instalación en orden.
# -----------------------------------------------------------------------------
#  Uso:  bash implementacion/scripts/run-all.sh
#  Ejecuta: 00 → 01 → 02 → 03 → 04 → 05 → 06
#  Log:    implementacion/logs/run-all-<timestamp>.log
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/run-all-$(date +%Y%m%d-%H%M%S).log"

echo "==> Ejecutando secuencia completa. Log: $LOG"
{
  for s in 00-bootstrap 01-base 02-docker 03-kolla-ansible 04-openstack-cli 05-k8s-tools 06-nvidia-runtime 07-kolla-config 08-kolla-bootstrap 09-kolla-hosts; do
    echo; echo "############ $s ############"
    bash "$SCRIPT_DIR/$s.sh"
  done
} 2>&1 | tee "$LOG"

echo
echo "==> Secuencia completada. Ver log: $LOG"
