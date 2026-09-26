# El Inventario Ansible — Guía detallada

> **Objetivo:** Entender cada línea del inventario y por qué está ahí.  
> El inventario es la base de todo — sin él Ansible no sabe a quién hablar.

---

## ¿Qué es el inventario?

El inventario es el "mapa" de tu infraestructura. Le dice a Ansible:
- **Quiénes** son los nodos gestionados.
- **Cómo** conectar a ellos (IP, usuario, contraseña).
- **A qué grupos** pertenece cada nodo.
- **Qué variables** son específicas de cada nodo o grupo.

---

## Formato: INI vs YAML

Ansible soporta dos formatos. Usamos **YAML** porque:
- Es más legible para estructuras jerárquicas.
- Permite variables anidadas.
- Es el estándar moderno.

Comparativa del mismo inventario en ambos formatos:

```ini
# Formato INI (más antiguo, más simple)
[controller]
serverocontroller ansible_host=203.0.113.239 mgmt_ip=10.0.0.11

[compute]
compute1 ansible_host=203.0.113.240 mgmt_ip=10.0.0.10
compute2 ansible_host=203.0.113.241 mgmt_ip=10.0.0.12
```

```yaml
# Formato YAML (usamos este)
all:
  children:
    controller:
      hosts:
        serverocontroller:
          ansible_host: 203.0.113.239
          mgmt_ip: 10.0.0.11
    compute:
      hosts:
        compute1:
          ansible_host: 203.0.113.240
          mgmt_ip: 10.0.0.10
        compute2:
          ansible_host: 203.0.113.241
          mgmt_ip: 10.0.0.12
```

---

## El inventario completo — línea a línea

```yaml
all:                          # Grupo raíz. Siempre existe. Contiene todos los hosts.
  vars:                       # Variables que aplican a TODOS los hosts
    ansible_user: uceda       # Usuario SSH con el que conectar
    ansible_password: asdfghjkl          # Contraseña SSH
    ansible_become_password: asdfghjkl   # Contraseña para sudo
    ansible_python_interpreter: /usr/bin/python3  # Python en los nodos
```

> **`ansible_become_password`**: Es la contraseña de sudo. Ansible la necesita porque los nodos tienen `uceda` con `sudo` pero sin NOPASSWD. En producción esto se gestionaría con SSH keys y NOPASSWD en sudoers.

```yaml
  children:                   # Sub-grupos de "all"
    controller:               # Grupo que contiene el(los) controller(s)
      hosts:
        serverocontroller:    # Nombre del host en Ansible (alias, no tiene que ser el hostname)
          ansible_host: 203.0.113.239   # IP real de conexión
          mgmt_ip: 10.0.0.11            # Variable propia: IP de br-mgmt
          public_ip: 203.0.113.239      # Variable propia: IP pública
          mgmt_mac: "52:54:00:99:07:38" # Variable propia: MAC de enp7s0
```

> **¿Por qué `mgmt_ip` como variable de host y no `ansible_host`?**  
> `ansible_host` es la IP con la que Ansible conecta por SSH. Usamos `enp1s0` (203.0.113.x) para eso.  
> `mgmt_ip` es la IP que los servicios OpenStack usan internamente (10.0.0.x, la de `br-mgmt`).  
> Son dos propósitos diferentes → dos variables diferentes.

```yaml
    compute:                  # Grupo que contiene los 4 computes
      hosts:
        compute1:
          ansible_host: 203.0.113.240
          mgmt_ip: 10.0.0.10
          public_ip: 203.0.113.240
          mgmt_mac: "52:54:00:25:40:01"  # MAC de enp7s0 en compute1

        compute2:
          ansible_host: 203.0.113.241
          mgmt_ip: 10.0.0.12
          ...
```

---

## Grupos y targeting

Los grupos permiten ejecutar playbooks contra subconjuntos de nodos:

```bash
# Ejecutar contra todos los nodos
ansible-playbook -i inventory/hosts.yml playbooks/bridges.yml

# Ejecutar solo contra los computes
ansible-playbook -i inventory/hosts.yml playbooks/bridges.yml --limit compute

# Ejecutar solo contra un nodo específico
ansible-playbook -i inventory/hosts.yml playbooks/bridges.yml --limit compute1

# Ejecutar contra controller + compute1
ansible-playbook -i inventory/hosts.yml playbooks/bridges.yml --limit 'controller,compute1'
```

---

## Verificar el inventario

Antes de ejecutar cualquier playbook, verifica que Ansible ve bien el inventario:

```bash
# Desde la carpeta ansible/
cd documentacion_ansible/ansible/

# Listar todos los hosts
ansible-inventory --list

# Ver el inventario en formato YAML
ansible-inventory --list -y

# Ver el inventario en forma de árbol
ansible-inventory --graph
```

**Salida esperada de `--graph`:**
```
@all:
  |--@ungrouped:
  |--@controller:
  |  |--serverocontroller
  |--@compute:
  |  |--compute1
  |  |--compute2
  |  |--compute3
  |  |--compute4
```

---

## Probar conectividad

El módulo `ping` de Ansible (no es un ping ICMP — es una verificación de conexión SSH + Python):

```bash
# Ping a todos los nodos
ansible all -m ping

# Ping solo a los computes
ansible compute -m ping

# Salida esperada (todos verdes):
# serverocontroller | SUCCESS => {"ping": "pong"}
# compute1          | SUCCESS => {"ping": "pong"}
# compute2          | SUCCESS => {"ping": "pong"}
# compute3          | SUCCESS => {"ping": "pong"}
# compute4          | SUCCESS => {"ping": "pong"}
```

---

## Ver los facts de un nodo

Los **facts** son variables que Ansible recopila automáticamente del nodo antes de ejecutar tasks. Incluyen: IPs, interfaces, memoria, CPU, distribución, etc.

```bash
# Ver todos los facts del controller
ansible serverocontroller -m setup

# Filtrar solo los facts de red
ansible serverocontroller -m setup -a 'filter=ansible_interfaces'

# Ver la IP de gestión detectada
ansible serverocontroller -m setup -a 'filter=ansible_default_ipv4'
```

**Facts útiles para este proyecto:**

```yaml
ansible_hostname                    # "serverocontroller"
ansible_distribution                # "Ubuntu"
ansible_distribution_version       # "24.04"
ansible_interfaces                  # ["enp1s0", "enp7s0", "enp8s0", "br-mgmt", ...]
ansible_br_mgmt.ipv4.address        # "10.0.0.11"
ansible_default_ipv4.interface      # "enp1s0"
```

---

## El MAC de br-mgmt: por qué es una variable de host

Como descubrimos en la guía 06, cuando Linux crea un bridge, le asigna un MAC aleatorio en lugar de heredar el del primer miembro. Esto rompe en KVM porque el hypervisor filtra por MAC.

La solución en Ansible es fijar el MAC en el template de netplan:

```yaml
# En el template roles/linux-bridges/templates/netplan.yaml.j2
bridges:
  br-mgmt:
    macaddress: "{{ mgmt_mac }}"   # ← MAC de enp7s0, definido en hosts.yml
    addresses: ["{{ mgmt_ip }}/{{ mgmt_prefix }}"]
    interfaces: ["{{ mgmt_interface }}"]
```

Cada nodo tiene su propio `mgmt_mac` en `hosts.yml`, por lo que Ansible genera un netplan diferente para cada nodo con el MAC correcto.

---

## Siguiente paso

Lee [05-VARIABLES-ROLES.md](05-VARIABLES-ROLES.md) para entender cómo funcionan las variables en los roles y cómo se organizan los templates Jinja2.
