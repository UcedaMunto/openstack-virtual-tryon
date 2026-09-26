# Guía de Uso - VMs con bridge01dh

**Fecha:** 2026-03-15
**Bridge:** bridge01dh
**Ubicación:** `/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/`

---

## 📋 RESUMEN

Has creado un bridge personalizado llamado `bridge01dh` y ahora tienes 2 VMs configuradas para usarlo.

### Archivos Creados

```
/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/
├── start_vm1_bridge01.sh        ← Iniciar VM1
├── start_vm2_bridge01.sh        ← Iniciar VM2
├── stop_vms_bridge01.sh         ← Detener ambas VMs
├── verificar_bridge01.sh        ← Verificar estado del entorno
└── vms-bridge01/                ← Directorio para PIDs
```

### Discos de VM

```
/home/uceda/
├── vm1-virtual-disk-bridge01.qcow2    ← Disco VM1 (20 GB) - CREAR
└── vm2-virtual-disk-bridge01.qcow2    ← Disco VM2 (20 GB) - ✓ CREADO
```

---

## 🚀 PASOS PARA INICIAR

### 1. Dar Permisos de Ejecución a los Scripts

```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA"

chmod +x start_vm1_bridge01.sh
chmod +x start_vm2_bridge01.sh
chmod +x stop_vms_bridge01.sh
chmod +x verificar_bridge01.sh
```

### 2. Crear Disco de VM1 (si no existe)

```bash
cd /home/uceda
qemu-img create -f qcow2 vm1-virtual-disk-bridge01.qcow2 20G
```

**Salida esperada:**
```
Formatting 'vm1-virtual-disk-bridge01.qcow2', fmt=qcow2 cluster_size=65536 extended_l2=off compression_type=zlib size=21474836480 lazy_refcounts=off refcount_bits=16
```

### 3. Verificar Estado del Entorno

```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA"
./verificar_bridge01.sh
```

Este script verifica:
- Estado del bridge bridge01dh
- Existencia de discos VM1 y VM2
- Existencia del ISO de Alpine
- Permisos de QEMU
- VMs en ejecución
- Interfaces TAP conectadas

### 4. Activar el Bridge (si está DOWN)

Si el bridge está desactivado, activarlo:

```bash
sudo nmcli connection up conexion-forbridge01
```

**O manualmente:**
```bash
sudo ip link set bridge01dh up
```

### 5. Asignar IP al Bridge (opcional pero recomendado)

Para que el host pueda comunicarse con las VMs:

```bash
sudo ip addr add 192.168.101.1/24 dev bridge01dh
```

**¿Por qué 192.168.101.x?**
- Para evitar conflicto con br0 (192.168.100.x)
- Red privada para tus VMs de bridge01dh

### 6. Iniciar VM1

```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA"
./start_vm1_bridge01.sh
```

**Salida esperada:**
```
Iniciando VM1 en bridge01dh...
  Disco: /home/uceda/vm1-virtual-disk-bridge01.qcow2
  Bridge: bridge01dh
  VNC: localhost:5911 (puerto :11)
  Monitor: telnet://127.0.0.1:5555
✓ VM1 iniciada correctamente

Conectar por VNC:
  vncviewer localhost:5911

Conectar al monitor QEMU:
  telnet localhost 5555

PID guardado en: /home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms-bridge01/vm1.pid
```

### 7. Iniciar VM2

```bash
./start_vm2_bridge01.sh
```

**Salida esperada:**
```
Iniciando VM2 en bridge01dh...
  Disco: /home/uceda/vm2-virtual-disk-bridge01.qcow2
  Bridge: bridge01dh
  VNC: localhost:5912 (puerto :12)
  Monitor: telnet://127.0.0.1:5556
✓ VM2 iniciada correctamente

Conectar por VNC:
  vncviewer localhost:5912

Conectar al monitor QEMU:
  telnet localhost 5556

PID guardado en: /home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms-bridge01/vm2.pid
```

### 8. Verificar que las VMs Están Corriendo

```bash
./verificar_bridge01.sh
```

O manualmente:

```bash
# Ver procesos QEMU
ps aux | grep qemu | grep bridge01

# Ver interfaces TAP creadas
ip link show | grep tap

# Ver estado del bridge
bridge link show | grep bridge01dh
```

### 9. Conectarse a las VMs por VNC

**Opción 1: TigerVNC (recomendado)**
```bash
# Conectar a VM1
vncviewer localhost:5911

# Conectar a VM2
vncviewer localhost:5912
```

