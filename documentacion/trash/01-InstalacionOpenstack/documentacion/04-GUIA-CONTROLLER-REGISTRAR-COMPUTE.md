# Guía: Registrar un nuevo compute en el controller

> **Fecha:** 2026-07-06  
> **Nodo:** `[CONTROLLER]` — `ssh uceda@203.0.113.239`  
> **Prerrequisito:** compute2 (10.0.0.12) debe estar corriendo con nova-compute y neutron-openvswitch-agent activos.

---

## Resumen de pasos

| # | Paso |
|---|------|
| 1 | Añadir compute2 a /etc/hosts del controller |
| 2 | Verificar conectividad al nuevo nodo |
| 3 | Descubrir el nuevo host con nova-manage |
| 4 | Verificar registro en Nova |
| 5 | Verificar agente de red en Neutron |
| 6 | Verificar inventario de recursos en Placement |

---

## Paso 1 — Añadir compute2 a /etc/hosts

```bash
# [CONTROLLER] ssh uceda@203.0.113.239

# Añadir solo si no existe ya:
grep -q 'compute2' /etc/hosts || \
  echo asdfghjkl | sudo -S bash -c "echo '10.0.0.12 compute2' >> /etc/hosts"

# Verificar:
cat /etc/hosts | grep compute
# Esperado:
# 10.0.0.10 compute1
# 10.0.0.12 compute2
```

---

## Paso 2 — Verificar conectividad al nuevo nodo

```bash
# [CONTROLLER] ssh uceda@203.0.113.239

# Ping por IP:
ping -c3 10.0.0.12

# Ping por nombre:
ping -c3 compute2

# Verificar que nova-compute en compute2 responde (puerto RabbitMQ 5672 va en sentido contrario)
# Comprobar que el nodo está vivo:
ssh uceda@203.0.113.241 "echo asdfghjkl | sudo -S systemctl is-active nova-compute neutron-openvswitch-agent"
# Esperado: active / active
```

> Si nova-compute no está activo en compute2, resolver primero con `GUIA-SEGUNDO-COMPUTE-INSTALACION.md` antes de continuar.

---

## Paso 3 — Descubrir el nuevo host

Nova no registra automáticamente un nuevo compute. Hay que ejecutar `discover_hosts` para que lo añada a la cell.

```bash
# [CONTROLLER] ssh uceda@203.0.113.239

echo asdfghjkl | sudo -S nova-manage cell_v2 discover_hosts --verbose
# Esperado:
# Found 2 cell mappings.
# Skipping cell0 since it does not contain hosts.
# Getting compute nodes from cell 'cell1': ...
# Added host compute2 in cell cell1
# Discovered 1 new hosts.
```

> Si dice `Discovered 0 new hosts`, nova-compute en compute2 no está registrado aún. Ver paso 2 y el troubleshooting al final.

---

## Paso 4 — Verificar registro en Nova

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
# NOTA: el admin-openrc en este cluster está en /root/admin-openrc (sin .sh)
echo asdfghjkl | sudo -S bash -c 'source /root/admin-openrc && openstack compute service list'
openstack compute service list
# Esperado: nova-compute para compute1 Y compute2, ambos enabled/up
# +----+----------------+---------------------+----------+---------+-------+
# | ID | Binary         | Host                | Zone     | Status  | State |
# +----+----------------+---------------------+----------+---------+-------+
# |  1 | nova-scheduler | serverocontroller   | internal | enabled | up    |
# |  2 | nova-conductor | serverocontroller   | internal | enabled | up    |
# |  3 | nova-compute   | compute1            | nova     | enabled | up    |
# |  4 | nova-compute   | compute2            | nova     | enabled | up    |  ← NUEVO

# Lista de hypervisores:
openstack hypervisor list
# Esperado:
# +----+---------------------+-----------------+--------------+-------+
# | ID | Hypervisor Hostname | Hypervisor Type | Host IP      | State |
# +----+---------------------+-----------------+--------------+-------+
# |  1 | compute1            | QEMU            | 10.0.0.10    | up    |
# |  2 | compute2            | QEMU            | 10.0.0.12    | up    |  ← NUEVO

