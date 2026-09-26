# Estructura del Proyecto Ansible

> **Objetivo:** Entender el árbol de directorios antes de ver el código.  
> Una estructura bien definida es la diferencia entre un proyecto mantenible y un caos.

---

## Árbol completo del proyecto

```
documentacion_ansible/
│
├── ansible/                        ← Raíz del proyecto Ansible
│   │
│   ├── ansible.cfg                 ← Configuración global de Ansible
│   │
│   ├── inventory/                  ← "¿a qué máquinas hablo?"
│   │   ├── hosts.yml               ← Inventario: los 5 nodos y sus grupos
│   │   └── group_vars/             ← Variables por grupo
│   │       ├── all.yml             ← Común a todos (contraseñas, IPs internas)
│   │       ├── controller.yml      ← Solo para el controller
│   │       └── compute.yml         ← Solo para los computes
│   │
│   ├── playbooks/                  ← "¿qué quiero hacer?"
│   │   ├── site.yml                ← Maestro: ejecuta todo en orden correcto
│   │   ├── bridges.yml             ← Fase 1: Linux bridges en todos los nodos
│   │   ├── ovs.yml                 ← Fase 2: OVS bridges (br-provider + br-vlan)
│   │   ├── controller.yml          ← Fase 3: Servicios del controller
│   │   ├── computes.yml            ← Fase 4: Servicios de los computes
│   │   └── verify.yml              ← Verificación final del cluster
│   │
│   └── roles/                      ← "¿cómo hago cada cosa?"
│       ├── common/                 ← Configuración base de todos los nodos
│       │   ├── tasks/
│       │   │   └── main.yml        ← /etc/hosts, sysctl, paquetes base
│       │   └── defaults/
│       │       └── main.yml
│       │
│       ├── linux-bridges/          ← Crear br-mgmt, br-vlan, br-vxlan
│       │   ├── tasks/
│       │   │   └── main.yml        ← Escribir netplan + aplicarlo
│       │   ├── handlers/
│       │   │   └── main.yml        ← netplan apply
│       │   ├── templates/
│       │   │   └── netplan.yaml.j2 ← Plantilla netplan con variables
│       │   └── defaults/
│       │       └── main.yml        ← Valores por defecto
│       │
│       ├── ovs-bridges/            ← Asegurar OVS: br-provider + br-vlan
│       │   ├── tasks/
│       │   │   └── main.yml        ← ovs-vsctl idempotente
│       │   └── handlers/
│       │       └── main.yml        ← reiniciar neutron-ovs-agent
│       │
│       ├── nova-compute/           ← Instalar/configurar nova-compute
│       │   ├── tasks/
│       │   │   └── main.yml
│       │   ├── handlers/
│       │   │   └── main.yml        ← reiniciar nova-compute
│       │   ├── templates/
│       │   │   └── nova.conf.j2    ← nova.conf con variables por nodo
│       │   └── defaults/
│       │       └── main.yml
│       │
│       └── neutron-ovs-agent/      ← Configurar neutron-openvswitch-agent
│           ├── tasks/
│           │   └── main.yml
│           ├── handlers/
│           │   └── main.yml        ← reiniciar neutron-openvswitch-agent
│           ├── templates/
│           │   └── openvswitch_agent.ini.j2
│           └── defaults/
│               └── main.yml
│
├── 00-INDICE.md
├── 01-CONCEPTOS-ANSIBLE.md
├── 02-CONCEPTOS-REDES.md
├── 03-ESTRUCTURA-PROYECTO.md      ← Este fichero
├── 04-INVENTARIO.md
├── 05-VARIABLES-ROLES.md
├── 06-FASE1-BRIDGES.md
├── 07-FASE2-CONTROLLER.md
├── 08-FASE3-COMPUTES.md
└── 09-EJECUCION.md
```

---

## El fichero ansible.cfg