**Opción 2: Vinagre**
```bash
# Conectar a VM1
vinagre localhost:5911

# Conectar a VM2
vinagre localhost:5912
```

**Opción 3: RealVNC**
```bash
# Conectar a VM1
vncviewer localhost::5911

# Conectar a VM2
vncviewer localhost::5912
```

### 10. Instalar Alpine Linux en las VMs

Una vez conectado por VNC:

```bash
# Dentro de la VM (por VNC)
localhost login: root
(sin password - presiona Enter)

# Ejecutar instalador
setup-alpine

# Sigue las instrucciones:
# - Keyboard: es (español)
# - Hostname: vm1-bridge01 (o vm2-bridge01)
# - Network: eth0
# - IP: 192.168.101.10 (VM1) o 192.168.101.20 (VM2)
# - Netmask: 255.255.255.0
# - Gateway: 192.168.101.1
# - DNS: 8.8.8.8
# - Timezone: America/Santiago (o tu zona)
# - Proxy: none
# - Mirror: 1 (detección automática)
# - SSH server: openssh
# - Disk: vda
# - Mode: sys
```

### 11. Reiniciar las VMs

Después de instalar, apaga las VMs:

```bash
# Dentro de cada VM
poweroff
```

Modifica los scripts de inicio para arrancar desde el disco (sin ISO):

```bash
# Editar start_vm1_bridge01.sh y start_vm2_bridge01.sh
# Comentar la línea del CDROM y cambiar boot a 'c'

# De:
#    -cdrom "$ISO_PATH" \
#    -boot d \

# A:
#    -boot c \
```

Reinicia las VMs:

```bash
./start_vm1_bridge01.sh
./start_vm2_bridge01.sh
```

---

## 🛑 DETENER LAS VMS

```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA"
./stop_vms_bridge01.sh
```

**Salida esperada:**
```
Deteniendo VMs de bridge01dh...
  Deteniendo vm1 (PID: 12345)...
  ✓ vm1 detenida
  Deteniendo vm2 (PID: 12346)...
  ✓ vm2 detenida

Verificando interfaces TAP...
(ninguna)

Estado del bridge:
16: bridge01dh: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN
...

✓ Proceso completado
```

---

## 🔍 COMANDOS DE VERIFICACIÓN

### Ver Estado del Bridge

```bash
ip addr show bridge01dh
```

**Esperado:**
```
16: bridge01dh: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet 192.168.101.1/24 scope global bridge01dh
       valid_lft forever preferred_lft forever
```

### Ver Interfaces TAP Conectadas

```bash
bridge link show | grep bridge01dh
```

**Esperado:**
```
tap2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master bridge01dh
tap3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master bridge01dh
```

### Ver IPs en la Red del Bridge

```bash
ip neigh show dev bridge01dh
```

**Esperado (después de instalar VMs):**
```
192.168.101.10 lladdr 52:54:00:aa:bb:01 REACHABLE
192.168.101.20 lladdr 52:54:00:aa:bb:02 REACHABLE
```

### Ver Procesos QEMU

```bash
ps aux | grep qemu-system-x86_64 | grep bridge01
```

### Probar Conectividad (desde el host)

```bash
# Ping a VM1
ping -c 4 192.168.101.10

# Ping a VM2
ping -c 4 192.168.101.20
```

---

## 📊 CONFIGURACIÓN DE RED

### Host (tu laptop)

```
Bridge: bridge01dh
IP: 192.168.101.1/24
Estado: UP
```

### VM1 (vm1-bridge01)

```
Hostname: vm1-bridge01
Interfaz: eth0 (virtio-net)
IP sugerida: 192.168.101.10/24
Gateway: 192.168.101.1
MAC: 52:54:00:aa:bb:01
VNC: localhost:5911
Monitor: telnet://127.0.0.1:5555
```

### VM2 (vm2-bridge01)

```
Hostname: vm2-bridge01
Interfaz: eth0 (virtio-net)
IP sugerida: 192.168.101.20/24
Gateway: 192.168.101.1
MAC: 52:54:00:aa:bb:02
VNC: localhost:5912
Monitor: telnet://127.0.0.1:5556
```

---

## 🗺️ ARQUITECTURA DE RED

