# Guía: Confirmación del cluster en el controller

> **Fecha:** 2026-07-07  
> **Nodo:** `[CONTROLLER]` — `ssh uceda@203.0.113.239`  
> **Objetivo:** Verificar paso a paso que compute2 está completamente registrado y operativo desde el punto de vista del controller.

```bash
# Cargar credenciales OpenStack (el admin-openrc en este cluster está en /root/admin-openrc sin .sh):
echo asdfghjkl | sudo -S bash -c 'source /root/admin-openrc && openstack compute service list'
# O para una sesión interactiva larga:
sudo su -c 'source /root/admin-openrc; exec bash'
```

---

## Paso 1 — Nova: servicios compute

```bash
openstack compute service list
```

**Esperado:**

```
| nova-scheduler | serverocontroller | internal | enabled | up |
| nova-conductor | serverocontroller | internal | enabled | up |
| nova-compute   | compute1          | nova     | enabled | up |
| nova-compute   | compute2          | nova     | enabled | up |  ← debe aparecer
```

> Si compute2 no aparece o su State es `down`: ver troubleshooting al final.

---

## Paso 2 — Nova: hypervisores

```bash
openstack hypervisor list
```

**Esperado:**

```
| compute1 | QEMU | 10.0.0.10 | up |
| compute2 | QEMU | 10.0.0.12 | up |  ← debe aparecer
```

Detalle de compute2:

```bash
openstack hypervisor show compute2
```

> Verificar que `vcpus`, `memory_mb` y `local_gb` muestran valores mayores que 0.

---

## Paso 3 — Neutron: agentes de red

```bash
openstack network agent list
```

**Esperado:**

```
| Open vSwitch agent | compute1          | :-) | UP |
| Open vSwitch agent | compute2          | :-) | UP |  ← debe aparecer
| Open vSwitch agent | serverocontroller | :-) | UP |
| L3 agent           | serverocontroller | :-) | UP |
| DHCP agent         | serverocontroller | :-) | UP |
```

> Si el agente OVS de compute2 muestra `xxx` en lugar de `:-)`, está caído. Ver troubleshooting.

---

## Paso 4 — Placement: inventario de recursos

```bash
openstack resource provider list
```

**Esperado:** compute1 y compute2 listados.

```bash
# Ver inventario de compute2:
COMPUTE2_UUID=$(openstack resource provider list -f value -c uuid -c name \
  | grep compute2 | awk '{print $1}')
openstack resource provider inventory list $COMPUTE2_UUID
```

**Esperado:** VCPU, MEMORY_MB y DISK_GB con `total` y `free` mayores que 0.

---

## Paso 5 — Prueba funcional: lanzar VM en compute2

```bash
openstack server create \
  --flavor m1.tiny \
  --image cirros \
  --network selfservice-net \
  --availability-zone nova:compute2 \
  --key-name mykey \
  test-compute2 \
  --wait
```

```bash
openstack server show test-compute2 | grep -E 'status|OS-EXT-SRV-ATTR:host|addresses'
```

**Esperado:**

```
| status                    | ACTIVE   |
| OS-EXT-SRV-ATTR:host      | compute2 |
| addresses                 | selfservice-net=...  |
```

Limpiar después de verificar:

```bash
openstack server delete test-compute2
```

---

## Resultado final esperado

| Comprobación | Resultado |
|---|---|
| `nova-compute compute2` enabled/up | ✅ |
| `hypervisor compute2` QEMU up | ✅ |
| OVS agent compute2 :-) UP | ✅ |
| Placement: compute2 con inventario | ✅ |
| VM lanzada en compute2 ACTIVE | ✅ |

---

## Troubleshooting rápido

### compute2 no aparece en compute service list

```bash
# Forzar redescubrimiento:
echo asdfghjkl | sudo -S nova-manage cell_v2 discover_hosts --verbose

# Si sigue sin aparecer, verificar en compute2:
ssh uceda@203.0.113.241 "echo asdfghjkl | sudo -S systemctl is-active nova-compute"
ssh uceda@203.0.113.241 "echo asdfghjkl | sudo -S journalctl -u nova-compute -n 20 --no-pager | grep -E 'ERROR|CRITICAL'"
```

### compute2 aparece con State=down

```bash
# RabbitMQ: verificar que nova-compute en compute2 se conecta
ssh uceda@203.0.113.241 "echo asdfghjkl | sudo -S journalctl -u nova-compute --since '3 minutes ago' --no-pager | grep -Ei 'rabbit|amqp|error'"
```

### Agente OVS de compute2 está DOWN

```bash
ssh uceda@203.0.113.241 "echo asdfghjkl | sudo -S systemctl restart neutron-openvswitch-agent"
# Esperar ~10s y volver a verificar:
openstack network agent list | grep compute2
```

### VM queda en ERROR en lugar de ACTIVE

```bash
openstack server show test-compute2 | grep fault
# Ver logs en compute2:
ssh uceda@203.0.113.241 "echo asdfghjkl | sudo -S journalctl -u nova-compute -n 40 --no-pager | grep -E 'ERROR|fault|instance'"
```
