# Respaldo reproducible del laboratorio Kubernetes + Rook-Ceph + WordPress

Este directorio contiene **todo lo necesario para recrear el laboratorio desde
cero en un equipo externo**: red libvirt, cloud-init de las VMs, scripts de
instalación/configuración y los manifiestos YAML de Kubernetes.

## Flujo completo de despliegue

> **Atajo:** `scripts/deploy-all.sh` ejecuta en el anfitrión los pasos 0-2 y te
> indica los pasos 3-4. Los pasos 3-4 corren en **k8-master**.

Los pasos de libvirt/VMs corren en el **anfitrión**; `kubectl`/`kubeadm` corren
en **k8-master**.

0. **Preparar imágenes** (descargar base de Ubuntu + overlays qcow2):
   ```bash
   cd deployment-set
   scripts/prepare-images.sh
   ```

1. **Generar cloud-init** (user-data + meta-data + seed.iso):
   ```bash
   cd deployment-set
   scripts/gen-cloud-init.sh ~/.ssh/id_ed25519.pub
   ```
   - Genera `cloud-init/<nodo>-user-data`, `-meta-data` y `-seed.iso`.
   - Nodos: `k8-master`, `k8-worker1..4`, `ceph-admin` (opcional/histórico).
   - Usa `--no-iso` si no quieres regenerar los seed.iso.

2. **Crear la red y las VMs**:
   ```bash
   sudo virsh net-define net/k8s-lab-network.xml
   sudo virsh net-start k8s-lab
   sudo virsh net-autostart k8s-lab
   scripts/create-k8s-lab-vms.sh          # crea k8-master + worker1..4 + ceph-admin
   ```
   > Requiere: discos `.qcow2` base y los `*-seed.iso` copiados en
   > `/var/lib/libvirt/images/k8s-lab/`. Los discos `vdb` (OSDs de Ceph)
   > los crea y adjunta automáticamente el propio script.

3. **Instalar el clúster Kubernetes** (en `k8-master`):
   ```bash
   ssh uceda@192.168.90.1
   cd deployment-set
   scripts/bootstrap-cluster.sh
   ```
   - Etapas: `prereq` → `runtime` (containerd) → `packages` (kubeadm) →
     `init` (kubeadm init + Calico) → `join` (workers) → `metallb` →
     `rook` (operador) → `dashboard` (Helm + Dashboard).
   - Se puede ejecutar una etapa sola: `scripts/bootstrap-cluster.sh rook`.

4. **Desplegar la aplicación** (en `k8-master`):
   ```bash
   scripts/deploy-manifests.sh
   ```
   - Aplica en orden: namespace → secrets → Rook-Ceph → StorageClass →
     PVCs → WordPress → MetalLB pool → LoadBalancer → dashboards → NGINX.

## Estructura

```
deployment-set/
├── net/k8s-lab-network.xml          # red libvirt k8s-lab (192.168.90.0/24)
├── cloud-init/                       # user-data.tmpl + <nodo>-{user-data,meta-data,seed.iso}
├── scripts/
│   ├── prepare-images.sh             # descarga imagen base + overlays qcow2
│   ├── gen-cloud-init.sh             # genera user-data + meta-data + seed.iso
│   ├── create-k8s-lab-vms.sh         # crea las VMs + discos vdb (OSD)
│   ├── bootstrap-cluster.sh          # instala el clúster (por etapas)
│   ├── deploy-manifests.sh           # aplica los YAMLs en orden
│   └── deploy-all.sh                 # orquestador (host): pasos 0-2
└── tmp/                              # manifiestos YAML (respaldo canónico)
    ├── 01-wordpress-namespace.yaml
    ├── 02-wordpress-secrets.yaml
    ├── 03-rook-cluster.yaml          # CephCluster (3 mon, 1 mgr, 4 OSDs vdb)
    ├── 04-rook-filesystem.yaml       # CephFilesystem myfs + subvolumegroup
    ├── 05-cephfs-storageclass.yaml
    ├── 06-wordpress-pvcs.yaml        # 3 PVCs CephFS
    ├── 07-wordpress-cephfs.yaml      # Deployment (wordpress+mariadb+redis) + Service
    ├── 08-metallb-k8s-lab-pool.yaml  # IPAddressPool + L2Advertisement
    ├── 09-wordpress-lb-http.yaml     # (obsoleto) Service LoadBalancer HTTP :80
    ├── 10-rook-ceph-mgr-dashboard-external.yaml  # Dashboard Ceph NodePort 32174
    ├── 11-kubernetes-dashboard-rbac.yaml         # admin-user + cluster-admin
    ├── 12-nginx-app.yaml             # NGINX de prueba NodePort 30885
    └── 13-wordpress-ingress.yaml     # Ingress WordPress TLS (https://192.168.90.50)
```

## Topología

| Nodo | IP | Rol |
|---|---|---|
| `k8-master` | 192.168.90.1 | Control-plane |
| `k8-worker1` | 192.168.90.2 | Worker (OSD `vdb`) |
| `k8-worker2` | 192.168.90.3 | Worker (OSD `vdb`) |
| `k8-worker3` | 192.168.90.4 | Worker (OSD `vdb`) |
| `k8-worker4` | 192.168.90.5 | Worker (OSD `vdb`) |
| `ceph-admin` | 192.168.90.40 | Ceph opcional/histórico (cephadm) |

- Red de Pods: Calico `172.16.0.0/16`
- LoadBalancer: MetalLB VIP `192.168.90.50`

## Credenciales (laboratorio)

| Recurso | Usuario | Password |
|---|---|---|
| SSH VMs | `uceda` | llave `~/.ssh/id_ed25519` |
| MariaDB root | `root` | `RootK8sLab2026!` |
| MariaDB WordPress | `wordpress` | `MariaDbK8sLab2026!` |
| WordPress admin | `uceda` | `WordPressK8sLab2026!` |
| Ceph Dashboard | `admin` | `13tAxYZaHbq0ujaxTkmU` |
| Dashboard Kubernetes | `admin-user` | token temporal |

## Accesos web (desde el anfitrión)

| Interfaz | URL |
|---|---|
| WordPress | `https://192.168.90.50/` |
| Dashboard Kubernetes | `https://192.168.90.1:32000` |
| Dashboard Ceph | `http://192.168.90.1:32174/` |
| NGINX prueba | `http://192.168.90.1:30885` |
