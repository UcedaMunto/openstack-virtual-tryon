# 📜 Scripts de instalación (secuencia 00–11)

> Índice de los scripts de la carpeta. Todos son **idempotentes** (re-ejecutables) y leen la red desde [`../inventory/nodes.env`](../inventory/nodes.env).
> Se ejecutan **en orden**, desde el nodo de control (`anfitrion`), cada uno declara su prerequisito.

## Tabla de scripts

| # | Script | Nodos | Qué hace | Prerequisito |
|---|---|---|---|---|
| 00 | `00-bootstrap.sh` | todos | Habilita `sudo NOPASSWD` y verifica Ubuntu 24.04/SSH | — |
| 01 | `01-base.sh` | todos | Paquetes base (curl, git, vim, chrony, python3-venv, jq…) | 00 |
| 02 | `02-docker.sh` | todos | Docker CE + Compose + containerd | 00 |
| 03 | `03-kolla-ansible.sh` | control | Kolla-Ansible en venv `/opt/kolla-ansible` + `/etc/kolla` | 00+02 |
| 04 | `04-openstack-cli.sh` | control | `python-openstackclient` + clientes glance/neutron/nova/cinder | 03 |
| 05 | `05-k8s-tools.sh` | todos | `kubectl` + `helm` | 00 |
| 06 | `06-nvidia-runtime.sh` | GPU | `nvidia-container-toolkit` + runtime NVIDIA en containerd | 00+02 |
| 07 | `07-kolla-config.sh` | control | Genera `/etc/kolla/multinode` + `globals.yml` + `passwords.yml` | 03 |
| 08 | `08-kolla-bootstrap.sh` | control | `bootstrap-servers` + `prechecks` | 07 |
| 09 | `09-kolla-hosts.sh` | todos | `/etc/hosts` con resolución única + desactiva avahi (mDNS) | 00 |
| 10 | `10-verificar.sh` | todos | Verificación integral (solo lectura, informe PASS/FAIL/WARN) | — |
| 11 | `11-kolla-deploy.sh` | control | **`deploy` + `post-deploy`** (arranca OpenStack) | 08 |
| 12 | `12-openstack-recursos.sh` | control | recursos base: flavors, imagen Cirros, keypair, red self-service | 11 |
| 13 | `13-openstack-cinder.sh` | control+storage | Cinder (bloque) con backend LVM (loopback) | 11 |
| — | `run-all.sh` | todos | Ejecuta la secuencia **00-09** y guarda log | — |

## Cómo ejecutar

```bash
# Todo de una vez (instalación + preparación, sin deploy):
bash scripts/run-all.sh

# O paso a paso (recomendado la primera vez):
bash scripts/00-bootstrap.sh
bash scripts/01-base.sh
# ... (ver ../README.md)

# Despliegue de OpenStack (paso pesado, aparte):
bash scripts/11-kolla-deploy.sh

# Verificación:
bash scripts/10-verificar.sh
```

## Notas

- `run-all.sh` **no incluye** `10-verificar.sh` ni `11-kolla-deploy.sh` (la verificación y el despliegue se corren aparte).
- Los logs quedan en [`../logs/`](../logs/).
- Claves de entorno usadas: `PATH=/opt/kolla-ansible/bin:$PATH` (scripts 08/11, porque kolla-ansible invoca `ansible-playbook` por PATH) y `SUDO_PASSWORD` (solo 00-bootstrap).
