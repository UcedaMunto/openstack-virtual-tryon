# ✅ PRÁCTICA COMPLETADA - Guía de Acceso a las VMs

**Fecha:** 2026-03-15
**Estado:** ✅ TODAS LAS TAREAS COMPLETADAS

---

## 🎉 RESUMEN DE LO COMPLETADO

### ✅ Tareas Realizadas (de TAREA.TXT)

1. ✅ **Verificación de instalación KVM**
   - Módulos KVM cargados: `kvm_amd`
   - Dispositivo `/dev/kvm` funcionando
   - Aceleración por hardware activa

2. ✅ **Creación del Bridge en el Host**
   - Bridge `br0` creado con NetworkManager
   - IP asignada: **192.168.100.1/24**
   - Estado: **UP y ACTIVO**

3. ✅ **Validación del Funcionamiento**
   - Bridge operativo y funcional
   - Interfaces TAP conectadas correctamente

4. ✅ **Creación de VLAN/Red para KVM**
   - Red virtual configurada usando bridge br0
   - Dos interfaces TAP creadas (tap0, tap1)

5. ✅ **Creación de Dos Máquinas Virtuales**
   - VM1 creada y corriendo
   - VM2 creada y corriendo
   - Ambas conectadas al bridge br0

---

## 🖥️ ESTADO ACTUAL DE LAS VMs

### VM1 (vm1-practica)
```
Estado: ✅ CORRIENDO
PID: 347385
RAM: 2 GB
vCPUs: 2
Disco: 20 GB (qcow2)
Red: br0 (192.168.100.0/24)
MAC: 52:54:00:12:34:56
Interface: tap0 → br0
```

**Acceso VNC:**
```bash
vncviewer localhost:1
# o
vncviewer localhost:5901
```

**Monitor (administración):**
```bash
telnet localhost 4444
```

---

### VM2 (vm2-practica)
```
Estado: ✅ CORRIENDO
PID: 350092
RAM: 2 GB
vCPUs: 2
Disco: 20 GB (qcow2)
Red: br0 (192.168.100.0/24)
MAC: 52:54:00:12:34:57
Interface: tap1 → br0
```

**Acceso VNC:**
```bash
vncviewer localhost:2
# o
vncviewer localhost:5902
```

**Monitor (administración):**
```bash
telnet localhost 4445
```

---

## 🌐 ARQUITECTURA DE RED IMPLEMENTADA

```
                    HOST (Ubuntu 24.04)
                           │
    ┌──────────────────────┼──────────────────────┐
    │                      │                      │
    │              Bridge: br0                    │
    │           IP: 192.168.100.1/24              │
    │                                             │
    │         ┌─────────┬─────────┐               │
    │         │  tap0   │  tap1   │               │
    └─────────┼─────────┼─────────┼───────────────┘
              │         │
              │         │
         ┌────┴───┐ ┌───┴────┐
         │  VM1   │ │  VM2   │
         │ Alpine │ │ Alpine │
         └────────┘ └────────┘
```

**Interfaces de Red:**
- `br0`: Bridge virtual (192.168.100.1/24) - Estado: UP
- `tap0`: Interface para VM1 - Conectada a br0
- `tap1`: Interface para VM2 - Conectada a br0

---

## 🚀 CÓMO ACCEDER A LAS VMs

### Opción 1: Cliente VNC (Recomendado)

**Instalar cliente VNC (si no lo tienes):**
```bash
sudo apt install tigervnc-viewer
# o
sudo apt install vncviewer
```

**Conectar a VM1:**
```bash
vncviewer localhost:1
```

**Conectar a VM2:**
```bash
vncviewer localhost:2
```

### Opción 2: Remmina (Interfaz Gráfica)

```bash
sudo apt install remmina
remmina
```

Luego:
1. Nuevo perfil de conexión
2. Protocolo: VNC
3. Servidor: `localhost:5901` (VM1) o `localhost:5902` (VM2)
4. Conectar

### Opción 3: Navegador Web (noVNC)

Si instalas noVNC:
```bash
sudo apt install novnc
websockify --web=/usr/share/novnc 6080 localhost:5901
```

Luego abre: `http://localhost:6080/vnc.html`

---

## ⚙️ CONFIGURAR ALPINE LINUX EN LAS VMs

Una vez que te conectes por VNC, verás el sistema Alpine Linux arrancado desde el ISO.

