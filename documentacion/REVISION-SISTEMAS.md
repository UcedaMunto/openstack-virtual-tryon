# 🔎 Revisión de Sistemas — Factibilidad Real del Plan

> Inspección del equipo/red donde se ejecutaría el plan (V4: OpenStack Kolla-Ansible + Kubernetes + FASHN-VTON).
> **Fecha:** 2026-09-24 · **Host inspeccionado:** `anfitrion`

> ✅ **ACTUALIZACIÓN (misma fecha):** tras conectar por SSH a los equipos de la red, se confirmó que **sí hay 3 nodos y GPU NVIDIA**. Ver [`INVENTARIO-EQUIPOS.md`](INVENTARIO-EQUIPOS.md). Esta revisión inicial quedó superada; las tablas de abajo están corregidas.

---

## 1. Resumen ejecutivo

| Requisito del plan (V4) | Estado real | Veredicto |
|---|---|---|
| 3 servidores físicos (NODE-01/02/03) | ✅ `anfitrion` + `server` + `asus-tuf` (ver inventario) | ✅ **Disponible** |
| GPU dedicada NVIDIA (NODE-03, FASHN-VTON/CUDA) | ✅ **RTX 3060 12 GB** en `server` (CUDA 13.2) + GTX 1650 4 GB en `asus-tuf` | ✅ **Disponible** |
| Virtualización KVM + IOMMU | ✅ AMD-V + KVM + IOMMU activos | ✅ Disponible |
| RAM para OpenStack+K8s | 30 GB (≈17 GB libres) | ⚠️ Justo para lab anidado |
| Disco | NVMe 931 GB, **191 GB libres (78 % usado)** | ⚠️ Justo |
| Red segmentada (VLAN mgmt/storage/tunnel/external) | 1 NIC, 1 subred `192.168.0.0/24` | ⚠️ Solo software (bridges) |
| Herramientas (kubeadm/helm/kolla-ansible/openstack) | **Faltan** (sí hay k3s, Docker, virsh, ansible) | ⚠️ Instalar |

**Conclusión (corregida):** el plan **es factible sobre hardware real**: hay 3 equipos Ubuntu 24.04 LTS y una **GPU NVIDIA RTX 3060 de 12 GB** para la IA. El único punto débil es `asus-tuf` (NODE-02): 15 GB de RAM y conexión por Wi-Fi.

---

## 2. Inventario del sistema

### Sistema operativo
- **Host:** `anfitrion` · **SO:** Ubuntu 24.04.4 LTS (Noble Numbat) · **Kernel:** 7.0.0-31-generic · x86_64

### CPU
- AMD Ryzen 5 PRO 5650U (Cezanne) · 6 núcleos / 12 hilos · AMD-V (SVM) · NUMA 1 socket

### Memoria
- 30 GiB total · 12 GiB usados · **≈17 GiB disponibles** · Swap 8 GiB

### Almacenamiento
- 1× NVMe **931 GB** (LVM `/` en 913 GB) · 676 GB usados · **191 GB libres (78 % usado)**

### GPU
- **AMD Radeon Vega (integrada, Cezanne)** — módulo `amdgpu` cargado.
- **No hay GPU NVIDIA** (`nvidia-smi` ausente, sin módulos `nvidia`).
- ⚠️ FASHN-VTON 1.5 (PyTorch/CUDA) **no corre** en iGPU AMD.

### Virtualización
- `/dev/kvm` presente · AMD-V activo (12/12 hilos con `svm`) · **IOMMU** presente (Renoir/Cezanne IOMMU).
- `libvirtd` **inactivo**, pero existen **VMs de labs previos apagadas**: `controller`, `compute..compute4`, `k8-master`, `k8-worker1..4`, `os-controller`, `os-compute01/02`, `swift1..3`.

### Red
- NIC activa: `enp2s0f0` · **IP 192.168.0.10/24** · GW `192.168.0.1` · DNS `192.168.0.1` + `8.8.8.8`.
- Otras interfaces: `wlp3s0` (Wi-Fi, DOWN), `docker0`, `flannel.1`, `cni0` (10.42.0.0/24).
- Equipos (por cable): `anfitrion` 192.168.0.10 · `server` 192.168.0.100 · `asus-tuf` 192.168.0.126 (gateway `192.168.0.1`).

### Servicios ya en ejecución
- **k3s** (clúster Kubernetes activo, CNI flannel, `metrics-server`) — API en puerto `6444`.
- **Docker** 29.1.3 · **containerd** 2.2.1.
- **PostgreSQL** escuchando en `5432`.
- **Ollama** (inferencia LLM local) en `11434`.

### Herramientas instaladas vs faltantes
| Presente | Versión | Faltante |
|---|---|---|
| kubectl | 1.36.3 | ❌ kubeadm |
| k3s / minikube / lxc | — | ❌ helm |
| Docker / Compose | 29.1.3 / 2.40.3 | ❌ kolla-ansible |
| containerd / runc | 2.2.1 / 1.3.4 | ❌ openstack CLI |
| virsh / virt-install / QEMU | 10.0.0 / 4.1.0 / 8.2.2 | ❌ terraform |
| ansible | core 2.16.3 | ❌ argocd |

---

## 3. Análisis de factibilidad por bloque

| Bloque del plan | ¿Factible aquí? | Detalle |
|---|---|---|
| **OpenStack Kolla-Ansible** (Etapa 2) | ✅ Simulable (anidado) | KVM+IOMMU disponibles; las VMs `os-controller/os-compute*/os-storage*` ya existen apagadas. Falta instalar `kolla-ansible` + `docker` (ya está). |
| **Kubernetes** (Etapa 4) | ✅ Disponible | Ya hay un **k3s activo**; kubeadm/helm faltan si se exige el stack exacto del lab. |
| **Red segmentada** (Etapa 1) | ⚠️ Solo software | 1 NIC física; las VLANs serían bridges libvirt (patrón `networks/*.xml`), no hardware. |
| **GPU / FASHN-VTON** (Etapas 6-7, 9) | ✅ Factible | **RTX 3060 12 GB** en `server` (driver 595.84, CUDA 13.2). Ver inventario. |
| **3 nodos físicos** | ✅ Disponible | `anfitrion` + `server` + `asus-tuf` (3 equipos Ubuntu 24.04). |
| **Almacenamiento/Ceph** | ⚠️ Justo | `anfitrion` 191 GB libres · `server` 600 GB LVM · `asus-tuf` 237 GB. |

---

## 4. Recomendaciones

1. **Para IA:** usar la **RTX 3060 (12 GB)** de `server` (NODE-03); ya tiene driver NVIDIA 595.84 + CUDA 13.2 listos. La GTX 1650 (4 GB) de `asus-tuf` queda como GPU secundaria (insuficiente para FASHN-VTON).
2. **Para los 3 nodos:** ✅ ya disponibles (`anfitrion`=NODE-01 control, `asus-tuf`=NODE-02 compute/storage, `server`=NODE-03 GPU). Atención a `asus-tuf` (15 GB RAM, Wi-Fi).
3. **Software:** instalar `kubeadm`, `helm`, `kolla-ansible` y `python-openstackclient` si se quiere reproducir el flujo exacto del lab; o **reutilizar el k3s ya activo** para la parte Kubernetes.
4. **Decidir convivencia:** el host ya corre k3s + Ollama + PostgreSQL; el plan debe aclarar si se **reutilizan** o se **aíslan** esos servicios (evitar colisión de puertos 5432/6444).
5. **Disco:** liberar espacio (78 % usado) antes de descargar imágenes de OpenStack + K8s + pesos del modelo.
