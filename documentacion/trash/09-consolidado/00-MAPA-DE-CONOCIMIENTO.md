# 🧠 Mapa de Conocimiento Consolidado

> Síntesis técnica de lo aprendido en las 7 implementaciones previas, organizada por tecnología y orientada a **levantar el proyecto OpenStack (Kolla-Ansible) + Kubernetes + FASHN-VTON**.

---

## 1. Visión general: de dónde venimos y adónde vamos

Todas las implementaciones previas comparten un mismo patrón de laboratorio sobre **KVM/QEMU + libvirt**:

```
HOST físico (KVM/libvirt)
 ├── Redes libvirt (XML)  ──►  bridges software (NAT / aislada / route)
 ├── VMs aprovisionadas con cloud-init (seed.iso) + qcow2 base
 │    ├── OpenStack:  controller + compute(s) + storage + network
 │    └── Kubernetes:  master + workers (OSD) [+ ceph-admin]
 └── Dentro de las VMs:
      ├── OpenStack  →  Kolla-Ansible (contenedores)  o  OSA (LXC)
      ├── Kubernetes →  kubeadm + Calico + MetalLB + Rook-Ceph
      └── Ceph       →  docker-compose | KVM nativo | Rook dentro de K8s
```

**El salto del proyecto actual:** pasar del laboratorio anidado (VMs dentro de VMs) a **3 nodos físicos bare-metal**, con OpenStack desplegado vía **Kolla-Ansible** (no OSA), y Kubernetes como orquestador de la aplicación.

---

## 2. OpenStack: Kolla-Ansible vs OpenStack-Ansible (OSA)

### 2.1 Lo que se demostró en el laboratorio

| Aspecto | OSA (manual, `InstalacionOpenstack/`) | Kolla-Ansible (`openstack-ansible/`) |
|---|---|---|
| Empaquetado de servicios | Contenedores **LXC** por servicio | Contenedores **Docker** por servicio |
| Nodos extra | `deploy-node` separado | El "deploy" es el host Ansible (localhost) |
| Bridges requeridos | `br-mgmt`, `br-vlan`, `br-vxlan`, `br-storage` (4) | Sólo las redes que declares (mgmt/tunnel/external) |
| Inventario | `openstack_user_config.yml` (YAML anidado) | `inventory/multinode` (INI con grupos) |
| Complejidad operativa | Alta (sobreingeniería a 3 nodos) | **Menor** → es la elección del proyecto V4 |

### 2.2 Inventario Kolla-Ansible real (reutilizable)

El archivo `01-InstalacionOpenstack/openstack-ansible/ansible/inventory/multinode` es el inventario canónico. Grupos base:

```ini
[control]     os-controller ansible_host=192.168.60.10
[network]     os-network   ansible_host=192.168.60.20
[compute]     os-compute01 ... / os-compute02 ...
[storage]     os-storage01 ...
[deployment]  localhost ansible_connection=local

[all:vars]
ansible_user=uceda
ansible_become=true
ansible_python_interpreter=/usr/bin/python3
```

> **Traducción al proyecto (3 nodos):** control+network+compute-cpu en NODE-01, compute+storage en NODE-02, compute-gpu en NODE-03. Los grupos `[control]`, `[compute]`, `[storage]`, `[monitoring]` se rellenan con los hosts del `.env` del proyecto (`10.10.0.11/12/13`).

### 2.3 Redes OpenStack y sus XML

Los XML de `openstack-ansible/networks/` explican **el porqué** de cada red (recomendado leer sus comentarios):

| Red libvirt | Equivale a | Modo | Subred lab |
|---|---|---|---|
| `os-mgmt` | `br-mgmt` | NAT + DHCP | 192.168.60.0/24 |
| `os-tunnel` | `br-vxlan` | aislada, sin DHCP | 10.10.20.0/24 |
| `os-external` | `br-ex`/provider | bridge puro (L2) | — |

> **Proyecto actual:** `.env` define `MGMT 10.10.0.0/24`, `STORAGE 10.10.2.0/24`, `TUNNEL 10.10.3.0/24`, `EXTERNAL 10.10.4.0/24`. Son las mismas 3 redes físicas del lab (mgmt/tunnel/external) más una de storage, ya sin NAT (bare-metal).

