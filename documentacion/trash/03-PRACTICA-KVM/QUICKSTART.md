# QUICKSTART - Guía Rápida de 5 Minutos

**Sistema:** Ubuntu 24.04 con KVM
**Práctica:** Bridge Virtual y VMs
**Última actualización:** 2026-03-17

---

## ⚡ TL;DR - Lo Esencial

```bash
# 1. Verificar que todo funciona
./verificar_sistema.sh

# 2. Conectar a VM1
vncviewer localhost:1

# 3. Conectar a VM2 (en otra terminal)
vncviewer localhost:2

# 4. Login: root (sin password, solo Enter)
```

---

## 📊 Estado Actual del Sistema

### ✅ Lo que ya está funcionando:

| Componente | Estado | Detalles |
|------------|--------|----------|
| **KVM** | ✅ Activo | Hipervisor funcionando |
| **Bridge br0** | ✅ UP | IP: 192.168.100.1/24 |
| **VM1** | ✅ Corriendo | PID: 347385, VNC: 5901 |
| **VM2** | ✅ Corriendo | PID: 350092, VNC: 5902 |
| **Red Virtual** | ✅ Activa | tap0 ↔ br0 ↔ tap1 |

---

## 🚀 Acceso Inmediato a las VMs

### Método 1: VNC (Recomendado)

```bash
# Instalar cliente VNC (si no lo tienes)
sudo apt install tigervnc-viewer -y

# Conectar a VM1
vncviewer localhost:1

# Conectar a VM2 (en otra terminal)
vncviewer localhost:2
```

**Login inicial:**
- Usuario: `root`
- Password: `(presiona Enter sin escribir nada)`

### Método 2: Monitor QEMU (Avanzado)

```bash
# VM1
telnet localhost 4444

# VM2
telnet localhost 4445
```

---

## 🌐 Configurar Red en las VMs

Una vez dentro de la VM por VNC:

```bash
# 1. Activar interfaz de red
ip link set eth0 up

# 2. Obtener IP por DHCP (si hay servidor DHCP)
udhcpc -i eth0

# 3. O configurar IP manualmente
ip addr add 192.168.100.10/24 dev eth0  # VM1
ip addr add 192.168.100.20/24 dev eth0  # VM2

# 4. Agregar ruta por defecto
ip route add default via 192.168.100.1

# 5. Verificar
ip addr show eth0
ping 192.168.100.1  # Host
```

---

## 🔍 Verificación Rápida

### Ver todo el sistema:

```bash
./verificar_sistema.sh
```

### Comandos individuales:

```bash
# Bridge
ip addr show br0

# VMs corriendo
ps aux | grep qemu | grep vm

# Interfaces TAP conectadas
bridge link show

# KVM habilitado
lsmod | grep kvm
```

---

## 🛑 Detener/Reiniciar VMs

### Detener:

```bash
cd vms
./stop_vms.sh
```

### Reiniciar:

```bash
cd vms
./start_vm1.sh
./start_vm2.sh
```

### Ver si están corriendo:

```bash
ps aux | grep qemu | grep vm
```

---

## 🔧 Comandos Útiles

### Ping entre VMs

**Desde VM1:**
```bash
ping 192.168.100.20  # VM2
```

**Desde VM2:**
```bash
ping 192.168.100.10  # VM1
```

**Desde Host:**
```bash
ping 192.168.100.10  # VM1
ping 192.168.100.20  # VM2
```

### Copiar archivos al host (futuro, con SSH)

```bash
# Desde el host
scp root@192.168.100.10:/path/to/file .
```

---

## 🐛 Troubleshooting Express

### VM no responde por VNC

```bash
# Verificar que la VM está corriendo
ps aux | grep qemu | grep vm1

# Verificar puerto VNC
ss -tlnp | grep 5901

# Reiniciar VM
cd vms
./stop_vms.sh
./start_vm1.sh
```

### VM sin red

```bash
# En el host, verificar bridge
ip addr show br0
bridge link show

# En la VM, activar interfaz
ip link set eth0 up
ip addr show eth0
```

### Bridge caído

```bash
# Levantar conexión
sudo nmcli connection up bridge-br0

# Verificar
ip addr show br0
```

### KVM no funciona

