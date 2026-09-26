# ⚠️ Errores y percances — lecciones para futuros despliegues

> Registro de los errores encontrados durante la instalación y cómo se corrigieron.
> Sirve para **reintentar sin tropezar dos veces** y para adaptar el despliegue a otras redes.

---

## Resumen

| # | Síntoma | Causa | Solución aplicada |
|---|---|---|---|
| E1 | SSH `Too many authentication failures` | Muchas llaves en `~/.ssh` (>6) agotan `MaxAuthTries` del servidor | Forzar una sola identidad / autenticación por contraseña |
| E2 | `00-bootstrap.sh`: `syntax error near unexpected token '('` | Anidamiento de comillas simples al construir `bash -c` con la regla sudoers `(ALL)` | Reescribir con **heredoc** (`sudo -S bash -s <<EOF`) |
| E3 | `bash: asdfghjkl: command not found` (cosmético) | Tras tener NOPASSWD, `sudo -S` ya no consume la línea de contraseña y ésta llega a `bash -s` | Inofensivo (idempotente); no afecta el resultado |
| E4 | `apt-get update` falla con exit 100 | Repo roto preexistente `download.ceph.com/debian-quincy` (Ceph Quincy no soporta Ubuntu 24.04/noble) | Desactivar repo (`ceph.list` → `.disabled`) |
| E5 | `nmcli radio wifi off` → `Not authorized` | Operación requiere root | Usar `sudo` |
| E6 | Docker 29.1.3 vs 29.8.1 entre nodos | `docker.io` (Ubuntu) vs `docker-ce` (repo oficial) | Cosmético; ambos válidos para Kolla |
| E7 | `nvidia-ctk`: `Could not infer options from runtimes [runc crun]` | containerd del sistema vs containerd embebido de k3s | Pendiente (configurar runtime NVIDIA según el K8s final) |
| E8 | Doble ruta en `asus-tuf` (cable + Wi-Fi) | Dos interfaces activas (`.126` y `.20`) | `sudo nmcli radio wifi off` |
| E9 | `ansible ping` a `anfitrion` (nodo de control) → "Too many authentication failures" | El nodo de control **no tiene su propia clave pública** en su `authorized_keys` (SSH a sí mismo) | `cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys` |
| E10 | `ansible ping` se queda pidiendo "continue connecting (yes/no)" | Host key de la IP local no estaba en `known_hosts` | `ssh-keyscan <ip> >> ~/.ssh/known_hosts` + `ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes'` |
| E11 | filtro Jinja `kolla_address` no carga ("No module named 'kolla_ansible'") | `kolla-ansible` invoca `ansible-playbook` por `PATH` (subprocess); sin el venv activado usa el ansible del sistema | `export PATH=/opt/kolla-ansible/bin:$PATH` antes de llamar a `kolla-ansible` |
| E12 | precheck RabbitMQ: "hostname resuelve a varias IPs" | `avahi` (mDNS) anuncia el hostname con todas las IPs (docker0/cni0/flannel) | `09-kolla-hosts.sh`: entradas únicas en `/etc/hosts` + `systemctl disable --now avahi-daemon` |
| E13 | conflicto de paquetes `docker-compose-v2` vs `docker-compose-plugin` (y `docker.service` enmascarado) | `anfitrion` tenía `docker.io`+`docker-compose-v2` (Ubuntu) mezclados con Docker CE | quitar `docker-compose-v2`, desenmascarar `docker.service`, override a `-H unix://` |

> 🚨 **HALLAZGO CRÍTICO:** el clúster k3s de los 3 nodos **ya ejecuta la propia aplicación VTON** (namespace `vton`: `minio`, `redis`, `vton-api-gateway`, `vton-cpu-worker`, `vton-gpu-worker`, `vton-registry` en puerto 5000, `vton-web`). El despliegue de OpenStack (Kolla) **choca** con esta app (puerto 5000 = Keystone vs registry, etc.). Ver `implementacion/README.md` → "Decisión pendiente: coexistencia con k3s".

| E14 | `cinder-manage db sync` falla: "ProxySQL Error: Access denied for user 'cinder'@'192.168.0.200'" | ProxySQL no tiene el usuario `cinder` sincronizado (el deploy con `--tags cinder` omitió el rol `proxysql`) | ✅ Resuelto: re-ejecutar el **deploy completo** (sin `--tags`), que corre el rol `proxysql` y sincroniza los usuarios de BD |

> ℹ️ **Nota cinder-backup:** tras desplegar Cinder, `openstack volume service list` puede mostrar `cinder-backup` en `down` aunque el contenedor esté `healthy` (heartbeat en BD obsoleto). Es **cosmético**: la creación/borrado de volúmenes funciona correctamente. `cinder-volume` y `cinder-scheduler` quedan `up`.

---

## Detalle

