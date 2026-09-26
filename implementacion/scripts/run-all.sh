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
  # ---- 00: sudo NOPASSWD + verificación -------------------------------------
  echo; echo "############ 00-bootstrap ############"
  bash "$SCRIPT_DIR/00-bootstrap.sh"

  # ---- 01: paquetes base + chrony -------------------------------------------
  echo; echo "############ 01-base ############"
  bash "$SCRIPT_DIR/01-base.sh"

  # ---- 02: Docker CE + Compose + containerd ---------------------------------
  echo; echo "############ 02-docker ############"
  bash "$SCRIPT_DIR/02-docker.sh"

  # ---- 03: Kolla-Ansible (venv) [control] -----------------------------------
  echo; echo "############ 03-kolla-ansible ############"
  bash "$SCRIPT_DIR/03-kolla-ansible.sh"

  # ---- 04: openstack CLI [control] ------------------------------------------
  echo; echo "############ 04-openstack-cli ############"
  bash "$SCRIPT_DIR/04-openstack-cli.sh"

  # ---- 05: kubectl + helm [todos] -------------------------------------------
  echo; echo "############ 05-k8s-tools ############"
  bash "$SCRIPT_DIR/05-k8s-tools.sh"

  # ---- 06: nvidia-container-toolkit [GPU] -----------------------------------
  echo; echo "############ 06-nvidia-runtime ############"
  bash "$SCRIPT_DIR/06-nvidia-runtime.sh"

  # ---- 07: inventario Kolla + globals + passwords ---------------------------
  echo; echo "############ 07-kolla-config ############"
  bash "$SCRIPT_DIR/07-kolla-config.sh"

  # ---- 08: bootstrap-servers + prechecks ------------------------------------
  echo; echo "############ 08-kolla-bootstrap ############"
  bash "$SCRIPT_DIR/08-kolla-bootstrap.sh"

  # ---- 09: /etc/hosts único + avahi (mask) ----------------------------------
  echo; echo "############ 09-kolla-hosts ############"
  bash "$SCRIPT_DIR/09-kolla-hosts.sh"
} 2>&1 | tee "$LOG"

echo
echo "==> Secuencia completada. Ver log: $LOG"
