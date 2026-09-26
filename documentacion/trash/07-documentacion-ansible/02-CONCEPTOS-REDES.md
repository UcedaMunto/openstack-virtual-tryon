# Conceptos de Redes — Arquitectura completa del laboratorio

> **Objetivo:** Entender exactamente qué hay entre tu instancia OpenStack y la red física.  
> Este documento explica cada capa de red, por qué existe, y qué papel juega Ansible en ella.

---

## Visión general: las 3 redes KVM

El host físico (tu ThinkPad) crea 3 redes virtuales con `libvirt`:

```
HOST FÍSICO (ThinkPad)
│
├── virbr113  ──  openstack-public   ──  203.0.113.0/24
│     │           (bridge Linux en el host)
│     ├── enp1s0 del controller  (203.0.113.239)
│     ├── enp1s0 del compute1    (203.0.113.240)
│     ├── enp1s0 del compute2    (203.0.113.241)
│     ├── enp1s0 del compute3    (203.0.113.242)
│     └── enp1s0 del compute4    (203.0.113.243)
│
├── virbr10   ──  openstack-admin    ──  10.0.0.0/24
│     │           (bridge Linux en el host, sin gateway)
│     ├── enp7s0 del controller  (10.0.0.11)  → br-mgmt
│     ├── enp7s0 del compute1    (10.0.0.10)  → br-mgmt
│     ├── enp7s0 del compute2    (10.0.0.12)  → br-mgmt
│     ├── enp7s0 del compute3    (10.0.0.13)  → br-mgmt
│     └── enp7s0 del compute4    (10.0.0.14)  → br-mgmt
│
└── virbr30   ──  openstack-provider ──  L2 puro (sin IP)
      │           (bridge Linux en el host)
      ├── enp8s0 del controller  → br-vlan → OVS br-provider
      ├── enp8s0 del compute1    → br-vlan → OVS br-provider
      ├── enp8s0 del compute2    → br-vlan → OVS br-provider
      ├── enp8s0 del compute3    → br-vlan → OVS br-provider
      └── enp8s0 del compute4    → br-vlan → OVS br-provider
```

**Cada red tiene un propósito diferente:**

| Red KVM | ¿Para qué? | ¿Quién la usa? |
|---------|-----------|----------------|
| `openstack-public` (203.0.113.x) | SSH de administración, API OpenStack, consola VNC, Floating IPs | Tú (desde el laptop) + los APIs de OpenStack |
| `openstack-admin` (10.0.0.x) | Comunicación interna OpenStack: RabbitMQ, MySQL, mensajes Nova↔Neutron | Los propios servicios OpenStack entre sí |
| `openstack-provider` (L2) | Red de las instancias tenant — el tráfico real de las VMs | Instancias OpenStack + router neutron |

---

## Capa 1: KVM y las interfaces virtuales

Cuando libvirt crea una VM, para cada interfaz de red crea un **par veth** (par de interfaces virtuales conectadas en los extremos):

```
Dentro de la VM       Fuera de la VM (en el host)
──────────────        ──────────────────────────
enp1s0       ◄──────► vnet54  (conectado a virbr113)
enp7s0       ◄──────► vnet55  (conectado a virbr10)
enp8s0       ◄──────► vnet56  (conectado a virbr30)
```

Esto es transparente para la VM — ella ve `enp1s0`, `enp7s0`, `enp8s0` como si fueran NICs físicas. El host ve `vnetX` como puertos del bridge `vibrXXX`.

**Restricción de seguridad KVM:** El bridge del host solo acepta tramas con el MAC que libvirt asignó al vnetX. Si el Linux bridge `br-mgmt` dentro de la VM usa un MAC diferente al de `enp7s0`, el host descarta los paquetes. Por eso es importante fijar `macaddress` en netplan cuando se crea `br-mgmt`.

---

## Capa 2: Linux bridges dentro de los nodos OpenStack

Después de ejecutar la guía 06, cada nodo tiene esta estructura de bridges Linux:

```
DENTRO DE CADA NODO (ej. compute1)
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  enp1s0 ─────────────────────────────────────  203.0.113.x │
│            (sin bridge — IP directa)                        │
│                                                             │
│  enp7s0 ──┐                                                 │
│           ├── br-mgmt ──────────────────────  10.0.0.x/24  │
│           │   (Linux bridge)                                │
│                                                             │
│  enp8s0 ──┐                                                 │
│           ├── br-vlan ──────────────────────  (sin IP)     │
│           │   (Linux bridge)                                │
│                ↓                                            │
│           OVS br-provider                                   │
│                                                             │
│  (sin NIC)──┐                                               │
│             ├── br-vxlan ──────────────────  (sin IP, UP)  │
│               (Linux bridge software, sin miembro físico)   │
└─────────────────────────────────────────────────────────────┘
```

### ¿Por qué br-mgmt y no la IP directa en enp7s0?

