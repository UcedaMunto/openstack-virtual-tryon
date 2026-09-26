#!/bin/bash
# setup-openstack-resources.sh
# Crea los recursos necesarios en OpenStack para lanzar VMs
# Ejecutar DENTRO del controller: ssh uceda@203.0.113.239
# Prerequisito: haber ejecutado fix-openstack-bugs.sh primero

set -e

export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=icc115
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

echo "======================================================"
echo "  Setup de recursos OpenStack — ICC115 Lab"
echo "======================================================"

# ── FLAVORS ──────────────────────────────────────────────
echo ""
echo "[1/6] Creando flavors..."
openstack flavor create --id 1 --ram 512  --disk 1  --vcpus 1 m1.tiny   2>/dev/null || echo "  m1.tiny ya existe"
openstack flavor create --id 2 --ram 2048 --disk 20 --vcpus 1 m1.small  2>/dev/null || echo "  m1.small ya existe"
openstack flavor create --id 3 --ram 4096 --disk 40 --vcpus 2 m1.medium 2>/dev/null || echo "  m1.medium ya existe"
openstack flavor list
echo "  ✅ Flavors OK"

# ── RED PROVIDER (flat) ───────────────────────────────────
echo ""
echo "[2/6] Creando red provider (flat)..."
if ! openstack network show provider-net &>/dev/null; then
  openstack network create \
    --share \
    --external \
    --provider-physical-network provider \
    --provider-network-type flat \
    provider-net

  openstack subnet create \
    --network provider-net \
    --allocation-pool start=192.168.122.100,end=192.168.122.200 \
    --dns-nameserver 8.8.8.8 \
    --gateway 192.168.122.1 \
    --subnet-range 192.168.122.0/24 \
    provider-subnet
  echo "  ✅ Red provider creada"
else
  echo "  provider-net ya existe"
fi

# ── RED SELF-SERVICE (VXLAN) ──────────────────────────────
echo ""
echo "[3/6] Creando red self-service + router..."
if ! openstack network show selfservice-net &>/dev/null; then
  openstack network create selfservice-net

  openstack subnet create \
    --network selfservice-net \
    --dns-nameserver 8.8.8.8 \
    --gateway 10.10.10.1 \
    --subnet-range 10.10.10.0/24 \
    selfservice-subnet

  openstack router create router1
  openstack router set router1 --external-gateway provider-net
  openstack router add subnet router1 selfservice-subnet
  echo "  ✅ Red self-service + router creados"
else
  echo "  selfservice-net ya existe"
fi

# ── SECURITY GROUPS ───────────────────────────────────────
echo ""
echo "[4/6] Configurando security group default..."
SG_ID=$(openstack security group list --project admin -f value -c ID 2>/dev/null | head -1)
if [ -n "$SG_ID" ]; then
  openstack security group rule create --proto icmp $SG_ID 2>/dev/null || echo "  regla icmp ya existe"
  openstack security group rule create --proto tcp --dst-port 22 $SG_ID 2>/dev/null || echo "  regla SSH ya existe"
  openstack security group rule create --proto tcp --dst-port 80 $SG_ID 2>/dev/null || echo "  regla HTTP ya existe"
  echo "  ✅ Security group configurado"
else
  echo "  ⚠️ No se encontró security group default para admin"
fi

# ── KEYPAIR ───────────────────────────────────────────────
echo ""
echo "[5/6] Creando keypair..."
if ! openstack keypair show mykey &>/dev/null; then
  if [ -f ~/.ssh/id_rsa.pub ]; then
    openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
    echo "  ✅ Keypair 'mykey' creado desde ~/.ssh/id_rsa.pub"
  else
    openstack keypair create mykey > ~/mykey.pem
    chmod 600 ~/mykey.pem
    echo "  ✅ Keypair 'mykey' generado — clave privada en ~/mykey.pem"
  fi
else
  echo "  keypair mykey ya existe"
fi

# ── LANZAR VM DE PRUEBA ───────────────────────────────────
echo ""
echo "[6/6] Lanzando VM de prueba (cirros en self-service)..."
NET_ID=$(openstack network show selfservice-net -f value -c id)
CIRROS_ID=$(openstack image list -f value -c ID | head -1)

if ! openstack server show test-vm1 &>/dev/null; then
  openstack server create \
    --flavor m1.tiny \
    --image "$CIRROS_ID" \
    --nic net-id="$NET_ID" \
    --security-group default \
    --key-name mykey \
    test-vm1
  echo "  ✅ VM test-vm1 creada — espera 30s para que arranque"
else
  echo "  test-vm1 ya existe"
fi

echo ""
sleep 10
openstack server show test-vm1 | grep -E "status|OS-EXT-STS|addresses|host"

echo ""
echo "======================================================"
echo "  Recursos creados. Para ver log de la VM:"
echo "    openstack console log show test-vm1"
echo "  Para consola VNC:"
echo "    openstack console url show test-vm1"
echo "  Para asignar floating IP:"
echo "    FIP=\$(openstack floating ip create provider-net -f value -c floating_ip_address)"
echo "    openstack server add floating ip test-vm1 \$FIP"
echo "    ssh -i ~/mykey.pem cirros@\$FIP   # pass: gocubsgo"
echo "======================================================"
