# Conceptos de Ansible — Guía desde cero con contexto OpenStack

> **Objetivo:** Entender Ansible antes de tocar un solo fichero de código.  
> Todo se explica con ejemplos concretos de **este** cluster.

---

## ¿Qué es Ansible?

Ansible es una herramienta de **automatización de infraestructura** que permite:
- Instalar software en múltiples servidores a la vez.
- Cambiar configuraciones de forma repetible y segura.
- Orquestar el orden en que ocurren las cosas.

**¿Cómo funciona a bajo nivel?**

```
Tu laptop (nodo de control)
        │
        │  SSH  (puerto 22)
        │
        ├──────────────► controller (203.0.113.239)
        ├──────────────► compute1   (203.0.113.240)
        ├──────────────► compute2   (203.0.113.241)
        ├──────────────► compute3   (203.0.113.242)
        └──────────────► compute4   (203.0.113.243)
```

Ansible se conecta por SSH a cada nodo, copia un pequeño programa Python temporal, lo ejecuta, y devuelve el resultado. **No hay agentes** — los nodos no necesitan tener Ansible instalado, solo Python 3 y SSH.

---

## Los 6 bloques fundamentales de Ansible

### 1. Inventario (Inventory)

El inventario responde: **"¿a qué máquinas voy a hablar?"**

```yaml
# inventory/hosts.yml
all:
  children:
    controller:
      hosts:
        serverocontroller:
          ansible_host: 203.0.113.239
    compute:
      hosts:
        compute1:
          ansible_host: 203.0.113.240
        compute2:
          ansible_host: 203.0.113.241
```

- `all` es el grupo raíz que incluye todo.
- `controller` y `compute` son **grupos** — puedes ejecutar un playbook solo contra un grupo.
- `ansible_host` es la IP real con la que conectar (el nombre puede ser un alias).

**¿Por qué grupos?** Porque el controller necesita Keystone, Nova API, Glance... mientras que los computes solo necesitan nova-compute y neutron-ovs-agent. Los grupos permiten aplicar tareas diferentes a conjuntos diferentes de nodos.

---

### 2. Playbook

El playbook responde: **"¿qué quiero hacer?"**

```yaml
# playbooks/bridges.yml
---
- name: Configurar Linux bridges en todos los nodos    # ← nombre descriptivo
  hosts: all                                           # ← a quién se aplica
  become: true                                         # ← ejecutar como root (sudo)
  roles:
    - linux-bridges                                    # ← qué role ejecutar
```

Un playbook es un fichero YAML que contiene uno o más **plays**. Cada play define:
- `hosts:` — a qué grupo/nodo del inventario se aplica.
- `become: true` — usar `sudo` para tener privilegios.
- `roles:` / `tasks:` — qué trabajo hacer.

**Estructura de un playbook con múltiples plays:**

```yaml
---
# Play 1: primero los computes
- name: Configurar bridges en computes
  hosts: compute
  become: true
  roles:
    - linux-bridges

# Play 2: luego el controller
- name: Configurar bridges en controller
  hosts: controller
  become: true
  roles:
    - linux-bridges
```

Esto garantiza el orden: primero los 4 computes en paralelo, luego el controller.

---

### 3. Task (Tarea)

La task responde: **"acción concreta a ejecutar"**

```yaml
- name: Asegurar que br-provider tiene br-vlan como puerto
  openvswitch_port:
    bridge: br-provider
    port: br-vlan
    state: present          # ← "present" = créalo si no existe, no hagas nada si ya existe
```

Cada task usa un **módulo** — una unidad de funcionalidad de Ansible. En lugar de escribir:
```bash
ovs-vsctl add-port br-provider br-vlan   # falla si ya existe
```
Usas el módulo `openvswitch_port` que sabe comprobar si ya está antes de intentar crearlo.

**Módulos clave para este proyecto:**