OpenStack-Ansible (OSA) espera bridges Linux, no IPs en NICs. Ansible y OSA despliegan sus contenedores LXC (en instalaciones OSA completas) anclando interfaces de contenedor a los bridges del host. Aunque en este lab no usamos LXC, seguimos el mismo modelo para:

1. **Consistencia** con cualquier guía OSA que consultes.
2. **Flexibilidad** — puedes mover la IP a otro uplink sin cambiar los contenedores.
3. **Aislamiento** — el bridge desacopla la capa de configuración (IP) del hardware (NIC).

### ¿Por qué br-vlan sin IP?

`br-vlan` es el uplink del plano de datos (tráfico de instancias). No debe tener IP porque:
- No es una interfaz de gestión.
- Todo el tráfico que pasa por él lo gestiona OVS (la capa por encima).
- Si tuviera IP, se crearía una ruta de kernel que competiría con OVS.

### ¿Por qué br-vxlan sin NIC física?

En un servidor real tendríamos 3 NICs:
- `eth0` → br-mgmt (gestión)
- `eth1` → br-vlan (provider/VLAN)
- `eth2` → br-vxlan (underlay VXLAN, dedicado)

En este lab solo tenemos 2 NICs de datos (`enp7s0` y `enp8s0`). La solución:
- `br-vxlan` existe como bridge software (sin miembro físico)
- OVS crea los túneles VXLAN usando la IP de `br-mgmt` (10.0.0.x) como `local_ip`
- El tráfico VXLAN fluye por `br-mgmt` → `enp7s0` → `virbr10` → otros nodos

---

## Capa 3: Open vSwitch (OVS)

OVS es un switch virtual programable que gestiona el plano de datos de las instancias. Es diferente a un Linux bridge:

| Característica | Linux bridge | Open vSwitch |
|---------------|-------------|-------------|
| Rendimiento | Alto (kernel) | Alto (kernel con DPDK opcional) |
| Programabilidad | Baja (solo iptables) | Alta (OpenFlow, tablas de flujo) |
| VXLAN nativo | No | Sí |
| GRE/Geneve | No | Sí |
| Integración con SDN | No | Sí (controlador OpenFlow) |
| Uso en OpenStack | Legacy | Estándar (ML2/OVS) |

### Los 3 bridges OVS de cada nodo

```
OVS en cada nodo
│
├── br-provider  (bridge de entrada/salida hacia la red física)
│     ├── phy-br-provider   ← patch cable interno → br-int
│     └── br-vlan           ← uplink físico (Linux bridge → enp8s0 → virbr30)
│
├── br-int  (integration bridge — el cerebro)
│     ├── int-br-provider   ← patch cable interno → br-provider
│     ├── patch-tun         ← patch cable interno → br-tun
│     ├── tap-XXXXXXXX      ← interfaz de cada instancia corriendo aquí
│     └── qr-XXXXXXXX       ← interfaz del router neutron (solo en controller)
│
└── br-tun  (tunnel bridge — VXLAN)
      ├── patch-int         ← patch cable interno → br-int
      └── vxlan-0a00000X    ← uno por cada nodo remoto (underlay 10.0.0.x UDP 4789)
```

### ¿Qué es un patch cable OVS?

Un **patch port** es un par de puertos OVS que conectan dos bridges OVS directamente, sin pasar por el kernel de red. Son ultra-eficientes porque el paquete nunca sale al stack de red del sistema operativo.

```
br-provider  ←──── patch ────►  br-int  ←──── patch ────►  br-tun
  phy-br-provider         int-br-provider   patch-int
  (un lado)               (otro lado)       (un lado)        patch-tun
                                                             (otro lado)
```

### Flujo de un paquete de una instancia hasta el exterior

**Tráfico Este-Oeste (entre instancias en diferentes computes via VXLAN):**

```
Instancia en compute1
  → tap interface → br-int
  → patch-tun → br-tun
  → OVS encapsula en VXLAN (UDP 4789)
  → La IP de destino del paquete VXLAN es la mgmt IP del compute destino
  → Sale por br-mgmt → enp7s0 → virbr10 (host) → vnet del compute destino
  → br-tun del compute destino desencapsula VXLAN
  → br-int → tap interface → Instancia destino
```

**Tráfico Norte-Sur (desde instancia hacia Internet via Floating IP):**

```
Instancia en compute1
  → tap interface → br-int (compute1)
  → patch-tun → br-tun → VXLAN → br-tun del controller
  → br-int del controller
  → qr-XXXX (interfaz del router neutron) → br-int del controller
  → int-br-provider → phy-br-provider (patch ports)
  → br-provider → br-vlan → enp8s0 → virbr30 (host)
  → El host hace SNAT con la Floating IP → responde
```

> **Nota:** El router neutron (L3 agent) vive en el controller. Todo el tráfico Norte-Sur pasa por el controller aunque la instancia esté en compute4. Esto es una limitación del modelo legacy, no del lab.