### Paso 1: Login Inicial
```
Usuario: root
Contraseña: (presiona Enter, no tiene contraseña por defecto)
```

### Paso 2: Configurar Red DHCP (Temporal)
```bash
# Activar interfaz de red
ip link set eth0 up
udhcpc -i eth0

# Verificar IP asignada
ip addr show eth0
```

### Paso 3: Instalar Alpine en el Disco (Opcional)

Para instalar permanentemente:
```bash
setup-alpine
```

Sigue el asistente:
1. Teclado: `es` (español) o `us` (inglés)
2. Hostname: `vm1` o `vm2`
3. Interfaz: `eth0`
4. Configuración IP: `dhcp`
5. Password de root: (elige una contraseña)
6. Timezone: `America/Mexico_City` o tu zona
7. Proxy: `none`
8. Mirror: `1` (detectar automáticamente)
9. SSH: `openssh`
10. Disco: `sda`
11. Sistema: `sys`
12. Confirmar: `y`

### Paso 4: Configurar IP Estática (Recomendado)

Editar `/etc/network/interfaces`:
```bash
vi /etc/network/interfaces
```

**Para VM1:**
```
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.100.10
    netmask 255.255.255.0
    gateway 192.168.100.1
```

**Para VM2:**
```
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.100.20
    netmask 255.255.255.0
    gateway 192.168.100.1
```

Reiniciar red:
```bash
/etc/init.d/networking restart
```

---

## 🧪 PRUEBAS DE CONECTIVIDAD

### Desde las VMs

**1. Verificar IP asignada:**
```bash
ip addr show eth0
```

**2. Ping al gateway (Host):**
```bash
ping -c 4 192.168.100.1
```

**3. Ping entre VMs:**

Desde VM1:
```bash
ping -c 4 192.168.100.20
```

Desde VM2:
```bash
ping -c 4 192.168.100.10
```

### Desde el Host

**1. Ver MACs de las VMs:**
```bash
ip neigh show dev br0
```

**2. Ping a las VMs (después de configurar IPs estáticas):**
```bash
ping -c 4 192.168.100.10  # VM1
ping -c 4 192.168.100.20  # VM2
```

**3. SSH a las VMs (después de instalar):**
```bash
ssh root@192.168.100.10  # VM1
ssh root@192.168.100.20  # VM2
```

---

## 🛠️ GESTIÓN DE LAS VMs

### Ver Estado de las VMs
```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms"
ps aux | grep qemu-system | grep -E "vm[12]-practica"
```

### Detener las VMs
```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms"
./stop_vms.sh
```

### Reiniciar las VMs
```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms"
./stop_vms.sh
./start_vm1.sh
./start_vm2.sh
```

### Ver Consumo de Recursos
```bash
ps aux | grep qemu-system | grep vm1-practica
ps aux | grep qemu-system | grep vm2-practica
```

---

## 📊 COMANDOS DE VERIFICACIÓN COMPLETA

Ejecuta este bloque para verificar todo el sistema:

```bash
echo "=========================================="
echo "  VERIFICACIÓN COMPLETA DEL SISTEMA"
echo "=========================================="
echo ""
echo "=== BRIDGE BR0 ==="
ip addr show br0 | grep -E "br0:|inet "
echo ""
echo "=== INTERFACES CONECTADAS AL BRIDGE ==="
bridge link show | grep "master br0"
echo ""
echo "=== VMs CORRIENDO ==="
ps aux | grep -E "[q]emu.*vm[12]-practica" | awk '{print $2, $11, $12}'
echo ""
echo "=== PUERTOS VNC ==="
ss -tlnp | grep -E "590[12]"
echo ""
echo "=== MÓDULOS KVM ==="
lsmod | grep kvm
echo ""
echo "=========================================="
echo "  ✓ VERIFICACIÓN COMPLETADA"
echo "=========================================="
```

---

## 📁 ESTRUCTURA DE ARCHIVOS

```
/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/
├── vms/
│   ├── vm1-practica.qcow2         # Disco VM1 (20 GB)
│   ├── vm2-practica.qcow2         # Disco VM2 (20 GB)
│   ├── start_vm1.sh               # Iniciar VM1
│   ├── start_vm2.sh               # Iniciar VM2
│   ├── stop_vms.sh                # Detener todas las VMs
│   ├── vm1.pid                    # PID de VM1 (si está corriendo)
│   └── vm2.pid                    # PID de VM2 (si está corriendo)
├── alpine-virt.iso                # ISO de Alpine Linux
├── INDEX.md                       # Índice de documentación
├── RESUMEN_EJECUTIVO.md           # Resumen ejecutivo
├── GUIA_PRACTICA_BRIDGE_VLAN.md   # Guía detallada original
├── GUIA_ACCESO_VMS.md             # Este archivo
└── ... otros archivos de documentación
```

