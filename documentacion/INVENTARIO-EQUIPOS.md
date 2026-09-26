# 🖥️ Inventario de Equipos (red real — 3 nodos)

> Relevamiento real de los 3 equipos de la red `192.168.0.0/24`, con **acceso SSH por llave ya configurado** desde `anfitrion`.
> **Fecha:** 2026-09-24

---

## Resumen y mapeo al plan (V4)

| Rol V4 | Equipo | IP (verificada) | SO | CPU | RAM | GPU | Disco |
|---|---|---|---|---|---|---|---|
| **NODE-01** (control + network + compute CPU) | `anfitrion` (Lenovo) | 192.168.0.10 (cable) | Ubuntu 24.04.4 | AMD Ryzen 5 PRO 5650U · 6C/12T · AMD-V | 30 GB | iGPU Radeon Vega | NVMe 931 GB |
| **NODE-03** (compute GPU / IA) | `server` | 192.168.0.100 (cable) | Ubuntu 24.04.4 | Intel Core i5-10400 · 6C/12T · VT-x | 31 GB | **NVIDIA RTX 3060 · 12 GB VRAM** · CUDA 13.2 | NVMe 931 GB (600 GB LVM) |
| **NODE-02** (compute CPU + storage) | `asus-tuf` (portátil) | 192.168.0.126 (cable) | Ubuntu 24.04.5 | AMD Ryzen 5 3550H · 4C/8T · AMD-V | 15 GB | NVIDIA GTX 1650 Mobile 4 GB + iGPU Vega | NVMe 238 GB |

> **Nota IPs (por cable):** `anfitrion=192.168.0.10` · `server=192.168.0.100` · `asus-tuf=192.168.0.126`. Son **dinámicas (DHCP)**; para el despliegue conviene fijar **IPs estáticas o reservas DHCP**. `asus-tuf` además conserva el Wi-Fi activo (`wlp4s0` 192.168.0.20), que debería desactivarse para evitar rutas duales.

---

## Detalle por equipo

### `anfitrion` (NODE-01 · control · máquina principal)
- **SO:** Ubuntu 24.04.4 LTS · kernel 7.0.0-31-generic
- **CPU:** AMD Ryzen 5 PRO 5650U · 6 núcleos / 12 hilos · AMD-V (SVM)
- **RAM:** 30 GB (≈17 GB libres) · Swap 8 GB
- **Disco:** NVMe 931 GB (LVM `/` 913 GB, 78 % usado)
- **GPU:** iGPU AMD Radeon Vega (Cezanne) — sin NVIDIA
- **Red:** `enp2s0f0` 192.168.0.10 (cable) · `wlp3s0` Wi-Fi
- **Servicios ya activos:** **k3s server** (control-plane del clúster), Docker 29.1.3, containerd 2.2.1, PostgreSQL (5432), Ollama (11434)
- **Virtualización:** KVM + IOMMU OK (labs previos corrieron aquí)

### `server` (NODE-03 · GPU / cálculos · conectado por cable)
- **SO:** Ubuntu 24.04.4 LTS · kernel 6.8.0-139-generic
- **CPU:** Intel Core i5-10400 · 6 núcleos / 12 hilos · VT-x
- **RAM:** 31 GB (≈29 GB libres)
- **Disco:** NVMe 931 GB (LVM `/` 600 GB)
- **GPU:** **NVIDIA GeForce RTX 3060 · 12 GB VRAM** · driver 595.84 · **CUDA 13.2**
  - `nvidia-smi` operativo; GPU en P8, 45 °C, 126 MiB usados (solo Xorg/gnome-shell)
- **Red:** `eno1` 192.168.0.100 (cable, estable)

### `asus-tuf` (NODE-02 · compute + storage · por cable)
- **SO:** Ubuntu 24.04.5 LTS · kernel 6.8.0-142-generic
- **CPU:** AMD Ryzen 5 3550H · 4 núcleos / 8 hilos · AMD-V
- **RAM:** 15 GB (≈12 GB libres)
- **Disco:** NVMe 238 GB (`/` 237 GB)
- **GPU:** **NVIDIA GTX 1650 Mobile 4 GB** + iGPU AMD Radeon Vega — sin driver NVIDIA cargado aún
- **Red:** `enp2s0` 192.168.0.126 (cable) · `wlp4s0` 192.168.0.20 (Wi-Fi, aún activa — desactivar)

---

## Estado de conectividad SSH

| Origen → Destino | IP | Resultado |
|---|---|---|
| `anfitrion` → `server` | 192.168.0.100 | ✅ llave `id_ed25519.pub` copiada · acceso sin contraseña OK |
| `anfitrion` → `asus-tuf` | 192.168.0.126 | ✅ llave copiada · acceso sin contraseña OK |

- Comando usado: `sshpass -p '…' ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no …` (evita el fallo "Too many authentication failures" por las múltiples llaves de `~/.ssh`).
- Los 3 equipos están **por cable**: `anfitrion` .10 · `server` .100 · `asus-tuf` .126.

---

## Clúster k3s preexistente (hallazgo)

Los 3 equipos **ya forman un clúster Kubernetes k3s** (CNI flannel, Pod CIDR `10.42.0.0/16`):

| Equipo | Rol k3s | Estado |
|---|---|---|
| `anfitrion` | `k3s server` (control-plane) | ✅ active |
| `asus-tuf` | `k3s agent` (worker) | ✅ active |
| `server` | `k3s agent` (worker) | ✅ active |

**Implicación para el plan (V4):** la capa Kubernetes ya está montada (k3s, no kubeadm). Decidir si se **reutiliza k3s** (más simple, ya operativo) o se **reemplaza por kubeadm+Calico+MetalLB+Rook** como describe el laboratorio de referencia (`openstack-ansible/kubernetes/`).

---

## Veredicto de factibilidad (actualizado)

| Requisito V4 | Antes (revisión inicial) | **Ahora (verificado)** |
|---|---|---|
| 3 nodos físicos | 🔴 solo 1 | ✅ **3 equipos disponibles** |
| GPU NVIDIA para IA | 🔴 no | ✅ **RTX 3060 12 GB (server)** + GTX 1650 4 GB (asus-tuf) |
| Virtualización KVM/IOMMU | ✅ | ✅ en los 3 (AMD-V/VT-x) |
| RAM | ⚠️ | ✅ 30 + 31 + 15 = 76 GB totales |
| SO homogéneo | ✅ | ✅ Ubuntu 24.04 LTS en los 3 |

**El plan es factible sobre hardware real.** Riesgo principal: `asus-tuf` (NODE-02) es el más limitado (15 GB RAM), y la GTX 1650 de 4 GB no alcanza para FASHN-VTON (el modelo se correrá en la **RTX 3060 de `server`**).
