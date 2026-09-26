# Documentación Unificada: Bridge y VLAN en KVM
# Arquitectura Completa con VMM e Hipervisor

**Fecha:** 2026-03-17
**Sistema:** Ubuntu 24.04 con KVM/libvirt
**Hardware:** AMD ThinkPad L15 Gen 2a
**Estado:** ✅ Completado

---

## Índice

1. [Arquitectura Completa del Sistema](#1-arquitectura-completa-del-sistema)
2. [Capas de Virtualización](#2-capas-de-virtualización)
3. [Diagrama de Red Detallado](#3-diagrama-de-red-detallado)
4. [Flujo de Datos](#4-flujo-de-datos)
5. [Guía de Implementación](#5-guía-de-implementación)
6. [Comandos de Gestión](#6-comandos-de-gestión)
7. [Troubleshooting](#7-troubleshooting)
8. [Referencias](#8-referencias)

---

## 1. Arquitectura Completa del Sistema

### 1.1 Stack Completo de Virtualización

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│                        CAPA 5: APLICACIONES VM                          │
│                                                                         │
│  ┌────────────────────────┐  ┌────────────────────────┐               │
│  │        VM1             │  │        VM2             │               │
│  │   Ubuntu/Alpine        │  │   Ubuntu/Alpine        │               │
│  │   Aplicaciones         │  │   Aplicaciones         │               │
│  │   Servicios de red     │  │   Servicios de red     │               │
│  └────────────────────────┘  └────────────────────────┘               │
│              ▲                          ▲                               │
└──────────────┼──────────────────────────┼───────────────────────────────┘
               │                          │
┌──────────────┼──────────────────────────┼───────────────────────────────┐
│              │                          │                               │
│          CAPA 4: SISTEMA OPERATIVO GUEST (VM OS)                        │
│                                                                         │
│  ┌────────────────────────┐  ┌────────────────────────┐               │
│  │   VM1 Linux Kernel     │  │   VM2 Linux Kernel     │               │
│  │   - Drivers virtio     │  │   - Drivers virtio     │               │
│  │   - Network stack      │  │   - Network stack      │               │
│  │   - eth0 (virtual NIC) │  │   - eth0 (virtual NIC) │               │
│  │   IP: 192.168.100.10   │  │   IP: 192.168.100.20   │               │
│  └────────────────────────┘  └────────────────────────┘               │
│              ▲                          ▲                               │
└──────────────┼──────────────────────────┼───────────────────────────────┘
               │ (virtio)                 │ (virtio)
┌──────────────┼──────────────────────────┼───────────────────────────────┐
│              │                          │                               │
│         CAPA 3: VMM - VIRTUAL MACHINE MANAGER (QEMU/libvirt)            │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    libvirt Daemon                                │  │
│  │  - Gestión de VMs (virsh, virt-manager)                         │  │
│  │  - Definiciones XML de VMs                                      │  │
│  │  - Redes virtuales                                              │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│              ▲                          ▲                               │
│              │                          │                               │
│  ┌───────────┴──────────┐  ┌───────────┴──────────┐                   │
│  │  QEMU Process VM1    │  │  QEMU Process VM2    │                   │
│  │  PID: 347385         │  │  PID: 350092         │                   │
│  │  - Emulación CPU     │  │  - Emulación CPU     │                   │
│  │  - Emulación RAM     │  │  - Emulación RAM     │                   │
│  │  - Emulación Disco   │  │  - Emulación Disco   │                   │
│  │  - Emulación NIC     │  │  - Emulación NIC     │                   │
│  │  - Backend TAP: tap0 │  │  - Backend TAP: tap1 │                   │
│  └──────────────────────┘  └──────────────────────┘                   │
│              ▲                          ▲                               │
└──────────────┼──────────────────────────┼───────────────────────────────┘
               │ (ioctl)                  │ (ioctl)
┌──────────────┼──────────────────────────┼───────────────────────────────┐
│              │                          │                               │
│              CAPA 2: HIPERVISOR (KVM)                                   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │           Kernel Linux (6.17.0-14-generic)                       │  │
│  │                                                                  │  │
│  │  ┌────────────────────────────────────────────────────────────┐ │  │
│  │  │  KVM Kernel Modules                                        │ │  │
│  │  │  ├─ kvm.ko          (Core KVM)                             │ │  │
│  │  │  └─ kvm_amd.ko      (AMD-specific virtualization)          │ │  │
│  │  │                                                            │ │  │
│  │  │  Funciones:                                                │ │  │
│  │  │  - Virtualización asistida por hardware (AMD-V/SVM)        │ │  │
│  │  │  - Gestión de vCPUs                                        │ │  │
│  │  │  - Memory mapping (EPT/NPT)                                │ │  │
│  │  │  - Dispositivo /dev/kvm                                    │ │  │
│  │  └────────────────────────────────────────────────────────────┘ │  │
│  │                                                                  │  │
│  │  ┌────────────────────────────────────────────────────────────┐ │  │
│  │  │  Network Stack del Host                                    │ │  │
│  │  │  ├─ Bridge subsystem                                       │ │  │
│  │  │  ├─ TAP/TUN driver                                         │ │  │
│  │  │  └─ Ethernet driver (enp2s0f0)                             │ │  │
│  │  └────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│              ▲                          ▲                               │
└──────────────┼──────────────────────────┼───────────────────────────────┘
               │                          │
┌──────────────┼──────────────────────────┼───────────────────────────────┐
│              │                          │                               │
│              CAPA 1: HARDWARE FÍSICO                                    │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  CPU: AMD Ryzen (con AMD-V/SVM habilitado)                       │  │
│  │  - Extensiones de virtualización                                 │  │
│  │  - Soporte para nested page tables (NPT)                         │  │
│  │  - Soporte para Extended Page Tables                             │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  RAM: Memoria Física                                             │  │
│  │  - Host memory                                                   │  │
│  │  - VM1 memory (2 GB)                                             │  │
│  │  - VM2 memory (2 GB)                                             │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  NIC: enp2s0f0 - Ethernet Controller                             │  │
│  │  MAC: 88:a4:c2:xx:xx:xx                                          │  │
│  │  IP: 192.168.0.195/24 (Red LAN física)                           │  │
│  │  Conexión: Router → Internet                                     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Almacenamiento                                                  │  │
│  │  - Disco del host                                                │  │
│  │  - vm1-practica.qcow2 (20 GB - sparse)                           │  │
│  │  - vm2-practica.qcow2 (20 GB - sparse)                           │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Capas de Virtualización

### 2.1 Capa 1: Hardware Físico

**Componentes:**
- **CPU con AMD-V/SVM**: Extensiones de virtualización por hardware
- **RAM**: Memoria física compartida entre host y guests
- **NIC física (enp2s0f0)**: Controlador Ethernet para conectividad
- **Almacenamiento**: Discos físicos que alojan imágenes QCOW2

**Características:**
- Virtualización asistida por hardware (AMD-V en este caso)
- Memory mapping avanzado (Nested Page Tables)
- I/O virtualización

---

### 2.2 Capa 2: Hipervisor (KVM)

**Tipo:** Hipervisor tipo 1 integrado al kernel

**Módulos KVM:**
```
kvm.ko         → Core del hipervisor
kvm_amd.ko     → Específico para AMD (o kvm_intel.ko para Intel)
```

**Funciones principales:**
1. **Virtualización de CPU**
   - Ejecución de instrucciones privilegiadas
   - Context switching entre host y guests
   - Manejo de interrupciones virtuales

2. **Virtualización de Memoria**
   - Extended/Nested Page Tables (EPT/NPT)
   - Memory ballooning
   - Transparent Huge Pages

3. **Interfaz /dev/kvm**
   - Device file para comunicación con userspace
   - ioctl() para control de VMs
   - Usado por QEMU para crear VMs

**Verificación:**
```bash
lsmod | grep kvm          # Ver módulos cargados
ls -l /dev/kvm            # Verificar dispositivo
kvm-ok                    # Verificar soporte
```

---

### 2.3 Capa 3: VMM - Virtual Machine Manager

#### A. QEMU (Quick Emulator)

**Procesos en ejecución:**
```
PID 347385: /usr/bin/qemu-system-x86_64 (VM1)
PID 350092: /usr/bin/qemu-system-x86_64 (VM2)
```

**Funciones de QEMU:**
1. **Emulación de dispositivos virtuales**
   - CPU virtual (virtio)
   - Disco virtual (formato qcow2)
   - NIC virtual (virtio-net)
   - Consola VNC

2. **Backend de red**
   - Conexión a interfaz TAP (tap0, tap1)
   - Modelo de NIC: virtio (alto rendimiento)

3. **Gestión de memoria**
   - Asignación de RAM a la VM
   - Memory mapping con KVM

#### B. libvirt

**Daemon:** libvirtd / virtqemud

**Funciones:**
1. **API unificada**
   - Gestión de VMs (crear, iniciar, detener)
   - Gestión de redes virtuales
   - Gestión de almacenamiento

2. **Herramientas:**
   - `virsh`: CLI para gestión
   - `virt-manager`: GUI completa
   - `virt-install`: Creación de VMs

3. **Definiciones XML**
   - Configuración de VMs
   - Configuración de redes
   - Almacenamiento pools

**Comandos útiles:**
```bash
sudo systemctl status libvirtd    # Estado del daemon
sudo virsh list --all              # Listar VMs
sudo virsh net-list --all          # Listar redes
```

---

### 2.4 Capa 4: Sistema Operativo Guest

**Componentes dentro de cada VM:**

1. **Kernel Linux del Guest**
   - Drivers paravirtualizados (virtio)
   - Network stack completo
   - Scheduler, memory management

2. **Drivers virtio**
   - virtio-net: NIC virtual de alto rendimiento
   - virtio-blk: Disco virtual optimizado
   - virtio-balloon: Gestión dinámica de memoria

3. **Interfaz de red (eth0)**
   - Configurada con IP estática o DHCP
   - Conectada al backend virtio-net de QEMU

---

### 2.5 Capa 5: Aplicaciones

**Servicios que pueden ejecutarse en las VMs:**
- Servidores web (Apache, Nginx)
- Bases de datos (MySQL, PostgreSQL)
- Servicios de red (DNS, DHCP, SSH)
- Aplicaciones personalizadas

---

## 3. Diagrama de Red Detallado

### 3.1 Topología de Red con VMM y Puentes

```
                            INTERNET
                               │
                               │ WAN
                               │
                        ┌──────┴──────┐
                        │   Router    │
                        │ Gateway     │
                        │192.168.0.1  │
                        └──────┬──────┘
                               │
                               │ LAN: 192.168.0.0/24
                               │
┌──────────────────────────────┼──────────────────────────────────────────┐
│                              │          HOST FÍSICO                     │
│                              │      Ubuntu 24.04 LTS                    │
│                              │                                          │
│  ┌───────────────────────────┴──────────────────────────────┐          │
│  │            Kernel Linux + KVM                            │          │
│  │                                                          │          │
│  │  ┌────────────────────────────────────────────────────┐ │          │
│  │  │  KVM Modules (kvm.ko + kvm_amd.ko)                 │ │          │
│  │  │  /dev/kvm (Character Device)                       │ │          │
│  │  └────────────────────────────────────────────────────┘ │          │
│  │                                                          │          │
│  │  ┌────────────────────────────────────────────────────┐ │          │
│  │  │  Network Stack                                     │ │          │
│  │  │  ┌──────────────────────────────────────────────┐ │ │          │
│  │  │  │    Bridge: br0 (192.168.100.1/24)            │ │ │          │
│  │  │  │    - Layer 2 switching                       │ │ │          │
│  │  │  │    - MAC address learning                    │ │ │          │
│  │  │  │    - STP (Spanning Tree Protocol)            │ │ │          │
│  │  │  │                                              │ │ │          │
│  │  │  │    Puertos/Ports:                            │ │ │          │
│  │  │  │    ├─ tap0  (VM1 backend)                    │ │ │          │
│  │  │  │    └─ tap1  (VM2 backend)                    │ │ │          │
│  │  │  └──────────┬───────────────┬───────────────────┘ │ │          │
│  │  │             │               │                     │ │          │
│  │  │        ┌────┴────┐     ┌────┴────┐               │ │          │
│  │  │        │  tap0   │     │  tap1   │               │ │          │
│  │  │        │ (TAP/   │     │ (TAP/   │               │ │          │
│  │  │        │ TUN     │     │ TUN     │               │ │          │
│  │  │        │ Driver) │     │ Driver) │               │ │          │
│  │  │        └────┬────┘     └────┬────┘               │ │          │
│  │  └─────────────┼───────────────┼────────────────────┘ │          │
│  └────────────────┼───────────────┼──────────────────────┘          │
│                   │               │                                  │
│  ┌────────────────┼───────────────┼──────────────────────┐          │
│  │                │               │                      │          │
│  │  libvirt / QEMU Layer                                 │          │
│  │                                                       │          │
│  │  ┌─────────────┴──────────┐  ┌──────────┴──────────┐ │          │
│  │  │  QEMU Process VM1      │  │  QEMU Process VM2   │ │          │
│  │  │  PID: 347385           │  │  PID: 350092        │ │          │
│  │  │                        │  │                     │ │          │
│  │  │  Dispositivos Emulados:│  │  Dispositivos Emul: │ │          │
│  │  │  ├─ vCPU (2 cores)     │  │  ├─ vCPU (2 cores)  │ │          │
│  │  │  ├─ RAM (2 GB)         │  │  ├─ RAM (2 GB)      │ │          │
│  │  │  ├─ Disk (qcow2, 20GB) │  │  ├─ Disk (qcow2)    │ │          │
│  │  │  ├─ VNC (port 5901)    │  │  ├─ VNC (port 5902) │ │          │
│  │  │  └─ virtio-net         │  │  └─ virtio-net      │ │          │
│  │  │     ↓ netdev=tap0      │  │     ↓ netdev=tap1   │ │          │
│  │  └────────────┬───────────┘  └──────────┬──────────┘ │          │
│  └───────────────┼──────────────────────────┼────────────┘          │
│                  │                          │                        │
└──────────────────┼──────────────────────────┼────────────────────────┘
                   │ virtio                   │ virtio
                   │ (paravirtualización)     │
┌──────────────────┼───────────────┐ ┌────────┼───────────────────────┐
│                  ▼               │ │        ▼                       │
│  ┌────────────────────────────┐  │ │  ┌──────────────────────────┐ │
│  │   VM1 - Guest OS           │  │ │  │   VM2 - Guest OS         │ │
│  │   Alpine/Ubuntu Linux      │  │ │  │   Alpine/Ubuntu Linux    │ │
│  │                            │  │ │  │                          │ │
│  │   ┌──────────────────────┐ │  │ │  │  ┌──────────────────────┐│ │
│  │   │  Network Interface   │ │  │ │  │  │  Network Interface   ││ │
│  │   │  eth0                │ │  │ │  │  │  eth0                ││ │
│  │   │  Driver: virtio_net  │ │  │ │  │  │  Driver: virtio_net  ││ │
│  │   │                      │ │  │ │  │  │                      ││ │
│  │   │  IP: 192.168.100.10  │ │  │ │  │  │  IP: 192.168.100.20  ││ │
│  │   │  MAC: 52:54:00:...:56│ │  │ │  │  │  MAC: 52:54:00:...:57││ │
│  │   └──────────────────────┘ │  │ │  │  └──────────────────────┘│ │
│  │                            │  │ │  │                          │ │
│  │   Servicios:               │  │ │  │  Servicios:              │ │
│  │   - SSH                    │  │ │  │  - SSH                   │ │
│  │   - Aplicaciones           │  │ │  │  - Aplicaciones          │ │
│  │                            │  │ │  │                          │ │
│  └────────────────────────────┘  │ │  └──────────────────────────┘ │
│                                  │ │                              │
│  VM1                             │ │  VM2                         │
└──────────────────────────────────┘ └──────────────────────────────┘
```

### 3.2 Componentes de Red Explicados

| Componente | Capa | Tipo | Función |
|------------|------|------|---------|
| **enp2s0f0** | L1 (Física) | NIC física | Conecta host a LAN física (192.168.0.x) |
| **br0** | L2 (Kernel) | Bridge virtual | Switch L2 que conecta VMs |
| **tap0, tap1** | L2 (Kernel) | TAP interfaces | Backend de red para VMs |
| **virtio-net** | L3 (QEMU) | Emulación NIC | Frontend de red en QEMU |
| **eth0 (guest)** | L4 (VM) | Virtual NIC | Interfaz de red vista por el guest |

---

## 4. Flujo de Datos

### 4.1 VM1 → VM2 (Tráfico Local)

```
┌──────────────────────────────────────────────────────────────────┐
│ VM1 (192.168.100.10)                                             │
│                                                                  │
│ Aplicación envía datos                                          │
│  ↓                                                               │
│ Kernel Guest: TCP/IP Stack                                      │
│  ↓                                                               │
│ Driver virtio_net → eth0                                        │
│  ↓ (genera frame Ethernet)                                      │
└───────────────────┬──────────────────────────────────────────────┘
                    │
                    │ virtio ring buffer
                    ↓
┌───────────────────────────────────────────────────────────────────┐
│ QEMU VM1 (userspace)                                              │
│                                                                   │
│ virtio-net backend                                                │
│  ↓                                                                │
│ Escribe frame a tap0 (write to file descriptor)                  │
└───────────────────┬───────────────────────────────────────────────┘
                    │
                    │ system call
                    ↓
┌───────────────────────────────────────────────────────────────────┐
│ Kernel Host                                                       │
│                                                                   │
│ TAP Driver (tap0)                                                 │
│  ↓ (recibe frame Ethernet L2)                                    │
│ Bridge br0                                                        │
│  ├─ Lee MAC destino                                              │
│  ├─ Consulta tabla MAC (MAC learning)                            │
│  └─ Reenvía a puerto tap1                                        │
│     ↓                                                             │
│ TAP Driver (tap1)                                                 │
└───────────────────┬───────────────────────────────────────────────┘
                    │
                    │ read() syscall
                    ↓
┌───────────────────────────────────────────────────────────────────┐
│ QEMU VM2 (userspace)                                              │
│                                                                   │
│ Lee frame desde tap1                                              │
│  ↓                                                                │
│ virtio-net backend                                                │
└───────────────────┬───────────────────────────────────────────────┘
                    │
                    │ virtio ring buffer
                    ↓
┌───────────────────────────────────────────────────────────────────┐
│ VM2 (192.168.100.20)                                              │
│                                                                   │
│ Driver virtio_net recibe frame                                   │
│  ↓                                                                │
│ Kernel Guest: TCP/IP Stack procesa paquete                       │
│  ↓                                                                │
│ Aplicación recibe datos                                          │
└───────────────────────────────────────────────────────────────────┘
```

**Latencia:** < 1ms (todo en memoria del host)
**Rendimiento:** ~10-40 Gbps (limitado por CPU)

---

### 4.2 Ejecución de vCPU (KVM)

```
┌──────────────────────────────────────────────────────────────────┐
│ VM Guest ejecuta instrucción                                     │
└───────────────────┬──────────────────────────────────────────────┘
                    │
                    ↓
┌──────────────────────────────────────────────────────────────────┐
│ CPU Hardware (AMD-V/SVM)                                         │
│                                                                  │
│ ¿Es instrucción privilegiada?                                   │
│   NO → Ejecutar directamente (VMX non-root mode)                │
│   SÍ → VM Exit (trampa al hipervisor)                           │
└───────────────────┬──────────────────────────────────────────────┘
                    │ (VM Exit)
                    ↓
┌──────────────────────────────────────────────────────────────────┐
│ KVM (kernel module)                                              │
│                                                                  │
│ Handle VM Exit:                                                  │
│  ├─ I/O instruction → Emular en QEMU                            │
│  ├─ CPUID → Emular en KVM                                       │
│  ├─ Page fault → Gestionar EPT/NPT                              │
│  └─ Otros → Delegar a QEMU                                      │
└───────────────────┬──────────────────────────────────────────────┘
                    │
                    ↓
┌──────────────────────────────────────────────────────────────────┐
│ QEMU (si es necesario)                                           │
│                                                                  │
│ Emular dispositivo o instrucción compleja                       │
│  ↓                                                               │
│ Retornar resultado a KVM via ioctl()                            │
└───────────────────┬──────────────────────────────────────────────┘
                    │
                    ↓ (VM Entry)
┌──────────────────────────────────────────────────────────────────┐
│ CPU Hardware                                                     │
│                                                                  │
│ VM Entry → Retomar ejecución en VM guest                        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 5. Guía de Implementación

### 5.1 Verificación de KVM (Capa 2)

```bash
# 1. Verificar módulos del kernel
lsmod | grep kvm

# Resultado esperado:
# kvm_amd               155648  0    (para AMD)
# kvm                  1150976  1 kvm_amd

# 2. Verificar dispositivo
ls -l /dev/kvm

# Resultado: crw-rw----+ 1 root kvm ... /dev/kvm

# 3. Verificar capacidad
kvm-ok

# Resultado:
# INFO: /dev/kvm exists
# KVM acceleration can be used

# 4. Verificar extensiones CPU
grep -E 'svm|vmx' /proc/cpuinfo

# 5. Información detallada
sudo dmesg | grep -i kvm
```

---

### 5.2 Creación del Bridge (Capa de Red)

#### Opción A: Bridge Aislado (Recomendado para laboratorio)

```bash
# Crear bridge con NetworkManager
sudo nmcli connection add type bridge \
  ifname br0 \
  con-name bridge-br0 \
  ipv4.method manual \
  ipv4.addresses 192.168.100.1/24

# Activar
sudo nmcli connection up bridge-br0

# Verificar
ip addr show br0
bridge link show
```

**Resultado:**
- Bridge funcional para VMs
- No interfiere con red del host
- Ideal para práctica

---

#### Opción B: Bridge Conectado a Física (Producción)

```bash
# 1. Crear bridge (con DHCP para obtener IP del router)
sudo nmcli connection add type bridge \
  ifname br0 \
  con-name bridge-br0 \
  ipv4.method auto

# 2. Agregar interfaz física como esclava
sudo nmcli connection add type ethernet \
  ifname enp2s0f0 \
  con-name bridge-br0-slave-enp2s0f0 \
  master bridge-br0

# 3. Bajar conexión actual
sudo nmcli connection down netplan-zz-all-en

# 4. Activar bridge y esclava
sudo nmcli connection up bridge-br0
sudo nmcli connection up bridge-br0-slave-enp2s0f0

# Verificar
ip addr show br0
bridge link show
```

**Resultado:**
- VMs en la misma red que el host
- Pueden obtener IP del router por DHCP
- Acceso directo desde otros dispositivos de la LAN

---

### 5.3 Configuración de Red Virtual en libvirt (Capa VMM)

#### Crear definición de red

```bash
# Crear archivo XML
cat > /tmp/br0-network.xml << 'EOF'
<network>
  <name>br0-network</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>
EOF

# Definir en libvirt
sudo virsh net-define /tmp/br0-network.xml

# Iniciar red
sudo virsh net-start br0-network

# Auto-inicio al arrancar
sudo virsh net-autostart br0-network

# Verificar
sudo virsh net-list --all
```

---

### 5.4 Creación de Máquinas Virtuales

#### VM1 con virt-install

```bash
sudo virt-install \
  --name vm1-bridge \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/vm1.qcow2,size=20,format=qcow2 \
  --os-variant ubuntu22.04 \
  --network network=br0-network,model=virtio \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole \
  --cdrom /path/to/ubuntu-22.04.iso
```

**Parámetros explicados:**
- `--ram 2048`: 2 GB RAM (gestionado por QEMU)
- `--vcpus 2`: 2 CPUs virtuales (ejecutadas por KVM)
- `--disk format=qcow2`: Formato copy-on-write
- `--network model=virtio`: Driver paravirtualizado (alto rendimiento)
- `--graphics vnc`: Acceso por VNC

---

#### VM2 (similar)

```bash
sudo virt-install \
  --name vm2-bridge \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/vm2.qcow2,size=20,format=qcow2 \
  --os-variant ubuntu22.04 \
  --network network=br0-network,model=virtio \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole \
  --cdrom /path/to/ubuntu-22.04.iso
```

---

### 5.5 Verificación de Arquitectura Completa

```bash
# === CAPA 1: Hardware ===
lscpu | grep -E 'Vendor|Virtualization'
cat /proc/cpuinfo | grep -E 'svm|vmx' | head -1

# === CAPA 2: Hipervisor (KVM) ===
lsmod | grep kvm
ls -l /dev/kvm

# === CAPA 3: VMM (libvirt/QEMU) ===
sudo systemctl status libvirtd
ps aux | grep qemu
sudo virsh list --all

# === CAPA 3: Red Virtual ===
ip addr show br0
bridge link show
sudo virsh net-list --all

# === CAPA 4-5: VMs ===
sudo virsh dominfo vm1-bridge
sudo virsh dominfo vm2-bridge

# Ver interfaces TAP creadas
ip link show | grep -E 'tap|vnet'
```

---

## 6. Comandos de Gestión

### 6.1 Gestión de VMs (libvirt)

```bash
# Listar VMs
sudo virsh list --all

# Iniciar VM
sudo virsh start vm1-bridge

# Detener VM (graceful)
sudo virsh shutdown vm1-bridge

# Forzar apagado
sudo virsh destroy vm1-bridge

# Eliminar VM
sudo virsh undefine vm1-bridge --remove-all-storage

# Acceder a consola
sudo virsh console vm1-bridge

# Ver información
sudo virsh dominfo vm1-bridge
sudo virsh domiflist vm1-bridge  # Interfaces de red

# Snapshots
sudo virsh snapshot-create-as vm1-bridge snapshot1
sudo virsh snapshot-list vm1-bridge
sudo virsh snapshot-revert vm1-bridge snapshot1
```

---

### 6.2 Gestión de Red

```bash
# Redes virtuales
sudo virsh net-list --all
sudo virsh net-dumpxml br0-network

# Bridge en host
ip addr show br0
bridge link show
bridge fdb show br0      # Forwarding database (tabla MAC)

# Interfaces TAP
ip link show tap0
ip link show tap1

# NetworkManager
nmcli connection show
nmcli connection show bridge-br0
```

---

### 6.3 Monitoreo de KVM

```bash
# Estadísticas de VM
sudo virsh domstats vm1-bridge

# CPU stats
sudo virsh cpu-stats vm1-bridge

# Uso de vCPUs
sudo virsh vcpuinfo vm1-bridge

# Memoria
sudo virsh dommemstat vm1-bridge

# I/O
sudo virsh domblkstat vm1-bridge vda

# Network
sudo virsh domifstat vm1-bridge vnet0
```

---

### 6.4 Inspección de Procesos QEMU

```bash
# Ver procesos QEMU
ps aux | grep qemu-system

# Ver línea de comando completa
ps -ef | grep qemu-system

# Uso de recursos
top -p $(pgrep -d',' qemu-system)

# Archivos abiertos
sudo lsof -p <PID_QEMU>

# Conexiones de red
sudo ss -tlnp | grep qemu
```

---

## 7. Troubleshooting

### 7.1 KVM no disponible

**Síntoma:**
```
ERROR: KVM acceleration cannot be used
```

**Diagnóstico:**
```bash
kvm-ok
ls -l /dev/kvm
lsmod | grep kvm
```

**Solución:**
```bash
# 1. Verificar BIOS (AMD-V/Intel VT-x habilitado)

# 2. Cargar módulos
sudo modprobe kvm
sudo modprobe kvm_amd  # o kvm_intel

# 3. Verificar permisos
sudo chmod 666 /dev/kvm
sudo usermod -aG kvm $USER
```

---

### 7.2 libvirtd no responde

**Síntoma:**
```
error: failed to connect to the hypervisor
```

**Diagnóstico:**
```bash
sudo systemctl status libvirtd
sudo systemctl status virtqemud.socket
sudo journalctl -u libvirtd -n 50
```

**Solución:**
```bash
# Opción 1: Reiniciar servicio
sudo systemctl restart libvirtd

# Opción 2: Usar servicios modulares (Ubuntu 24.04+)
sudo systemctl start virtqemud.socket
sudo systemctl start virtnetworkd.socket
sudo systemctl start virtstoraged.socket

# Opción 3: Reiniciar sistema
sudo reboot
```

---

### 7.3 VMs sin conectividad

**Síntoma:** VM no puede hacer ping al host ni a Internet

**Diagnóstico:**
```bash
# En el host
ip addr show br0        # ¿Tiene IP?
bridge link show        # ¿tap0/tap1 conectadas?
ip link show tap0       # ¿Estado UP?

# En la VM
ip addr show eth0       # ¿Tiene IP?
ip link show eth0       # ¿Estado UP?
ip route                # ¿Ruta por defecto?
ping 192.168.100.1      # ¿Puede alcanzar el host?
```

**Solución:**
```bash
# Activar forwarding en host
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

# Verificar firewall
sudo iptables -L -v -n
sudo iptables -I FORWARD -i br0 -o br0 -j ACCEPT

# En la VM: configurar IP manualmente
sudo ip addr add 192.168.100.10/24 dev eth0
sudo ip link set eth0 up
sudo ip route add default via 192.168.100.1
```

---

### 7.4 Bridge no funciona después de reinicio

**Diagnóstico:**
```bash
nmcli connection show
ip addr show br0
```

**Solución:**
```bash
# Activar conexión
sudo nmcli connection up bridge-br0

# Verificar autoconnect
nmcli connection modify bridge-br0 connection.autoconnect yes
```

---

### 7.5 Performance de red lenta

**Diagnóstico:**
```bash
# En VM: probar iperf3
iperf3 -c 192.168.100.1

# Ver modelo de NIC
sudo virsh dumpxml vm1-bridge | grep model
```

**Solución:**
```bash
# Asegurar virtio (no e1000 o rtl8139)
sudo virsh edit vm1-bridge
# Cambiar:
# <model type='virtio'/>

# Habilitar multiq
# <driver name='vhost' queues='4'/>
```

---

## 8. Referencias

### 8.1 Documentación Oficial

- **KVM**: https://www.linux-kvm.org/
- **QEMU**: https://www.qemu.org/documentation/
- **libvirt**: https://libvirt.org/
- **NetworkManager**: https://networkmanager.dev/

---

### 8.2 Libros y Recursos

- "Mastering KVM Virtualization" - Packt Publishing
- Red Hat Virtualization Guide
- Ubuntu KVM Documentation

---

### 8.3 Comandos de Ayuda

```bash
man kvm
man qemu-system-x86_64
man virsh
man virt-install
man nmcli
man bridge
```

---

### 8.4 Arquitectura de Archivos del Sistema

```
/dev/kvm                          ← Dispositivo KVM
/sys/module/kvm/                  ← Parámetros del módulo KVM
/var/lib/libvirt/images/          ← Discos virtuales (qcow2)
/etc/libvirt/qemu/                ← Definiciones XML de VMs
/etc/libvirt/qemu/networks/       ← Definiciones de redes
/var/log/libvirt/qemu/            ← Logs de VMs
/run/libvirt/qemu/                ← Sockets y PIDs
```

---

## Resumen de Capas y Tecnologías

| Capa | Tecnología | Componente | Función Principal |
|------|------------|------------|-------------------|
| **5** | Aplicaciones | Apps, servicios | Lógica de negocio |
| **4** | Guest OS | Linux kernel + virtio | Sistema operativo de la VM |
| **3** | VMM | QEMU + libvirt | Emulación y gestión de VMs |
| **2** | Hipervisor | KVM (kvm.ko) | Virtualización por hardware |
| **1** | Hardware | CPU (AMD-V), RAM, NIC | Infraestructura física |

---

## Comandos de Verificación Rápida

```bash
#!/bin/bash
echo "=== CAPA 1: Hardware ==="
lscpu | grep -E 'Vendor|Model name|Virtualization'

echo -e "\n=== CAPA 2: KVM ==="
lsmod | grep kvm
ls -l /dev/kvm 2>/dev/null || echo "KVM no disponible"

echo -e "\n=== CAPA 3: VMM (libvirt/QEMU) ==="
systemctl is-active libvirtd || systemctl is-active virtqemud
sudo virsh list --all 2>/dev/null || echo "libvirt no disponible"
ps aux | grep qemu-system | grep -v grep

echo -e "\n=== RED: Bridge y TAP ==="
ip addr show br0 2>/dev/null | grep -E 'br0:|inet '
bridge link show 2>/dev/null
ip link show | grep -E 'tap|vnet'

echo -e "\n=== Redes Virtuales ==="
sudo virsh net-list --all 2>/dev/null

echo -e "\n=== Resumen ==="
echo "VMs corriendo: $(sudo virsh list --name 2>/dev/null | grep -v '^$' | wc -l)"
echo "Interfaces TAP: $(ip link show | grep -c 'tap')"
```

---

**Documento creado:** 2026-03-17
**Versión:** 1.0
**Autor:** Documentación Unificada - Claude Code
**Ubicación:** `/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/`

---

## Glosario Técnico

- **AMD-V / SVM**: Extensiones de virtualización de AMD
- **Bridge**: Switch virtual de capa 2
- **EPT/NPT**: Extended/Nested Page Tables (virtualización de memoria)
- **Hipervisor Tipo 1**: Ejecuta directamente sobre hardware
- **KVM**: Kernel-based Virtual Machine
- **libvirt**: API de gestión de virtualización
- **QEMU**: Quick Emulator (emulador y virtualizador)
- **qcow2**: QEMU Copy-On-Write (formato de disco virtual)
- **TAP**: Network TAP device (layer 2 virtual interface)
- **virtio**: Framework de paravirtualización de alto rendimiento
- **VMM**: Virtual Machine Manager
- **vnet/tap**: Interfaces virtuales conectadas a VMs

---

**FIN DEL DOCUMENTO**