Este fichero configura el comportamiento por defecto de Ansible para este proyecto. Se busca en este orden: variable de entorno `ANSIBLE_CONFIG` → `./ansible.cfg` → `~/.ansible.cfg`.

```ini
# ansible/ansible.cfg
[defaults]
# Dónde está el inventario por defecto (relativo a ansible.cfg)
inventory = inventory/hosts.yml

# Usuario SSH con el que conectar a los nodos
remote_user = uceda

# Escalada de privilegios por defecto (sudo)
become = true
become_method = sudo

# Número de hosts en paralelo
forks = 5

# No verificar fingerprint SSH (lab, no producción)
host_key_checking = False

# Dónde guardar los facts recopilados (caché de 1 hora)
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts_cache
fact_caching_timeout = 3600

# Formato de salida más legible
stdout_callback = yaml

# Mostrar tiempo que tarda cada task
callback_whitelist = timer, profile_tasks

[privilege_escalation]
become_ask_pass = false
```

> **`host_key_checking = False`:** En un entorno de producción real jamás se deshabilita la verificación de fingerprint SSH. En un laboratorio lo hacemos para no tener que aceptar manualmente el fingerprint de cada nodo cuando se reconstruye la infraestructura.

---

## Convenciones de nombres usadas en este proyecto

### Nombres de los nodos en el inventario

Los nombres del inventario Ansible no tienen que coincidir con los nombres de las VMs KVM ni con los hostnames del sistema. Usamos los hostnames reales de los nodos:

| Nombre en inventario | Hostname real | IP de conexión |
|---------------------|---------------|----------------|
| `serverocontroller` | serverocontroller | 203.0.113.239 |
| `compute1` | compute1 | 203.0.113.240 |
| `compute2` | compute2 | 203.0.113.241 |
| `compute3` | compute3 | 203.0.113.242 |
| `compute4` | compute4 | 203.0.113.243 |

### Nombres de variables

Las variables siguen el patrón `<servicio>_<parametro>`:

```yaml
nova_virt_type: kvm
neutron_local_ip: "{{ mgmt_ip }}"
rabbitmq_password: icc115
openstack_admin_password: icc115
```

### Nombres de roles

Siguiendo kebab-case (guiones, no underscores): `linux-bridges`, `ovs-bridges`, `nova-compute`.

---

## Por qué esta estructura y no otra

### ¿Por qué `inventory/` separado de `playbooks/`?

El inventario cambia con mucha menos frecuencia que los playbooks. Separarlo permite:
- Tener un inventario de `dev` y otro de `prod` con los mismos playbooks.
- Versionarlos de forma independiente.

### ¿Por qué roles en lugar de tasks directamente en el playbook?

```yaml
# ❌ Mal — todo en el playbook, imposible reutilizar
- hosts: compute
  tasks:
    - name: instalar nova-compute
      apt:
        name: nova-compute
    - name: configurar nova.conf
      template:
        ...  # 200 líneas más

# ✅ Bien — role reutilizable
- hosts: compute
  roles:
    - nova-compute   # toda la lógica en roles/nova-compute/
```

Los roles permiten:
- Reutilizar la misma lógica en diferentes playbooks.
- Mantener el playbook limpio y legible (describe el QUÉ, no el CÓMO).
- Testear roles de forma independiente.

### ¿Por qué `defaults/main.yml` y no `vars/main.yml`?

```
defaults/main.yml  → prioridad MÁS BAJA  → fácilmente sobreescribible
vars/main.yml      → prioridad MÁS ALTA  → difícil de sobreescribir
```

Los valores por defecto del role van en `defaults/`. Los valores de `group_vars/` los sobreescriben automáticamente. Los valores fijos internos del role (que nunca deben cambiarse desde fuera) van en `vars/`.

---

## Siguiente paso

Lee [04-INVENTARIO.md](04-INVENTARIO.md) para ver el inventario completo con explicaciones línea a línea.
