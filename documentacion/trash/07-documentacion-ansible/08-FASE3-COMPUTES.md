# Fase 3 — Computes con Ansible

> **Objetivo:** Entender el playbook `computes.yml` y el role `nova-compute`.

---

## ¿Qué hace el role `nova-compute`?

En orden de ejecución:

```
1. Instalar paquetes (nova-compute, qemu-kvm, libvirt...)
2. Crear override de libvirtd (sin --timeout 120)
3. Borrar compute_id heredado de clone (si existe)
4. Generar nova.conf desde template (con mgmt_ip real, sin $my_ip literal)
5. Arrancar libvirtd
6. Arrancar nova-compute
```

---

## El bug del clone: `$my_ip` literal en nova.conf

Cuando clonamos compute1 para crear compute2/3/4, heredaron el `nova.conf` de compute1. El problema: en la sección `[vnc]`:

```ini
# nova.conf en compute2 heredado (BUGGY)
[vnc]
server_proxyclient_address = $my_ip   ← LITERAL, no la IP 10.0.0.12
```

Nova interpreta `$my_ip` como variable de entorno shell, que en el contexto del proceso nova-compute tiene el valor incorrecto (vacío o la IP de compute1).

**El template Ansible genera el valor correcto para cada nodo:**

```ini
# nova.conf generado por Ansible para compute2
[vnc]
server_proxyclient_address = 10.0.0.12   ← IP real de br-mgmt de compute2
```

Esto es imposible de hacer correctamente con `sed` de forma genérica. Ansible lo resuelve con un template que tiene acceso a todas las variables del host.

---

## El bug de libvirtd: `--timeout 120`

Ubuntu instala libvirtd con un ExecStart que incluye `--timeout 120`:

```ini
# /lib/systemd/system/libvirtd.service (default Ubuntu)
[Service]
ExecStart=/usr/sbin/libvirtd --timeout 120
```

El `--timeout 120` significa: "si en 120 segundos ningún cliente (nova-compute) se conecta, ciérrate". En una VM lenta o con muchos servicios arrancando simultáneamente, nova-compute puede tardar más de 2 minutos en conectar a libvirtd → libvirtd se cierra → nova-compute falla → ciclo infinito.

**El role `nova-compute` crea un override de systemd:**

```yaml
- name: Override de libvirtd — eliminar --timeout 120
  copy:
    dest: /etc/systemd/system/libvirtd.service.d/override.conf
    content: |
      [Service]
      ExecStart=
      ExecStart=/usr/sbin/libvirtd
```

La línea `ExecStart=` vacía **borra** el ExecStart anterior (comportamiento de systemd drop-in). La segunda línea establece el nuevo ExecStart sin `--timeout`.

---

## El bug del UUID duplicado: `compute_id`

Nova asigna un UUID único a cada nodo compute en `/var/lib/nova/compute_id`. Este UUID identifica el nodo en la base de datos de Nova.

Si compute2 fue clonado de compute1, heredó el fichero `compute_id` de compute1. Cuando nova-compute arranca en compute2, intenta registrarse con el UUID de compute1 → Nova rechaza el registro porque ese UUID ya está en uso.

**El role lo borra antes de arrancar nova-compute:**

```yaml
- name: Borrar compute_id heredado del clone
  file:
    path: /var/lib/nova/compute_id
    state: absent
  notify: reiniciar nova-compute
```

Nova genera un nuevo UUID al arrancar nova-compute si el fichero no existe.

---

## El role `neutron-ovs-agent` y la configuración `bridge_mappings`

La configuración más crítica del agente OVS es `bridge_mappings`:

```ini
# En /etc/neutron/plugins/ml2/openvswitch_agent.ini
[ovs]
bridge_mappings = provider:br-provider
```

Esto le dice al agente: "la red Neutron llamada `provider` (flat) se gestiona a través del bridge OVS `br-provider`".

**¿Por qué `provider` (sin guion) y no `provider-net`?**

`provider-net` es el **nombre de la red** en Neutron (lo que ves en `openstack network list`). `provider` es el **nombre del Physical Network** en la configuración ML2 — es el nombre lógico que aparece en:

```ini
# /etc/neutron/plugins/ml2/ml2_conf.ini en el controller
[ml2_type_flat]
flat_networks = provider
```

Son dos identificadores diferentes. El `bridge_mappings` debe usar el nombre lógico de ML2 (`provider`), no el nombre de la red Neutron (`provider-net`).

---

## Flujo completo de la creación de una VM (para entender qué configura Ansible)

```
Usuario → openstack server create --network selfservice-net --flavor m1.small ...
    │
    ▼
Nova API (controller) → recibe la petición
    │
    ▼ RabbitMQ
Nova Conductor (controller) → orquesta el proceso
    │
    ▼ Nova Scheduler
Selecciona compute3 (tiene más RAM libre)
    │
    ▼ RabbitMQ → compute3
nova-compute (compute3) → recibe orden de crear VM
    │
    ├─ Pide a Neutron: crea un puerto en selfservice-net para esta VM
    │   Neutron → crea puerto en MariaDB → manda mensaje a neutron-ovs-agent
    │   neutron-ovs-agent (compute3) → configura OVS:
    │       - crea tap interface en br-int
    │       - asigna VNI 640 al tráfico de esa VM
    │       - configura túnel VXLAN hacia el controller (para L3)
    │
    └─ Llama a libvirtd via API libvirt:
        libvirtd → crea el XML de la VM → qemu-kvm arranca la VM
        La VM arranca, DHCP le da IP 10.10.10.x
```

**Lo que Ansible configura en este flujo:**
- `nova.conf` correcto → nova-compute puede comunicar con Nova API y RabbitMQ
- `openvswitch_agent.ini` correcto → neutron-ovs-agent sabe a qué bridge conectar
- `br-provider` con `br-vlan` → el tráfico flat puede salir al host
- Override libvirtd → libvirtd no se cierra mientras nova-compute arranca

---

## Ejecutar el playbook de computes

```bash
cd documentacion_ansible/ansible/

# Dry-run:
ansible-playbook playbooks/computes.yml --check

# Solo en compute1:
ansible-playbook playbooks/computes.yml --limit compute1

# Todos los computes:
ansible-playbook playbooks/computes.yml

# Solo verificar servicios:
ansible-playbook playbooks/verify.yml --limit compute
```

---

## Verificar manualmente tras la fase

```bash
# Estado de servicios en todos los computes
for ip in 240 241 242 243; do
  echo "=== compute (203.0.113.$ip) ==="
  ssh uceda@203.0.113.$ip "echo asdfghjkl | sudo -S systemctl is-active nova-compute neutron-openvswitch-agent libvirtd"
done

# Desde el controller: verificar que los computes están registrados
ssh uceda@203.0.113.239 "echo asdfghjkl | sudo -S bash -c '
  source /root/admin-openrc
  openstack compute service list
  openstack hypervisor list
'"
```

---

## Siguiente paso

Lee [09-EJECUCION.md](09-EJECUCION.md) para ver cómo instalar Ansible y ejecutar el proyecto completo.
