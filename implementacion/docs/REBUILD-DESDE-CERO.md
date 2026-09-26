# 🔁 Reconstrucción desde cero — guía completa

> Procedimiento para **borrar todo** (OpenStack + Kubernetes + Cinder) y **re-levantar** la plataforma usando los scripts `00..13`. Es la referencia única para redespliegues en esta red o en otras.

---

## 0. Prerrequisitos

- **3 nodos físicos Ubuntu 24.04** en la misma red, con `sudo`.
- **SSH sin contraseña** desde el nodo de control hacia los 3 nodos.
- **Docker** disponible (se instala en el paso 02 si falta).
- **Internet** (para descargar imágenes/pip/apt).

> El nodo de control es donde corren los scripts (por defecto `anfitrion`). Editar SOLO `inventory/nodes.env`.

---

## 1. Inventario (`inventory/nodes.env`)

Es la **única fuente de verdad**. Contiene IPs, nombres, roles, NICs y la contraseña sudo del bootstrap:

```bash
NODE01 (control):  anfitrion  192.168.0.10   NIC enp2s0f0
NODE02 (storage):  asus-tuf   192.168.0.126  NIC enp2s0
NODE03 (GPU):      server     192.168.0.100  NIC eno1
```

---

## 2. Borrado total (opcional, solo si hay que empezar limpio)

```bash
bash scripts/destroy-all.sh        # pide escribir "BORRAR"
```

Esto elimina OpenStack, k3s, Cinder, `/etc/kolla`, `/opt/kolla-ansible` e imágenes Docker. **No** toca el SO ni los nodos físicos.

---

## 3. Secuencia completa de instalación

```bash
cd implementacion
vim inventory/nodes.env              # 1) IPs/nombres/roles

bash scripts/00-bootstrap.sh         # 2) sudo NOPASSWD + verificar Ubuntu 24.04
bash scripts/01-base.sh              # 3) paquetes base + chrony
bash scripts/02-docker.sh            # 4) Docker CE + Compose + containerd
bash scripts/03-kolla-ansible.sh     # 5) Kolla-Ansible (venv)  [control]
bash scripts/04-openstack-cli.sh     # 6) openstack CLI          [control]
bash scripts/05-k8s-tools.sh         # 7) kubectl + helm         [todos]
bash scripts/06-nvidia-runtime.sh    # 8) nvidia-container-toolkit [GPU]
bash scripts/07-kolla-config.sh      # 9) multinode + globals + passwords
bash scripts/08-kolla-bootstrap.sh   # 10) bootstrap-servers + prechecks
bash scripts/09-kolla-hosts.sh       # 11) /etc/hosts único + avahi (mask)
bash scripts/11-kolla-deploy.sh      # 12) deploy + post-deploy (¡OpenStack en línea!)
bash scripts/12-openstack-recursos.sh# 13) flavors, imagen, keypair, red
bash scripts/13-openstack-cinder.sh  # 14) Cinder (bloque, LVM)
bash scripts/10-verificar.sh         # 15) verificación integral (0 FAIL esperado)
```

> `run-all.sh` ejecuta automáticamente los pasos **00-09**. Los pasos 10-13 se corren aparte (verificación y despliegue).

---

## 4. Errores comunes (y su solución)

Todos están en [`ERRORES-Y-PERCANCES.md`](ERRORES-Y-PERCANCES.md). Los más importantes:

| # | Error | Fix |
|---|---|---|
| E1 | SSH "Too many authentication failures" | 1 sola identidad / auth por contraseña |
| E4 | `apt-get update` falla (repo ceph-quincy roto) | desactivar el repo |
| E11 | filtro `kolla_address` no carga | `export PATH=/opt/kolla-ansible/bin:$PATH` |
| E12 | hostname resuelve a varias IPs (RabbitMQ) | `09-kolla-hosts.sh` (+ mask avahi) |
| E13 | `docker-compose-v2` vs `docker-compose-plugin`; docker.service enmascarado | quitar `docker-compose-v2`, desenmascarar, override `-H unix://` |
| E14 | `cinder db sync`: "ProxySQL Access denied" | re-ejecutar **deploy completo** (sin `--tags`) |

---

## 5. Acceso final

| Interfaz | URL | Credencial |
|---|---|---|
| **OpenStack Horizon** | `http://192.168.0.200/` | `admin` / ver `/etc/kolla/passwords.yml` |
| **Kubernetes Dashboard** | `https://192.168.0.10:30443` | token `kubectl -n kubernetes-dashboard create token admin-user` |
| **Web del proyecto VTON** | `http://192.168.0.240/` (Host `vton.example.com`) | — |

---

## 6. Decisiones pendientes (no bloqueantes)

1. **Red provider/externa (br-ex)**: los nodos tienen 1 sola NIC; requiere subinterfaces VLAN o plano único.
2. **Object Storage (Swift/MinIO)**: el plan V4 lo requiere para fotos/resultados; el k3s ya usa MinIO.
3. **k3s vs kubeadm**: el proyecto VTON ya corre en k3s; decidir si se reutiliza o se migra a OpenStack.
