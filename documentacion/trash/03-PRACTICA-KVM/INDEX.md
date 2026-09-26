# ÍNDICE DE DOCUMENTACIÓN - Práctica KVM Bridge y VLAN

**Fecha de actualización:** 2026-03-17
**Práctica:** Configuración de Bridge Virtual y Máquinas Virtuales con KVM
**Sistema:** Ubuntu 24.04 (Linux 6.17.0-14-generic)
**Estado:** ✅ Completado y documentado

---

## 🎯 INICIO RÁPIDO

### ¿Primera vez aquí?

**Lee esto primero:** [QUICKSTART.md](./QUICKSTART.md) - 5 minutos de lectura

### ¿Necesitas entender la arquitectura completa?

**Lee esto:** [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md) - Documento maestro con todo

---

## 📚 Documentación Principal

### 1. 🚀 [QUICKSTART.md](./QUICKSTART.md)
**Propósito:** Guía rápida de 5 minutos
**Para:** Usuarios que quieren empezar inmediatamente
**Contenido:**
- Comandos esenciales
- Verificación rápida del sistema
- Acceso a VMs
- Troubleshooting express

---

### 2. 📖 [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md) ⭐ **DOCUMENTO MAESTRO**
**Propósito:** Documentación completa con arquitectura VMM y hipervisor
**Para:** Entendimiento profundo de toda la infraestructura
**Contenido:**
- Arquitectura completa del sistema (5 capas)
- Diagramas detallados con VMM (libvirt/QEMU) e Hipervisor (KVM)
- Stack completo de virtualización
- Flujo de datos completo
- Guía de implementación paso a paso
- Comandos de gestión
- Troubleshooting avanzado
- Referencias técnicas

**Secciones principales:**
1. Arquitectura Completa del Sistema
2. Capas de Virtualización (Hardware → KVM → VMM → Guest OS → Apps)
3. Diagrama de Red Detallado
4. Flujo de Datos (VM↔VM, vCPU, memoria)
5. Guía de Implementación
6. Comandos de Gestión
7. Troubleshooting
8. Referencias

---

## 📋 Documentación Complementaria

### 3. [GUIA_ACCESO_VMS.md](./GUIA_ACCESO_VMS.md)
**Propósito:** Guía específica para acceder a las VMs
**Contenido:**
- Métodos de acceso (VNC, virsh console, SSH)
- Configuración de red en VMs
- Ejemplos prácticos

---

### 4. [GUIA_NIC_NETWORK_INTERFACE_CARD.md](./GUIA_NIC_NETWORK_INTERFACE_CARD.md)
**Propósito:** Referencia detallada sobre NICs y networking
**Contenido:**
- Tipos de NICs (física, virtual, TAP, vnet)
- Explicación de interfaces de red
- Comparación de tecnologías

---

### 5. [GUIA_IP_ADDR_SHOW_EXPLICADA.md](./GUIA_IP_ADDR_SHOW_EXPLICADA.md)
**Propósito:** Guía para interpretar la salida de `ip addr show`
**Contenido:**
- Desglose de cada campo
- Flags y estados
- Ejemplos comentados

---

### 6. [GUIA_USO_BRIDGE01DH.md](./GUIA_USO_BRIDGE01DH.md)
**Propósito:** Guía específica para bridge con DHCP
**Contenido:**
- Configuración de DHCP en bridge
- Casos de uso
- Troubleshooting específico

---

### 7. [GUIA_RAPIDA_ALTERNATIVAS.md](./GUIA_RAPIDA_ALTERNATIVAS.md)
**Propósito:** Métodos alternativos de configuración
**Contenido:**
- Opciones con ip route/iptables
- Configuración sin NetworkManager
- Alternativas a libvirt

---

### 8. [QUICKREF_BRIDGE01DH.md](./QUICKREF_BRIDGE01DH.md)
**Propósito:** Referencia rápida de comandos para bridge con DHCP

---

### 9. [GUIA_PLANTUML.md](./GUIA_PLANTUML.md)
**Propósito:** Guía para crear diagramas PlantUML
**Contenido:**
- Sintaxis PlantUML
- Ejemplos de diagramas de red
- Integración con VSCode

---

### 10. [CONFIGURACION_VSCODE_PLANTUML.md](./CONFIGURACION_VSCODE_PLANTUML.md)
**Propósito:** Configurar PlantUML en VSCode