### 2.4 cloud-init de nodos (patrón reutilizable)

`openstack-ansible/cloud-init/<nodo>/` demuestra el patrón ideal:
- `network-config` (netplan v2): IP estática en `enp1s0` (mgmt) + `enp2s0` (tunnel), sin DHCP.
- `user-data`: `qemu-guest-agent`, `python3`, usuario `uceda` sudo NOPASSWD, `ssh_authorized_keys`, `disable_root: true`.
- `scripts/gen-user-data.sh`: sustituye `__SSH_PUBLIC_KEY__` en `user-data.tmpl` → la clave `.pub` es la única fuente de verdad.

---

## 3. Kubernetes: el patrón completo (kubeadm → app)

El laboratorio `openstack-ansible/kubernetes/` es **la implementación de referencia más valiosa** para el proyecto. Flujo reproducido de punta a punta:

```
prepare-images.sh → gen-cloud-init.sh → create-k8s-lab-vms.sh
        (host)             (host)                (host)
                        ↓
bootstrap-cluster.sh (k8-master): prereq→runtime(containerd)→packages(kubeadm)
   →init(kubeadm+Calico)→join(workers)→metallb→ingress(nginx)→rook→dashboard
                        ↓
deploy-manifests.sh: ns→secrets→Rook-Ceph→StorageClass→PVC→WordPress→MetalLB→Ingress
```

**Decisiones técnicas probadas (copiar en el proyecto):**
- **Runtime:** `containerd` con `SystemdCgroup = true` (obligatorio para kubeadm v1.36).
- **CNI:** Calico v3.32.1 (tigera-operator + custom-resources), Pod CIDR `172.16.0.0/16`.
- **LoadBalancer bare-metal:** MetalLB v0.16.1 (IPAddressPool + L2Advertisement).
- **Ingress:** ingress-nginx vía Helm, `controller.service.type=LoadBalancer`.
- **Storage:** Rook v1.20.6 + Ceph v20.2.4 (`CephCluster` con 3 MON, 1 MGR, 4 OSD en `vdb`), `CephFilesystem` + StorageClass CephFS.
- **Observabilidad:** Dashboard de Kubernetes 7.14.0 (NodePort 32000) + Dashboard Ceph (NodePort 32174).

**Manifests canónicos** (`kubernetes/tmp/`): numerados 01..13 para aplicar en orden (namespace → secrets → rook → storageclass → pvcs → wordpress → metallb → ingress → dashboards → nginx).

> **Traducción al proyecto:** el Worker GPU equivale a un `k8-worker` con `nvidia` runtime; los manifests de la app SaaS reemplazan a WordPress; el Object Storage (Swift/S3) puede convivir con CephFS para PVCs.

---

## 4. Ceph: tres caminos equivalentes

1. **Docker Compose** (`04-LXC-ceph/`): `ceph-admin`+`ceph-mon`+3 OSD, 2 redes (`admin_net`, `data_net`), `setup-cluster.sh` idempotente. Útil para **entender** Ceph sin VMs.
2. **KVM nativo** (`04-LXC-ceph/ceph-kvm/` y `02-cluster-ceph/`): redes libvirt separadas por plano, `bootstrap-ceph.sh`, `cephadm`, OSDs en discos `vdb`.
3. **Rook dentro de K8s** (`kubernetes/tmp/03-rook-cluster.yaml`): el camino recomendado para el proyecto, porque el storage queda gestionado por Kubernetes.

**Conceptos consolidados:**
- Planos separados: **public/`data_net`** (clientes) vs **cluster/`cluster_net`** (replicación OSD).
- `ceph status` salud = `HEALTH_OK`; `ceph osd tree`; `ceph df`.
- Bootstrap keys + monmap + keyrings → ver `setup-cluster.sh` (docker) o `30-bootstrap-ceph.sh` (kvm).

---

## 5. KVM/libvirt: crear VMs, redes y bridges

**Patrones canónicos de creación de VMs** (`create-kvm-vm.sh` en `02-cluster-ceph/kvm-generic/` y `proyecto-manual-infraestructura/`):
```bash
virt-install --name <vm> --memory <MB> --vcpus <n> --cpu host-passthrough \
  --import --disk path=<vm>.qcow2,format=qcow2,bus=virtio \
  --disk path=<vm>-seed.iso,device=cdrom \
  --network network=<red>,model=virtio,mac=52:54:00:... \
  --os-variant ubuntu24.04 --graphics none --noautoconsole
```

