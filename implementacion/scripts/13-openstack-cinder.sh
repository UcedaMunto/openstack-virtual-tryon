#!/usr/bin/env bash
# =============================================================================
# 13-openstack-cinder.sh — Habilita Cinder (almacenamiento en bloque) con LVM
# -----------------------------------------------------------------------------
#  Crea un volume group LVM sobre un archivo loopback en el nodo de storage,
#  habilita cinder en globals.yml y re-despliega solo cinder.
#  Requiere: 11-kolla-deploy.sh (OpenStack desplegado).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"
export PATH="$KOLLA_VENV/bin:$PATH"

KOLLA_BIN="$KOLLA_VENV/bin/kolla-ansible"
INV="/etc/kolla/multinode"
VG="cinder-volumes"
IMG_FILE="/var/lib/cinder/cinder-volumes.img"
SIZE_MB=30720   # 30 GB

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

# ---- 1. Crear loopback + PV + VG en el nodo de storage (NODE02) ---------------
log "Creando LVM ($VG) en el storage node ($NODE02_NAME)"
block=$(cat <<EOF
set -e
if sudo -n vgs "$VG" >/dev/null 2>&1; then
  echo "  VG $VG ya existe"
else
  sudo -n mkdir -p /var/lib/cinder
  [ -f "$IMG_FILE" ] || sudo -n dd if=/dev/zero of="$IMG_FILE" bs=1M count=$SIZE_MB status=none
  LOOP=\$(sudo -n losetup -f)
  sudo -n losetup "\$LOOP" "$IMG_FILE"
  sudo -n pvcreate "\$LOOP" >/dev/null
  sudo -n vgcreate "$VG" "\$LOOP" >/dev/null
  echo "  VG $VG creado sobre \$LOOP ($SIZE_MB MB)"
fi
sudo -n vgs "$VG"
EOF
)
if [[ "$NODE02_IP" == "$(hostname -I | awk '{print $1}')" ]]; then
  printf '%s' "$block" | bash -s
else
  printf '%s' "$block" | ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER@$NODE02_IP" 'bash -s'
fi

# ---- 2. Habilitar cinder en globals.yml --------------------------------------
log "Habilitando Cinder en /etc/kolla/globals.yml"
if grep -q '^enable_cinder:' /etc/kolla/globals.yml; then
  echo "  cinder ya habilitado en globals.yml"
else
  cat >> /etc/kolla/globals.yml <<'EOF'

# --- Cinder (almacenamiento en bloque) ---
enable_cinder: "yes"
enable_cinder_backend_lvm: "yes"
cinder_volume_group: "cinder-volumes"
EOF
  echo "  enable_cinder añadido"
fi

# ---- 3. Re-deploy (deploy COMPLETO: sincroniza proxysql + despliega cinder) ---
#  NOTA: usar `-t cinder` falla con "ProxySQL Access denied" (E14) porque no
#  corre el rol proxysql. Por eso se usa el deploy completo (idempotente).
log "Re-desplegando (deploy completo: proxysql + cinder)"
$KOLLA_BIN deploy -i "$INV" 2>&1 | tee "$SCRIPT_DIR/../logs/cinder-deploy.log" | tail -20

log "Verificación de Cinder (crear + eliminar volumen de prueba)"
source /etc/kolla/admin-openrc.sh
openstack volume create --size 1 cinder-test-vol >/dev/null 2>&1
sleep 5
echo "  Estado del volumen de prueba: $(openstack volume show cinder-test-vol -c status -f value 2>/dev/null)"
openstack volume delete cinder-test-vol >/dev/null 2>&1 || true
echo
openstack volume service list
