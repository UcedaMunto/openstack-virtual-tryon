# Guía: Añadir compute2 — Comprobaciones

> **Fecha:** 2026-07-05  
> **Pasos de instalación:** Ver `GUIA-SEGUNDO-COMPUTE-INSTALACION.md`

Cada sección corresponde al paso de instalación del mismo número. Ejecutar las comprobaciones **después** de completar el paso correspondiente.

**Convención de nodos:**
- `[LAPTOP]` → ThinkPad local
- `[CONTROLLER]` → `ssh uceda@203.0.113.239`
- `[COMPUTE1]` → `ssh uceda@203.0.113.240`
- `[COMPUTE2]` → `ssh uceda@203.0.113.241`

---

## Comprobación 1 — Disco y VM (tras el paso 1)

### 1.1 Disco clonado correctamente

```bash
# [LAPTOP]
sudo ls -lh /var/lib/libvirt/images/compute2.qcow2
# Esperado: ~6.7G, propietario libvirt-qemu
```

### 1.2 virt-customize aplicó bien los cambios

```bash
# [LAPTOP]
# Netplan: IPs correctas y sin sección bridges:
sudo virt-cat -a /var/lib/libvirt/images/compute2.qcow2 /etc/netplan/50-cloud-init.yaml
# Esperado:
# network:
#   version: 2
#   ethernets:
#     enp1s0: addresses: [203.0.113.241/24]
#     enp7s0: addresses: [10.0.0.12/24]
#     enp8s0: (sin IP)
# NO debe aparecer sección "bridges:"

# Grub con consola serie:
sudo virt-cat -a /var/lib/libvirt/images/compute2.qcow2 /etc/default/grub | grep CMDLINE
# Esperado: GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"

# nova.conf con IP correcta:
sudo virt-cat -a /var/lib/libvirt/images/compute2.qcow2 /etc/nova/nova.conf | grep my_ip
# Esperado: my_ip = 10.0.0.12

# neutron agente con IP correcta:
sudo virt-cat -a /var/lib/libvirt/images/compute2.qcow2 \
  /etc/neutron/plugins/ml2/openvswitch_agent.ini | grep local_ip
# Esperado: local_ip = 10.0.0.12

# compute_id borrado:
sudo virt-cat -a /var/lib/libvirt/images/compute2.qcow2 /var/lib/nova/compute_id 2>&1
# Esperado: error "No such file or directory" (es lo correcto)
```

### 1.3 VM definida con topología PCI correcta

```bash
# [LAPTOP]
# Verificar nombre y UUID:
grep -E 'name>|uuid>' /tmp/compute2.xml | head -4

# Verificar que las NICs tienen los mismos buses que compute1:
echo "=== NICs compute2 ==="
virsh --connect qemu:///system dumpxml compute2 | grep -B8 'mac address' | grep 'pci.*bus'
echo "=== NICs compute1 (referencia) ==="
virsh --connect qemu:///system dumpxml compute | grep -B8 'mac address' | grep 'pci.*bus'
# Ambos deben mostrar: bus='0x01', bus='0x07', bus='0x08' en el mismo orden

# VM definida y corriendo:
virsh --connect qemu:///system list --all | grep compute
# Esperado:
#  ID  compute   running
#  ID  compute2  running
```

### 1.4 Conectividad de red tras el arranque

```bash
# [LAPTOP] Esperar ~40s y verificar:
sleep 40
ping -c3 203.0.113.241
ping -c3 10.0.0.12
# Ambos deben responder (tiempo ~1ms por ser VMs locales)
```

---

## Comprobación 2 — Primer arranque (tras el paso 2)