```bash
# Verificar módulos
lsmod | grep kvm

# Cargar módulos si no están
sudo modprobe kvm kvm_amd  # o kvm_intel

# Verificar dispositivo
ls -l /dev/kvm
```

---

## 📚 ¿Necesitas más detalles?

| Tema | Archivo a consultar |
|------|---------------------|
| Arquitectura completa | [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md) |
| Acceso a VMs | [GUIA_ACCESO_VMS.md](./GUIA_ACCESO_VMS.md) |
| Configuración de red | [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md) §5 |
| Troubleshooting avanzado | [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md) §7 |
| Índice completo | [INDEX.md](./INDEX.md) |

---

## 🎯 Próximos Pasos Sugeridos

1. **Instalar Alpine Linux permanentemente en las VMs**
   ```bash
   # Dentro de cada VM
   setup-alpine
   ```

2. **Configurar IPs estáticas** (ver DOCUMENTACION_UNIFICADA.md)

3. **Habilitar SSH**
   ```bash
   # En las VMs
   rc-update add sshd default
   /etc/init.d/sshd start
   ```

4. **Probar conectividad** entre VMs y con el host

5. **Experimentar** con servicios de red (web, DB, etc.)

---

## 📈 Arquitectura Simplificada

```
Host (Ubuntu 24.04)
    ├─ KVM (Hipervisor)
    ├─ QEMU Process VM1 ──→ tap0 ──┐
    ├─ QEMU Process VM2 ──→ tap1 ──┤
    └─ Bridge br0 (192.168.100.1/24)
           ├─ tap0 (VM1 backend)
           └─ tap1 (VM2 backend)

VM1 (Alpine Linux - 192.168.100.10)
VM2 (Alpine Linux - 192.168.100.20)
```

---

## ⚙️ Información Técnica Rápida

| Parámetro | Valor |
|-----------|-------|
| **Hipervisor** | KVM (kvm_amd) |
| **VMM** | QEMU |
| **Red Host** | 192.168.0.195/24 (enp2s0f0) |
| **Red Virtual** | 192.168.100.0/24 (br0) |
| **VM1 RAM** | 2 GB |
| **VM1 vCPUs** | 2 |
| **VM1 Disco** | 20 GB (qcow2) |
| **VM1 VNC** | localhost:5901 (display :1) |
| **VM2 RAM** | 2 GB |
| **VM2 vCPUs** | 2 |
| **VM2 Disco** | 20 GB (qcow2) |
| **VM2 VNC** | localhost:5902 (display :2) |

---

## 💡 Tips Rápidos

- **VNC más rápido:** Usa TigerVNC en lugar de otros clientes
- **Copiar/pegar:** Funciona en VNC si configuras clipboard sharing
- **Performance:** Las VMs usan virtio (drivers paravirtualizados) = muy rápido
- **Disco ahorro:** qcow2 es sparse, solo ocupa espacio usado real (~196 KB ahora)
- **Multitarea:** Puedes tener ambas VMs abiertas simultáneamente

---

## 🆘 Ayuda Rápida

```bash
# Ver procesos de las VMs
ps aux | grep qemu

# Ver uso de recursos
top -p $(pgrep -d',' qemu-system)

# Logs del sistema
sudo journalctl -f

# Reiniciar todo si algo falla
cd vms && ./stop_vms.sh
sudo reboot
# Después de reiniciar:
cd vms && ./start_vm1.sh && ./start_vm2.sh
```

---

## ✅ Checklist de Funcionalidad

```
□ VMs corriendo: ps aux | grep qemu | grep vm
□ Bridge activo: ip addr show br0
□ TAPs conectadas: bridge link show
□ KVM cargado: lsmod | grep kvm
□ VNC accesible: vncviewer localhost:1
□ Red en VM funcional: ip addr show eth0 (dentro VM)
```

---

**¡Listo! Tu laboratorio de virtualización está operativo.**

**¿Dudas?** Consulta [DOCUMENTACION_UNIFICADA.md](./DOCUMENTACION_UNIFICADA.md) para detalles completos.

---

**Archivo:** QUICKSTART.md
**Versión:** 1.0
**Fecha:** 2026-03-17
**Ubicación:** `/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/`
