# Quick Reference - bridge01dh

## 🚀 INICIO RÁPIDO

### 1. Dar permisos (solo primera vez)
```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA"
chmod +x *.sh
```

### 2. Crear disco VM1 (solo primera vez)
```bash
cd /home/uceda
qemu-img create -f qcow2 vm1-virtual-disk-bridge01.qcow2 20G
```

### 3. Configurar bridge (solo primera vez)
```bash
sudo ip link set bridge01dh up
sudo ip addr add 192.168.101.1/24 dev bridge01dh
```

### 4. Iniciar VMs
```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA"
./start_vm1_bridge01.sh
./start_vm2_bridge01.sh
```

### 5. Conectar por VNC
```bash
vncviewer localhost:5911  # VM1
vncviewer localhost:5912  # VM2
```

### 6. Detener VMs
```bash
./stop_vms_bridge01.sh
```

## 🔍 VERIFICACIÓN

```bash
./verificar_bridge01.sh
```

## 📊 CONFIGURACIÓN

| Item | Valor |
|------|-------|
| **Bridge** | bridge01dh |
| **Red** | 192.168.101.0/24 |
| **Gateway (host)** | 192.168.101.1 |
| **VM1 IP** | 192.168.101.10 |
| **VM2 IP** | 192.168.101.20 |
| **VM1 VNC** | localhost:5911 |
| **VM2 VNC** | localhost:5912 |

## 🗂️ ARCHIVOS

```
/home/uceda/
├── vm1-virtual-disk-bridge01.qcow2
└── vm2-virtual-disk-bridge01.qcow2

/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/
├── start_vm1_bridge01.sh
├── start_vm2_bridge01.sh
├── stop_vms_bridge01.sh
├── verificar_bridge01.sh
└── vms-bridge01/
    ├── vm1.pid
    └── vm2.pid
```
