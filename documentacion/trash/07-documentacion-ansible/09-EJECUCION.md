# Guía de Ejecución — Instalar Ansible y Correr los Playbooks

> **Objetivo:** Pasar de 0 a tener Ansible instalado y ejecutando contra el cluster.  
> Todos los comandos se ejecutan desde el **laptop** (nodo de control).

---

## Paso 1 — Instalar Ansible en el laptop

```bash
# Opción A: pip (recomendado — versión más reciente)
pip3 install --user ansible

# Opción B: apt (Ubuntu — puede ser versión más antigua)
sudo apt update && sudo apt install -y ansible

# Verificar instalación
ansible --version
# Debe mostrar: ansible [core 2.x.x]

# Instalar colecciones necesarias para OVS
ansible-galaxy collection install ansible.netcommon
```

---

## Paso 2 — Preparar claves SSH

Ansible necesita conectar a los nodos **sin pedir contraseña** (o con la contraseña en el inventario, que es lo que tenemos configurado). En el inventario ya tenemos `ansible_password`, pero usar clave SSH es más seguro y rápido.

### Opción A: Usar password en inventario (ya configurado, más fácil)

El inventario ya tiene `ansible_password: asdfghjkl`. Funciona tal cual, pero necesita que `sshpass` esté instalado:

```bash
sudo apt install -y sshpass
```

### Opción B: Clave SSH (recomendado para flujo de trabajo diario)

```bash
# Generar clave SSH si no tienes una
ssh-keygen -t ed25519 -C "ansible-lab" -f ~/.ssh/id_ed25519_lab

# Copiar la clave a todos los nodos
for ip in 203.0.113.239 203.0.113.240 203.0.113.241 203.0.113.242 203.0.113.243; do
  ssh-copy-id -i ~/.ssh/id_ed25519_lab uceda@$ip
done

# Verificar que funciona sin contraseña
ssh -i ~/.ssh/id_ed25519_lab uceda@203.0.113.239 "echo OK"
```

Si usas clave SSH, elimina las líneas `ansible_password` y `ansible_become_password` del inventario y añade:

```yaml
# En inventory/hosts.yml, sección vars:
ansible_ssh_private_key_file: ~/.ssh/id_ed25519_lab
```

---

## Paso 3 — Verificar la instalación

```bash
# Ir a la carpeta del proyecto Ansible
cd /home/uceda/Documents/InstalacionOpenstack/documentacion_ansible/ansible/

# Probar conectividad a todos los nodos
ansible all -m ping

# Salida esperada:
# serverocontroller | SUCCESS => {"ping": "pong"}
# compute1          | SUCCESS => {"ping": "pong"}
# compute2          | SUCCESS => {"ping": "pong"}
# compute3          | SUCCESS => {"ping": "pong"}
# compute4          | SUCCESS => {"ping": "pong"}
```

Si ves errores:
- `UNREACHABLE` → problema de SSH (IP incorrecta, nodo apagado)
- `MODULE_FAILURE` → Python no encontrado en el nodo (`ansible_python_interpreter` incorrecto)
- `Authentication failure` → contraseña incorrecta

---

## Paso 4 — Ver el inventario

```bash
# Árbol del inventario
ansible-inventory --graph

# Salida:
# @all:
#   |--@ungrouped:
#   |--@controller:
#   |  |--serverocontroller
#   |--@compute:
#   |  |--compute1
#   |  |--compute2
#   |  |--compute3
#   |  |--compute4

# Variables de un host concreto
ansible-inventory --host compute1
```

---

## Paso 5 — Recopilar facts (opcional pero útil)

```bash
# Ver todos los facts del controller
ansible serverocontroller -m setup | less

# Ver solo las interfaces de red de compute1
ansible compute1 -m setup -a 'filter=ansible_interfaces'

# Ver IP de br-mgmt en todos los nodos
ansible all -m setup -a 'filter=ansible_br_mgmt'
```

---

## Paso 6 — Dry-run antes de ejecutar

**Siempre** ejecuta con `--check` primero para ver qué cambiaría:

```bash
# Simular la Fase 1 (bridges) sin aplicar nada
ansible-playbook playbooks/bridges.yml --check

# Simular solo en compute1
ansible-playbook playbooks/bridges.yml --check --limit compute1
```

La salida mostrará `changed` en verde (sin asterisco) para los cambios que haría, pero SIN aplicarlos.

---

## Paso 7 — Ejecutar las fases

### Secuencia recomendada para el cluster actual (ya instalado)

El cluster ya está funcionando. Ejecutar los playbooks en este orden:

```bash
cd documentacion_ansible/ansible/

# ── Fase 1: Bridges (re-aplica y verifica configuración de bridges) ──────────
ansible-playbook playbooks/bridges.yml

# ── Fase 2: Computes (verifica/corrige servicios en los computes) ────────────
ansible-playbook playbooks/computes.yml

# ── Fase 3: Controller (verifica servicios + discover_hosts) ─────────────────
ansible-playbook playbooks/controller.yml

# ── Verificación final ───────────────────────────────────────────────────────
ansible-playbook playbooks/verify.yml
```

### Todo en un comando (playbook maestro)

```bash
ansible-playbook playbooks/site.yml
```

---

## Comandos Ansible ad-hoc (sin playbook)

Los **comandos ad-hoc** son para operaciones rápidas sin crear un playbook:

```bash
# Reiniciar nova-compute en todos los computes
ansible compute -m service -a "name=nova-compute state=restarted"

# Ver estado de un servicio en todos los nodos
ansible all -m command -a "systemctl is-active nova-compute"

# Ver br-mgmt en todos los nodos
ansible all -m command -a "ip -br addr show br-mgmt"

# Ejecutar comando arbitrario con sudo
ansible all -m shell -a "ovs-vsctl list-ports br-provider" --become

# Copiar un fichero a todos los computes
ansible compute -m copy -a "src=/tmp/test.txt dest=/tmp/test.txt"

# Hacer ping real ICMP desde cada nodo al controller
ansible compute -m command -a "ping -c2 10.0.0.11"
```

---

## Interpretar la salida de Ansible

```
PLAY [Configurar Linux bridges en los computes] *******

TASK [Gathering Facts] *********************************
ok: [compute1]   ← Recopiló facts sin problemas
ok: [compute2]
ok: [compute3]
ok: [compute4]

TASK [linux-bridges : Generar fichero netplan] *********
ok: [compute1]   ← Verde/ok: fichero ya estaba correcto, sin cambios
changed: [compute2]  ← Amarillo/changed: fichero diferente, lo actualizó
ok: [compute3]
ok: [compute4]

RUNNING HANDLER [linux-bridges : aplicar netplan] ******
changed: [compute2]  ← Handler ejecutado solo en compute2 (el que cambió)

PLAY RECAP *********************************************
compute1    : ok=2  changed=0  unreachable=0  failed=0
compute2    : ok=2  changed=2  unreachable=0  failed=0
compute3    : ok=2  changed=0  unreachable=0  failed=0
compute4    : ok=2  changed=0  unreachable=0  failed=0
```

**Colores en la salida:**
- `ok` (verde) — task ejecutada, nada cambió
- `changed` (amarillo) — task ejecutada, algo cambió
- `failed` (rojo) — task falló, play se detiene
- `skipped` (cyan) — task saltada (condición `when:` no cumplida)
- `unreachable` (rojo) — no se pudo conectar al nodo

---

## Errores comunes y soluciones

| Error | Causa | Solución |
|-------|-------|---------|
| `UNREACHABLE! SSH Error` | El nodo no responde | Verificar que la VM está encendida: `virsh list` |
| `MODULE_FAILURE: No Python` | Python no está en `/usr/bin/python3` | Añadir `ansible_python_interpreter: auto` en inventario |
| `Missing sudo password` | `become_password` incorrecto | Verificar `ansible_become_password` en inventario |
| `openvswitch_bridge not found` | Colección OVS no instalada | `ansible-galaxy collection install ansible.netcommon` |
| `netplan apply failed` | YAML inválido en el template | Probar con `ansible-playbook --check` primero |
| `service not found` | Nombre de servicio incorrecto | Verificar con `systemctl list-units` en el nodo |

---

## Flujo de trabajo recomendado para cambios futuros

```
1. Editar la variable o template necesario
2. ansible-playbook ... --check    ← Ver qué cambiaría
3. ansible-playbook ... --limit compute1  ← Probar en un nodo
4. Verificar manualmente en compute1
5. ansible-playbook ...            ← Aplicar en todos
6. ansible-playbook playbooks/verify.yml  ← Verificación final
```

---

## Referencia rápida de comandos

```bash
# Ping a todos
ansible all -m ping

# Árbol del inventario
ansible-inventory --graph

# Facts de un host
ansible <host> -m setup

# Dry-run de un playbook
ansible-playbook <playbook> --check

# Ejecutar contra un host/grupo
ansible-playbook <playbook> --limit <host_o_grupo>

# Ejecutar solo tareas con una tag
ansible-playbook <playbook> --tags <tag>

# Verbose (ver más detalle)
ansible-playbook <playbook> -v    # un nivel
ansible-playbook <playbook> -vvv  # tres niveles (muy detallado)

# Ver las tasks sin ejecutarlas
ansible-playbook <playbook> --list-tasks

# Ver los hosts que serían afectados
ansible-playbook <playbook> --list-hosts
```