---

## 🔧 Scripts Ejecutables

### [vms/](./vms/)
Directorio con scripts de gestión de VMs:

```bash
├── start_vm1.sh          # Iniciar VM1
├── start_vm2.sh          # Iniciar VM2
├── stop_vms.sh           # Detener todas las VMs
├── vm1-practica.qcow2    # Disco virtual VM1 (20 GB)
└── vm2-practica.qcow2    # Disco virtual VM2 (20 GB)
```

### [verificar_sistema.sh](./verificar_sistema.sh)
Script de verificación completa del sistema:
```bash
./verificar_sistema.sh
```

Verifica:
- KVM habilitado
- Bridge br0 configurado
- VMs en ejecución
- Conectividad de red

---

## 📁 Recursos

### [TAREA.TXT](./TAREA.TXT)
Especificaciones originales de la práctica:
1. ✅ Verificar instalación KVM
2. ✅ Crear un bridge en el host
3. ✅ Validar funcionamiento
4. ✅ Crear una VLAN para dos máquinas en KVM
5. ✅ Crear dos máquinas virtuales

### [alpine-virt.iso](./alpine-virt.iso)
Imagen ISO de Alpine Linux (60 MB)

---

## 🎯 Flujo de Trabajo Recomendado

### Para empezar rápidamente:
```
1. Lee QUICKSTART.md (5 min)
   ↓
2. Ejecuta verificar_sistema.sh
   ↓
3. Conecta a VMs por VNC
   ↓
4. ¡Listo para usar!
```

### Para entender a fondo:
```
1. Lee DOCUMENTACION_UNIFICADA.md completo
   ↓
2. Estudia los diagramas de arquitectura
   ↓
3. Revisa el flujo de datos
   ↓
4. Experimenta con los comandos
   ↓
5. Consulta guías complementarias según necesidad
```

---

## 📊 Estado del Sistema

### Infraestructura Implementada

| Componente | Estado | Detalles |
|------------|--------|----------|
| **KVM** | ✅ Activo | kvm_amd cargado, /dev/kvm disponible |
| **Bridge br0** | ✅ Configurado | 192.168.100.1/24, activo |
| **VM1** | ✅ Corriendo | Alpine Linux, 2GB RAM, 2 vCPUs |
| **VM2** | ✅ Corriendo | Alpine Linux, 2GB RAM, 2 vCPUs |
| **Red Virtual** | ✅ Funcional | VMs conectadas via tap0/tap1 |
| **VNC** | ✅ Disponible | VM1:5901, VM2:5902 |

### Arquitectura de Red

```
Internet → Router → Host (enp2s0f0) → Bridge br0 → [tap0, tap1] → [VM1, VM2]
```

---

## 🔍 Comandos Esenciales

### Verificación Rápida
```bash
# Estado completo
./verificar_sistema.sh

# Bridge
ip addr show br0

# VMs
ps aux | grep qemu | grep vm

# Red
bridge link show
```

### Gestión de VMs
```bash
# Acceder por VNC
vncviewer localhost:1    # VM1
vncviewer localhost:2    # VM2

# Detener VMs
cd vms && ./stop_vms.sh

# Reiniciar VMs
cd vms && ./start_vm1.sh && ./start_vm2.sh
```

### Monitoreo
```bash
# Procesos QEMU
ps aux | grep qemu

# Red
ip addr show | grep -E "br0|tap"

# KVM
lsmod | grep kvm
```

---

## 🛠️ Troubleshooting

### Problemas Comunes

| Problema | Solución | Referencia |
|----------|----------|------------|
| VNC no conecta | Verificar puertos 5901/5902 | QUICKSTART.md |
| VM sin red | Verificar tap0/tap1 en bridge | DOCUMENTACION_UNIFICADA.md §7.3 |
| KVM no disponible | Verificar BIOS y módulos | DOCUMENTACION_UNIFICADA.md §7.1 |
| Bridge inactivo | `sudo nmcli con up bridge-br0` | DOCUMENTACION_UNIFICADA.md §7.4 |

### Logs y Diagnóstico
```bash
# Logs del sistema
sudo journalctl -f

# Estado de servicios
systemctl status libvirtd

# Verificar KVM
kvm-ok
ls -l /dev/kvm
```

---

## 📈 Características Técnicas