```bash
# [COMPUTE2] ssh uceda@203.0.113.241

# Hostname:
hostname
# Esperado: compute2

# IPs y estado de interfaces:
ip -br addr
# Esperado:
#   lo        UNKNOWN  127.0.0.1/8
#   enp1s0    UP       203.0.113.241/24
#   enp7s0    UP       10.0.0.12/24
#   enp8s0    UP       (sin IP, sin br-provider como Linux bridge)

# ⚠️ Si las IPs no aparecen (solo lo y direcciones link-local fe80::...):
#    Bug de Ubuntu 24.04 — dhcp6/systemd-networkd interfiere con IPs estáticas.
#    Verificar que el netplan tiene dhcp6: false y link-local: [] en cada interfaz.
#    Corregir y aplicar:
# echo asdfghjkl | sudo -S bash -c "cat > /etc/netplan/50-cloud-init.yaml << 'EOF'
# network:
#   version: 2
#   ethernets:
#     enp1s0:
#       dhcp4: false
#       dhcp6: false
#       link-local: []
#       addresses: [203.0.113.241/24]
#       routes: [{to: default, via: 203.0.113.1}]
#       nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
#     enp7s0:
#       dhcp4: false
#       dhcp6: false
#       link-local: []
#       addresses: [10.0.0.12/24]
#     enp8s0:
#       dhcp4: false
#       dhcp6: false
#       link-local: []
# EOF"
# echo asdfghjkl | sudo -S netplan apply

# Machine-id (debe existir y ser diferente al de compute1):
cat /etc/machine-id
# Esperado: 32 caracteres hex, generado desde el UUID de la VM

# SSH host keys regeneradas:
ls /etc/ssh/ssh_host_*
# Esperado: varios archivos ssh_host_*_key y ssh_host_*_key.pub

# Conectividad al controller y compute1:
ping -c2 10.0.0.11   # controller
ping -c2 10.0.0.10   # compute1

# Estado de servicios (esperado inactive hasta el paso 5 — es normal):
echo asdfghjkl | sudo -S systemctl is-active nova-compute neutron-openvswitch-agent || true
# Esperado: inactive / inactive
```

---

## Comprobación 3 — nova.conf (tras el paso 3)

```bash
# [COMPUTE2] ssh uceda@203.0.113.241

# my_ip:
grep 'my_ip' /etc/nova/nova.conf
# Esperado: my_ip = 10.0.0.12

# Sección [libvirt] — IMPORTANTE: verificar que virt_type NO está comentado:
grep -A4 '^\[libvirt\]' /etc/nova/nova.conf
# Esperado:
# [libvirt]
# virt_type = kvm          ← debe estar sin # al inicio
# cpu_mode = host-passthrough
#
# ⚠️ Si solo aparece #virt_type = kvm (comentado), el grep-q sin ^ lo detectó
#    como ya configurado y no añadió la línea activa. Corregir:
# echo asdfghjkl | sudo -S sed -i '/^\[libvirt\]/a virt_type = kvm\ncpu_mode = host-passthrough' /etc/nova/nova.conf

# Sección [vnc]:
grep -A6 '^\[vnc\]' /etc/nova/nova.conf
# Esperado:
# [vnc]
# enabled = true
# server_listen = 0.0.0.0
# server_proxyclient_address = 10.0.0.12
# novncproxy_base_url = http://203.0.113.239:6080/vnc_auto.html
```

---

## Comprobación 4 — neutron-openvswitch-agent (tras el paso 4)

```bash
# [COMPUTE2] ssh uceda@203.0.113.241

# local_ip:
grep 'local_ip' /etc/neutron/plugins/ml2/openvswitch_agent.ini
# Esperado: local_ip = 10.0.0.12

# Configuración completa (sin comentarios):
echo asdfghjkl | sudo -S grep -v '^#\|^$' /etc/neutron/plugins/ml2/openvswitch_agent.ini
# Esperado:
# [ovs]
# bridge_mappings = provider:br-provider
# local_ip = 10.0.0.12
# [agent]
# tunnel_types = vxlan
# l2_population = true
# [securitygroup]
# enable_security_group = true
# firewall_driver = openvswitch
```

---

## Comprobación 5 — OVS bridges y servicios (tras el paso 5)

### 5.1-5.2 OVS bridges creados correctamente

```bash
# [COMPUTE2] ssh uceda@203.0.113.241

echo asdfghjkl | sudo -S ovs-vsctl show
# Esperado (estructura):
#   Bridge br-provider
#       Port enp8s0
#           Interface enp8s0
#       Port phy-br-provider   ← patch port hacia br-int (lo crea neutron-ovs-agent)
#   Bridge br-int
#       Port patch-tun         ← patch port hacia br-tun
#   Bridge br-tun
#       Port patch-int
#       Port vxlan-0a000b0b    ← túnel VXLAN hacia controller (10.0.0.11)
#       Port vxlan-0a000b0a    ← túnel VXLAN hacia compute1 (10.0.0.10)

# Verificar que enp8s0 está en br-provider:
echo asdfghjkl | sudo -S ovs-vsctl port-to-br enp8s0
# Esperado: br-provider
```

### 5.3 Servicios activos

