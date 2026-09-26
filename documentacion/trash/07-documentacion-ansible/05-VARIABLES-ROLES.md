# Variables, Roles y Templates — Guía detallada

> **Objetivo:** Entender cómo fluyen los datos desde el inventario hasta los ficheros de configuración generados en los nodos.

---

## Precedencia de variables en Ansible

Ansible tiene más de 20 niveles de precedencia. Los más relevantes para este proyecto (de menor a mayor prioridad):

```
1. defaults/main.yml del role          ← MÁS FÁCIL de sobreescribir
2. inventory/group_vars/all.yml
3. inventory/group_vars/<grupo>.yml    (ej. compute.yml)
4. inventory/hosts.yml (vars de host)
5. vars/main.yml del role
6. vars: en el playbook
7. --extra-vars (-e) en línea de cmd   ← MÁS DIFÍCIL de sobreescribir
```

**Ejemplo práctico:**

```yaml
# roles/linux-bridges/defaults/main.yml
bridge_stp: false          # Valor por defecto del role

# inventory/group_vars/all.yml
bridge_stp: false          # Sobreescribe el default (mismo valor, sin cambio)

# Si en algún nodo quisieras STP activado:
# inventory/host_vars/compute1.yml
bridge_stp: true           # Sobreescribe para compute1 solamente
```

---

## El role `linux-bridges` — completo

### `roles/linux-bridges/defaults/main.yml`

```yaml
# Valores por defecto — sobreescribibles desde group_vars o host_vars

# Interfaz física para br-mgmt
mgmt_interface: enp7s0
# Interfaz física para br-vlan
provider_interface: enp8s0
# Ruta del fichero netplan a generar
netplan_file: /etc/netplan/50-cloud-init.yaml
# STP desactivado (sin bucles en este lab)
bridge_stp: false
bridge_forward_delay: 0
```

### `roles/linux-bridges/tasks/main.yml`

```yaml
---
- name: Generar fichero netplan con Linux bridges
  template:
    src: netplan.yaml.j2         # Plantilla Jinja2
    dest: "{{ netplan_file }}"   # /etc/netplan/50-cloud-init.yaml
    owner: root
    group: root
    mode: '0600'                 # netplan requiere permisos restrictivos
  notify: aplicar netplan        # Solo reinicia si el fichero cambió

- name: Asegurar que br-mgmt tiene el MAC correcto (fix KVM)
  command: "ip link set br-mgmt address {{ mgmt_mac }}"
  changed_when: false            # No marcar como "changed" (es idempotente por sí solo)
  when: mgmt_mac is defined      # Solo si la variable mgmt_mac existe para este host
```

### `roles/linux-bridges/handlers/main.yml`

```yaml
---
- name: aplicar netplan
  command: netplan apply
  # Este handler se ejecuta UNA SOLA VEZ al final del play
  # si una o más tasks lo notificaron con "notify: aplicar netplan"
```

> **¿Por qué `netplan apply` en un handler y no en una task normal?**
> Si el fichero netplan no cambia (segunda ejecución), la task `template` no notifica
> al handler → `netplan apply` NO se ejecuta → más rápido y sin interrupciones de red.

### `roles/linux-bridges/templates/netplan.yaml.j2`

```jinja2
{# Template Jinja2 para netplan
   Las variables {{ }} se resuelven con valores del host específico
   Los comentarios {# #} no aparecen en el fichero generado #}
network:
  version: 2
  ethernets:
    {{ public_interface }}:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: ["{{ public_ip }}/{{ public_prefix }}"]
      routes:
        - to: default
          via: {{ public_gateway }}
      nameservers:
        addresses: {{ nameservers | to_yaml | trim }}
    {{ mgmt_interface }}:
      dhcp4: false
      dhcp6: false
      link-local: []
    {{ provider_interface }}:
      dhcp4: false
      dhcp6: false
      link-local: []
  bridges:
    br-mgmt:
      dhcp4: false
      dhcp6: false
      link-local: []
      macaddress: "{{ mgmt_mac }}"
      addresses: ["{{ mgmt_ip }}/{{ mgmt_prefix }}"]
      interfaces: ["{{ mgmt_interface }}"]
      parameters:
        stp: {{ bridge_stp | lower }}
        forward-delay: {{ bridge_forward_delay }}
    br-vlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      interfaces: ["{{ provider_interface }}"]
      parameters:
        stp: {{ bridge_stp | lower }}
        forward-delay: {{ bridge_forward_delay }}
    br-vxlan:
      dhcp4: false
      dhcp6: false
      link-local: []
      parameters:
        stp: {{ bridge_stp | lower }}
        forward-delay: {{ bridge_forward_delay }}
```

**¿Qué genera este template para compute1?**

```yaml
# Generado en compute1 (mgmt_ip=10.0.0.10, mgmt_mac=52:54:00:25:40:01)
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: ["203.0.113.240/24"]
      routes:
        - to: default
          via: 203.0.113.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
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
      macaddress: "52:54:00:25:40:01"
      addresses: ["10.0.0.10/24"]
      interfaces: ["enp7s0"]
      parameters:
        stp: false
        forward-delay: 0
    br-vlan:
      interfaces: ["enp8s0"]
      parameters:
        stp: false
        forward-delay: 0
    br-vxlan:
      parameters:
        stp: false
        forward-delay: 0
```