| Módulo | Para qué sirve | Ejemplo de uso |
|--------|---------------|----------------|
| `apt` | Instalar paquetes Debian/Ubuntu | Instalar nova-compute |
| `template` | Copiar fichero con variables sustituidas | Generar netplan |
| `service` | Arrancar/parar/reiniciar servicios | Reiniciar neutron-openvswitch-agent |
| `command` / `shell` | Ejecutar comandos arbitrarios (último recurso) | netplan apply |
| `openvswitch_bridge` | Crear/borrar OVS bridges | Crear br-provider |
| `openvswitch_port` | Añadir/quitar puertos de OVS bridges | Añadir br-vlan a br-provider |
| `lineinfile` | Añadir/modificar una línea en un fichero | Fijar `virt_type = kvm` |
| `blockinfile` | Insertar un bloque de texto en un fichero | Añadir sección [vnc] |
| `copy` | Copiar fichero estático al nodo | Copiar admin-openrc |
| `file` | Crear directorios, cambiar permisos | Crear /etc/nova/ |
| `ini_file` | Modificar ficheros .ini (como nova.conf) | Configurar nova.conf |
| `wait_for` | Esperar a que un puerto esté abierto | Esperar a que RabbitMQ esté listo |
| `uri` | Hacer peticiones HTTP | Verificar que Keystone responde |

---

### 4. Handler

Un handler responde: **"acción que se ejecuta solo si algo cambió"**

```yaml
tasks:
  - name: Copiar configuración de nova-compute
    template:
      src: nova.conf.j2
      dest: /etc/nova/nova.conf
    notify: restart nova-compute         # ← "avisa" al handler si hubo cambio

handlers:
  - name: restart nova-compute
    service:
      name: nova-compute
      state: restarted
```

**¿Por qué handlers y no simplemente `systemctl restart` en cada task?**

1. Si copias nova.conf y nova.conf **no cambió** (porque ya era correcto), Ansible no notifica al handler → el servicio **no se reinicia innecesariamente**.
2. Si varias tasks modifican nova.conf, el handler se ejecuta **solo una vez** al final del play, no después de cada task.

Esto es idempotencia inteligente.

---

### 5. Variables

Las variables responden: **"¿qué valores concretos usar?"**

Existen varios lugares donde definir variables (orden de precedencia, de menos a más):

```
defaults/main.yml      (role — valores por defecto, fácilmente sobreescritos)
group_vars/all.yml     (para todos los hosts)
group_vars/compute.yml (solo para el grupo compute)
host_vars/compute1.yml (solo para compute1)
playbook vars:         (en el propio playbook)
extra_vars (-e)        (línea de comandos — máxima prioridad)
```

**Ejemplo concreto para nuestro cluster:**

```yaml
# group_vars/all.yml
openstack_admin_password: icc115
rabbitmq_host: 10.0.0.11
memcached_host: 10.0.0.11

# group_vars/compute.yml
nova_virt_type: kvm
neutron_bridge_mappings: "provider:br-provider"
neutron_local_ip: "{{ mgmt_ip }}"   # ← mgmt_ip se define en host_vars
```

```yaml
# host_vars/compute1.yml
mgmt_ip: 10.0.0.10
public_ip: 203.0.113.240
```

**Variables especiales de Ansible (facts):**

Ansible recopila automáticamente información del nodo cuando ejecuta un playbook:
```yaml
ansible_facts['default_ipv4']['address']   # IP de la interfaz por defecto
ansible_facts['hostname']                  # Nombre del host
ansible_facts['distribution']              # Ubuntu
ansible_facts['os_family']                 # Debian
```

Para ver todos los facts de un nodo:
```bash
ansible compute1 -m setup -i inventory/hosts.yml
```

---

### 6. Roles

Un role responde: **"agrupación de tasks, handlers, variables y templates con un propósito"**

Un role es una carpeta con una estructura estándar:

```
roles/
  linux-bridges/
    tasks/
      main.yml          ← Tareas del role (se ejecutan en orden)
    handlers/
      main.yml          ← Handlers (reiniciar servicios tras cambios)
    templates/
      netplan.yaml.j2   ← Plantilla Jinja2 del fichero netplan
    defaults/
      main.yml          ← Variables por defecto del role
    vars/
      main.yml          ← Variables fijas del role (alta prioridad)
    files/
      (ficheros estáticos si los hay)
```

Los roles son **reutilizables y portables**. El role `linux-bridges` puede aplicarse al controller y a todos los computes, con la única diferencia de las variables (IP, nombre de nodo).