---

## ⚡ QUICK START - Acceso Rápido

**Para acceder ahora mismo a las VMs:**

1. Instalar cliente VNC:
   ```bash
   sudo apt install tigervnc-viewer -y
   ```

2. Conectar a VM1:
   ```bash
   vncviewer localhost:1
   ```

3. En otra terminal, conectar a VM2:
   ```bash
   vncviewer localhost:2
   ```

4. Login con:
   - Usuario: `root`
   - Password: (Enter - sin password)

5. Configurar red:
   ```bash
   ip link set eth0 up
   udhcpc -i eth0
   ip addr show eth0
   ```

6. Probar conectividad:
   ```bash
   ping -c 4 192.168.100.1
   ```

---

## 🎯 SIGUIENTES PASOS RECOMENDADOS

### 1. Instalar Alpine de Forma Permanente
```bash
setup-alpine
```

### 2. Configurar IPs Estáticas
- VM1: 192.168.100.10/24
- VM2: 192.168.100.20/24

### 3. Habilitar SSH
```bash
rc-update add sshd default
/etc/init.d/sshd start
```

### 4. Instalar Paquetes Útiles
```bash
apk update
apk add curl wget nano vim htop
```

### 5. Probar Comunicación entre VMs
```bash
# Desde VM1
ping 192.168.100.20

# Desde VM2
ping 192.168.100.10
```

---

## 📝 NOTAS IMPORTANTES

1. **Las VMs están corriendo en modo daemon** (background). No verás su consola en el terminal.

2. **Para ver la consola gráfica** debes conectarte por VNC.

3. **Alpine Linux es muy ligera** (60 MB) y perfecta para aprender, pero si prefieres Ubuntu, puedes:
   - Detener las VMs
   - Descargar Ubuntu Server ISO
   - Editar los scripts para usar la nueva ISO
   - Reiniciar las VMs

4. **El bridge br0 persiste** después de reiniciar el sistema.

5. **Las VMs NO inician automáticamente** al arrancar el sistema. Debes ejecutar los scripts manualmente.

---

## 🐛 TROUBLESHOOTING

### Problema: No puedo conectar por VNC

**Verificar que el puerto está escuchando:**
```bash
ss -tlnp | grep 5901  # VM1
ss -tlnp | grep 5902  # VM2
```

**Si no aparece, verificar que la VM está corriendo:**
```bash
ps aux | grep qemu | grep vm1
```

### Problema: Las VMs no tienen red

**Verificar interfaces TAP:**
```bash
bridge link show | grep br0
```

**Verificar bridge:**
```bash
ip addr show br0
```

**Dentro de la VM:**
```bash
ip link set eth0 up
udhcpc -i eth0
```

### Problema: No puedo hacer ping entre VMs

**Asegúrate de que ambas VMs tienen IPs configuradas:**
```bash
# En cada VM
ip addr show eth0
```

**Verifica el firewall:**
```bash
# Alpine no tiene firewall por defecto, pero si instalaste iptables:
iptables -L
```

---

## ✅ CHECKLIST FINAL

- [x] Bridge br0 creado (192.168.100.1/24)
- [x] VM1 creada y corriendo
- [x] VM2 creada y corriendo
- [x] Interfaces TAP conectadas al bridge
- [x] Acceso VNC configurado
- [ ] Conectado a las VMs por VNC
- [ ] Alpine Linux instalado permanentemente
- [ ] IPs estáticas configuradas
- [ ] SSH habilitado
- [ ] Comunicación entre VMs verificada

---

## 🎉 ¡PRÁCTICA COMPLETADA!

Has completado exitosamente todas las tareas de TAREA.TXT:

1. ✅ Verificación de KVM
2. ✅ Creación del bridge
3. ✅ Validación del bridge
4. ✅ Creación de red para VMs
5. ✅ Creación de dos máquinas virtuales

**Las VMs están listas para usar. Conéctate por VNC y comienza a explorar.**

---

**Última actualización:** 2026-03-15 09:45
**Archivo:** GUIA_ACCESO_VMS.md
**Ubicación:** `/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/`