**El mismo template en compute4 genera** (con `mgmt_ip=10.0.0.14`, `mgmt_mac=52:54:00:d4:e5:b7`):

```yaml
    br-mgmt:
      macaddress: "52:54:00:d4:e5:b7"
      addresses: ["10.0.0.14/24"]
```

Un solo template, 5 ficheros diferentes, 0 copiar-pegar.

---

## El role `ovs-bridges`

### `roles/ovs-bridges/tasks/main.yml`

```yaml
---
- name: Asegurar que br-provider existe en OVS
  openvswitch_bridge:
    bridge: "{{ neutron_provider_bridge }}"
    state: present
    fail_mode: secure
  notify: reiniciar neutron-openvswitch-agent

- name: Asegurar que br-vlan es el uplink de br-provider
  openvswitch_port:
    bridge: "{{ neutron_provider_bridge }}"
    port: "{{ neutron_provider_uplink_bridge }}"
    state: present
  notify: reiniciar neutron-openvswitch-agent
```

> **`fail_mode: secure`**: Si OVS pierde la conexión con el controlador OpenFlow (neutron-ovs-agent), los flujos existentes se mantienen pero no se añaden nuevos. Es el modo correcto para OpenStack.

### `roles/ovs-bridges/handlers/main.yml`

```yaml
---
- name: reiniciar neutron-openvswitch-agent
  service:
    name: neutron-openvswitch-agent
    state: restarted
```

---

## El role `nova-compute`

### `roles/nova-compute/tasks/main.yml`

```yaml
---
- name: Instalar nova-compute
  apt:
    name:
      - nova-compute
      - nova-compute-kvm
      - qemu-kvm
      - libvirt-daemon-system
    state: present
    update_cache: true

- name: Configurar nova.conf en los computes
  template:
    src: nova.conf.j2
    dest: /etc/nova/nova.conf
    owner: nova
    group: nova
    mode: '0640'
  notify: reiniciar nova-compute

- name: Override de libvirtd (eliminar --timeout 120)
  # El --timeout 120 hace que libvirtd se cierre si nova-compute no
  # conecta en 2 min. Esto causa fallos si nova-compute tarda en arrancar.
  copy:
    dest: /etc/systemd/system/libvirtd.service.d/override.conf
    content: "{{ libvirtd_override_content }}"
    owner: root
    group: root
    mode: '0644'
  notify:
    - reload systemd
    - reiniciar libvirtd

- name: Asegurar nova-compute habilitado y activo
  service:
    name: nova-compute
    state: started
    enabled: true
```

### `roles/nova-compute/templates/nova.conf.j2`

```ini
[DEFAULT]
# my_ip es la IP de gestión del nodo (br-mgmt)
# CRÍTICO: debe ser un valor literal, no la variable $my_ip
# (que es un bug heredado de clone que rompe VNC)
my_ip = {{ mgmt_ip }}
transport_url = rabbit://{{ rabbitmq_user }}:{{ rabbitmq_password }}@{{ controller_fqdn }}:5672/

[api]
auth_strategy = keystone

[keystone_authtoken]
www_authenticate_uri = http://{{ controller_fqdn }}:5000
auth_url = http://{{ controller_fqdn }}:5000
memcached_servers = {{ controller_mgmt_ip }}:{{ memcached_port }}
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = {{ openstack_admin_password }}

[vnc]
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = {{ mgmt_ip }}
novncproxy_base_url = http://{{ controller_public_ip }}:6080/vnc_lite.html

[glance]
api_servers = http://{{ controller_fqdn }}:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[placement]
region_name = {{ openstack_region }}
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://{{ controller_fqdn }}:5000/v3
username = placement
password = {{ openstack_admin_password }}

[libvirt]
virt_type = {{ nova_virt_type }}
cpu_mode = {{ nova_cpu_mode }}
```

---

## El role `neutron-ovs-agent`

### `roles/neutron-ovs-agent/templates/openvswitch_agent.ini.j2`

```ini
[ovs]
# bridge_mappings: nombre lógico de la red → bridge OVS
# "provider:br-provider" = la red llamada "provider" usa el bridge OVS br-provider
bridge_mappings = {{ neutron_bridge_mappings }}

# local_ip: IP de este nodo usada como extremo de los túneles VXLAN
# Debe ser la IP de br-mgmt (la red de administración, 10.0.0.x)
local_ip = {{ neutron_local_ip }}

[agent]
tunnel_types = vxlan
l2_population = true

[securitygroup]
enable_security_group = true
firewall_driver = openvswitch
```

---

## Filtros Jinja2 útiles

En los templates puedes usar **filtros** para transformar variables:

```jinja2
{{ bridge_stp | lower }}             # false → "false" (minúsculas)
{{ nameservers | to_yaml | trim }}   # lista Python → YAML inline
{{ mgmt_ip | default('10.0.0.1') }}  # valor por defecto si la var no existe
{{ nova_virt_type | upper }}         # "kvm" → "KVM"
{{ mgmt_mac | regex_replace(':', '-') }}  # reemplazar : por -
```

---

## Siguiente paso

Lee [06-FASE1-BRIDGES.md](06-FASE1-BRIDGES.md) para ver el playbook completo de la Fase 1 (Linux bridges).
