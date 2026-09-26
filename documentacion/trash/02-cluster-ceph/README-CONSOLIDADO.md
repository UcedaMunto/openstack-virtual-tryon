# 02 — cluster-ceph

Fuente: `~/Documents/cluster-ceph`. Infraestructura **HA/HC empresarial sobre KVM** (WinterCMS en `ti.mimas.net`) que demuestra el patrón de datos en clúster: Ceph, MariaDB Galera + MaxScale, Redis, NGINX L7, DNS y monitorización.

## Qué hay aquí

| Subcarpeta | Contenido |
|---|---|
| `proyecto-manual-infraestructura/` | Infra HA completa: `README.MD` (tabla nodos/redes), `configuraciones-*.sh`, `tools-sh/healthcheck-infra.sh`, `doc/puml/`, ejemplo Django |
| `proyecto-infra/` | Proyecto por fases (01-bases → 99-validacion) con guías + scripts + `generated/` |
| `proyecto-infraestructura/` | Subconjunto (datos/Redis) |
| `kvm-generic/` | Utilidades KVM genéricas: `create-kvm-vm.sh`, `vm-common.sh`, `create-libvirt-network.sh`, `first-boot-example.sh` |
| Archivos sueltos | `setup-kvm.md`, `limpiar-kvm-ceph.md`, `limpiar-ceph-kvm.sh`, `comandos ejecutados.txt` |

## Relevancia para el proyecto

- **Patrón de datos HA** (Galera+MaxScale, Redis réplica) → análogo a PostgreSQL/Redis del SaaS (V4 §33-35).
- **NGINX L7 + VRRP** → patrón de Ingress/balanceo.
- **Healthchecks** (`tools-sh/`) → base para la observabilidad (V4 §50-52).
- **`kvm-generic/`** → utilidades KVM reutilizables tal cual.
