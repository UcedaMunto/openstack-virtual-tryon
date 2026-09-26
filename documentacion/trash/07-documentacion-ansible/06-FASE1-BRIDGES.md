# Fase 1 — Linux Bridges y OVS con Ansible

> **Objetivo:** Entender el playbook `bridges.yml` línea a línea y cómo funciona  
> el role `linux-bridges` + `ovs-bridges` contra el cluster real.

---

## ¿Qué hace esta fase?

Asegura que en todos los nodos existe:

1. `br-mgmt` — bridge Linux con `enp7s0` + IP de gestión (`10.0.0.x/24`)
2. `br-vlan` — bridge Linux con `enp8s0` + sin IP
3. `br-vxlan` — bridge Linux software (sin NIC) + UP
4. OVS `br-provider` — con `br-vlan` como uplink

**Estado del cluster antes de esta fase** (cluster recién instalado):
- `enp7s0` tiene la IP directamente
- `enp8s0` está en OVS directamente
- No hay `br-mgmt`, `br-vlan`, `br-vxlan`

**Estado después de esta fase** (lo que hicimos manualmente en la guía 06):
- IPs movidas a los bridges
- OVS actualizado

---

## El playbook `bridges.yml` explicado

```yaml
# playbooks/bridges.yml
---
- name: Configurar Linux bridges en los computes
  hosts: compute          # ← Los 4 computes en paralelo
  become: true
  roles:
    - role: linux-bridges   # ← Crea/actualiza el fichero netplan
    - role: ovs-bridges     # ← Asegura br-provider con br-vlan
```

**¿Por qué computes primero y controller al final?**

Si algo sale mal en la configuración de un compute, el controller sigue funcionando. Podemos depurar el problema y corregirlo antes de tocar el nodo más crítico. El controller aloja todos los servicios de control (Keystone, MariaDB, RabbitMQ) — si se cae, todo el cluster pierde comunicación.

---

## El role `linux-bridges` paso a paso

### Task 1: Generar el netplan

```yaml
- name: Generar fichero netplan con Linux bridges
  template:
    src: netplan.yaml.j2
    dest: /etc/netplan/50-cloud-init.yaml
    mode: '0600'
  notify: aplicar netplan
```

Ansible:
1. Carga la plantilla `netplan.yaml.j2`.
2. Sustituye todas las variables `{{ }}` con los valores del host actual.
3. **Compara el resultado con el fichero en el nodo.**
4. Si son iguales → `ok` (no hace nada, no notifica handler).
5. Si son diferentes → sobreescribe el fichero → `changed` → notifica al handler.

**El handler `aplicar netplan`:**

```yaml
- name: aplicar netplan
  command: netplan apply
```

Se ejecuta SOLO si el template cambió. Si el netplan ya era correcto, el handler no se ejecuta y no hay interrupción de red.

### Task 2: Forzar MAC en br-mgmt

```yaml
- name: Forzar MAC de br-mgmt al MAC de la NIC física
  command: "ip link set br-mgmt address {{ mgmt_mac }}"
  when: mgmt_mac is defined
```

Como vimos en la guía 06, Linux bridges pueden tomar MAC aleatorio. Esta task lo corrige siempre.

> **`changed_when: false`**: Este comando no cambia estado de forma que Ansible pueda detectar, pero es idempotente (fijar el mismo MAC dos veces no cambia nada). Le decimos a Ansible que siempre lo marque como "ok".

### Task 3: Levantar br-vxlan

```yaml
- name: Asegurar que br-vxlan está UP
  command: ip link set br-vxlan up
  changed_when: false
```

`br-vxlan` no tiene NIC física, así que el kernel puede dejarlo DOWN. Esta task lo levanta. No tiene `notify` porque un bridge UP no necesita reiniciar ningún servicio.

---

## El role `ovs-bridges` paso a paso

### El módulo `openvswitch_bridge`

```yaml
- name: Asegurar que br-provider existe en OVS
  openvswitch_bridge:
    bridge: br-provider
    state: present
    fail_mode: secure
```

Este módulo ejecuta internamente `ovs-vsctl show` para comprobar si `br-provider` existe:
- Si existe → `ok`
- Si no existe → `ovs-vsctl add-br br-provider` → `changed`

Elimina completamente el problema de `ovs-vsctl add-br br-provider` fallando con "already exists".

> **Prerequisito:** Necesita tener instalado el paquete Python `python3-openvswitch` o que la colección `ansible.netcommon` esté instalada. En Ubuntu 24.04 el módulo viene en el paquete `python3-openvswitch`.

### El módulo `openvswitch_port`

```yaml
- name: Asegurar que br-vlan es uplink de br-provider
  openvswitch_port:
    bridge: br-provider
    port: br-vlan
    state: present
```

Comprueba si `br-vlan` es un puerto de `br-provider`:
- Si está → `ok`
- Si no está → `ovs-vsctl add-port br-provider br-vlan` → `changed`

---

## Qué genera el template para cada nodo

| Variable | compute1 | compute2 | compute3 | compute4 | controller |
|----------|---------|---------|---------|---------|-----------|
| `public_ip` | 203.0.113.240 | 203.0.113.241 | 203.0.113.242 | 203.0.113.243 | 203.0.113.239 |
| `mgmt_ip` | 10.0.0.10 | 10.0.0.12 | 10.0.0.13 | 10.0.0.14 | 10.0.0.11 |
| `mgmt_mac` | 52:54:00:25:40:01 | 52:54:00:d4:e5:f6 | 52:54:00:d4:e5:a6 | 52:54:00:d4:e5:b7 | 52:54:00:99:07:38 |

---

## Ejecutar esta fase

```bash
cd documentacion_ansible/ansible/

# Dry-run primero (no aplica cambios):
ansible-playbook playbooks/bridges.yml --check

# Ejecutar solo en compute1 para probar:
ansible-playbook playbooks/bridges.yml --limit compute1

# Ejecutar en todos:
ansible-playbook playbooks/bridges.yml

# Ejecutar solo la parte OVS (tag):
ansible-playbook playbooks/bridges.yml --tags ovs
```

---

## Verificación manual tras la fase

```bash
# Desde el laptop, verificar bridges en compute1:
ssh uceda@203.0.113.240 "echo asdfghjkl | sudo -S bash -c '
  ip -br addr | grep -E \"enp|br-\"
  bridge link show
  ovs-vsctl list-ports br-provider
  ping -c2 10.0.0.11
'"
```

**Salida esperada:**
```
enp1s0  UP  203.0.113.240/24
enp7s0  UP
enp8s0  UP
br-mgmt UP  10.0.0.10/24
br-vlan UP
br-vxlan UNKNOWN (o UP)

enp7s0 master br-mgmt forwarding
enp8s0 master br-vlan forwarding

br-vlan
phy-br-provider

64 bytes from 10.0.0.11: icmp_seq=1 ttl=64 time=0.3 ms
```

---

## Siguiente paso

Lee [07-FASE2-CONTROLLER.md](07-FASE2-CONTROLLER.md) para entender el playbook del controller.
