# Orden de instalación — detalle técnico

> Documenta **qué** se instala, **por qué** y **cómo verificarlo**, para cada paso de la secuencia.
> Todo sobre **Ubuntu 24.04**, idempotente y re-desplegable.

---

## 0 · Bootstrap (`00-bootstrap.sh`)

- **Qué:** habilita `sudo NOPASSWD` para el usuario, verifica Ubuntu 24.04 y SSH sin contraseña.
- **Por qué:** el resto de scripts ejecutan `sudo -n` (no interactivo); sin esto se quedarían esperando contraseña.
- **Verificar:** `sudo -n true` devuelve OK en los 3 nodos.

## 1 · Base (`01-base.sh`)

- **Qué:** `curl wget git vim htop net-tools ca-certificates gnupg lsb-release software-properties-common chrony python3 python3-pip python3-venv jq unzip bash-completion`.
- **Por qué:** herramientas de administración + `chrony` (NTP, requisito de Kolla-Ansible para que los tokens/servicios no fallen por deriva de reloj) + `python3-venv` (para Kolla y openstack).
- **Verificar:** `chronyc tracking` (o `systemctl is-active chrony`).

## 2 · Docker (`02-docker.sh`)

- **Qué:** Docker CE + plugin compose + `containerd.io` desde el repo oficial de Docker.
- **Por qué:** Kolla-Ansible despliega OpenStack en **contenedores Docker**; `containerd` es el runtime de Kubernetes.
- **Verificar:** `docker --version` y `docker compose version`.

## 3 · Kolla-Ansible (`03-kolla-ansible.sh`) — solo control

- **Qué:** crea el venv `/opt/kolla-ansible`, instala `ansible-core` + `kolla-ansible`, y copia los ejemplos de configuración a `/etc/kolla` (`globals.yml`, `passwords.yml`, inventario `multinode`).
- **Por qué:** Kolla-Ansible es el método elegido (V4) para desplegar OpenStack en contenedores.
- **Verificar:** `/opt/kolla-ansible/bin/kolla-ansible --version`.

## 4 · OpenStack CLI (`04-openstack-cli.sh`) — solo control

- **Qué:** `python-openstackclient` (+ `python-glanceclient/neutronclient/novaclient/cinderclient`) en el venv.
- **Por qué:** herramienta de administración para operar OpenStack tras el despliegue.
- **Verificar:** `/opt/kolla-ansible/bin/openstack --version`.

## 5 · kubectl + helm (`05-k8s-tools.sh`) — todos

- **Qué:** `kubectl` (repo oficial de Kubernetes `v1.36`) + `helm` (script oficial).
- **Por qué:** operar el clúster Kubernetes y desplegar charts. Nota: el clúster **k3s ya existe**; aquí solo se instalan las herramientas de cliente.
- **Verificar:** `kubectl version --client` y `helm version --short`.

## 6 · nvidia-container-toolkit (`06-nvidia-runtime.sh`) — solo GPU

- **Qué:** instala `nvidia-container-toolkit` y configura el runtime `nvidia` en containerd.
- **Por qué:** exponer la GPU (RTX 3060) a los contenedores/Pods de FASHN-VTON (`nvidia.com/gpu`).
- **Verificar:** `nvidia-ctk --version` y `nvidia-smi`.

## 7 · Configuración Kolla (`07-kolla-config.sh`) — solo control

- **Qué:** genera `/etc/kolla/multinode` (inventario con los 3 nodos + grupos `:children`), `/etc/kolla/globals.yml` (`binary`, `openstack_release: 2025.2`, VIP) y `/etc/kolla/passwords.yml` (`kolla-genpwd`).
- **Verificar:** `ls /etc/kolla/{multinode,globals.yml,passwords.yml}`.

## 8 · Bootstrap + prechecks (`08-kolla-bootstrap.sh`) — solo control

- **Qué:** `kolla-ansible bootstrap-servers` (prepara los nodos) y `kolla-ansible prechecks` (valida prerrequisitos).
- **Clave:** exportar `PATH=/opt/kolla-ansible/bin:$PATH` (kolla-ansible invoca `ansible-playbook` por PATH).
- **Verificar:** el `prechecks` termina sin errores (PLAY RECAP sin `failed`).

## 9 · `/etc/hosts` + avahi (`09-kolla-hosts.sh`) — todos

- **Qué:** entradas únicas de hostname→IP en `/etc/hosts` y desactiva `avahi-daemon` (mDNS), que hace que el hostname resuelva a varias IPs y rompe el precheck de RabbitMQ.
- **Verificar:** `getent ahostsv4 <hostname>` devuelve una sola IP.

## 10 · Verificación integral (`10-verificar.sh`) — todos (solo lectura)

- **Qué:** informe PASS/FAIL/WARN de nodos, Docker, k3s, dashboard, Kolla, OpenStack, GPU y red.
- **Verificar:** ejecutarlo y revisar el resumen.

## 11 · Deploy (`11-kolla-deploy.sh`) — solo control

- **Qué:** libera el puerto 5000 (escala a 0 el `vton-registry` del k3s si choca con Keystone), ejecuta `kolla-ansible deploy` (descarga imágenes y arranca OpenStack) y `post-deploy` (genera `/etc/kolla/admin-openrc.sh`).
- **Por qué:** es el paso que **enciende** OpenStack (hasta aquí solo estaba "instalado pero apagado").
- **Verificar:** `docker ps | grep -E 'keystone|horizon|nova|neutron'` y `source /etc/kolla/admin-openrc.sh && openstack service list`.

## 12 · Recursos base de OpenStack (`12-openstack-recursos.sh`) — control

- **Qué:** crea flavors (`m1.tiny/small/medium`, `gpu.1`), imagen Cirros, keypair `admin-key`, reglas del security group y una red self-service (VXLAN `10.10.10.0/24`) + router.
- **Verificar:** `openstack flavor list`, `openstack network list`, `openstack keypair list`.

## 13 · Cinder — almacenamiento en bloque (`13-openstack-cinder.sh`) — control+storage

- **Qué:** crea un VG LVM (`cinder-volumes`, loopback 30 GB) en el nodo de storage, habilita `enable_cinder` + `enable_cinder_backend_lvm` en `globals.yml` y re-despliega.
- **Ojo:** si falla el `db sync` con "ProxySQL Access denied", re-ejecutar el **deploy completo** (sin `--tags`) para que ProxySQL sincronice el usuario `cinder` (ver E14).
- **Verificar:** `openstack volume service list` (cinder-volume `up`) y crear/borrar un volumen.

---

## Notas

- Los scripts 00-13 son **idempotentes**: re-ejecutarlos no duplica ni rompe nada.
- El orden **es importante** (cada script declara su prerequisito).
- `run-all.sh` ejecuta la secuencia **00-09** (instalación + preparación) y guarda log en `logs/`. El **`deploy` (11)** se ejecuta aparte por ser la operación pesada.
