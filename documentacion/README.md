# 📚 Base de Conocimiento — openstack-virtual-tryon

> **Punto de entrada único** a toda la documentación consolidada de las implementaciones previas.
> **Stack objetivo:** OpenStack (Kolla-Ansible) + Kubernetes + FASHN-VTON 1.5 · 3 nodos físicos · red local única.
> **Fecha de consolidación:** 2026-09-24

> 🔗 **Documentos hermanos:**
> - Arquitectura: [`../ARQUITECTURA_SAAS_IA_OPENSTACK_KOLLA_K8S_V4.md`](../ARQUITECTURA_SAAS_IA_OPENSTACK_KOLLA_K8S_V4.md) (secciones enlazadas con esta base en su §100).
> - Verificación de factibilidad y revisión del plan: [`VERIFICACION-PLAN-Y-FACTIBILIDAD.md`](VERIFICACION-PLAN-Y-FACTIBILIDAD.md).
> - Revisión del sistema/red actual (factibilidad real del hardware): [`REVISION-SISTEMAS.md`](REVISION-SISTEMAS.md).
> - Inventario de los 3 equipos (IPs, specs, GPU, SSH): [`INVENTARIO-EQUIPOS.md`](INVENTARIO-EQUIPOS.md).
> - Instalación automatizada de dependencias (scripts secuenciales): [`../implementacion/README.md`](../implementacion/README.md).

---

## Índice

