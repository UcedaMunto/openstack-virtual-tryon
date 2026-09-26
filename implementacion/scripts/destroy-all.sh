#!/usr/bin/env bash
# =============================================================================
# destroy-all.sh — BORRADO TOTAL (OpenStack + Kubernetes k3s + Cinder + configs)
# -----------------------------------------------------------------------------
#  ⚠️  DESTRUCTIVO. Borra: OpenStack (Kolla), Kubernetes (k3s), Cinder (LVM),
#      /etc/kolla, /opt/kolla-ansible e imágenes Docker.
#  NO toca el sistema operativo (Ubuntu) ni los 3 nodos físicos.
#  Requiere confirmación explícita. Después de esto, reconstruir con 00..13.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"
export PATH="$KOLLA_VENV/bin:$PATH"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes"
LOCAL_IP="$(hostname -I | awk '{print $1}')"
log() { echo -e "\n\033[1;34m===> $1\033[0m"; }
is_local() { [[ "$1" == "$LOCAL_IP" || "$1" == "localhost" || "$1" == "127.0.0.1" ]]; }

run() {
  local ip="$1"; shift
  if is_local "$ip"; then bash -c "$*" 2>&1; else ssh $SSH_OPTS "$SSH_USER@$ip" "$*" 2>&1; fi
}

echo "════════════════════════════════════════════════════════════════════════"
echo "  ⚠️  BORRADO TOTAL — esto elimina:"
echo "     • OpenStack (Kolla-Ansible): contenedores, volúmenes, configs"
echo "     • Kubernetes (k3s): clúster completo en los 3 nodos"
echo "     • Cinder: volume group LVM + loopback"
echo "     • /etc/kolla  y  /opt/kolla-ansible  (venv)"
echo "     • Imágenes/contenedores Docker"
echo "  Los 3 nodos físicos (Ubuntu 24.04) NO se tocan."
echo "════════════════════════════════════════════════════════════════════════"
read -rp "  Escribe 'BORRAR' para continuar: " CONFIRM
[[ "$CONFIRM" == "BORRAR" ]] || { echo "  Cancelado."; exit 1; }

# ---- 1. OpenStack (Kolla) ----------------------------------------------------
if [[ -x "$KOLLA_VENV/bin/kolla-ansible" && -f /etc/kolla/multinode ]]; then
  log "1. Destruyendo OpenStack (kolla-ansible destroy)"
  kolla-ansible destroy -i /etc/kolla/multinode --yes-i-really-really-mean-it 2>&1 | tail -15 || \
    echo "  ⚠ destroy devolvió error (revisar); se continúa"
else
  echo "   (kolla-ansible o inventario no presente; se omite)"
fi

# ---- 2. Cinder LVM (storage) -------------------------------------------------
log "2. Limpiando Cinder LVM en $NODE02_NAME ($NODE02_IP)"
run "$NODE02_IP" 'sudo -n vgremove -f cinder-volumes 2>/dev/null || true; for d in $(sudo -n losetup -a 2>/dev/null | grep cinder | cut -d: -f1); do sudo -n losetup -d "$d"; done; sudo -n rm -f /var/lib/cinder/cinder-volumes.img; echo "  cinder limpio"'

# ---- 3. Kubernetes (k3s) -----------------------------------------------------
log "3. Desinstalando k3s (server + agents)"
for pair in "$NODE01_IP:$NODE01_NAME" "$NODE02_IP:$NODE02_NAME" "$NODE03_IP:$NODE03_NAME"; do
  ip="${pair%%:*}"; name="${pair##*:}"
  echo "  --- $name ($ip) ---"
  if is_local "$ip"; then
    sudo -n /usr/local/bin/k3s-uninstall.sh 2>&1 | tail -3 || sudo -n /usr/local/bin/k3s-agent-uninstall.sh 2>&1 | tail -3 || echo "  (k3s ya desinstalado o sin desinstalador)"
  else
    run "$ip" 'sudo -n /usr/local/bin/k3s-uninstall.sh 2>/dev/null || sudo -n /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || echo "  (k3s ya desinstalado o sin desinstalador)"'
  fi
done

# ---- 4. Configs + venv + docker ----------------------------------------------
log "4. Limpiando /etc/kolla y /opt/kolla-ansible"
sudo -n rm -rf /etc/kolla /opt/kolla-ansible

log "5. Limpieza Docker (contenedores/imágenes) en los 3 nodos"
for ip in $ALL_NODES; do
  echo "  --- $ip ---"
  run "$ip" 'sudo -n docker system prune -af --volumes 2>&1 | tail -2 || true'
done

log "✔ Borrado completado. Reconstruir desde cero: bash scripts/run-all.sh + 10/11/12/13"
