#!/usr/bin/env bash
# =============================================================================
# 12-openstack-recursos.sh — Recursos base de OpenStack (idempotente)
# -----------------------------------------------------------------------------
#  Crea: flavors, imagen Cirros, keypair, reglas del security group default y
#  una red self-service (VXLAN) + subnet + router. Requiere OpenStack ya
#  desplegado (11-kolla-deploy.sh).
# =============================================================================
set -euo pipefail
export PATH=/opt/kolla-ansible/bin:$PATH
source /etc/kolla/admin-openrc.sh

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }
PUBKEY="${HOME}/.ssh/id_ed25519.pub"

# ---- 1. Flavors --------------------------------------------------------------
log "Creando flavors"
declare -A FLAVORS=(
  [m1.tiny]="--vcpus 1 --ram 512 --disk 1"
  [m1.small]="--vcpus 1 --ram 2048 --disk 10"
  [m1.medium]="--vcpus 2 --ram 4096 --disk 20"
  [gpu.1]="--vcpus 2 --ram 8192 --disk 40"
)
for name in "${!FLAVORS[@]}"; do
  if openstack flavor show "$name" >/dev/null 2>&1; then
    echo "  flavor $name ya existe"
  else
    openstack flavor create $name ${FLAVORS[$name]} --public >/dev/null && echo "  flavor $name creado"
  fi
done

# ---- 2. Imagen Cirros --------------------------------------------------------
log "Creando imagen Cirros (test)"
IMG=cirros-0.6.2
IMG_FILE=/tmp/${IMG}-x86_64-disk.img
if ! openstack image show "$IMG" >/dev/null 2>&1; then
  [ -f "$IMG_FILE" ] || curl -fsSL -o "$IMG_FILE" https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
  openstack image create "$IMG" --file "$IMG_FILE" --disk-format qcow2 --container-format bare --public >/dev/null
  echo "  imagen $IMG creada"
else
  echo "  imagen $IMG ya existe"
fi

# ---- 3. Keypair --------------------------------------------------------------
log "Creando keypair"
if openstack keypair show admin-key >/dev/null 2>&1; then
  echo "  keypair admin-key ya existe"
else
  if [ -f "$PUBKEY" ]; then
    openstack keypair create admin-key --public-key "$PUBKEY" >/dev/null && echo "  keypair admin-key creado"
  else
    echo "  ⚠ no existe $PUBKEY; genera una llave SSH primero"
  fi
fi

# ---- 4. Security group default -------------------------------------------------
log "Reglas del security group default"
SG=$(openstack security group list -f value -c ID -c Name | awk '$2=="default"{print $1}')
for rule in "icmp" "tcp 22" "tcp 80" "tcp 443" "tcp 8000"; do
  proto=${rule%% *}; port=${rule##* }
  if [[ "$proto" == "icmp" ]]; then
    openstack security group rule list "$SG" --protocol icmp -f value 2>/dev/null | grep -q . || \
      openstack security group rule create "$SG" --protocol icmp >/dev/null && echo "  regla icmp añadida"
  else
    openstack security group rule list "$SG" --protocol tcp --dst-port "$port:$port" -f value 2>/dev/null | grep -q . || \
      openstack security group rule create "$SG" --protocol tcp --dst-port "$port" >/dev/null && echo "  regla tcp/$port añadida"
  fi
done

# ---- 5. Red self-service (VXLAN) + subnet + router ----------------------------
log "Creando red self-service (VXLAN)"
NET=selfservice-net; SUBNET=selfservice-subnet; ROUTER=router1
if openstack network show "$NET" >/dev/null 2>&1; then
  echo "  red $NET ya existe"
else
  openstack network create "$NET" >/dev/null && echo "  red $NET creada"
fi
if openstack subnet show "$SUBNET" >/dev/null 2>&1; then
  echo "  subnet $SUBNET ya existe"
else
  openstack subnet create "$SUBNET" --network "$NET" --subnet-range 10.10.10.0/24 --dns-nameserver 8.8.8.8 >/dev/null
  echo "  subnet $SUBNET (10.10.10.0/24) creada"
fi
if openstack router show "$ROUTER" >/dev/null 2>&1; then
  echo "  router $ROUTER ya existe"
else
  openstack router create "$ROUTER" >/dev/null && echo "  router $ROUTER creado"
fi
openstack router add subnet "$ROUTER" "$SUBNET" >/dev/null 2>&1 && echo "  subnet añadida al router"

log "Recursos base completados"
echo "  Flavors: $(openstack flavor list -f value -c Name | tr '\n' ' ')"
echo "  Imágenes: $(openstack image list -f value -c Name | tr '\n' ' ')"
echo "  Redes: $(openstack network list -f value -c Name | tr '\n' ' ')"
echo "  Keypairs: $(openstack keypair list -f value -c Name | tr '\n' ' ')"
