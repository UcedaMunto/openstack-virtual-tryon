# Guía: Preparar interfaces de red para OpenStack-Ansible (OSA)

> **Fecha:** 2026-07-07  ·  **Completada:** 2026-07-09  
> **Estado:** ✅ APLICADA en todos los nodos (1 controller + 4 computes)  
> **Objetivo:** Convertir las interfaces de red actuales al modelo que Ansible/OSA espera:  
> Linux bridges `br-mgmt`, `br-vlan` y `br-vxlan` como capa de abstracción sobre las NICs físicas.  
> **Afecta a:** controller + compute1 + compute2 + compute3 + compute4

> **⚠️ Corrección crítica aplicada:** `br-vxlan` usa `/32` (no `/24`) para evitar ruta duplicada.
> Ver [Paso 4 — Pitfall /24 vs /32](#paso-4--pitfall-ruta-duplicada-br-vxlan-vs-br-mgmt).

---

## Conceptos previos: por qué hace falta esto

OpenStack-Ansible (OSA) no habla directamente con las NICs físicas. Espera encontrar **Linux bridges** ya creados en el sistema operativo, y despliega los servicios OpenStack asumiendo que esos bridges existen. Ansible solo los usa — no los crea.

### Modelo que exige OSA

```
Hardware          Bridges Linux (HOST)         Red lógica
─────────         ────────────────────         ──────────────────
enp7s0     ──►   br-mgmt  (10.0.0.x/24)    ►  Gestión / APIs / RabbitMQ
enp8s0     ──►   br-vlan  (sin IP)          ►  Provider flat / Red pública
(sin NIC)  ──►   br-vxlan (10.0.0.x/32) ★  ►  Underlay VXLAN entre nodos
```

> **★ Limitación de este laboratorio (2 NICs):** En un diseño estándar (imagen de referencia)  
> habría 3 NICs: eth0→br-mgmt, eth1→br-vlan, **eth2→br-vxlan**. Aquí solo hay 2 NICs  
> (`enp7s0` y `enp8s0`), por lo que `br-vxlan` es un **bridge software sin NIC física**.  
> Usa `/32` (host address) para no crear una ruta 10.0.0.0/24 duplicada que interfiera  
> con `br-mgmt`. El tráfico VXLAN real viaja por `br-mgmt → enp7s0`.

---

## Estado actual vs estado objetivo

### Interfaces por nodo

| Nodo | enp1s0 (pública) | enp7s0 (mgmt) | enp8s0 (provider) |
|------|-----------------|---------------|-------------------|
| controller | 203.0.113.239/24 | 10.0.0.11/24 directo | sin IP |
| compute1 | 203.0.113.240/24 | 10.0.0.10/24 directo | sin IP |
| compute2 | 203.0.113.241/24 | 10.0.0.12/24 directo | sin IP |
| compute3 | 203.0.113.242/24 | 10.0.0.13/24 directo | sin IP |
| compute4 | 203.0.113.243/24 | 10.0.0.14/24 directo | sin IP |

### Cambios necesarios

| Situación actual | Situación objetivo | Motivo |
|-----------------|-------------------|--------|
| `enp7s0` tiene IP 10.0.0.x directa | IP se mueve al bridge `br-mgmt`, `enp7s0` queda como miembro sin IP | OSA gestiona servicios a través del bridge |
| `enp8s0` sin IP, miembro de OVS directamente | `enp8s0` pasa por `br-vlan` primero, luego OVS encima | OSA necesita el Linux bridge como punto de entrada para redes provider/VLAN |
| VXLAN underlay = IP de `enp7s0` (10.0.0.x) | VXLAN underlay = IP de `br-vxlan` (mismo rango) | OSA configura `tunnel_bridge: br-vxlan` |
| Netplan tiene `bridges: br-provider` Linux | Quitar ese bridge Linux (OVS lo gestiona; no debe coexistir un Linux bridge `br-provider`) | Conflicto OVS vs Linux bridge en provider |

---

## ⚠️ Advertencias antes de empezar

1. **Mover una IP de `enp7s0` a `br-mgmt` corta SSH temporalmente** (~2-3 s si se hace con netplan de forma atómica). Es imprescindible tener **acceso por consola serie** preparado (`virsh console`) por si algo sale mal.

2. **Hacer snapshot de los discos** antes de empezar:
   ```bash
   # [LAPTOP] — desde el host KVM, con las VMs apagadas
   # No es obligatorio con las VMs encendidas, pero sí recomendado
   sudo virsh snapshot-create-as controller snap-pre-ansible --disk-only --atomic
   sudo virsh snapshot-create-as compute snap-pre-ansible --disk-only --atomic
   # ... repetir para compute2, compute3, compute4
   ```

3. **Orden de operación:** Hacer el cambio nodo a nodo, empezando por **un compute** (no el controller). Si algo falla, el controller sigue accesible y puedes depurar.

4. **Los cambios en netplan no afectan a OVS** directamente — OVS tiene su propia configuración persistente en su base de datos. Los bridges OVS (`br-int`, `br-tun`, `br-provider`) siguen existiendo tras el cambio de netplan.

---

## Resumen de pasos

| # | Paso | Nodo | Estado |
|---|------|------|--------|
| 1 | Entender el nuevo netplan — estructura por nodo | (diseño) | ✅ |
| 2 | Aplicar nuevo netplan en compute1 | compute1 | ✅ |
| 3 | Verificar y corregir OVS (br-vlan como uplink) | compute1 | ✅ |
| 4 | Pitfall /32 en br-vxlan — ruta duplicada | todos | ✅ |
| 5 | Verificar servicios OpenStack en compute1 | compute1 + controller | ✅ |
| 6 | Repetir pasos 2-5 en compute2, compute3, compute4 | computes | ✅ |
| 7 | Aplicar en el controller (último) | controller | ✅ |
| 8 | Verificar cluster completo | controller | ✅ |

---

## Paso 1 — Diseño del nuevo netplan

### Explicación de la estructura

El netplan objetivo tiene **dos secciones**:
- `ethernets:` — interfaces físicas declaradas **sin IP** (son miembros de bridges)
- `bridges:` — bridges Linux con sus IPs y sus miembros

**Regla clave de netplan con bridges:**  
Si una interfaz física aparece en `interfaces:` de un bridge, **no debe tener IP en la sección `ethernets:`**. La IP se declara en el bridge.

### Netplan objetivo — controller (10.0.0.11)

```yaml
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [203.0.113.239/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp7s0:
      dhcp4: false
      dhcp6: false
      link-local: []
    enp8s0:
      dhcp4: false
      dhcp6: false
      link-local: []
  bridges:
    br-mgmt:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.11/24]
      interfaces: [enp7s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      interfaces: [enp8s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vxlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.11/32]    # ★ /32 no /24 — ver Paso 4
      parameters:
        stp: false
        forward-delay: 0
```

> **Por qué `br-vxlan` no tiene `interfaces:` y usa `/32`:**  
> — Sin NIC: `enp7s0` ya está en `br-mgmt`. No puede estar en dos bridges a la vez.  
> — `/32` (no `/24`): si br-vxlan tuviera `/24`, el kernel crearía **dos rutas** para  
>   `10.0.0.0/24` (una por br-vxlan, otra por br-mgmt). El kernel puede elegir br-vxlan  
>   (que no tiene NIC física) como salida, rompiendo la conectividad mgmt entre nodos.  
>   Con `/32` solo existe la ruta de red en br-mgmt. Ver [Paso 4](#paso-4--pitfall-ruta-duplicada-br-vxlan-vs-br-mgmt).

> **Por qué `stp: false` y `forward-delay: 0`:**  
> Spanning Tree Protocol en un bridge Linux introduce un retraso de 30 segundos antes de  
> que el puerto esté activo. En un entorno virtualizado sin bucles de red, STP es  
> innecesario y ralentiza el arranque.

### Netplan objetivo — nodos compute

La estructura es idéntica, cambiando solo las IPs.

> **⚠️ Usar `/32` en br-vxlan, NO `/24`** — ver [Paso 4](#paso-4--pitfall-ruta-duplicada-br-vxlan-vs-br-mgmt).

| Nodo | br-mgmt | br-vxlan ★ | enp1s0 |
|------|---------|------------|--------|
| compute1 | 10.0.0.10/24 | 10.0.0.10**/32** | 203.0.113.240/24 |
| compute2 | 10.0.0.12/24 | 10.0.0.12**/32** | 203.0.113.241/24 |
| compute3 | 10.0.0.13/24 | 10.0.0.13**/32** | 203.0.113.242/24 |
| compute4 | 10.0.0.14/24 | 10.0.0.14**/32** | 203.0.113.243/24 |

---

## Paso 2 — Aplicar nuevo netplan (compute1 como piloto)

> **Nodo:** `[COMPUTE1]` — `ssh uceda@203.0.113.240`  
> Este es el nodo piloto. Si funciona aquí, se replica en el resto.

### 2.1 Abrir consola serie de respaldo en otra terminal

Antes de tocar netplan, preparar la consola por si se pierde SSH:

```bash
# [LAPTOP — terminal separada]
virsh --connect qemu:///system console compute
# login: uceda / asdfghjkl
# Dejar esta terminal abierta durante todo el proceso
```

### 2.2 Escribir el nuevo netplan en compute1

```bash
# [COMPUTE1] ssh uceda@203.0.113.240
echo asdfghjkl | sudo -S bash -c "cat > /etc/netplan/50-cloud-init.yaml << 'EOF'
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [203.0.113.240/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp7s0:
      dhcp4: false
      dhcp6: false
      link-local: []
    enp8s0:
      dhcp4: false
      dhcp6: false
      link-local: []
  bridges:
    br-mgmt:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.10/24]
      interfaces: [enp7s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      interfaces: [enp8s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vxlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.10/32]    # ★ /32 no /24
      parameters:
        stp: false
        forward-delay: 0
EOF"
```

### 2.3 Validar la sintaxis antes de aplicar

```bash
# [COMPUTE1]
echo asdfghjkl | sudo -S netplan generate
# Si no muestra errores, la sintaxis es correcta.
# NUNCA aplicar un netplan con errores de sintaxis — puede dejar el nodo sin red.
```

### 2.4 Aplicar el nuevo netplan

```bash
# [COMPUTE1]
# Este comando puede cortar SSH ~2-3s mientras la IP se mueve de enp7s0 a br-mgmt
echo asdfghjkl | sudo -S netplan apply
```

> **Si se cae SSH:** Usar la consola serie preparada en el paso 2.1. Desde allí:
> ```bash
> echo asdfghjkl | sudo -S netplan apply
> # Si eso tampoco funciona, revisar el netplan y corregir:
> echo asdfghjkl | sudo -S bash -c "cat /etc/netplan/50-cloud-init.yaml"
> ```

### 2.5 Verificar interfaces tras el cambio

```bash
# [COMPUTE1] o reconectar por SSH tras unos segundos
ip -br addr
# Esperado:
# lo          UNKNOWN   127.0.0.1/8
# enp1s0      UP        203.0.113.240/24
# enp7s0      UP        (sin IP — es miembro de br-mgmt)
# enp8s0      UP        (sin IP — es miembro de br-vlan)
# br-mgmt     UP        10.0.0.10/24
# br-vlan     UP        (sin IP)
# br-vxlan    DOWN      10.0.0.10/32  ← DOWN es esperado (sin NIC física)

# Verificar que br-mgmt tiene enp7s0 como miembro:
bridge link show
# Debe mostrar: enp7s0 master br-mgmt
#               enp8s0 master br-vlan

# Verificar conectividad al controller:
ping -c2 10.0.0.11
```

---

## Paso 3 — Verificar y reconciliar OVS tras el cambio

> **Nodo:** `[COMPUTE1]` — `ssh uceda@203.0.113.240`

### Por qué puede haber conflicto

Antes del cambio, OVS `br-provider` tenía `enp8s0` como puerto físico directo.  
Ahora `enp8s0` está en el Linux bridge `br-vlan`.  
Hay dos opciones para la integración OVS ↔ provider:

**Opción A (recomendada para OSA):** OVS `br-provider` usa el Linux bridge `br-vlan` como uplink.  
La cadena queda: `instancia → tap → br-int → br-provider → br-vlan → enp8s0 → red provider`

**Opción B (equivalente a lo actual):** Sacar `enp8s0` de `br-vlan` y mantenerlo directo en OVS.  
Esto contradice el modelo OSA. No recomendado si el objetivo es OSA.

Se sigue la **Opción A**:

### 3.1 Verificar estado actual de OVS

```bash
# [COMPUTE1]
echo asdfghjkl | sudo -S ovs-vsctl show
# Verificar qué hay en br-provider:
# Si muestra "Port enp8s0" en br-provider → enp8s0 está duplicado (en OVS y en br-vlan)
# Si muestra "Port br-vlan" en br-provider → ya está correcto (poco probable sin cambiar)
```

### 3.2 Reemplazar enp8s0 por br-vlan en OVS br-provider

```bash
# [COMPUTE1]
echo asdfghjkl | sudo -S bash -c '
  # Parar el agente OVS para hacer cambios seguros
  systemctl stop neutron-openvswitch-agent

  # Quitar enp8s0 de OVS br-provider
  ovs-vsctl del-port br-provider enp8s0

  # Añadir br-vlan (Linux bridge) como uplink de OVS br-provider
  ovs-vsctl add-port br-provider br-vlan

  # Verificar
  echo "=== OVS br-provider ==="
  ovs-vsctl list-ports br-provider

  # Reiniciar el agente
  systemctl start neutron-openvswitch-agent
  sleep 3
  systemctl is-active neutron-openvswitch-agent
'
```

> **Por qué se detiene neutron-openvswitch-agent:** El agente reconecta puertos OVS
> continuamente. Si modificamos OVS mientras el agente corre, puede revertir el cambio.

### 3.3 Verificar que OVS reconoce el nuevo uplink

```bash
# [COMPUTE1]
echo asdfghjkl | sudo -S ovs-vsctl show
# Esperado en br-provider:
#   Bridge br-provider
#     Port br-vlan
#       Interface br-vlan
#     Port phy-br-provider
#       Interface phy-br-provider (patch hacia br-int)
```

---

## Paso 4 — Pitfall: Ruta duplicada br-vxlan vs br-mgmt

> **⚠️ Problema descubierto en producción** (2026-07-09): Este paso documenta un fallo  
> real que rompe la conectividad mgmt entre nodos si `br-vxlan` usa `/24`.

### El problema

Si `br-vxlan` tiene `addresses: [10.0.0.x/24]`, el kernel crea **dos rutas** para `10.0.0.0/24`:

```
10.0.0.0/24 dev br-vxlan  proto kernel  scope link  src 10.0.0.x   ← PROBLEMA
10.0.0.0/24 dev br-mgmt   proto kernel  scope link  src 10.0.0.x   ← correcto
```

El kernel puede elegir `br-vxlan` como salida. Como `br-vxlan` no tiene NIC física,  
los paquetes se pierden. Síntoma: `arping -I br-mgmt 10.0.0.11` funciona pero  
`ping 10.0.0.11` falla, y `ip route get 10.0.0.11` devuelve `dev br-vxlan`.

### La solución: /32 en br-vxlan

Con `/32` (dirección de host, no de red), el kernel solo crea una ruta de host:

```
10.0.0.x     dev br-vxlan  proto kernel  scope link  src 10.0.0.x  ← solo host route
10.0.0.0/24  dev br-mgmt   proto kernel  scope link  src 10.0.0.x  ← única ruta de red ✓
```

OVS solo necesita saber la IP del endpoint (`local_ip = 10.0.0.x`), no el prefijo.

### Aplicar la corrección en todos los nodos

```bash
# Script para aplicar /32 en br-vxlan vía python3 (evita corrupciones del yaml.dump)
# Ejecutar en CADA nodo cambiando la IP correspondiente:

# [CONTROLLER] 10.0.0.11
ssh uceda@203.0.113.239 "echo asdfghjkl | sudo -S python3 -c \"
import yaml
with open('/etc/netplan/50-cloud-init.yaml') as f:
    cfg = yaml.safe_load(f)
cfg['network']['bridges']['br-mgmt'].pop('macaddress', None)  # limpia si existe
cfg['network']['bridges']['br-vxlan']['addresses'] = ['10.0.0.11/32']
with open('/etc/netplan/50-cloud-init.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, sort_keys=False)
\" && sudo netplan generate && sudo netplan apply"
```

> **⚠️ Pitfall: yaml.dump convierte MAC a entero**  
> Si el netplan tiene `macaddress: 52:54:00:xx:xx:xx`, el módulo `yaml` de Python  
> lo deserializa como entero (`macaddress: 43354...`). Netplan lo rechaza con  
> `Invalid MAC address`. La línea `.pop('macaddress', None)` elimina este campo  
> antes de reescribir, ya que netplan no lo necesita cuando la MAC viene de la NIC.

### Verificar tras la corrección

```bash
# En cada nodo:
ip route show | grep '10.0.0'
# Esperado: solo UNA línea con dev br-mgmt (no br-vxlan para /24)
# 10.0.0.0/24 dev br-mgmt proto kernel scope link src 10.0.0.x

ping -c2 10.0.0.11  # debe funcionar desde cualquier nodo
```

### Estado de br-vxlan esperado (DOWN es normal)

```
br-vxlan  DOWN  10.0.0.x/32
```

`DOWN` (NO-CARRIER) es el comportamiento correcto para un bridge software sin NIC física.  
No indica error — indica que no hay ningún puerto físico conectado. OVS no usa este bridge  
directamente; usa la IP como referencia para `local_ip` en los túneles VXLAN.

### 4.1 Verificar local_ip en neutron-openvswitch-agent

```bash
# [COMPUTE1] — La IP no cambia, solo el prefijo del bridge
echo asdfghjkl | sudo -S grep '^local_ip' /etc/neutron/plugins/ml2/openvswitch_agent.ini
# Esperado: local_ip = 10.0.0.10
```

### 4.2 Verificar túneles VXLAN existentes

```bash
# [COMPUTE1]
echo asdfghjkl | sudo -S ovs-vsctl show | grep -A3 "br-tun"
# Los túneles vxlan-0a00000b se crean on-demand cuando hay VMs activas.
# Computes sin VMs pueden mostrar solo patch-int en br-tun — es normal.
# Si los túneles desaparecieron tras el cambio, reiniciar el agente:
# echo asdfghjkl | sudo -S systemctl restart neutron-openvswitch-agent
```

---

## Paso 5 — Verificar servicios OpenStack en compute1

```bash
# [COMPUTE1]
echo asdfghjkl | sudo -S systemctl is-active libvirtd nova-compute neutron-openvswitch-agent
# Los tres deben mostrar: active

# Ver logs de nova-compute para errores de red:
echo asdfghjkl | sudo -S journalctl -u nova-compute -n 20 --no-pager | grep -E 'ERROR|CRITICAL|Started'

# Verificar logs de neutron-openvswitch-agent:
echo asdfghjkl | sudo -S journalctl -u neutron-openvswitch-agent -n 10 --no-pager | grep -E 'ERROR|state|Agent'
```

```bash
# [CONTROLLER] — Verificar que compute1 sigue registrado y activo:
ssh uceda@203.0.113.239 "echo asdfghjkl | sudo -S bash -c '
  source /root/admin-openrc
  openstack compute service list | grep compute1
  openstack network agent list | grep compute1
'"
# Esperado: nova-compute compute1 enabled/up; ovs-agent compute1 alive/UP
```

---

## Paso 6 — Repetir en compute2, compute3, compute4

El procedimiento es idéntico. Solo cambian las IPs. Ejecutar nodo a nodo, verificando  
que OpenStack lo ve activo antes de pasar al siguiente.

### compute2 (10.0.0.12 / 203.0.113.241)

```bash
# [COMPUTE2] ssh uceda@203.0.113.241
echo asdfghjkl | sudo -S bash -c "cat > /etc/netplan/50-cloud-init.yaml << 'EOF'
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [203.0.113.241/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp7s0:
      dhcp4: false
      dhcp6: false
      link-local: []
    enp8s0:
      dhcp4: false
      dhcp6: false
      link-local: []
  bridges:
    br-mgmt:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.12/24]
      interfaces: [enp7s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      interfaces: [enp8s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vxlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.12/32]    # ★ /32
      parameters:
        stp: false
        forward-delay: 0
EOF"
echo asdfghjkl | sudo -S netplan generate && echo asdfghjkl | sudo -S netplan apply
```

### compute3 (10.0.0.13 / 203.0.113.242)

```bash
# [COMPUTE3] ssh uceda@203.0.113.242
echo asdfghjkl | sudo -S bash -c "cat > /etc/netplan/50-cloud-init.yaml << 'EOF'
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [203.0.113.242/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp7s0:
      dhcp4: false
      dhcp6: false
      link-local: []
    enp8s0:
      dhcp4: false
      dhcp6: false
      link-local: []
  bridges:
    br-mgmt:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.13/24]
      interfaces: [enp7s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      interfaces: [enp8s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vxlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.13/32]    # ★ /32 no /24
      parameters:
        stp: false
        forward-delay: 0
EOF"
echo asdfghjkl | sudo -S netplan generate && echo asdfghjkl | sudo -S netplan apply
```

### compute4 (10.0.0.14 / 203.0.113.243)

```bash
# [COMPUTE4] ssh uceda@203.0.113.243
echo asdfghjkl | sudo -S bash -c "cat > /etc/netplan/50-cloud-init.yaml << 'EOF'
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [203.0.113.243/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp7s0:
      dhcp4: false
      dhcp6: false
      link-local: []
    enp8s0:
      dhcp4: false
      dhcp6: false
      link-local: []
  bridges:
    br-mgmt:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.14/24]
      interfaces: [enp7s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      interfaces: [enp8s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vxlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.14/32]    # ★ /32 no /24
      parameters:
        stp: false
        forward-delay: 0
EOF"
echo asdfghjkl | sudo -S netplan generate && echo asdfghjkl | sudo -S netplan apply
```

---

## Paso 7 — Aplicar en el controller (último)

> **⚠️ Riesgo máximo:** El controller tiene todos los servicios OpenStack.  
> Hacer este paso al final, con la consola serie preparada.

```bash
# [LAPTOP — terminal separada ANTES de tocar netplan]
virsh --connect qemu:///system console controller
# login: uceda / asdfghjkl  — dejar abierta
```

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
echo asdfghjkl | sudo -S bash -c "cat > /etc/netplan/50-cloud-init.yaml << 'EOF'
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [203.0.113.239/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp7s0:
      dhcp4: false
      dhcp6: false
      link-local: []
    enp8s0:
      dhcp4: false
      dhcp6: false
      link-local: []
  bridges:
    br-mgmt:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.11/24]
      interfaces: [enp7s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      interfaces: [enp8s0]
      parameters:
        stp: false
        forward-delay: 0
    br-vxlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.11/24]
      parameters:
        stp: false
        forward-delay: 0
EOF"
echo asdfghjkl | sudo -S netplan generate && echo asdfghjkl | sudo -S netplan apply
```

### Reconciliar OVS en el controller

```bash
# [CONTROLLER]
echo asdfghjkl | sudo -S bash -c '
  systemctl stop neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent

  # Reemplazar enp8s0 por br-vlan en OVS br-provider
  ovs-vsctl del-port br-provider enp8s0
  ovs-vsctl add-port br-provider br-vlan

  systemctl start neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent
  sleep 5
  systemctl is-active neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent
'
```

---

## Paso 8 — Verificación final del cluster

### Estado real obtenido (2026-07-09) ✅

| Nodo | enp7s0 | enp8s0 | br-mgmt | br-vlan | br-vxlan | OVS br-provider uplink |
|------|--------|--------|---------|---------|----------|----------------------|
| controller | UP (sin IP) | UP (sin IP) | UP 10.0.0.11/24 | UP (sin IP) | DOWN 10.0.0.11/32 | br-vlan ✓ |
| compute1 | UP (sin IP) | UP (sin IP) | UP 10.0.0.10/24 | UP (sin IP) | DOWN 10.0.0.10/32 | br-vlan ✓ |
| compute2 | UP (sin IP) | UP (sin IP) | UP 10.0.0.12/24 | UP (sin IP) | DOWN 10.0.0.12/32 | br-vlan ✓ |
| compute3 | UP (sin IP) | UP (sin IP) | UP 10.0.0.13/24 | UP (sin IP) | DOWN 10.0.0.13/32 | br-vlan ✓ |
| compute4 | UP (sin IP) | UP (sin IP) | UP 10.0.0.14/24 | UP (sin IP) | DOWN 10.0.0.14/32 | br-vlan ✓ |

**Servicios OpenStack:**

| Servicio | Host | Estado |
|---------|------|--------|
| nova-compute | compute1..4 | enabled/up ✓ |
| neutron-openvswitch-agent | todos | alive/UP ✓ |
| neutron-l3-agent | controller | alive/UP ✓ |
| neutron-dhcp-agent | controller | alive/UP ✓ |

**Conectividad br-mgmt (ping matrix):**
```
ctrl ↔ c1 ↔ c2 ↔ c3 ↔ c4  →  todos alcanzables ✓
```

```bash
# [CONTROLLER] — Comando de verificación completo:
echo asdfghjkl | sudo -S bash -c '
  source /root/admin-openrc
  echo "=== compute service list ==="
  openstack compute service list
  echo "=== network agent list ==="
  openstack network agent list
'
# Todos los nova-compute deben ser enabled/up
# Todos los ovs-agents deben ser alive/UP
```

```bash
# Verificar bridges en un compute (ejemplo compute1):
ssh uceda@203.0.113.240 "
  ip -br addr | grep -E 'br-mgmt|br-vlan|br-vxlan|enp'
  echo '---'
  echo asdfghjkl | sudo -S bridge link show
  echo '---'
  echo asdfghjkl | sudo -S ovs-vsctl show | grep -A2 'br-provider'
"
# Esperado:
# enp7s0  UP  (sin IP)
# enp8s0  UP  (sin IP)
# br-mgmt UP  10.0.0.10/24
# br-vlan UP  (sin IP)
# br-vxlan DOWN 10.0.0.10/32   ← DOWN esperado (sin NIC física)
# ---
# enp7s0 master br-mgmt
# enp8s0 master br-vlan
# ---
# br-provider contiene: Port br-vlan (no enp8s0 directo) ✓
```

---

## Mapa final de bridges para inventario Ansible

Una vez completado, el inventario OSA (`openstack_user_config.yml`) debe referenciar:

```yaml
# Fragmento del inventario OSA (referencia)
cidr_networks:
  management: 10.0.0.0/24   # br-mgmt
  tunnel:      10.0.0.0/24   # br-vxlan (mismo rango en este lab)

provider_networks:
  - network:
      container_bridge: br-mgmt       # Gestión
      type: raw
      ip_from_q: management
  - network:
      container_bridge: br-vxlan      # Overlay VXLAN
      type: vxlan
      ip_from_q: tunnel
  - network:
      container_bridge: br-vlan       # Provider flat
      type: flat
      net_name: provider
```

---

## Resolución de problemas comunes

### SSH no responde tras netplan apply

```bash
# [LAPTOP] — Usar consola serie que dejaste abierta
virsh --connect qemu:///system console compute
# Verificar IP en br-mgmt:
ip -br addr | grep br-mgmt
# Si falta la IP, reaplicar:
echo asdfghjkl | sudo -S netplan apply
```

### br-vlan aparece con IP 192.168.122.10 residual

El netplan del controller original tenía `br-provider` con esa IP. Si queda residual:

```bash
# [CONTROLLER o COMPUTE]
echo asdfghjkl | sudo -S ip addr flush dev br-vlan
# Reaplicar netplan:
echo asdfghjkl | sudo -S netplan apply
```

### neutron-openvswitch-agent falla tras cambio de OVS

El agente puede tardar en reconectar los patch ports. Reiniciar:

```bash
echo asdfghjkl | sudo -S systemctl restart neutron-openvswitch-agent
sleep 5
echo asdfghjkl | sudo -S systemctl is-active neutron-openvswitch-agent
```

### El agente OVS vuelve a poner enp8s0 en br-provider

El agente neutron-ovs puede "reparar" el bridge y revertir el cambio. Para que sea permanente, actualizar `bridge_mappings` en el agente para que apunte a `br-vlan`:

```bash
# Verificar el mapeo actual (debe ser provider:br-provider, eso no cambia):
grep bridge_mappings /etc/neutron/plugins/ml2/openvswitch_agent.ini
# El mapeo lógico sigue siendo provider:br-provider (OVS bridge)
# Lo que cambia es el uplink físico de br-provider: pasa de enp8s0 a br-vlan
# Esto se controla solo con el cambio de OVS del paso 3.2
```
