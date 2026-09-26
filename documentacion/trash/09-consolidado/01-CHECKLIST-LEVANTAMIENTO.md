# ✅ Checklist de Levantamiento — openstack-virtual-tryon

> Hoja de ruta accionable que traduce las 9 etapas de la arquitectura V4 a pasos concretos, apuntando al recurso consolidado de `documentacion/` que resuelve cada paso.

---

## Etapa 0 — Direccionamiento (solo en papel)

- [ ] Confirmar las 4 redes en `.env`: MGMT `10.10.0.0/24`, STORAGE `10.10.2.0/24`, TUNNEL `10.10.3.0/24`, EXTERNAL `10.10.4.0/24`.
- [ ] Asignar IPs fijas a los 3 nodos (NODE-01 `10.10.0.11`, NODE-02 `10.10.0.12`, NODE-03 `10.10.0.13`).
- Referencia: `../00-INDICE-GENERAL.md` + `01-InstalacionOpenstack/openstack-ansible/networks/*.xml` (semántica de cada red).

## Etapa 1 — Hardware, BIOS y red física

- [ ] Activar virtualización anidada (AMD-V/Intel VT-x) — ver notas de `01-InstalacionOpenstack/README.md`.
- [ ] Configurar switches/VLANs: 10 (mgmt), 30 (storage), 40 (tunnel), 50 (external).
- [ ] Validar bridges y STP: patrón `stp='on' delay='0'` de `networks/*.xml` y `05-redes-xml-kvm/`.
- Referencia: `03-PRACTICA-KVM/` (bridges/VLAN), `05-redes-xml-kvm/`.

## Etapa 1.5 — Bootstrap con Ansible

- [ ] Crear usuario administrador + clave SSH (patrón `cloud-init/user-data`: sudo NOPASSWD, `disable_root`).
- [ ] Escribir inventario Ansible bare-metal (analogía: `07-documentacion-ansible/ansible/inventory/hosts.yml`).
- [ ] Playbook `00_connectivity` + `01_base_os` + `02_network` + `03_hardening` (roles de `07-documentacion-ansible`).
- Referencia: `07-documentacion-ansible/09-EJECUCION.md`, `01-CONCEPTOS-ANSIBLE.md`.

## Etapa 2 — OpenStack con Kolla-Ansible

- [ ] Instalar Kolla-Ansible + pip (venv), generar `passwords.yml` con `kolla-genpwd`.
- [ ] Declarar `multinode` (grupos `control`, `network`, `compute`, `storage`, `monitoring`) con IPs del `.env`.
- [ ] Definir redes: mgmt/tunnel/external/storage → `openstack-ansible/networks/*.xml` como modelo conceptual.
- [ ] `kolla-ansible bootstrap-servers` → `prechecks` → `deploy`.
- Referencia: `01-InstalacionOpenstack/openstack-ansible/ansible/inventory/multinode` + `hosts-minimal-backup.ini`.

## Etapa 3 / 3.5 — VMs base + configuración

- [ ] Imágenes base Ubuntu 24.04 (`noble-server-cloudimg-amd64.img`).
- [ ] cloud-init por VM: `user-data` + `network-config` + `seed.iso` (patrón `cloud-init/`).
- [ ] Crear VMs con `virt-install` (patrón `create-k8s-lab-vms.sh`).
- Referencia: `01-InstalacionOpenstack/openstack-ansible/cloud-init/`, `scripts/gen-user-data.sh`.

## Etapa 4 — Kubernetes

- [ ] `bootstrap-cluster.sh` adaptado: `prereq` (swap off, módulos, sysctl) → `runtime` (containerd `SystemdCgroup=true`) → `packages` (kubeadm v1.36) → `init` (Calico) → `join` (workers).
- [ ] MetalLB (`metallb-native.yaml` + IPAddressPool).
- [ ] ingress-nginx vía Helm (LoadBalancer).
- [ ] Rook-Ceph: operador + `CephCluster` (OSDs) + `CephFilesystem` + StorageClass.
- Referencia: `01-InstalacionOpenstack/openstack-ansible/kubernetes/scripts/bootstrap-cluster.sh`, `deploy-manifests.sh`.

## Etapa 5 — Servicios de plataforma

- [ ] Desplegar manifests en orden (patrón `tmp/01..13`): namespace → secrets → storage → DB → Redis → cola → API.
- [ ] Object Storage: Swift/S3 (análogo al patrón CephFS/Rook).
- Referencia: `kubernetes/tmp/*.yaml`, `02-cluster-ceph/proyecto-manual-infraestructura` (patrón datos HA).

## Etapa 6 — Worker FASHN-VTON (GPU)

- [ ] Instalar NVIDIA driver + `nvidia-container-toolkit` en NODE-03.
- [ ] Configurar `nvidia` runtime en containerd; tolerations/nodeSelector `gpu=true`.
- [ ] GPU passthrough si se virtualiza (ver `17. GPU passthrough` de V4).
- Referencia: patrón worker de `kubernetes/scripts/create-k8s-lab-vms.sh` + `kubernetes/puml/02-workers.puml`.

## Etapa 7 — Aplicación SaaS

- [ ] Frontend, Backend API, Upload Service, Workers: manifests numerados + `deploy-manifests.sh` como orquestador.
- [ ] Ingress + TLS (patrón `13-wordpress-ingress.yaml` con cert autofirmado → sustituir por cert real).
- Referencia: `kubernetes/tmp/07-wordpress-cephfs.yaml` (Deployment+Service), `13-wordpress-ingress.yaml`.

## Etapa 8 — Seguridad, observabilidad, recuperación

- [ ] Prometheus/Grafana + dashboards (patrón `kubernetes/tmp/10,11`).
- [ ] Healthchecks periódicos (patrón `02-cluster-ceph/proyecto-manual-infraestructura/tools-sh/healthcheck-infra.sh`).
- [ ] Backups PostgreSQL + Object Storage + etcd (patrón `configuraciones-backups.sh`).

## Etapa 9 — Capacidad comercial

- [ ] Benchmark GPU (`79. Benchmark obligatorio` de V4).
- [ ] Rate limiting, prioridades de cola, medición de consumo.

---

## 🔧 Comandos rápidos de verificación (recopilados)

```bash
# OpenStack
openstack compute service list
openstack network agent list

# Kubernetes
kubectl get nodes -o wide
kubectl -n rook-ceph get cephcluster cephfilesystem

# Ceph
ceph -s
ceph osd tree

# libvirt
virsh net-list --all
virsh list --all
```
