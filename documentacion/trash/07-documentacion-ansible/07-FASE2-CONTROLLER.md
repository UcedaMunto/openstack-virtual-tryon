# Fase 2 — Verificar y Gestionar el Controller con Ansible

> **Objetivo:** Entender qué hace Ansible en el controller y por qué es diferente a los computes.

---

## El controller es diferente a los computes

El controller no instala nova-compute — instala los servicios de **control**:

| Servicio | Función | Puerto |
|---------|---------|--------|
| **Keystone** | Autenticación y autorización de todos los servicios | 5000 |
| **Glance** | Catálogo de imágenes (cirros, Ubuntu, etc.) | 9292 |
| **Nova API / Conductor / Scheduler** | Recibe peticiones de crear VMs, decide en qué compute se crean | 8774 |
| **Nova NoVNC Proxy** | Proxy para las consolas gráficas de las VMs | 6080 |
| **Placement** | Inventario de recursos (CPUs, RAM) disponibles | 8778 |
| **Neutron Server** | API de redes, gestiona la base de datos de redes/subnets/puertos | 9696 |
| **Neutron L3 Agent** | Router virtual (NAT, Floating IPs) | — |
| **Neutron DHCP Agent** | Servidor DHCP para las redes de instancias | — |
| **Neutron OVS Agent** | Configura OVS en el controller (para el router L3) | — |
| **Horizon** | Panel web | 80 |
| **MariaDB** | Base de datos de todos los servicios | 3306 |
| **RabbitMQ** | Bus de mensajes entre servicios (Nova, Neutron) | 5672 |
| **Memcached** | Caché de tokens Keystone | 11211 |

---

## ¿Cuándo usar Ansible en el controller?

En este laboratorio **el controller ya está instalado y funcionando**. El rol de Ansible para el controller es principalmente de **gestión y verificación idempotente**, no de instalación desde cero.

Los casos de uso reales:

1. **Verificar estado** del cluster (todos los servicios UP).
2. **Registrar nuevos computes** (`nova-manage cell_v2 discover_hosts`).
3. **Modificar configuración** (cambiar rabbit password, añadir red, etc.).
4. **Recrear el controller** desde cero si se reinstalara.

---

## Playbook del controller — `controller.yml`

```yaml
---
# playbooks/controller.yml
# Verificación y gestión de servicios del controller

- name: Verificar y gestionar el controller OpenStack
  hosts: controller
  become: true
  tasks:
    # ── Verificar que los servicios esenciales están activos ─────────────────
    - name: Recopilar facts de servicios
      service_facts:

    - name: Verificar servicios del controller
      assert:
        that: "ansible_facts.services['{{ item }}.service'].state == 'running'"
        fail_msg: "Servicio {{ item }} NO está activo"
        success_msg: "{{ item }} OK"
      loop:
        - keystone
        - glance-api
        - nova-api
        - nova-conductor
        - nova-scheduler
        - neutron-server
        - neutron-l3-agent
        - neutron-dhcp-agent
        - neutron-openvswitch-agent
        - apache2
        - mariadb
        - rabbitmq-server
        - memcached

    # ── Descubrir nuevos computes (discover_hosts) ───────────────────────────
    - name: Ejecutar discover_hosts para registrar computes
      command: nova-manage cell_v2 discover_hosts --verbose
      register: discover_result
      changed_when: "'Found' in discover_result.stdout"
      # Solo marca "changed" si encontró nuevos hosts — idempotente

    - name: Mostrar resultado de discover_hosts
      debug:
        msg: "{{ discover_result.stdout_lines }}"

    # ── Verificar desde la API OpenStack ────────────────────────────────────
    - name: Listar compute services via API
      command: "bash -c 'source {{ admin_openrc_path }} && openstack compute service list -f table'"
      register: compute_services
      changed_when: false

    - name: Mostrar compute services
      debug:
        msg: "{{ compute_services.stdout_lines }}"

    - name: Listar hypervisors
      command: "bash -c 'source {{ admin_openrc_path }} && openstack hypervisor list -f table'"
      register: hypervisors
      changed_when: false

    - name: Mostrar hypervisors
      debug:
        msg: "{{ hypervisors.stdout_lines }}"

    - name: Listar network agents
      command: "bash -c 'source {{ admin_openrc_path }} && openstack network agent list -f table'"
      register: network_agents
      changed_when: false

    - name: Mostrar network agents
      debug:
        msg: "{{ network_agents.stdout_lines }}"
```

---

## Los servicios del controller y sus dependencias

El orden de arranque importa. Si vas a reiniciar servicios, hazlo en este orden:

```
1. mariadb        ← Base de datos (todos dependen de ella)
2. rabbitmq-server ← Bus de mensajes (nova, neutron dependen de él)
3. memcached      ← Caché de tokens
4. keystone       ← Autenticación (todos dependen de Keystone)
5. glance-api     ← Imágenes
6. placement-api  ← Recursos
7. nova-api       ← API de cómputo
8. nova-conductor ← Orquestación interna de Nova
9. nova-scheduler ← Selección de compute para nuevas VMs
10. neutron-server ← API de redes
11. neutron-*-agent ← Agentes de red
12. apache2       ← Keystone, Horizon (a través de mod_wsgi)
```

**¿Por qué MariaDB primero?**

Todos los servicios OpenStack almacenan estado en MariaDB. Al arrancar, cada servicio conecta a MariaDB para leer/verificar su esquema. Si MariaDB no está, el servicio falla inmediatamente.

**¿Por qué RabbitMQ antes que Nova?**

Nova usa RabbitMQ como bus de mensajes para comunicar:
- `nova-api` → `nova-conductor` (crear VM)
- `nova-conductor` → `nova-compute` en el nodo elegido
- `nova-compute` → `neutron-server` (crear puerto de red para la VM)

Si RabbitMQ no está, Nova no puede enviar mensajes y todas las operaciones de VM fallan.

---

## El concepto de Cell v2 en Nova

**¿Qué es una celda (cell) en Nova?**

Nova organiza los computes en "celdas" para escalar a miles de nodos. En instalaciones pequeñas como esta, solo existe `cell1`.

```
Nova Cell v2
├── cell0 (computes muertos/fallidos van aquí)
└── cell1 (los 4 computes activos)
      ├── compute1
      ├── compute2
      ├── compute3
      └── compute4
```

**¿Por qué `nova-manage cell_v2 discover_hosts`?**

Cuando un compute arranca `nova-compute` por primera vez, se registra en RabbitMQ. Pero Nova no lo añade automáticamente a la cell — hay que ejecutar `discover_hosts` para que Nova busque en RabbitMQ los nuevos computes y los añada a `cell1`.

Ansible puede automatizar esto:
```yaml
- name: Registrar nuevos computes en Nova
  command: nova-manage cell_v2 discover_hosts --verbose
  changed_when: "'Found' in discover_result.stdout"
```

Con `changed_when`, Ansible:
- Muestra `ok` si no hay computes nuevos (re-ejecución segura).
- Muestra `changed` si encuentra y registra computes nuevos.

---

## Ejecutar el playbook del controller

```bash
cd documentacion_ansible/ansible/

# Solo verificación (safe, no cambia nada):
ansible-playbook playbooks/verify.yml --limit controller

# Gestión completa del controller:
ansible-playbook playbooks/controller.yml

# Solo la tarea de discover_hosts:
ansible-playbook playbooks/controller.yml --tags discover
```

---

## Siguiente paso

Lee [08-FASE3-COMPUTES.md](08-FASE3-COMPUTES.md) para el playbook de los computes.