1. [Cómo usar esta documentación](#1-cómo-usar-esta-documentación)
2. [Organización y clasificación (estructura de carpetas)](#2-organización-y-clasificación)
3. [Mapa de conocimiento consolidado (por tecnología)](#3-mapa-de-conocimiento-consolidado)
4. [Checklist de levantamiento (etapas 0–9)](#4-checklist-de-levantamiento)
5. [Índice de recursos (scripts · XML · YAML · PlantUML · configs)](#5-índice-de-recursos)
6. [Carpeta `trash/` (los .md originales)](#6-carpeta-trash)
7. [Seguridad](#7-seguridad)
8. [Regenerar la base](#8-regenerar-la-base)
9. [Verificación de factibilidad y revisión del plan](#9-verificación-de-factibilidad)

---

## 1. Cómo usar esta documentación

1. Lee este `README.md` de principio a fin para ubicarte.
2. Usa el **§3 (Mapa de conocimiento)** para entender qué tecnología resuelve cada pieza del proyecto.
3. Usa el **§4 (Checklist)** como hoja de ruta accionable etapa por etapa.
4. Ve al **§5 (Índice de recursos)** para localizar el script/XML/YAML/PlantUML concreto que necesitas copiar o adaptar.

> Los **`.md` originales** de los proyectos fuente fueron movidos a [`trash/`](trash/) (ver §6); aquí se conservan únicamente los **activos ejecutables** (scripts, XML, YAML, PlantUML, configs, templates) organizados por tema.

---

## 2. Organización y clasificación

Los activos están **segmentados por tecnología** en 7 carpetas temáticas (más `trash/`):

| Carpeta | Tema | Fuente original | Activos clave que contiene |
|---|---|---|---|
| [`01-InstalacionOpenstack/`](01-InstalacionOpenstack/) | **OpenStack** (manual OSA + lab Kolla-Ansible + K8s) | `~/Documents/InstalacionOpenstack` | inventario Kolla `multinode`, `networks/*.xml`, `cloud-init/*`, scripts, PlantUML, laboratorio `kubernetes/` |
| [`02-cluster-ceph/`](02-cluster-ceph/) | **Infra HA/HC sobre KVM** (Ceph, DB, Redis, NGINX, DNS) | `~/Documents/cluster-ceph` | `configuraciones-*.sh`, `kvm-generic/`, `tools-sh/healthcheck`, `doc/puml/`, ejemplo Django |
| [`03-PRACTICA-KVM/`](03-PRACTICA-KVM/) | **KVM/libvirt + bridges + VLAN** | `~/Documents/ESPECIALIZACION/LAB 1/PRACTICA` | `crear_vms*.sh`, `start/stop_vms_bridge01.sh`, `verificar_*.sh`, `relaciones.puml` |
| [`04-LXC-ceph/`](04-LXC-ceph/) | **Ceph** (Docker Compose + KVM) | `~/Documents/ESPECIALIZACION/LXC` | `docker-compose.yml`, `scripts/init-*.sh`, `ceph-kvm/scripts/00..30`, `config/cluster.env` |
| [`05-redes-xml-kvm/`](05-redes-xml-kvm/) | **Redes libvirt (XML)** | `~/Documents/redes-xml-kvm` | `openstack-{admin,public,provider}.xml` |
| [`06-guias123/`](06-guias123/) | **Fundamentos de red y virtualización** (texto) | `~/Documents/ESPECIALIZACION/guias123` | `icc115-{bridge-linux,guia-lxc,kvm-guia-basica}.txt` |
| [`07-documentacion-ansible/`](07-documentacion-ansible/) | **Ansible** (roles + playbooks + inventario) | `~/Documents/InstalacionOpenstack/documentacion_ansible` | `ansible/inventory/`, `ansible/playbooks/`, `ansible/roles/{linux-bridges,ovs-bridges,nova-compute,neutron-ovs-agent}/` |
| [`trash/`](trash/) | **.md originales** (referencia, fuera del flujo) | *(movidos aquí)* | todos los `.md` fuente conservando su ruta relativa |


---

## 3. Mapa de conocimiento consolidado

### 3.1 Visión general

Todas las implementaciones previas comparten un mismo patrón de laboratorio sobre **KVM/QEMU + libvirt**:

```
HOST físico (KVM/libvirt)
 ├── Redes libvirt (XML)  ──►  bridges software (NAT / aislada / bridge)
 ├── VMs aprovisionadas con cloud-init (seed.iso) + qcow2 base
 │    ├── OpenStack:  controller + compute(s) + storage + network
 │    └── Kubernetes:  master + workers (OSD) [+ ceph-admin]
 └── Dentro de las VMs:
      ├── OpenStack  →  Kolla-Ansible (contenedores)  o  OSA (LXC)
      ├── Kubernetes →  kubeadm + Calico + MetalLB + Rook-Ceph
      └── Ceph       →  docker-compose | KVM nativo | Rook dentro de K8s
```

**Salto del proyecto actual:** pasar del laboratorio anidado (VMs dentro de VMs) a **3 nodos físicos bare-metal**, con OpenStack desplegado vía **Kolla-Ansible** (no OSA) y Kubernetes como orquestador de la aplicación.

### 3.2 OpenStack: Kolla-Ansible vs OpenStack-Ansible (OSA)

| Aspecto | OSA (manual) | Kolla-Ansible (elegido) |
|---|---|---|
| Empaquetado | Contenedores **LXC** | Contenedores **Docker** |
| Nodos extra | `deploy-node` separado | deploy = host Ansible (`localhost`) |
| Bridges | 4 (`br-mgmt`, `br-vlan`, `br-vxlan`, `br-storage`) | sólo los que declares (mgmt/tunnel/external) |
| Inventario | `openstack_user_config.yml` | `inventory/multinode` (INI) |
| Complejidad a 3 nodos | Alta | **Menor** |

**Inventario Kolla canónico** (`01-InstalacionOpenstack/openstack-ansible/ansible/inventory/multinode`):

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

> **Traducción al proyecto:** `[control+network+compute-cpu]` → NODE-01, `[compute+storage]` → NODE-02, `[compute-gpu]` → NODE-03, con las IPs del `.env` (`10.10.0.11/12/13`).

### 3.3 Redes OpenStack y sus XML

Los XML de `01-InstalacionOpenstack/openstack-ansible/networks/` explican el **porqué** de cada red (leer sus comentarios):

| Red libvirt | Equivale a | Modo | Subred lab | Proyecto (.env) |
|---|---|---|---|---|
| `os-mgmt` | `br-mgmt` | NAT + DHCP | 192.168.60.0/24 | `MGMT 10.10.0.0/24` |
| `os-tunnel` | `br-vxlan` | aislada, sin DHCP | 10.10.20.0/24 | `TUNNEL 10.10.3.0/24` |
| `os-external` | `br-ex`/provider | bridge puro (L2) | — | `EXTERNAL 10.10.4.0/24` |
| *(storage)* | `br-storage` | aislada | — | `STORAGE 10.10.2.0/24` |

### 3.4 cloud-init de nodos (patrón reutilizable)

`01-InstalacionOpenstack/openstack-ansible/cloud-init/<nodo>/` demuestra el patrón ideal:
- `network-config` (netplan v2): IP estática en `enp1s0` (mgmt) + `enp2s0` (tunnel), sin DHCP.
- `user-data`: `qemu-guest-agent`, `python3`, usuario sudo NOPASSWD, `ssh_authorized_keys`, `disable_root: true`.
- `scripts/gen-user-data.sh`: sustituye `__SSH_PUBLIC_KEY__` en `user-data.tmpl` → la clave `.pub` es la única fuente de verdad.

### 3.5 Kubernetes: patrón completo (kubeadm → app)

El laboratorio `01-InstalacionOpenstack/openstack-ansible/kubernetes/` es la **referencia más valiosa**. Flujo reproducido de punta a punta:

```
prepare-images.sh → gen-cloud-init.sh → create-k8s-lab-vms.sh   (host)
                        ↓
bootstrap-cluster.sh (k8-master):
  prereq → runtime(containerd) → packages(kubeadm) → init(Calico)
  → join(workers) → metallb → ingress(nginx) → rook → dashboard
                        ↓
deploy-manifests.sh: ns → secrets → Rook-Ceph → StorageClass
  → PVC → app → MetalLB → Ingress → dashboards
```

**Decisiones técnicas probadas (copiar en el proyecto):**
- **Runtime:** `containerd` con `SystemdCgroup = true` (obligatorio con kubeadm v1.36).
- **CNI:** Calico v3.32.1 (tigera-operator + custom-resources), Pod CIDR `172.16.0.0/16`.
- **LoadBalancer bare-metal:** MetalLB v0.16.1 (IPAddressPool + L2Advertisement).
- **Ingress:** ingress-nginx vía Helm, `controller.service.type=LoadBalancer`.
- **Storage:** Rook v1.20.6 + Ceph v20.2.4 (`CephCluster` 3 MON, 1 MGR, 4 OSD en `vdb`), `CephFilesystem` + StorageClass CephFS.
- **Observabilidad:** Dashboard K8s 7.14.0 (NodePort 32000) + Dashboard Ceph (NodePort 32174).

**Manifests canónicos** (`kubernetes/tmp/`): numerados `01..13` para aplicar en orden.

> **Traducción:** el Worker GPU = un `k8-worker` con `nvidia` runtime; los manifests SaaS reemplazan a WordPress; el Object Storage (Swift/S3) convive con CephFS para PVCs.

### 3.6 Ceph: tres caminos equivalentes

1. **Docker Compose** (`04-LXC-ceph/`): `ceph-admin`+`ceph-mon`+3 OSD, 2 redes (`admin_net`, `data_net`), `setup-cluster.sh` idempotente.
2. **KVM nativo** (`04-LXC-ceph/ceph-kvm/` y `02-cluster-ceph/`): redes separadas por plano, `bootstrap-ceph.sh`, OSDs en `vdb`.
3. **Rook dentro de K8s** (`kubernetes/tmp/03-rook-cluster.yaml`): el recomendado para el proyecto (storage gestionado por Kubernetes).

**Conceptos clave:** planos separados public/`data_net` (clientes) vs cluster/`cluster_net` (replicación OSD); `ceph -s` (HEALTH_OK), `ceph osd tree`, `ceph df`; bootstrap keys + monmap + keyrings.

### 3.7 KVM/libvirt: crear VMs, redes y bridges

**Patrón canónico de creación de VMs** (`02-cluster-ceph/kvm-generic/create-kvm-vm.sh` y `proyecto-manual-infraestructura/`):
```bash
virt-install --name <vm> --memory <MB> --vcpus <n> --cpu host-passthrough \
  --import --disk path=<vm>.qcow2,format=qcow2,bus=virtio \
  --disk path=<vm>-seed.iso,device=cdrom \
  --network network=<red>,model=virtio,mac=52:54:00:... \
  --os-variant ubuntu24.04 --graphics none --noautoconsole
```

**Redes libvirt (XML):** `05-redes-xml-kvm/` + `01-.../openstack-ansible/networks/` + `01-.../openstack-ansible/backups/libvirt-networks/` cubren los tres tipos: NAT (`<forward mode='nat'/>`), aislada (sin `<forward>`) y bridge. `kubernetes/net/k8s-lab-network.xml` muestra DHCP con reservas por MAC (`<host mac=... ip=.../>`).

**Bridges y VLAN** (`03-PRACTICA-KVM/`): guías de `br0`/`bridge01dh`, VLAN trunking, `ip addr show`, NIC bonding.

### 3.8 Ansible: automatización idempotente

`07-documentacion-ansible/ansible/` es código real reutilizable:
```
ansible/
├── inventory/{hosts.yml, group_vars/{all,controller,compute}.yml}
├── playbooks/{site,bridges,controller,computes,verify}.yml
└── roles/{common, linux-bridges, ovs-bridges, nova-compute, neutron-ovs-agent}/
```

**Lección clave — idempotencia:** usar módulos declarativos (`openvswitch_bridge`, `apt`, `lineinfile`) en vez de comandos crudos (`ovs-vsctl add-br`), para que re-ejecutar sea seguro.

### 3.9 Datos y HA (útil para PostgreSQL/Redis del SaaS)

El patrón de `02-cluster-ceph/proyecto-manual-infraestructura/` demuestra HA de datos sobre KVM:
- **MariaDB Galera** (3 nodos) + **MaxScale** (read-write split, puertos 3306/4008) → análogo a PostgreSQL HA (V4 §33-34).
- **Redis** (1+n réplicas) → V4 §35.
- **NGINX L7** (VRRP 112) → patrón de Ingress/balanceo.
- **DNS** jerárquico (raíz → delegación).
- **Healthchecks** (`tools-sh/healthcheck-infra.sh`, `check-logs-all.sh`).

### 3.10 Errores/trampas ya resueltas (para no repetirlos)

1. **`/32` en interfaz de tunnel** cuando hay varias NIC: evita que el kernel elija la ruta equivocada frente a `br-mgmt` (nota en `networks/os-tunnel.xml`).
2. **`SystemdCgroup=true`** en containerd, o kubelet no arranca con kubeadm moderno.
3. **Clonar computes**: borrar `compute_id`/UUID y las instancias libvirt heredadas antes de arrancar `nova-compute`.
4. **OVS vs Linux bridges**: no mezclar; gestionar ambos de forma idempotente con Ansible.
5. **STP `stp='on' delay='0'`** en bridges libvirt para convergencia inmediata.

---

## 4. Checklist de levantamiento

### Etapa 0 — Direccionamiento (papel)
- [ ] Confirmar redes `.env`: MGMT `10.10.0.0/24`, STORAGE `10.10.2.0/24`, TUNNEL `10.10.3.0/24`, EXTERNAL `10.10.4.0/24`.
- [ ] IPs fijas: NODE-01 `10.10.0.11`, NODE-02 `10.10.0.12`, NODE-03 `10.10.0.13`.
- Referencia: `01-InstalacionOpenstack/openstack-ansible/networks/*.xml`.

### Etapa 1 — Hardware, BIOS, red física
- [ ] Virtualización anidada (AMD-V/Intel VT-x).
- [ ] VLANs 10/30/40/50 en switches; bridges con `stp='on' delay='0'`.
- Referencia: `03-PRACTICA-KVM/`, `05-redes-xml-kvm/`.

### Etapa 1.5 — Bootstrap Ansible
- [ ] Usuario admin + clave SSH (patrón `cloud-init/user-data`: sudo NOPASSWD, `disable_root`).
- [ ] Inventario bare-metal (analogía `07-documentacion-ansible/ansible/inventory/hosts.yml`).
- [ ] Playbooks `00_connectivity`/`01_base_os`/`02_network`/`03_hardening`.

### Etapa 2 — OpenStack Kolla-Ansible
- [ ] Kolla-Ansible + `kolla-genpwd`; inventario `multinode` con IPs del `.env`.
- [ ] `kolla-ansible bootstrap-servers → prechecks → deploy`.
- Referencia: `01-.../openstack-ansible/ansible/inventory/multinode` + `hosts-minimal-backup.ini`.

### Etapa 3 / 3.5 — VMs base + configuración
- [ ] Imagen Ubuntu 24.04; cloud-init (`user-data`+`network-config`+`seed.iso`).
- [ ] `virt-install` (patrón `kubernetes/scripts/create-k8s-lab-vms.sh`).
- Referencia: `01-.../openstack-ansible/cloud-init/`, `scripts/gen-user-data.sh`.

### Etapa 4 — Kubernetes
- [ ] `bootstrap-cluster.sh`: prereq → runtime(containerd) → packages → init(Calico) → join → metallb → ingress → rook.
- [ ] `deploy-manifests.sh` para la app.
- Referencia: `01-.../openstack-ansible/kubernetes/scripts/`, `kubernetes/tmp/*.yaml`.

### Etapa 5 — Servicios de plataforma
- [ ] Manifests en orden (patrón `tmp/01..13`): ns → secrets → storage → DB → Redis → cola → API.
- [ ] Object Storage Swift/S3 (análogo a CephFS/Rook).
- Referencia: `02-cluster-ceph/proyecto-manual-infraestructura` (patrón datos HA).

### Etapa 6 — Worker FASHN-VTON (GPU)
- [ ] NVIDIA driver + `nvidia-container-toolkit` en NODE-03; runtime `nvidia` en containerd.
- [ ] tolerations/nodeSelector `gpu=true`; GPU passthrough si se virtualiza (V4 §17).
- Referencia: `kubernetes/puml/02-workers.puml`, `create-k8s-lab-vms.sh`.

### Etapa 7 — Aplicación SaaS
- [ ] Frontend, Backend API, Upload Service, Workers (manifests numerados).
- [ ] Ingress + TLS (patrón `13-wordpress-ingress.yaml`, sustituir cert autofirmado por real).

### Etapa 8 — Seguridad, observabilidad, recuperación
- [ ] Prometheus/Grafana + dashboards (`kubernetes/tmp/10,11`).
- [ ] Healthchecks (`02-cluster-ceph/.../tools-sh/healthcheck-infra.sh`).
- [ ] Backups PostgreSQL + Object Storage + etcd (`configuraciones-backups.sh`).

### Etapa 9 — Capacidad comercial
- [ ] Benchmark GPU (V4 §79); rate limiting; prioridades de cola; medición de consumo.

### Comandos rápidos de verificación

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


---

## 5. Índice de recursos

> Los `.md` originales ya no están en estas carpetas (fueron a `trash/`); aquí se indexa el **contenido ejecutable** que sí se conserva.

### OpenStack (Kolla-Ansible + manual) — `01-InstalacionOpenstack/`
| Recurso | Ruta |
|---|---|
| Inventario Kolla (`multinode`) | `openstack-ansible/ansible/inventory/multinode` |
| Inventario mínimo backup | `openstack-ansible/ansible/inventory/hosts-minimal-backup.ini` |
| Redes XML (mgmt/tunnel/external) | `openstack-ansible/networks/*.xml` |
| cloud-init por nodo | `openstack-ansible/cloud-init/{os-controller,os-compute01,os-compute02,os-storage01,os-network}/` |
| Generador de user-data | `openstack-ansible/scripts/gen-user-data.sh` |
| Backup redes libvirt (18 XML) | `openstack-ansible/backups/libvirt-networks/20260809-131924/` |
| Backup definiciones VM | `openstack-ansible/backups/libvirt-vms/20260809-132013/` |
| Scripts OpenStack | `expo.sh`, `fix-openstack-bugs.sh` |
| PlantUML redes/OSA | `puml/`, `pumla-actual/`, `*.puml` (raíz) |
| XML red lab Ansible | `guia_ansible_v1.0/ansible-lab-net.xml` |

### Kubernetes (kubeadm + Rook-Ceph) — `01-.../openstack-ansible/kubernetes/`
| Recurso | Ruta |
|---|---|
| Scripts de despliegue | `scripts/{prepare-images,gen-cloud-init,create-k8s-lab-vms,bootstrap-cluster,deploy-manifests,deploy-all}.sh` |
| Manifests numerados 01–13 | `tmp/*.yaml` |
| Manifests de respaldo | `deployment-set/tmp/`, `backups/septiembre1/manifests/` |
| Red libvirt `k8s-lab` | `net/k8s-lab-network.xml` |
| cloud-init plantilla | `cloud-init/user-data.tmpl` |
| Diagramas PlantUML | `puml/{01-red-y-bridges,02-workers,03-pods-y-conexion,04-infraestructura-sistema,05-arquitectura-servicios-pods}.puml` |
| Respaldos completos | `backups-files/k8s-manifests/*.yaml`, `backups-files/libvirt/*.xml` |

### Infra HA/KVM — `02-cluster-ceph/`
| Recurso | Ruta |
|---|---|
| Scripts de configuración | `proyecto-manual-infraestructura/configuraciones-*.sh`, `scripts.sh` |
| Utilidades KVM genéricas | `kvm-generic/{create-kvm-vm,create-kvm-vms,delete-kvm-vm,create-libvirt-network,first-boot-example,vm-common}.sh` |
| Healthchecks | `proyecto-manual-infraestructura/tools-sh/{healthcheck-infra,check-logs-all}.sh` |
| Fases 01–99 | `proyecto-infra/{01-bases,02-redes,03-dns-coredns,04-balanceadores-nginx,05-backends-django,06-datos,99-validacion}/` |
| PlantUML topología/DNS | `proyecto-manual-infraestructura/doc/puml/*.puml`, `diagrama-topologia-redes.puml` |
| Ejemplo Django | `proyecto-manual-infraestructura/django/` |

### KVM práctica — `03-PRACTICA-KVM/`
| Recurso | Ruta |
|---|---|
| Crear VMs | `crear_vms.sh`, `crear_vms_qemu.sh` |
| Ciclo de vida bridge01 | `start_vm1_bridge01.sh`, `start_vm2_bridge01.sh`, `stop_vms_bridge01.sh`, `verificar_bridge01.sh`, `verificar_sistema.sh` |
| Info NIC / diagrama | `info_nic.sh`, `generar_diagrama.sh`, `relaciones.puml` |

### Ceph (Docker + KVM) — `04-LXC-ceph/`
| Recurso | Ruta |
|---|---|
| Docker Compose | `docker-compose.yml` |
| Init scripts Docker | `scripts/{init-admin,init-mon,init-osd,setup-cluster}.sh` |
| Ceph sobre KVM | `ceph-kvm/{up,reset,start,stop,status,destroy}.sh`, `ceph-kvm/scripts/{00-check-prereqs,10-create-networks,20-create-vms,30-bootstrap-ceph,common}.sh` |
| Config cluster | `ceph-kvm/config/cluster.env` |

### Redes XML mínimas — `05-redes-xml-kvm/`
| Recurso | Ruta |
|---|---|
| Redes OpenStack | `openstack-admin.xml`, `openstack-public.xml`, `openstack-provider.xml` |

### Fundamentos (texto) — `06-guias123/`
| Recurso | Ruta |
|---|---|
| Bridge Linux | `icc115-bridge-linux.txt` |
| LXC | `icc115-guia-lxc.txt` |
| KVM básico | `icc115-kvm-guia-basica.txt` |

### Ansible — `07-documentacion-ansible/`
| Recurso | Ruta |
|---|---|
| Inventario + group_vars | `ansible/inventory/{hosts.yml, group_vars/{all,controller,compute}.yml}` |
| Playbooks | `ansible/playbooks/{site,bridges,controller,computes,verify}.yml` |
| Roles | `ansible/roles/{linux-bridges,ovs-bridges,nova-compute,neutron-ovs-agent}/` |
| Config | `ansible/ansible.cfg` |

---

## 6. Carpeta `trash/`

Contiene **todos los `.md` originales** copiados de los proyectos fuente, movidos fuera del flujo principal pero conservando su ruta relativa para poder localizarlos:

```
trash/
├── 00-INDICE-GENERAL.md
├── 01-InstalacionOpenstack/...            (guías 01-10, kubernetes/doc/*, READMEs…)
├── 02-cluster-ceph/...
├── 03-PRACTICA-KVM/...
├── 04-LXC-ceph/...
├── 06-guias123/GUIAS_CONSOLIDADAS.md
├── 07-documentacion-ansible/01..09-*.md
└── 09-consolidado/{00-MAPA,01-CHECKLIST}.md   (síntesis previa, absorbida en este README)
```

Consulta `trash/` sólo si necesitas el **texto largo original** de una guía concreta; el conocimiento ya está destilado en este `README.md` (§3 y §4).

---

## 7. Seguridad

- `trash/` y `01-InstalacionOpenstack/openstack-ansible/backups-files/` contienen **credenciales de laboratorio** (`k8-master-admin.conf`, `*.keyring.txt`, `secrets.yaml`, `.env`): son **de prueba local, no reutilizar en producción**.
- Las claves privadas SSH (`id_rsa`, `id_ed25519`) fueron **excluidas** del copiado.
- Los binarios pesados (ISO, `.qcow2`, `.img`, PDF, DOCX, imágenes, `plantuml.jar`) también fueron **excluidos**.

---

## 8. Regenerar la base

```bash
# Re-ejecutable: regenera los activos desde los proyectos origen (sin .md).
bash documentacion/_copiar-conocimientos.sh
```

---

## 9. Verificación de factibilidad

El documento [`VERIFICACION-PLAN-Y-FACTIBILIDAD.md`](VERIFICACION-PLAN-Y-FACTIBILIDAD.md) une la arquitectura V4 con esta base de conocimiento. Resumen:

- **Factibilidad:** ✅ las etapas de infraestructura (0–5, 8) están respaldadas por evidencia directa de los laboratorios; las de producto (6, 7, 9) dependen de trabajo nuevo de aplicación/benchmark, no de infraestructura.
- **Orden:** ✅ coherente (hardware → Ansible → Kolla → VMs → K8s → servicios → app).
- **8 hallazgos menores** (no bloqueantes): RabbitMQ de app ≠ RabbitMQ de Kolla, cierre de la Etapa 2, `pull` opcional, Object Storage (Swift vs MinIO), versión OpenStack, Metrics Server vs Prometheus, DNS/NTP del gateway, `monitoring-01` (VM vs K8s).
- **Pieza de mayor riesgo:** GPU passthrough **a través de Nova/Kolla** (los labs lo demostraron a nivel libvirt, no Nova).

Consulta los detalles y las correcciones recomendadas en [`VERIFICACION-PLAN-Y-FACTIBILIDAD.md`](VERIFICACION-PLAN-Y-FACTIBILIDAD.md).