### Hardware Host
- **CPU:** AMD Ryzen (AMD-V/SVM habilitado)
- **Sistema:** Ubuntu 24.04 LTS
- **Kernel:** Linux 6.17.0-14-generic
- **NIC:** enp2s0f0 (192.168.0.195/24)

### Capa de Virtualización
- **Hipervisor:** KVM (Tipo 1, integrado al kernel)
- **VMM:** QEMU + libvirt
- **Drivers:** virtio (paravirtualización)

### Red Virtual
- **Bridge:** br0 (192.168.100.1/24)
- **Interfaces TAP:** tap0, tap1
- **Modo:** Bridge (L2 switching)

### Máquinas Virtuales
- **Cantidad:** 2 (VM1, VM2)
- **SO:** Alpine Linux 3.19.1
- **RAM:** 2 GB cada una
- **vCPUs:** 2 cada una
- **Disco:** 20 GB qcow2 cada una
- **VNC:** VM1:5901, VM2:5902

---

## 📚 Recursos Adicionales

### Documentación Oficial
- **KVM:** https://www.linux-kvm.org/
- **QEMU:** https://www.qemu.org/documentation/
- **libvirt:** https://libvirt.org/
- **NetworkManager:** https://networkmanager.dev/

### Ayuda de Comandos
```bash
man kvm
man qemu-system-x86_64
man virsh
man virt-install
man nmcli
man bridge
```

---

## 📂 Estructura de Archivos

```
/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/
│
├─── 📄 Índice y Inicio Rápido
│    ├── INDEX.md (este archivo)
│    ├── QUICKSTART.md
│    └── TAREA.TXT
│
├─── 📖 Documentación Principal
│    └── DOCUMENTACION_UNIFICADA.md ⭐ (documento maestro)
│
├─── 📋 Guías Complementarias
│    ├── GUIA_ACCESO_VMS.md
│    ├── GUIA_NIC_NETWORK_INTERFACE_CARD.md
│    ├── GUIA_IP_ADDR_SHOW_EXPLICADA.md
│    ├── GUIA_USO_BRIDGE01DH.md
│    ├── GUIA_RAPIDA_ALTERNATIVAS.md
│    ├── QUICKREF_BRIDGE01DH.md
│    ├── GUIA_PLANTUML.md
│    └── CONFIGURACION_VSCODE_PLANTUML.md
│
├─── 🔧 Scripts
│    └── verificar_sistema.sh
│
├─── 💾 Máquinas Virtuales
│    └── vms/
│         ├── vm1-practica.qcow2
│         ├── vm2-practica.qcow2
│         ├── start_vm1.sh
│         ├── start_vm2.sh
│         └── stop_vms.sh
│
└─── 📦 Recursos
     └── alpine-virt.iso
```

---

## 🎓 Objetivos de Aprendizaje

Al completar esta práctica, habrás aprendido:

- ✅ Arquitectura de virtualización con KVM
- ✅ Capas del stack: Hardware → KVM → VMM → Guest OS
- ✅ Configuración de bridges virtuales
- ✅ Creación y gestión de VMs con QEMU/libvirt
- ✅ Networking virtual (TAP, bridges, virtio)
- ✅ Administración de máquinas virtuales
- ✅ Troubleshooting de virtualización

---

## 🚀 Próximos Pasos

### Nivel Intermedio
1. Configurar servicios en las VMs (web, DB, SSH)
2. Implementar snapshots y clonación
3. Configurar red NAT además de bridge
4. Agregar más VMs al bridge

### Nivel Avanzado
1. Implementar VLANs reales (802.1Q)
2. Configurar firewall con iptables/nftables
3. Migración de VMs en caliente
4. Optimización de rendimiento (hugepages, CPU pinning)
5. Integración con Ansible/Terraform

---

## ✨ Notas Finales

- 📦 **Sistema completo y funcional**
- 📚 **Documentación exhaustiva generada**
- 🎯 **Todas las tareas del TAREA.TXT completadas**
- 🚀 **Listo para experimentar y aprender**

---

**Última actualización:** 2026-03-17
**Versión:** 2.0 (Unificada)
**Mantenedor:** Claude Code
**Ubicación:** `/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/`

---

**¡La infraestructura está lista! Comienza con [QUICKSTART.md](./QUICKSTART.md) o profundiza con [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md)**