---

## Flujo completo de ejecución

```
ansible-playbook -i inventory/hosts.yml playbooks/bridges.yml
        │
        ├─ Ansible lee el inventario → sabe a qué IPs conectar
        ├─ Ansible resuelve variables (group_vars, host_vars, facts)
        ├─ Ansible se conecta por SSH a cada host en paralelo (forks=5 por defecto)
        │
        │  Por cada host:
        │    ├─ Ejecuta task 1 → comprueba si ya está hecho
        │    │    Si ya está: "ok" (verde)
        │    │    Si no está: "changed" (amarillo) → ejecuta el cambio
        │    │    Si falla:   "failed" (rojo) → Ansible se detiene
        │    ├─ Ejecuta task 2 ...
        │    └─ Al final: ejecuta handlers pendientes
        │
        └─ Muestra PLAY RECAP: hosts con ok/changed/failed
```

---

## El módulo `template` y Jinja2

Este es el módulo más usado con OpenStack porque los ficheros de configuración (nova.conf, neutron.conf, netplan.yaml) tienen IPs y contraseñas que cambian por nodo.

Un **template Jinja2** es un fichero con placeholders:

```ini
# templates/nova.conf.j2
[DEFAULT]
my_ip = {{ mgmt_ip }}
transport_url = rabbit://openstack:{{ rabbitmq_password }}@{{ controller_ip }}:5672

[vnc]
server_listen = 0.0.0.0
server_proxyclient_address = {{ mgmt_ip }}   # ← NO literal $my_ip
novncproxy_base_url = http://{{ controller_public_ip }}:6080/vnc_lite.html
```

Cuando Ansible ejecuta `template:`, sustituye `{{ mgmt_ip }}` con el valor real de ese host (ej. `10.0.0.10` para compute1) y copia el fichero generado al nodo.

---

## Comparativa: Script bash vs Ansible

| Aspecto | Script bash | Ansible |
|---------|------------|---------|
| Idempotencia | Manual (hay que añadir `if [ ! ... ]`) | Incorporada en cada módulo |
| Ejecución en paralelo | Complicado (`&` + wait) | Por defecto (forks=5) |
| Gestión de errores | `set -e` para parar, pero inconsistente | `failed_when`, `ignore_errors`, handlers |
| Documentación del estado | El script es el estado | El estado es declarativo en YAML |
| Re-ejecución segura | Muchas veces no | Siempre (si se escribe bien) |
| Variables por nodo | Arrays bash complicados | `host_vars/` por nodo |
| Condiciones | `if-else` bash | `when:` en tasks |
| Bucles | `for` bash | `loop:` o `with_items:` |

**Ejemplo de idempotencia real:**

Esta task de Ansible:
```yaml
- name: Asegurar nova-compute instalado
  apt:
    name: nova-compute
    state: present    # "instalado". No "última versión". No "reinstalar".
```

- **Primera ejecución:** instala nova-compute → `changed`
- **Segunda ejecución:** ya está instalado → `ok` (0 cambios)
- **Si se desinstala por error:** detecta que no está → lo instala → `changed`

---

## Ansible en modo check (dry-run)

Antes de ejecutar cualquier playbook, puedes ver **qué cambiaría** sin aplicar nada:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/bridges.yml --check
```

Los tasks marcan `changed` si detectan que harían un cambio, pero no lo ejecutan. Útil para validar antes de tocar producción.

---

## Estrategia de ejecución: `linear` vs `free`

Por defecto Ansible usa estrategia `linear`: todos los nodos ejecutan la misma task antes de pasar a la siguiente. Esto asegura que si la task 2 depende del resultado de la task 1 en otro nodo, está garantizado.

```
Task 1: instalar nova-compute
  → compute1: ok   compute2: ok   compute3: ok   compute4: ok
Task 2: arrancar nova-compute
  → compute1: changed   compute2: changed  ...
```

Para nuestro caso es el modelo correcto: queremos que todos los bridges estén creados antes de pasar a verificar conectividad.

---

## Siguiente paso

Lee [02-CONCEPTOS-REDES.md](02-CONCEPTOS-REDES.md) para entender la arquitectura de red antes de escribir las tasks que la configuran.
