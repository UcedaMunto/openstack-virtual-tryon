# Laboratorio OpenStack — ICC115

> **Última actualización:** 2026-07-07  
> **Estado del cluster:** controller + compute1 + compute2 + compute3 + compute4 — todos operativos ✅  
> **Host:** ThinkPad L15 Gen 2a · AMD Ryzen 5 PRO 5650U · 30 GB RAM · Ubuntu  
> **Hypervisor L0:** KVM/QEMU 8.2.2 · libvirt 10.0.0

---

## Índice

- [Arquitectura del laboratorio](#arquitectura-del-laboratorio)
- [Inventario de nodos](#inventario-de-nodos)
- [Redes KVM del host](#redes-kvm-del-host)
- [Redes OpenStack (Neutron)](#redes-openstack-neutron)
- [Bridges OVS por nodo](#bridges-ovs-por-nodo)
- [Servicios OpenStack activos](#servicios-openstack-activos)
- [Recursos del cluster](#recursos-del-cluster)
- [Credenciales y acceso](#credenciales-y-acceso)
- [Diagramas](#diagramas)
- [Guías y documentación](#guías-y-documentación)

---

## Arquitectura del laboratorio

```
┌────────────────────────────────────────────────────────────────────────────┐
│  HOST — ThinkPad L15 Gen 2a  (AMD Ryzen 5 PRO 5650U · 30 GB RAM)          │
│  Hipervisor L0: KVM/QEMU 8.2.2  ·  libvirt 10.0.0  ·  Ubuntu             │
│                                                                            │
│  ┌───────────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │   controller      │  │  compute1   │  │  compute2   │                 │
│  │  203.0.113.239    │  │ 203.0.113.240│  │ 203.0.113.241│                │
│  │  10.0.0.11        │  │  10.0.0.10  │  │  10.0.0.12  │                 │
│  │                   │  │             │  │             │                 │
│  │  Keystone         │  │ nova-compute│  │ nova-compute│                 │
│  │  Nova API/Sched   │  │ neutron-ovs │  │ neutron-ovs │                 │
│  │  Neutron Server   │  │ libvirtd    │  │ libvirtd    │                 │
│  │  Glance/Placement │  │  ┌────────┐ │  │             │                 │
│  │  Horizon          │  │  │VM(L2)  │ │  │             │                 │
│  │  MariaDB/RabbitMQ │  │  └────────┘ │  │             │                 │
│  └───────────────────┘  └─────────────┘  └─────────────┘                 │
│                                                                            │
│  ┌─────────────┐  ┌─────────────┐                                         │
│  │  compute3   │  │  compute4   │                                         │
│  │ 203.0.113.242│  │ 203.0.113.243│                                        │
│  │  10.0.0.13  │  │  10.0.0.14  │                                         │
│  │ nova-compute│  │ nova-compute│                                         │
│  │ neutron-ovs │  │ neutron-ovs │                                         │
│  │ libvirtd    │  │ libvirtd    │                                         │
│  └─────────────┘  └─────────────┘                                         │
│                                                                            │
│  Redes KVM:                                                                │
│    virbr113  openstack-public    203.0.113.0/24  (SSH · VNC · API)        │
│    virbr10   openstack-admin     10.0.0.0/24     (gestión · VXLAN)        │
│    virbr30   openstack-provider  L2 flat sin IP  (tráfico instancias)     │
└────────────────────────────────────────────────────────────────────────────┘
```

**Modelo de virtualización:**

| Capa | Tecnología | Detalle |
|------|-----------|---------|
| L0 — Hipervisor físico | KVM `kvm_amd` | AMD-V / SVM · nested = 1 |
| L1 — VMs OpenStack (nodos) | KVM guest | Ubuntu 24.04.4 LTS |
| L2 — Instancias tenant | Nested KVM vía libvirtd | `/dev/kvm` disponible en computes |
| Emulador | QEMU 8.2.2 | virt_type = kvm · cpu_mode = host-passthrough |

---

## Inventario de nodos

| Nodo | KVM VM | IP Pública | IP Mgmt | Disco | Estado |
|------|--------|-----------|---------|-------|--------|
| controller | `controller` | 203.0.113.239 | 10.0.0.11 | `controller.qcow2` (8 GB) | ✅ running |
| compute1 | `compute` | 203.0.113.240 | 10.0.0.10 | `compute.qcow2` (6.7 GB) | ✅ running |
| compute2 | `compute2` | 203.0.113.241 | 10.0.0.12 | `compute2.qcow2` (6.7 GB) | ✅ running |
| compute3 | `compute3` | 203.0.113.242 | 10.0.0.13 | `compute3.qcow2` (6.7 GB) | ✅ running |
| compute4 | `compute4` | 203.0.113.243 | 10.0.0.14 | `compute4.qcow2` (6.7 GB) | ✅ running |

### Interfaces de red por nodo

| Interfaz | Rol | controller | compute1 | compute2 | compute3 | compute4 |
|----------|-----|-----------|---------|---------|---------|---------|
| enp1s0 | SSH / VNC / API | 203.0.113.239 | 203.0.113.240 | 203.0.113.241 | 203.0.113.242 | 203.0.113.243 |
| enp7s0 | Gestión / VXLAN | 10.0.0.11 | 10.0.0.10 | 10.0.0.12 | 10.0.0.13 | 10.0.0.14 |
| enp8s0 | Provider (sin IP) | → OVS | → OVS | → OVS | → OVS | → OVS |

### Topología PCI de las VMs (igual en todos los nodos)

| Bus PCI | Interfaz | Red KVM |
|---------|----------|---------|
| pci.1 | enp1s0 | openstack-public (virbr113) |
| pci.7 | enp7s0 | openstack-admin (virbr10) |
| pci.8 | enp8s0 | openstack-provider (virbr30) |

### Acceso SSH

```bash
ssh uceda@203.0.113.239   # controller  — sudo password: asdfghjkl
ssh uceda@203.0.113.240   # compute1
ssh uceda@203.0.113.241   # compute2
ssh uceda@203.0.113.242   # compute3
ssh uceda@203.0.113.243   # compute4
```

---

## Redes KVM del host

| Red KVM | Bridge host | Subred | Gateway | Uso |
|---------|-------------|--------|---------|-----|
| openstack-public | virbr113 | 203.0.113.0/24 | 203.0.113.1 | SSH, VNC, API externa, Floating IPs |
| openstack-admin | virbr10 | 10.0.0.0/24 | — | Gestión OpenStack, underlay VXLAN |
| openstack-provider | virbr30 | L2 flat | — | Red provider de instancias (sin IP en host) |

---

## Redes OpenStack (Neutron)

| Nombre | Tipo | CIDR | Router externo |
|--------|------|------|----------------|
| `provider-net` | flat · physical: `provider` | 192.168.122.0/24 | ✅ sí |
| `selfservice-net` | vxlan · VNI: 640 | 10.10.10.0/24 | ❌ no |

### Configuración ML2

```ini
[ml2]
type_drivers         = flat, vlan, vxlan
tenant_network_types = vxlan
mechanism_drivers    = openvswitch, l2population

[ml2_type_flat]
flat_networks = provider

[ml2_type_vxlan]
vni_ranges = 1:1000
```

---

## Bridges OVS por nodo

Todos los nodos tienen la misma estructura:

```
br-provider  (fail_mode=secure)
  ├── enp8s0              ← uplink físico a virbr30
  └── phy-br-provider     ← patch → br-int

br-int  (fail_mode=secure)
  ├── int-br-provider     ← patch → br-provider
  ├── patch-tun           ← patch → br-tun
  └── tap-XXXXXXXX        ← interfaces de instancias (computes)

br-tun  (fail_mode=secure)
  ├── patch-int           ← patch → br-int
  └── vxlan-0a00000X      ← túneles VXLAN UDP 4789 hacia cada nodo
```

| Nodo | bridge_mappings | local_ip VXLAN |
|------|----------------|----------------|
| controller | provider:br-provider | 10.0.0.11 |
| compute1 | provider:br-provider | 10.0.0.10 |
| compute2 | provider:br-provider | 10.0.0.12 |
| compute3 | provider:br-provider | 10.0.0.13 |
| compute4 | provider:br-provider | 10.0.0.14 |

---

## Servicios OpenStack activos

### Controller

| Servicio | Puerto | Estado |
|---------|--------|--------|
| Keystone | 5000 | ✅ |
| Glance API | 9292 | ✅ |
| Nova API | 8774 | ✅ |
| Nova Conductor / Scheduler | — | ✅ |
| Nova NoVNC Proxy | 6080 | ✅ |
| Placement API | 8778 | ✅ |
| Neutron Server | 9696 | ✅ |
| Neutron L3 / DHCP / OVS Agent | — | ✅ |
| Horizon | 80 | ✅ |
| MariaDB | 3306 | ✅ |
| RabbitMQ | 5672 | ✅ |
| Memcached | 11211 | ✅ |

### Computes (compute1–4)

| Servicio | Estado |
|---------|--------|
| nova-compute | ✅ enabled / up |
| neutron-openvswitch-agent | ✅ alive / UP |
| libvirtd (override sin --timeout) | ✅ activo |

### Verificación rápida

```bash
ssh uceda@203.0.113.239 "echo asdfghjkl | sudo -S bash -c '
  source /root/admin-openrc
  openstack compute service list
  openstack hypervisor list
  openstack network agent list
'"
```

---

## Recursos del cluster

| Recurso | Valor |
|---------|-------|
| Imágenes Glance | `cirros` (×2) |
| Redes Neutron | `provider-net` (flat) · `selfservice-net` (vxlan) |
| Hypervisores | 4 (compute1–4) |
| vCPUs totales | 16 (4 × 4 vCPUs) |
| RAM total | ~20 GB |
| Disco total | ~44 GB |

---

## Credenciales y acceso

| Servicio | Usuario | Password | Endpoint |
|---------|---------|----------|----------|
| OpenStack admin | `admin` | `icc115` | http://controller:5000/v3 |
| Horizon | `admin` | `icc115` | http://203.0.113.239/dashboard |
| MariaDB root | `root` | `icc115` | localhost:3306 |
| RabbitMQ | `openstack` | `icc115` | controller:5672 |
| Nodos SSH | `uceda` | `asdfghjkl` | 203.0.113.239–243 |

```bash
# Cargar credenciales OpenStack en el controller:
ssh uceda@203.0.113.239
sudo su -
source /root/admin-openrc    # nota: sin extensión .sh
```

---

## Diagramas

Los diagramas PlantUML están en [`puml/`](puml/):

| Archivo | Contenido |
|---------|-----------|
| [puml/01-topologia-redes.puml](puml/01-topologia-redes.puml) | Redes KVM, nodos, interfaces e IPs |
| [puml/02-conectividad-externa.puml](puml/02-conectividad-externa.puml) | Stack OVS, flujo Norte-Sur y Este-Oeste (VXLAN) |

> Renderizar con la extensión PlantUML de VS Code (`Alt+D`) o en https://www.plantuml.com/plantuml

---

## Guías y documentación

Toda la documentación operativa está en [`documentacion/`](documentacion/):

| # | Archivo | Descripción |
|---|---------|-------------|
| 01 | [documentacion/01-GUIA-CREAR-VMS.md](documentacion/01-GUIA-CREAR-VMS.md) | Crear instancias OpenStack: flavors, imágenes, redes, keypairs y lanzamiento |
| 02 | [documentacion/02-GUIA-SEGUNDO-COMPUTE-INSTALACION.md](documentacion/02-GUIA-SEGUNDO-COMPUTE-INSTALACION.md) | Añadir un nuevo nodo compute: clonar disco, virt-customize, nova/neutron/OVS |
| 03 | [documentacion/03-GUIA-SEGUNDO-COMPUTE-COMPROBACIONES.md](documentacion/03-GUIA-SEGUNDO-COMPUTE-COMPROBACIONES.md) | Verificaciones paso a paso al añadir un compute |
| 04 | [documentacion/04-GUIA-CONTROLLER-REGISTRAR-COMPUTE.md](documentacion/04-GUIA-CONTROLLER-REGISTRAR-COMPUTE.md) | Registrar nuevo compute en el controller: `discover_hosts`, Nova y Neutron |
| 05 | [documentacion/05-GUIA-CONTROLLER-CONFIRMACION.md](documentacion/05-GUIA-CONTROLLER-CONFIRMACION.md) | Confirmación final del cluster desde el controller |
| 06 | [documentacion/06-GUIA-PREPARAR-BRIDGES-ANSIBLE.md](documentacion/06-GUIA-PREPARAR-BRIDGES-ANSIBLE.md) | Preparar Linux bridges (`br-mgmt`, `br-vlan`, `br-vxlan`) para OpenStack-Ansible |

### Scripts de apoyo

| Script | Descripción |
|--------|-------------|
| [`setup-openstack-resources.sh`](setup-openstack-resources.sh) | Crea flavors, redes, router, security groups y keypair |
| [`fix-openstack-bugs.sh`](fix-openstack-bugs.sh) | Corrige bugs del despliegue inicial (IPs, UUIDs, OVS) |

---

## Notas de diseño

### Cómo se clona un nuevo nodo compute

Los computes 2, 3 y 4 se crearon clonando el disco de compute1 con `virt-customize`.  
Ver [guía 02](documentacion/02-GUIA-SEGUNDO-COMPUTE-INSTALACION.md). Puntos clave:
- Netplan escrito completo (no sed) con `dhcp6: false` + `link-local: []`
- `compute_id` borrado para evitar conflicto de UUID con Nova
- Instancias libvirt heredadas (`instance-XXXXXXXX`) eliminadas antes de arrancar nova-compute
- Override de systemd para quitar `--timeout 120` de libvirtd

### Estado de preparación para OpenStack-Ansible (OSA)

| Requisito OSA | Estado | Guía |
|--------------|--------|------|
| `br-mgmt` Linux bridge | ❌ falta | [guía 06](documentacion/06-GUIA-PREPARAR-BRIDGES-ANSIBLE.md) |
| `br-vlan` Linux bridge | ❌ falta | [guía 06](documentacion/06-GUIA-PREPARAR-BRIDGES-ANSIBLE.md) |
| `br-vxlan` Linux bridge | ❌ falta | [guía 06](documentacion/06-GUIA-PREPARAR-BRIDGES-ANSIBLE.md) |
| Bridges OVS en todos los nodos | ✅ | — |
| nova-compute activo en 4 computes | ✅ | — |
| neutron-ovs-agent activo en todos | ✅ | — |