# Detalle de compute2:
openstack hypervisor show compute2
# Muestra vCPUs, RAM, disco disponible y estado
```

---

## Paso 5 — Verificar agente de red en Neutron

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
echo asdfghjkl | sudo -S bash -c 'source /root/admin-openrc && openstack network agent list'
# Esperado: "Open vSwitch agent" para compute2 con Alive=True / State=UP
# +--------------------------------------+--------------------+-----------+-------------------+-------+-------+
# | ID                                   | Agent Type         | Host      | Availability Zone | Alive | State |
# +--------------------------------------+--------------------+-----------+-------------------+-------+-------+
# | ...                                  | Open vSwitch agent | compute1  | None              | True  | UP    |
# | ...                                  | Open vSwitch agent | compute2  | None              | True  | UP    |  ← NUEVO
```

> Si el agente OVS de compute2 no aparece o está DOWN, ver troubleshooting.

---

## Paso 6 — Verificar inventario de recursos en Placement

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
source ~/admin-openrc.sh

# Listar resource providers (uno por hypervisor):
openstack resource provider list
# Esperado: compute1 y compute2 listados

# Ver inventario de compute2:
COMPUTE2_UUID=$(openstack resource provider list -f value -c uuid -c name | grep compute2 | awk '{print $1}')
openstack resource provider inventory list $COMPUTE2_UUID
# Esperado: VCPU, MEMORY_MB, DISK_GB con valores disponibles
```

---

## Paso 7 — Prueba funcional: lanzar una VM en compute2

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

## Resultado esperado

```
openstack compute service list:
  nova-compute  compute1  enabled  up  ✅
  nova-compute  compute2  enabled  up  ✅

openstack hypervisor list:
  compute1  QEMU  10.0.0.10  up  ✅
  compute2  QEMU  10.0.0.12  up  ✅

openstack network agent list:
  Open vSwitch agent  compute1  UP  ✅
  Open vSwitch agent  compute2  UP  ✅
```

---

## Resolución de problemas

### `discover_hosts` dice "Discovered 0 new hosts"

nova-compute en compute2 no se ha registrado aún en la base de datos de Nova.

```bash
# [COMPUTE2] ssh uceda@203.0.113.241
# 1. Verificar estado:
echo asdfghjkl | sudo -S systemctl is-active nova-compute
# 2. Ver últimos errores:
echo asdfghjkl | sudo -S journalctl -u nova-compute -n 30 --no-pager | grep -E 'ERROR|CRITICAL|Started'
# 3. Si está inactive, reiniciar en orden:
echo asdfghjkl | sudo -S bash -c '
  systemctl start libvirtd
  sleep 3
  systemctl restart nova-compute
  sleep 10
  systemctl is-active nova-compute
'
# [CONTROLLER] Volver a ejecutar discover_hosts:
echo asdfghjkl | sudo -S nova-manage cell_v2 discover_hosts --verbose
```

### compute2 aparece en `compute service list` pero con State=down

nova-compute está registrado pero no responde. Normalmente es un problema de RabbitMQ.

```bash
# [COMPUTE2] ssh uceda@203.0.113.241
# Ver si puede conectar a RabbitMQ:
echo asdfghjkl | sudo -S journalctl -u nova-compute --since "3 minutes ago" --no-pager \
  | grep -Ei 'rabbit|amqp|connect|error'
# "Authentication Failure" → contraseña RabbitMQ incorrecta en nova.conf
# "Connection refused"    → controller no responde en 5672

# Verificar transport_url en nova.conf:
grep 'transport_url' /etc/nova/nova.conf
# Debe coincidir con el del controller
```

### Agente OVS de compute2 no aparece o está DOWN

```bash
# [COMPUTE2] ssh uceda@203.0.113.241
echo asdfghjkl | sudo -S systemctl is-active neutron-openvswitch-agent
echo asdfghjkl | sudo -S journalctl -u neutron-openvswitch-agent -n 20 --no-pager | grep -E 'ERROR|state|Agent'

# Verificar OVS bridges:
echo asdfghjkl | sudo -S ovs-vsctl show | grep -E 'Bridge|Port|Interface'
# Deben existir br-int, br-tun y br-provider con enp8s0

# Si falta br-provider o enp8s0:
echo asdfghjkl | sudo -S ovs-vsctl add-port br-provider enp8s0
echo asdfghjkl | sudo -S systemctl restart neutron-openvswitch-agent
```

### Placement no muestra inventario de compute2

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
source ~/admin-openrc.sh

# Forzar sincronización del inventario de resources:
echo asdfghjkl | sudo -S nova-manage placement sync_aggregates
echo asdfghjkl | sudo -S nova-manage placement heal_allocations

# Volver a listar:
openstack resource provider list
```
