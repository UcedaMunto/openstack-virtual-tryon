# 🚀 Implementación — Instalación automatizada de dependencias

> Carpeta con la **secuencia de scripts** que instala todas las dependencias de la plataforma
> (OpenStack Kolla-Ansible + Kubernetes + GPU) sobre **Ubuntu 24.04**.
> Diseñada para ser **idempotente** y **re-desplegable en otras redes** editando un solo archivo.

---

## ✅ Estado actual

- **OpenStack (Kolla-Ansible 21.3.0):** desplegado — 3 hypervisors `up` + servicios Keystone/Glance/Placement/Nova/Neutron/Cinder/Heat/Horizon.
- **Cinder (bloque, LVM):** operativo — `cinder-volume` up (volúmenes creables).
- **Kubernetes (k3s):** activo — 3 nodos Ready + Dashboard en `https://192.168.0.10:30443`.
- **GPU:** NVIDIA RTX 3060 (12 GB) operativa en `server`.

## 🔑 Acceso a interfaces de administración

| Interfaz | URL | Acceso |
|---|---|---|
| **OpenStack Horizon** | `http://192.168.0.200/` | usuario `admin` · password en `/etc/kolla/passwords.yml` (`source /etc/kolla/admin-openrc.sh`) |
| **Kubernetes Dashboard** | `https://192.168.0.10:30443` | token: `kubectl -n kubernetes-dashboard create token admin-user` |

---

## Cómo usar

```bash
cd /home/uceda/Documents/proyecto-en-kubernetes/implementacion

# 1. Editar SOLO el inventario con las IPs/roles de la red:
vim inventory/nodes.env

# 2. (opcional) exportar la contraseña sudo del primer bootstrap:
export SUDO_PASSWORD='<password>'

# 3. Ejecutar toda la secuencia:
bash scripts/run-all.sh
```

O ejecutar paso a paso (recomendado la primera vez):

```bash
bash scripts/00-bootstrap.sh       # sudo NOPASSWD + verificar Ubuntu 24.04
bash scripts/01-base.sh            # paquetes base + chrony
bash scripts/02-docker.sh          # Docker CE + Compose + containerd
bash scripts/03-kolla-ansible.sh   # Kolla-Ansible (venv) [solo control]
bash scripts/04-openstack-cli.sh   # python-openstackclient [solo control]
bash scripts/05-k8s-tools.sh       # kubectl + helm [todos]
bash scripts/06-nvidia-runtime.sh  # nvidia-container-toolkit [solo GPU]
bash scripts/07-kolla-config.sh    # inventario Kolla (multinode) + globals.yml + passwords
bash scripts/08-kolla-bootstrap.sh # bootstrap-servers + prechecks [control]
bash scripts/09-kolla-hosts.sh     # /etc/hosts con IP única + desactivar avahi [todos]
bash scripts/10-verificar.sh       # verificación integral (informe PASS/FAIL/WARN)
bash scripts/11-kolla-deploy.sh    # deploy + post-deploy (OpenStack en línea)
bash scripts/12-openstack-recursos.sh # recursos base: flavors, imagen, keypair, red
bash scripts/13-openstack-cinder.sh   # Cinder (bloque) con backend LVM
```

---

## Secuencia y responsabilidad de cada script

| Script | Nodos | Qué instala | Prerequisito |
|---|---|---|---|
| `00-bootstrap.sh` | todos | sudo NOPASSWD + verificación Ubuntu 24.04/SSH | — |
| `01-base.sh` | todos | curl, git, vim, htop, chrony, python3-venv, jq… | 00 |
| `02-docker.sh` | todos | Docker CE + Compose + containerd | 00 |
| `03-kolla-ansible.sh` | control | Kolla-Ansible en venv `/opt/kolla-ansible` + `/etc/kolla` | 00+02 |
| `04-openstack-cli.sh` | control | `python-openstackclient` (+clientes glance/neutron/nova/cinder) | 03 |
| `05-k8s-tools.sh` | todos | `kubectl` (repo oficial) + `helm` | 00 |
| `06-nvidia-runtime.sh` | GPU | `nvidia-container-toolkit` + runtime containerd | 00+02 |
| `07-kolla-config.sh` | control | inventario Kolla `multinode` + `globals.yml` + `kolla-genpwd` | 03 |
| `08-kolla-bootstrap.sh` | control | `bootstrap-servers` + `prechecks` | 07 |
| `09-kolla-hosts.sh` | todos | `/etc/hosts` con resolución única + desactivar avahi | 00 |
| `10-verificar.sh` | todos | verificación integral (solo lectura, informe) | — |
| `11-kolla-deploy.sh` | control | **`deploy` + `post-deploy`** (arranca OpenStack) | 08 |
| `12-openstack-recursos.sh` | control | recursos base: flavors, imagen Cirros, keypair, red self-service | 11 |
| `13-openstack-cinder.sh` | control+storage | Cinder (bloque) con backend LVM (loopback) | 11 |

---

## Inventario (`inventory/nodes.env`)

Es la **única fuente de verdad** de la red. Contiene:

```bash
NODE01 (control):  anfitrion  192.168.0.10
NODE02 (compute):  asus-tuf   192.168.0.126
NODE03 (GPU):      server     192.168.0.100
```

**Para otra red:** cambiar IPs/nombres/roles y `SUDO_PASSWORD`; el resto no se toca.

---

## Registro (logs)

`run-all.sh` deja un log con timestamp en `logs/run-all-<fecha>.log`.

## 🔁 Borrado y reconstrucción

- **Borrado total** (OpenStack + k3s + Cinder + configs): `bash scripts/destroy-all.sh` (⚠️ destructivo, pide "BORRAR").
- **Guía completa de reconstrucción desde cero:** [`docs/REBUILD-DESDE-CERO.md`](docs/REBUILD-DESDE-CERO.md).

---

## Detalle completo

Ver [`docs/00-orden-de-instalacion.md`](docs/00-orden-de-instalacion.md) para el detalle de cada comando, por qué se instala y cómo verificar.

## Errores y percances

Registro de errores encontrados (y su solución) para futuros reintentos: [`docs/ERRORES-Y-PERCANCES.md`](docs/ERRORES-Y-PERCANCES.md).