```
HOST (tu laptop)
│
├─ bridge01dh (192.168.101.1/24)
│  │
│  ├─ tap2 ──→ VM1 (eth0: 192.168.101.10)
│  │           │
│  │           └─ Disco: vm1-virtual-disk-bridge01.qcow2
│  │              VNC: :5911
│  │
│  └─ tap3 ──→ VM2 (eth0: 192.168.101.20)
│              │
│              └─ Disco: vm2-virtual-disk-bridge01.qcow2
│                 VNC: :5912
│
└─ br0 (192.168.100.1/24) - Bridge de la práctica anterior
   │
   ├─ tap0 ──→ VM1-practica (192.168.100.10)
   └─ tap1 ──→ VM2-practica (192.168.100.20)
```

---

## 🐛 TROUBLESHOOTING

### Error: "Permission denied" al iniciar VM

**Causa:** El script no tiene permisos de ejecución.

**Solución:**
```bash
chmod +x start_vm1_bridge01.sh start_vm2_bridge01.sh
```

### Error: "Could not access KVM kernel module"

**Causa:** Tu usuario no está en el grupo `kvm`.

**Solución:**
```bash
sudo usermod -aG kvm $USER
# Cerrar sesión e iniciar de nuevo
```

### Error: "failed to create bridge"

**Causa:** bridge01dh no está en `/etc/qemu/bridge.conf`.

**Solución:**
```bash
echo "allow bridge01dh" | sudo tee -a /etc/qemu/bridge.conf
sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
```

### Error: bridge01dh está DOWN

**Solución:**
```bash
sudo ip link set bridge01dh up
sudo ip addr add 192.168.101.1/24 dev bridge01dh
```

### VMs no se pueden comunicar entre ellas

**Verificar:**
```bash
# Desde el host, verificar que las VMs están en la misma red
bridge link show | grep bridge01dh

# Verificar IPs dentro de las VMs
# (conectar por VNC y ejecutar)
ip addr show eth0
ping 192.168.101.1  # Debe responder (es el host)
ping 192.168.101.10  # Debe responder (VM1)
ping 192.168.101.20  # Debe responder (VM2)
```

### No puedo conectar por VNC

**Verificar que la VM está corriendo:**
```bash
./verificar_bridge01.sh
```

**Verificar puertos VNC:**
```bash
ss -tulnp | grep 59
```

**Esperado:**
```
tcp   LISTEN 0  1  127.0.0.1:5911  (VM1)
tcp   LISTEN 0  1  127.0.0.1:5912  (VM2)
```

---

## 📝 DIFERENCIAS CON LA PRÁCTICA ANTERIOR (br0)

| Característica | br0 (práctica anterior) | bridge01dh (nueva) |
|----------------|-------------------------|---------------------|
| **Nombre del bridge** | br0 | bridge01dh |
| **IP del host** | 192.168.100.1/24 | 192.168.101.1/24 |
| **Red** | 192.168.100.0/24 | 192.168.101.0/24 |
| **IPs de VMs** | .10, .20 | .10, .20 |
| **Interfaces TAP** | tap0, tap1 | tap2, tap3 (se crean dinámicamente) |
| **VNC ports** | 5901, 5902 | 5911, 5912 |
| **Monitor ports** | 4444, 4445 | 5555, 5556 |
| **Scripts** | start_vm1.sh, start_vm2.sh | start_vm1_bridge01.sh, start_vm2_bridge01.sh |
| **Discos** | vms/vm1-practica.qcow2 | vm1-virtual-disk-bridge01.qcow2 |

**Importante:** Ambos bridges pueden coexistir sin problemas porque usan redes diferentes.

---

## 🎯 CHECKLIST COMPLETO

- [ ] Bridge bridge01dh creado
- [ ] Bridge bridge01dh activado (UP)
- [ ] IP asignada al bridge (192.168.101.1/24)
- [ ] Permisos QEMU configurados (/etc/qemu/bridge.conf)
- [ ] Disco VM1 creado (vm1-virtual-disk-bridge01.qcow2)
- [ ] Disco VM2 creado (vm2-virtual-disk-bridge01.qcow2)
- [ ] Scripts ejecutables (chmod +x)
- [ ] VM1 iniciada correctamente
- [ ] VM2 iniciada correctamente
- [ ] Conexión VNC a VM1 funcionando
- [ ] Conexión VNC a VM2 funcionando
- [ ] Alpine instalado en VM1
- [ ] Alpine instalado en VM2
- [ ] Conectividad entre VMs verificada

---

**Archivo:** `GUIA_USO_BRIDGE01DH.md`
**Ubicación:** `/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/`
**Fecha:** 2026-03-15
