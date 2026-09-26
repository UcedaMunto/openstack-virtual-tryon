# 04 — LXC-ceph

Fuente: `~/Documents/ESPECIALIZACION/LXC`. **Ceph en dos sabores**: con Docker Compose (didáctico) y sobre KVM/libvirt (más realista).

## Qué hay aquí

| Archivo/Carpeta | Contenido |
|---|---|
| `GUIA_CEPH_COMPLETA.md`, `GUIA_CEPH_CLUSTER.md` | Guía completa + referencia detallada de Ceph |
| `RESUMEN_EJECUTIVO.md`, `INDICE_DOCUMENTACION.md`, `README.md` | Índices y resumen |
| `docker-compose.yml` + `scripts/` | Cluster Ceph en contenedores (`setup-cluster.sh`, `init-{admin,mon,osd}.sh`) |
| `ceph-kvm/` | Ceph sobre KVM: `up.sh`, `reset.sh`, `start/stop/status.sh`, `scripts/00..30`, `config/cluster.env`, guías |
| `version-kvm/` | PDF de cluster-ceph (referencia) |

## Relevancia para el proyecto

- **Entender Ceph** (MON/MGR/OSD, pools, keyrings, monmap) sin levantar infraestructura.
- **Patrón de 2 planos** (admin/data o public/cluster) → replicar en las redes storage/tunnel del proyecto.
- `ceph-kvm/` es el puente entre Ceph "nativo" y el **Rook-Ceph dentro de Kubernetes** que usará el proyecto.