### E1 — SSH "Too many authentication failures"
- **Cuándo:** al hacer `ssh-copy-id` / `ssh` hacia `server` y `asus-tuf`.
- **Causa:** `~/.ssh` tiene 6+ llaves (`id_ed25519`, `id_rsa`, `id_rsa_controller`, `id_rsagit`, `openstack_lab`, `github…`); el servidor rechaza tras agotar `MaxAuthTries`.
- **Solución:**
  ```bash
  sshpass -p '<pass>' ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no uceda@<ip> '...'
  ```
  o, para `ssh-copy-id`, añadir `-o IdentitiesOnly=yes -i ~/.ssh/id_ed25519.pub`.

### E2 — Error de comillas en `00-bootstrap.sh`
- **Causa:** `run_cmd` empaquetaba el comando en comillas simples anidadas; la regla sudoers `ALL=(ALL)` rompía el parseo.
- **Solución:** pasar la contraseña (1ª línea) y el script (resto) vía heredoc:
  ```bash
  ssh host "sudo -S -p '' bash -s" <<EOF
  $SUDO_PASSWORD
  printf '%s\n' '$USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$USER-nopasswd
  chmod 440 /etc/sudoers.d/$USER-nopasswd
  EOF
  ```

### E3 — "asdfghjkl: command not found"
- **Causa:** una vez habilitado NOPASSWD, `sudo -S` no lee la contraseña y la línea pasa a `bash -s` como comando.
- **Solución:** aceptable (inofensivo). Para evitarlo, detectar si ya hay NOPASSWD y no enviar la contraseña.

### E4 — Repo APT roto (Ceph Quincy en noble)
- **Causa:** `ceph.list` apuntaba a `debian-quincy` (compatible con 22.04, no con 24.04).
- **Solución:** `sudo mv /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.list.disabled`.
- **Lección:** en futuros despliegues, verificar `apt-get update` antes de instalar, y desactivar repos de terceros incompatibles.

### E5 — `nmcli radio wifi off` sin permisos
- **Solución:** `sudo nmcli radio wifi off` (o `rfkill block wifi`).

### E6 — Versión de Docker distinta
- **Causa:** `anfitrion` ya tenía `docker.io` (29.1.3); los otros instalaron `docker-ce` (29.8.1). El script `02-docker.sh` **omite** instalar si ya existe `docker`.
- **Impacto:** ninguno (Kolla solo necesita un Docker funcional).

### E7 — nvidia-container-toolkit vs containerd de k3s
- **Contexto:** `server` es un **agente k3s**; k3s usa su **propio containerd** (`/var/lib/rancher/k3s/...`), no el del sistema.
- **Estado:** el toolkit se instaló y configuró el containerd **del sistema**; para exponer la GPU al clúster k3s hará falta configurar el runtime en el containerd de k3s (o usar `--container-runtime-endpoint`).
- **Lección:** decidir k3s-vs-kubeadm **antes** de configurar el runtime GPU.

### E8 — Doble interfaz (cable + Wi-Fi)
- **Solución:** `sudo nmcli radio wifi off` en `asus-tuf`; verificar que `ip route` solo muestra una ruta por defecto.

### E9 — SSH a sí mismo (nodo de control) falla
- **Cuándo:** `ansible -i /etc/kolla/multinode all -m ping` falla solo en `anfitrion` (el nodo que ejecuta Ansible).
- **Causa:** `anfitrion` no tenía su **propia** `id_ed25519.pub` en su `authorized_keys`, por lo que el SSH hacia su propia IP agotaba los intentos.
- **Solución:** `cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys`.
- **Lección:** cuando el nodo de control **también** es nodo gestionado, debe poder hacer SSH a sí mismo.

### E10 — Prompt de host key en `ansible`
- **Causa:** la IP local (`192.168.0.10`) no estaba en `~/.ssh/known_hosts`.
- **Solución:** `ssh-keyscan <ip> >> ~/.ssh/known_hosts` y añadir al inventario:
  `ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes'`.

---

## Percances a prever en futuros despliegues

1. **IPs dinámicas (DHCP):** fijar IPs estáticas o reservas DHCP antes de desplegar (las IPs cambiaron durante la sesión).
2. **Nombres de NIC distintos por nodo** (`enp2s0f0`, `eno1`, `enp2s0`): declarar por host en el inventario Kolla.
3. **Servicios preexistentes** en `anfitrion` (k3s server, PostgreSQL 5432, Ollama 11434): pueden chocar con OpenStack/Kolla; decidir aislamiento o reutilización.
4. **`asus-tuf` limitado** (15 GB RAM): no sobrecargarlo como storage+compute.
5. **Sin VLANs físicas:** el plan V4 asume mgmt/storage/tunnel/external separados; aquí hay 1 NIC/1 subred → definir subinterfaces VLAN o un único plano inicial.
