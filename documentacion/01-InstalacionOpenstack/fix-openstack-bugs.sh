#!/bin/bash
# fix-openstack-bugs.sh
# Aplica los fixes críticos antes de crear VMs en este laboratorio OpenStack
# Ejecutar desde el host local (ThinkPad) — se conecta por SSH a ambos nodos
# Uso: bash fix-openstack-bugs.sh
# Passwords: VMs=asdfghjkl | OpenStack admin=icc115

set -e

CONTROLLER="uceda@203.0.113.239"
COMPUTE="uceda@203.0.113.240"
VM_PASS="asdfghjkl"

echo "======================================================"
echo "  Fix OpenStack Lab — ICC115"
echo "======================================================"

# ── FIX 1: my_ip incorrecto en compute1 ──────────────────
echo ""
echo "[1/5] Corrigiendo my_ip en compute1 (10.0.0.31 → 10.0.0.10)..."
ssh -o StrictHostKeyChecking=no "$COMPUTE" "
  echo '$VM_PASS' | sudo -S sed -i 's/^my_ip = 10.0.0.31/my_ip = 10.0.0.10/' /etc/nova/nova.conf
  grep 'my_ip' /etc/nova/nova.conf
"
echo "  ✅ my_ip corregido"

# ── FIX 2: virt_type = kvm en compute1 ───────────────────
echo ""
echo "[2/5] Configurando virt_type=kvm en compute1..."
ssh -o StrictHostKeyChecking=no "$COMPUTE" "
  echo '$VM_PASS' | sudo -S bash -c \"
    if ! grep -q 'virt_type' /etc/nova/nova.conf; then
      sed -i '/^\[libvirt\]/a virt_type = kvm\ncpu_mode = host-passthrough' /etc/nova/nova.conf
      echo 'virt_type añadido'
    else
      echo 'virt_type ya existe'
    fi
  \"
"
echo "  ✅ virt_type configurado"

# ── FIX 3: br-provider y br-int/br-tun en controller ─────
echo ""
echo "[3/5] Arreglando OVS br-provider + br-int/br-tun en CONTROLLER..."
ssh -o StrictHostKeyChecking=no "$CONTROLLER" "
  echo '$VM_PASS' | sudo -S bash -c '
    # Quitar IP duplicada del br-provider
    ip addr del 192.168.122.10/24 dev br-provider 2>/dev/null && echo \"IP quitada de br-provider\" || echo \"IP no estaba o ya quitada\"
    # Desconectar enp8s0 de Linux bridge si está
    ip link set enp8s0 nomaster 2>/dev/null || true
    # Limpiar puerto OVS y re-agregar
    ovs-vsctl del-port br-provider enp8s0 2>/dev/null || true
    ovs-vsctl add-port br-provider enp8s0 2>/dev/null && echo \"enp8s0 re-agregado a OVS br-provider\" || echo \"error al agregar enp8s0\"
    # Levantar bridges de integración
    ip link set br-int up && echo \"br-int UP\" || true
    ip link set br-tun up && echo \"br-tun UP\" || true
    # Reiniciar agente OVS
    systemctl restart neutron-openvswitch-agent
    echo \"neutron-openvswitch-agent reiniciado\"
  '
"
echo "  ✅ Controller OVS arreglado"

# ── FIX 4: br-provider y br-int/br-tun en compute1 ───────
echo ""
echo "[4/5] Arreglando OVS br-provider + br-int/br-tun en COMPUTE1..."
ssh -o StrictHostKeyChecking=no "$COMPUTE" "
  echo '$VM_PASS' | sudo -S bash -c '
    ip addr del 192.168.122.10/24 dev br-provider 2>/dev/null && echo \"IP quitada de br-provider\" || echo \"IP no estaba o ya quitada\"
    ip link set enp8s0 nomaster 2>/dev/null || true
    ovs-vsctl del-port br-provider enp8s0 2>/dev/null || true
    ovs-vsctl add-port br-provider enp8s0 2>/dev/null && echo \"enp8s0 re-agregado a OVS br-provider\" || echo \"error al agregar enp8s0\"
    ip link set br-int up && echo \"br-int UP\" || true
    ip link set br-tun up && echo \"br-tun UP\" || true
    systemctl restart neutron-openvswitch-agent
    echo \"neutron-openvswitch-agent reiniciado\"
  '
"
echo "  ✅ Compute1 OVS arreglado"

# ── FIX 5: Reiniciar nova-compute para aplicar todos los cambios ──
echo ""
echo "[5/5] Reiniciando nova-compute en compute1..."
ssh -o StrictHostKeyChecking=no "$COMPUTE" "
  echo '$VM_PASS' | sudo -S systemctl restart nova-compute
  sleep 5
  systemctl is-active nova-compute
"
echo "  ✅ nova-compute reiniciado"

# ── VERIFICACIÓN FINAL ────────────────────────────────────
echo ""
echo "======================================================"
echo "  Verificación final vía OpenStack CLI"
echo "======================================================"
ssh -o StrictHostKeyChecking=no "$CONTROLLER" "
  export OS_PROJECT_DOMAIN_NAME=Default
  export OS_USER_DOMAIN_NAME=Default
  export OS_PROJECT_NAME=admin
  export OS_USERNAME=admin
  export OS_PASSWORD=icc115
  export OS_AUTH_URL=http://controller:5000/v3
  export OS_IDENTITY_API_VERSION=3

  echo '--- Compute services ---'
  openstack compute service list
  echo '--- Network agents ---'
  openstack network agent list
  echo '--- Hypervisor ---'
  openstack hypervisor show compute1 | grep -E 'host_ip|state|hypervisor_type'
  echo '--- OVS controller ---'
  echo icc115 | sudo -S ovs-vsctl show 2>/dev/null | head -30 || true
"

echo ""
echo "======================================================"
echo "  Todos los fixes aplicados. Revisa la salida arriba."
echo "  Siguiente paso: crear flavors, redes y keypairs."
echo "  Ver /home/uceda/Documents/InstalacionOpenstack/README.md"
echo "======================================================"
