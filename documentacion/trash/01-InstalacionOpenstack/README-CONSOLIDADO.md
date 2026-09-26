# 01 — InstalacionOpenstack

Fuente: `~/Documents/InstalacionOpenstack`. Es la fuente **más rica**: contiene el OpenStack manual (OSA con LXC) y, dentro de `openstack-ansible/`, el **laboratorio Kolla-Ansible + Kubernetes + Rook-Ceph** que es la referencia directa del proyecto.

## Qué hay aquí

| Subcarpeta | Contenido |
|---|---|
| `documentacion/` | Guías 01-10 de OpenStack manual: crear VMs, añadir computes, Ceph, Swift, RBD, bridges |
| `openstack-ansible/` | **Kolla-Ansible + K8s**: `ansible/inventory/multinode`, `networks/*.xml`, `cloud-init/*`, `kubernetes/*` (scripts + manifests + docs) |
| `guia_ansible_v1.0/` | Guía Ansible (PDF/HTML/MD) + `ansible-lab-net.xml` |
| `puml/`, `pumla-actual/` | Diagramas PlantUML de topología/redes/OSA-LXC |
| `verificacion-openstack/` | Guía de verificación + informe de salud RBD-Ceph |
| `instalacion-wordpress/` | Ejemplo completo: WordPress sobre OpenStack |

## Archivos sueltos clave

- `README.md` — arquitectura del lab (controller + 4 computes), credenciales, inventario.
- `setup-openstack-resources.sh` — crea flavors/redes/router/security groups/keypair.
- `fix-openstack-bugs.sh` — corrige bugs del despliegue inicial.

## Relevancia para el proyecto

- Inventario `multinode` y `networks/*.xml` → patrón directo para Kolla-Ansible de 3 nodos.
- `openstack-ansible/kubernetes/` → implementación completa de kubeadm+Calico+MetalLB+Rook-Ceph.
- PlantUML de redes → base para los diagramas `diagrams/*.puml` del proyecto.
