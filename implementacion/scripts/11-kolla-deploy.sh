#!/usr/bin/env bash
# =============================================================================
# 11-kolla-deploy.sh — Despliega OpenStack (deploy + post-deploy)
# -----------------------------------------------------------------------------
#  Requiere: 07-kolla-config.sh + 08-kolla-bootstrap.sh + 09-kolla-hosts.sh.
#  Libera el puerto 5000 (vton-registry de k3s) si choca con Keystone, y luego
#  ejecuta `kolla-ansible deploy` y `post-deploy` (genera admin-openrc.sh).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

export PATH="$KOLLA_VENV/bin:$PATH"
KOLLA_BIN="$KOLLA_VENV/bin/kolla-ansible"
INV="/etc/kolla/multinode"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

# 1) Liberar puerto 5000 (Keystone) si está ocupado por vton-registry (k3s)
log "Verificando puerto 5000 (Keystone)"
if sudo -n ss -tlnp 2>/dev/null | grep -q ':5000 '; then
  echo "  ⚠ Puerto 5000 ocupado. Deteniendo vton-registry (escala a 0 réplicas)..."
  kubectl -n vton scale deployment vton-registry --replicas=0 2>&1 || \
    kubectl -n vton scale statefulset vton-registry --replicas=0 2>&1 || \
    echo "  ⚠ No se pudo escalar vton-registry (verificar recurso)"
  sleep 3
  if sudo -n ss -tlnp 2>/dev/null | grep -q ':5000 '; then
    echo "  ❌ El puerto 5000 sigue ocupado: $(sudo -n ss -tlnp 2>/dev/null | grep ':5000 ')"
    exit 1
  else
    echo "  ✅ Puerto 5000 libre."
  fi
else
  echo "  ✅ Puerto 5000 libre."
fi

# 2) Deploy
log "kolla-ansible deploy (descarga imágenes y arranca OpenStack)"
$KOLLA_BIN deploy -i "$INV" 2>&1 | tee "$LOG_DIR/deploy.log"

# 3) post-deploy (genera /etc/kolla/admin-openrc.sh)
log "kolla-ansible post-deploy"
$KOLLA_BIN post-deploy -i "$INV" 2>&1 | tee "$LOG_DIR/post-deploy.log"

log "Deploy completado. Credenciales: /etc/kolla/admin-openrc.sh"
echo "  Para cargarlas:  source /etc/kolla/admin-openrc.sh"
echo "  Horizon (si está habilitado): http://$KOLLA_VIP/  (ver globals.yml enable_horizon)"