```bash
# [COMPUTE2] ssh uceda@203.0.113.241

echo asdfghjkl | sudo -S systemctl is-active libvirtd neutron-openvswitch-agent nova-compute
# Esperado: active / active / active

# ⚠️ Si nova-compute no arranca: verificar dominios libvirt heredados del disco clonado:
# echo asdfghjkl | sudo -S virsh list --all
# Si aparece algún "instance-XXXXXXXX shut off", eliminarlo:
# echo asdfghjkl | sudo -S bash -c '
#   for dom in $(virsh list --all --name | grep ^instance-); do
#     virsh destroy "$dom" 2>/dev/null || true
#     virsh undefine "$dom" 2>/dev/null || true
#   done
# '
# Luego: echo asdfghjkl | sudo -S systemctl restart libvirtd nova-compute

# Ver el UUID que Nova asignó a este nodo:
cat /var/lib/nova/compute_id
# Esperado: un UUID nuevo (diferente al de compute1)

# Logs de nova-compute (verificar que no hay errores de autenticación ni de libvirt):
echo asdfghjkl | sudo -S journalctl -u nova-compute -n 20 --no-pager | grep -E 'ERROR|WARNING|Started|nova-compute'

# Logs del agente OVS (verificar estado :-)):
echo asdfghjkl | sudo -S journalctl -u neutron-openvswitch-agent -n 10 --no-pager | grep -E 'ERROR|state|Agent'
```

---

## Comprobación 6 — /etc/hosts (tras el paso 6)

```bash
# Verificar en cada nodo:

# [CONTROLLER] ssh uceda@203.0.113.239
cat /etc/hosts | grep -E 'compute|controller'
# Esperado: 10.0.0.12 compute2  ← debe existir

# [COMPUTE1] ssh uceda@203.0.113.240
cat /etc/hosts | grep -E 'compute|controller'
# Esperado: 10.0.0.12 compute2, y 127.0.1.1 compute1 (no serverocontroller)

# [COMPUTE2] ssh uceda@203.0.113.241
cat /etc/hosts
# Esperado:
# 127.0.1.1 compute2
# 10.0.0.11 controller
# 10.0.0.10 compute1
# 10.0.0.12 compute2

# Resolución de nombres desde compute2:
ping -c2 controller
ping -c2 compute1
ping -c2 compute2
```

---

## Comprobación 7 — Nova registra compute2 (tras el paso 7)

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
source ~/admin-openrc.sh

# Servicios compute:
openstack compute service list
# Esperado: nova-compute para compute1 Y compute2, ambos enabled/up

# Hypervisores:
openstack hypervisor list
# Esperado:
#   compute1  QEMU  10.0.0.10  up
#   compute2  QEMU  10.0.0.12  up   ← NUEVO
```

---

## Comprobación 8 — Verificación completa del cluster

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
source ~/admin-openrc.sh

echo "=== Compute services ==="
openstack compute service list

echo "=== Hypervisors ==="
openstack hypervisor list

echo "=== Network agents ==="
openstack network agent list
# Esperado: "Open vSwitch agent" para compute2 con state UP

echo "=== Resource providers ==="
openstack resource provider list
# Esperado: compute1 y compute2 listados

echo "=== OVS en compute2 (túneles VXLAN) ==="
ssh uceda@203.0.113.241 "echo asdfghjkl | sudo -S ovs-vsctl show | grep -A2 vxlan"
# Esperado: túneles vxlan hacia 10.0.0.11 (controller) y 10.0.0.10 (compute1)
```

### Prueba funcional: lanzar una VM en compute2

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
source ~/admin-openrc.sh

openstack server create \
  --flavor m1.tiny \
  --image cirros \
  --network selfservice-net \
  --availability-zone nova:compute2 \
  --key-name mykey \
  test-compute2 \
  --wait

openstack server show test-compute2 | grep -E 'status|OS-EXT-SRV-ATTR:host|addresses'
# status: ACTIVE
# OS-EXT-SRV-ATTR:host: compute2   ← confirma que está en compute2

# Limpiar:
openstack server delete test-compute2
```

> `--availability-zone nova:compute2` fuerza el scheduler a usar compute2 específicamente.

---

## Resultado esperado tras completar todos los pasos

```
openstack compute service list:
  nova-scheduler  serverocontroller  enabled  up  ✅
  nova-conductor  serverocontroller  enabled  up  ✅
  nova-compute    compute1           enabled  up  ✅
  nova-compute    compute2           enabled  up  ✅  ← NUEVO

openstack hypervisor list:
  compute1  QEMU  10.0.0.10  up  ✅
  compute2  QEMU  10.0.0.12  up  ✅  ← NUEVO

openstack network agent list:
  Open vSwitch agent  compute1  UP  ✅
  Open vSwitch agent  compute2  UP  ✅  ← NUEVO
```