**Redes libvirt (XML):** `05-redes-xml-kvm/` + `openstack-ansible/networks/` + `backups/libvirt-networks/` contienen los tres tipos: NAT (`<forward mode='nat'/>`), aislada (sin `<forward>`), y route/bridge. El archivo `k8s-lab-network.xml` muestra DHCP con reservas por MAC (`<host mac=... ip=.../>`).

**Bridges y VLAN** (`03-PRACTICA-KVM/`): guías de `br0`/`bridge01dh`, VLAN trunking, `ip addr show`, NIC bonding. Complementan los 4 bridges de OpenStack.

---

## 6. Ansible: automatización idempotente

`07-documentacion-ansible/` es la guía conceptual + código real. Estructura de roles reutilizable:

```
ansible/
├── inventory/{hosts.yml, group_vars/{all,controller,compute}.yml}
├── playbooks/{site,bridges,controller,computes,verify}.yml
└── roles/{common, linux-bridges, ovs-bridges, nova-compute, neutron-ovs-agent}/
```

**Lección clave — idempotencia:** usar módulos declarativos (`openvswitch_bridge`, `apt`, `lineinfile`) en vez de comandos crudos (`ovs-vsctl add-br`), para que re-ejecutar sea seguro.

---

## 7. Datos y HA (del cluster-ceph, útil para PostgreSQL/Redis del SaaS)

El patrón de `proyecto-manual-infraestructura/` demuestra HA de datos sobre KVM:
- **MariaDB Galera** (3 nodos) + **MaxScale** (read-write split, puertos 3306/4008) → análogo a PostgreSQL HA del proyecto.
- **Redis** (1+n réplicas) para sesiones/cache.
- **NGINX L7** (VRRP 112) como balanceador/Ingress.
- **DNS** jerárquico (raíz → delegación).
- **Healthchecks** en `tools-sh/healthcheck-infra.sh` y `check-logs-all.sh`.

> **Traducción:** PostgreSQL (sección 33-34 de V4) puede seguir el patrón Galera (replicación + failover), Redis (sección 35) el patrón Redis réplica, y el Ingress el patrón NGINX L7 + MetalLB.

---

## 8. Errores/trampas ya resueltas (para no repetirlos)

1. **`/32` en interfaz de tunnel** cuando hay varias NIC: evita que el kernel elija la ruta equivocada frente a `br-mgmt` (nota en `networks/os-tunnel.xml`).
2. **`SystemdCgroup=true`** en containerd o kubelet no arranca con kubeadm moderno.
3. **Clonar computes**: borrar `compute_id`/UUID y las instancias libvirt heredadas antes de arrancar `nova-compute` (ver `01-.../documentacion/02-...`).
4. **OVS vs Linux bridges**: no mezclar; Ansible debe gestionar ambos de forma idempotente.
5. **STP `stp='on' delay='0'`** en bridges libvirt para convergencia inmediata.

---

## 9. Cómo se mapea todo al proyecto (resumen)

| Etapa V4 del proyecto | Recurso consolidado a usar |
|---|---|
| Etapa 0-1 (direccionamiento, hardware, red) | `.env` del proyecto + `openstack-ansible/networks/*.xml` + `03-PRACTICA-KVM` |
| Etapa 1.5-2 (bootstrap Ansible + Kolla) | `07-documentacion-ansible` + `ansible/inventory/multinode` + `cloud-init` |
| Etapa 3-3.5 (VMs base + Ansible) | `cloud-init/*` + `create-k8s-lab-vms.sh` (adaptado) |
| Etapa 4 (Kubernetes) | `kubernetes/scripts/bootstrap-cluster.sh` + `deploy-manifests.sh` |
| Etapa 5-7 (servicios de plataforma + app) | `kubernetes/tmp/*.yaml` (patrón manifests) + `cluster-ceph` (patrón datos) |
| Etapa 8 (seguridad/observabilidad) | `tools-sh/healthcheck-infra.sh` + dashboards |