---

## Capa 4: Las redes Neutron (overlay)

Neutron gestiona dos tipos de redes:

### Red provider (flat)

```
Nombre:     provider-net
Tipo:       flat (sin VLAN tagging)
Physical:   provider → mapea a → br-provider (OVS)
CIDR:       192.168.122.0/24
Gateway:    192.168.122.1
```

Una red **flat** significa que el tráfico viaja sin encapsulación VLAN. El bridge OVS simplemente conecta la instancia directamente a la red física (virbr30 en este lab).

### Red selfservice (VXLAN)

```
Nombre:     selfservice-net
Tipo:       vxlan
VNI:        640
CIDR:       10.10.10.0/24
```

Una red **VXLAN** encapsula el tráfico L2 dentro de paquetes UDP. Permite crear redes virtuales privadas entre instancias sin necesitar VLANs reales en el hardware.

El VNI (VXLAN Network Identifier) es como el número de VLAN pero para VXLAN. El VNI 640 identifica este segmento de red en todos los nodos.

---

## El modelo br-mgmt / br-vlan / br-vxlan explicado para OSA

OpenStack-Ansible usa estas convenciones de nombres para saber qué hace cada bridge:

| Bridge | Tipo | ¿Qué tráfico lleva? | IP en este lab |
|--------|------|---------------------|----------------|
| `br-mgmt` | Linux bridge | APIs, RabbitMQ, MySQL, SSH de gestión | 10.0.0.x/24 |
| `br-vlan` | Linux bridge | Uplink para redes provider y VLAN de tenants | sin IP |
| `br-vxlan` | Linux bridge | Underlay de túneles VXLAN entre nodos | sin IP (usa br-mgmt) |
| `br-storage` | Linux bridge | Ceph/Swift (si hubiera storage) | no en este lab |

**En nuestro lab de 2 NICs**, `br-vxlan` no tiene NIC física. OVS detecta que la IP local para VXLAN (`local_ip = 10.0.0.x`) es alcanzable por `br-mgmt`, y mete los paquetes VXLAN por ahí. Funciona correctamente en un entorno de laboratorio.

---

## Diagrama completo de una instancia en tráfico

```
┌─────────────────────────────────────────────────────────────┐
│ HOST (ThinkPad)                                             │
│                                                             │
│  virbr30 ◄──────────────────────────────────────────────┐  │
│  (L2 flat)                                              │  │
│                                                         │  │
│  ┌──────────────────── compute1 ──────────────────────┐ │  │
│  │                                                     │ │  │
│  │  [Instancia VM]                                     │ │  │
│  │     ↕ tap interface                                 │ │  │
│  │  br-int (OVS) ←→ br-tun (OVS, VXLAN)              │ │  │
│  │     ↕ patch port                  ↕ vxlan-0a00000b │ │  │
│  │  br-provider (OVS)              virbr10             │ │  │
│  │     ↕ br-vlan (Linux bridge)  (a otros computes)   │ │  │
│  │     ↕ enp8s0                                        │ │  │
│  └─────────────────────────────────────────────────────┘ │  │
│                                                           │  │
│  ┌─────────────────── controller ─────────────────────┐  │  │
│  │                                                     │  │  │
│  │  neutron-l3-agent (router)                          │  │  │
│  │     ↕ qg interface (gateway)                        │  │  │
│  │  br-int (OVS) ←→ br-provider (OVS)                 │  │  │
│  │     ↕ br-vlan (Linux bridge)                        │  │  │
│  │     ↕ enp8s0 ─────────────────────────────────────►┘  │  │
│  └─────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## Resumen de lo que Ansible necesita configurar

Para que esta arquitectura de red funcione, Ansible necesita asegurar en **cada nodo**:

### A nivel de sistema operativo (netplan)
1. `enp7s0` sin IP — miembro de `br-mgmt`
2. `br-mgmt` con IP `10.0.0.x/24` — STP desactivado
3. `enp8s0` sin IP — miembro de `br-vlan`
4. `br-vlan` sin IP — STP desactivado
5. `br-vxlan` sin IP, sin miembros — STP desactivado, UP

### A nivel OVS
6. `br-provider` existe
7. `br-vlan` es el uplink de `br-provider`
8. El agente OVS tiene `bridge_mappings = provider:br-provider`
9. El agente OVS tiene `local_ip = 10.0.0.x` (IP de br-mgmt)

### A nivel de servicios
10. `neutron-openvswitch-agent` activo y conectado al controller
11. `nova-compute` activo (en computes)
12. `libvirtd` activo (sin `--timeout 120`)

---

## Siguiente paso

Continúa con [03-ESTRUCTURA-PROYECTO.md](03-ESTRUCTURA-PROYECTO.md) para ver cómo organizamos el código Ansible.
