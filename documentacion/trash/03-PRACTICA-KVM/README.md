# Práctica: Bridge Virtual y Máquinas Virtuales con KVM

![Estado](https://img.shields.io/badge/Estado-Completado-success)
![Sistema](https://img.shields.io/badge/Ubuntu-24.04-orange)
![KVM](https://img.shields.io/badge/KVM-Habilitado-blue)

Laboratorio completo de virtualización con KVM, QEMU, y redes virtuales usando bridges.

---

## 🚀 Inicio Rápido

**¿Primera vez?** Lee esto primero:

### **→ [QUICKSTART.md](./QUICKSTART.md)** ⚡ (5 minutos)

Guía express para conectarte a las VMs inmediatamente.

### **→ [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md)** 📖 (Lectura completa)

Documento maestro con toda la arquitectura, diagramas del stack completo (Hardware → KVM → QEMU/libvirt → Guest OS), y guías detalladas.

### **→ [INDEX.md](./INDEX.md)** 📑 (Índice completo)

Tabla de contenidos de toda la documentación disponible.

---

## 📊 ¿Qué hay implementado?

- ✅ **KVM** (Hipervisor tipo 1) con soporte AMD-V
- ✅ **QEMU** como VMM (Virtual Machine Manager)
- ✅ **libvirt** para gestión de VMs
- ✅ **Bridge virtual br0** (192.168.100.1/24)
- ✅ **2 Máquinas Virtuales** (Alpine Linux)
  - VM1: 2GB RAM, 2 vCPUs, VNC en puerto 5901
  - VM2: 2GB RAM, 2 vCPUs, VNC en puerto 5902
- ✅ **Red virtual** con interfaces TAP (tap0, tap1)
- ✅ **Acceso VNC** configurado y funcional
- ✅ **Scripts de gestión** para start/stop de VMs

---

## 🎯 Arquitectura (Vista Simplificada)

```
┌─────────────────────────────────────────────────────────────────┐
│  HARDWARE FÍSICO                                                │
│  CPU: AMD Ryzen + AMD-V                                         │
│  ────────────────────────────────────────────────────────────   │
│  HIPERVISOR: KVM (Kernel-based Virtual Machine)                │
│  ────────────────────────────────────────────────────────────   │
│  VMM: QEMU + libvirt                                            │
│    ├─ QEMU Process VM1 (PID 347385) → tap0                     │
│    └─ QEMU Process VM2 (PID 350092) → tap1                     │
│  ────────────────────────────────────────────────────────────   │
│  BRIDGE: br0 (192.168.100.1/24)                                 │
│    ├─ tap0 (VM1 backend)                                        │
│    └─ tap1 (VM2 backend)                                        │
└─────────────────────────────────────────────────────────────────┘
         │                          │
    ┌────┴─────┐              ┌─────┴────┐
    │   VM1    │              │   VM2    │
    │ Alpine   │              │ Alpine   │
    │192.168.  │              │192.168.  │
    │ 100.10   │              │ 100.20   │
    └──────────┘              └──────────┘
```

**Ver arquitectura completa de 5 capas en:** [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md#1-arquitectura-completa-del-sistema)

---

## ⚡ Acceso Inmediato

### Conectar a las VMs:

```bash
# VM1
vncviewer localhost:1

# VM2
vncviewer localhost:2
```

**Login inicial:** `root` (sin password)

### Verificar sistema:

```bash
./verificar_sistema.sh
```

### Gestión de VMs:

```bash
# Detener
cd vms && ./stop_vms.sh

# Reiniciar
cd vms && ./start_vm1.sh && ./start_vm2.sh
```

---

## 📚 Documentación Disponible

### Principales

| Documento | Descripción | Tiempo lectura |
|-----------|-------------|----------------|
| [QUICKSTART.md](./QUICKSTART.md) | Guía rápida de inicio | 5 min |
| [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md) | Documento maestro completo | 45 min |
| [INDEX.md](./INDEX.md) | Índice de toda la documentación | 10 min |

### Guías Complementarias

- [GUIA_ACCESO_VMS.md](./GUIA_ACCESO_VMS.md) - Métodos de acceso a VMs
- [GUIA_PRACTICA_BRIDGE_VLAN.md](./GUIA_PRACTICA_BRIDGE_VLAN.md) - Paso a paso detallado
- [GUIA_NIC_NETWORK_INTERFACE_CARD.md](./GUIA_NIC_NETWORK_INTERFACE_CARD.md) - Referencia de NICs
- [GUIA_IP_ADDR_SHOW_EXPLICADA.md](./GUIA_IP_ADDR_SHOW_EXPLICADA.md) - Interpretar salida de `ip addr`
- [SOLUCION_TROUBLESHOOTING_LIBVIRTD.md](./SOLUCION_TROUBLESHOOTING_LIBVIRTD.md) - Solución a problemas comunes

---

## 🛠️ Requisitos

### Ya instalado en el sistema:

- ✅ Ubuntu 24.04 LTS
- ✅ KVM (kvm_amd)
- ✅ QEMU
- ✅ libvirt
- ✅ NetworkManager
- ✅ Bridge br0 configurado

### Para acceder a las VMs:

```bash
sudo apt install tigervnc-viewer
```

---

## 🎓 ¿Qué aprenderás?

1. **Arquitectura de virtualización moderna**
   - Stack completo: Hardware → KVM → QEMU → Guest OS
   - Rol del hipervisor vs VMM
   - Paravirtualización (virtio)

2. **Redes virtuales**
   - Bridges de capa 2
   - Interfaces TAP/TUN
   - Switching virtual

3. **Gestión de VMs**
   - Creación con QEMU/libvirt
   - Acceso por VNC, consola, SSH
   - Snapshots y clonación

4. **Troubleshooting**
   - Diagnóstico de red virtual
   - Logs y monitoreo
   - Optimización de rendimiento

---

## 📊 Especificaciones Técnicas

| Componente | Especificación |
|------------|----------------|
| **Host OS** | Ubuntu 24.04 LTS (Kernel 6.17.0-14) |
| **CPU** | AMD Ryzen con AMD-V/SVM |
| **Hipervisor** | KVM (Tipo 1, integrado al kernel) |
| **VMM** | QEMU 8.x + libvirt |
| **Bridge** | br0 (192.168.100.1/24) |
| **VMs** | 2x Alpine Linux 3.19.1 |
| **VM RAM** | 2 GB cada una |
| **VM vCPUs** | 2 cada una |
| **VM Discos** | 20 GB qcow2 (sparse) cada uno |
| **Red Virtual** | 192.168.100.0/24 |
| **Drivers VM** | virtio (paravirtualización) |

---

## 🔍 Comandos Rápidos

```bash
# Estado del sistema
./verificar_sistema.sh

# Bridge
ip addr show br0

# VMs corriendo
ps aux | grep qemu | grep vm

# Interfaces TAP
bridge link show

# KVM
lsmod | grep kvm

# VNC
vncviewer localhost:1  # VM1
vncviewer localhost:2  # VM2
```

---

## 🗂️ Estructura del Proyecto

```
.
├── README.md (este archivo)
├── INDEX.md (índice completo)
├── QUICKSTART.md (guía rápida 5 min)
├── DOCUMENTACION_UNIFICADA.md (documento maestro)
│
├── Guías complementarias/
│   ├── GUIA_ACCESO_VMS.md
│   ├── GUIA_PRACTICA_BRIDGE_VLAN.md
│   ├── GUIA_NIC_NETWORK_INTERFACE_CARD.md
│   ├── GUIA_IP_ADDR_SHOW_EXPLICADA.md
│   ├── GUIA_USO_BRIDGE01DH.md
│   ├── GUIA_RAPIDA_ALTERNATIVAS.md
│   ├── SOLUCION_TROUBLESHOOTING_LIBVIRTD.md
│   └── ...
│
├── Scripts/
│   └── verificar_sistema.sh
│
└── vms/
    ├── vm1-practica.qcow2
    ├── vm2-practica.qcow2
    ├── start_vm1.sh
    ├── start_vm2.sh
    └── stop_vms.sh
```

---

## 🐛 Troubleshooting

### VMs no responden

```bash
# Verificar procesos
ps aux | grep qemu

# Reiniciar
cd vms && ./stop_vms.sh && ./start_vm1.sh && ./start_vm2.sh
```

### Bridge inactivo

```bash
# Levantar bridge
sudo nmcli connection up bridge-br0

# Verificar
ip addr show br0
```

### Sin conectividad en VM

```bash
# Dentro de la VM
ip link set eth0 up
udhcpc -i eth0
```

**Más detalles:** [DOCUMENTACION_UNIFICADA.md §7](./DOCUMENTACION_UNIFICADA.md#7-troubleshooting)

---

## 📈 Próximos Pasos

1. **Instalar Alpine permanentemente** en las VMs
2. **Configurar SSH** para acceso remoto
3. **Implementar servicios** (web, DB, etc.)
4. **Crear snapshots** para backup/restore
5. **Experimentar con VLANs** reales

---

## 📖 Referencias

- **KVM Official:** https://www.linux-kvm.org/
- **QEMU Docs:** https://www.qemu.org/documentation/
- **libvirt Wiki:** https://libvirt.org/
- **Documento técnico completo:** [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md)

---

## ✨ Características Destacadas

- 🚀 **Zero-to-Hero:** De instalación a VMs funcionando
- 📖 **Documentación exhaustiva:** 60+ páginas de guías
- 🎨 **Diagramas detallados:** Arquitectura de 5 capas visualizada
- 🔧 **Scripts automatizados:** Gestión simplificada
- 🎓 **Enfoque educativo:** Explicaciones técnicas profundas
- ✅ **100% funcional:** Sistema completo y probado

---

## 👨‍💻 Autor

**Claude Code** - Documentación generada automáticamente
**Fecha:** 2026-03-17
**Versión:** 2.0 (Unificada)

---

## 📝 Licencia

Material educativo de la Especialización - Laboratorio 1

---

## 🎯 Estado del Proyecto

- ✅ KVM verificado y funcionando
- ✅ Bridge br0 creado y configurado
- ✅ 2 VMs creadas y en ejecución
- ✅ Red virtual funcional
- ✅ Acceso VNC configurado
- ✅ Documentación completa
- ✅ Scripts de gestión creados

---

**¡El laboratorio está listo para usar!**

**Comienza aquí:** [QUICKSTART.md](./QUICKSTART.md) → [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md)
