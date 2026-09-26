#!/bin/bash

##############################################################################
# Script de Creación de VMs con QEMU Directo (Sin libvirt)
# Fecha: 2026-03-12
# Propósito: Crear 2 VMs conectadas al bridge br0 usando QEMU
##############################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Creación de VMs con QEMU Directo${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

##############################################################################
# CONFIGURACIÓN
##############################################################################

WORK_DIR="/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms"
ISO_PATH="/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/ubuntu-22.04.5-live-server-amd64.iso"
BRIDGE="br0"

# VM1
VM1_NAME="vm1-practica"
VM1_DISK="$WORK_DIR/vm1-practica.qcow2"
VM1_MAC="52:54:00:12:34:56"
VM1_VNC_PORT="5901"
VM1_MONITOR_PORT="4444"

# VM2
VM2_NAME="vm2-practica"
VM2_DISK="$WORK_DIR/vm2-practica.qcow2"
VM2_MAC="52:54:00:12:34:57"
VM2_VNC_PORT="5902"
VM2_MONITOR_PORT="4445"

##############################################################################
# VERIFICACIONES
##############################################################################

echo -e "${YELLOW}[1/5] Verificando requisitos...${NC}"

# Verificar QEMU
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "${RED}ERROR: qemu-system-x86_64 no está instalado${NC}"
    exit 1
fi

# Verificar bridge
if ! ip addr show "$BRIDGE" &>/dev/null; then
    echo -e "${RED}ERROR: Bridge $BRIDGE no existe${NC}"
    exit 1
fi

# Verificar permisos
if ! groups | grep -q "kvm"; then
    echo -e "${RED}ADVERTENCIA: El usuario no está en el grupo 'kvm'${NC}"
    echo "Esto puede causar problemas. Ejecuta: sudo usermod -aG kvm $USER"
fi

# Verificar ISO
if [ ! -f "$ISO_PATH" ]; then
    echo -e "${RED}ERROR: ISO no encontrada en $ISO_PATH${NC}"
    echo "Descargando..."
    mkdir -p "$(dirname "$ISO_PATH")"
    wget -O "$ISO_PATH" "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
fi

echo -e "${GREEN}✓ Requisitos verificados${NC}"
echo ""

##############################################################################
# CREAR DIRECTORIO Y DISCOS
##############################################################################

echo -e "${YELLOW}[2/5] Creando discos virtuales...${NC}"

mkdir -p "$WORK_DIR"

# Crear disco VM1
if [ -f "$VM1_DISK" ]; then
    echo -e "${YELLOW}Disco VM1 ya existe. ¿Eliminar y recrear? (s/N):${NC}"
    read -r respuesta
    if [[ "$respuesta" =~ ^[Ss]$ ]]; then
        rm -f "$VM1_DISK"
        qemu-img create -f qcow2 "$VM1_DISK" 20G
        echo -e "${GREEN}✓ Disco VM1 creado (20 GB)${NC}"
    else
        echo -e "${YELLOW}Usando disco existente${NC}"
    fi
else
    qemu-img create -f qcow2 "$VM1_DISK" 20G
    echo -e "${GREEN}✓ Disco VM1 creado (20 GB)${NC}"
fi

# Crear disco VM2
if [ -f "$VM2_DISK" ]; then
    echo -e "${YELLOW}Disco VM2 ya existe. ¿Eliminar y recrear? (s/N):${NC}"
    read -r respuesta
    if [[ "$respuesta" =~ ^[Ss]$ ]]; then
        rm -f "$VM2_DISK"
        qemu-img create -f qcow2 "$VM2_DISK" 20G
        echo -e "${GREEN}✓ Disco VM2 creado (20 GB)${NC}"
    else
        echo -e "${YELLOW}Usando disco existente${NC}"
    fi
else
    qemu-img create -f qcow2 "$VM2_DISK" 20G
    echo -e "${GREEN}✓ Disco VM2 creado (20 GB)${NC}"
fi

echo ""

##############################################################################
# CREAR SCRIPTS DE INICIO
##############################################################################

echo -e "${YELLOW}[3/5] Creando scripts de inicio...${NC}"

# Script para VM1
cat > "$WORK_DIR/start_vm1.sh" << EOF
#!/bin/bash
sudo qemu-system-x86_64 \\
    -name "$VM1_NAME" \\
    -machine type=q35,accel=kvm \\
    -cpu host \\
    -smp 2 \\
    -m 2048 \\
    -drive file="$VM1_DISK",if=virtio,format=qcow2 \\
    -cdrom "$ISO_PATH" \\
    -boot d \\
    -netdev bridge,id=net0,br=$BRIDGE \\
    -device virtio-net-pci,netdev=net0,mac=$VM1_MAC \\
    -vnc :1 \\
    -monitor telnet:127.0.0.1:$VM1_MONITOR_PORT,server,nowait \\
    -daemonize \\
    -pidfile "$WORK_DIR/vm1.pid"

echo "VM1 iniciada"
echo "VNC: localhost:$VM1_VNC_PORT"
echo "Monitor: telnet localhost $VM1_MONITOR_PORT"
echo "PID guardado en: $WORK_DIR/vm1.pid"
EOF

chmod +x "$WORK_DIR/start_vm1.sh"
echo -e "${GREEN}✓ Script VM1: $WORK_DIR/start_vm1.sh${NC}"

# Script para VM2
cat > "$WORK_DIR/start_vm2.sh" << EOF
#!/bin/bash
sudo qemu-system-x86_64 \\
    -name "$VM2_NAME" \\
    -machine type=q35,accel=kvm \\
    -cpu host \\
    -smp 2 \\
    -m 2048 \\
    -drive file="$VM2_DISK",if=virtio,format=qcow2 \\
    -cdrom "$ISO_PATH" \\
    -boot d \\
    -netdev bridge,id=net0,br=$BRIDGE \\
    -device virtio-net-pci,netdev=net0,mac=$VM2_MAC \\
    -vnc :2 \\
    -monitor telnet:127.0.0.1:$VM2_MONITOR_PORT,server,nowait \\
    -daemonize \\
    -pidfile "$WORK_DIR/vm2.pid"

echo "VM2 iniciada"
echo "VNC: localhost:$VM2_VNC_PORT"
echo "Monitor: telnet localhost $VM2_MONITOR_PORT"
echo "PID guardado en: $WORK_DIR/vm2.pid"
EOF

chmod +x "$WORK_DIR/start_vm2.sh"
echo -e "${GREEN}✓ Script VM2: $WORK_DIR/start_vm2.sh${NC}"

# Script para detener VMs
cat > "$WORK_DIR/stop_vms.sh" << 'EOF'
#!/bin/bash
echo "Deteniendo VMs..."
if [ -f "$WORK_DIR/vm1.pid" ]; then
    PID=$(cat "$WORK_DIR/vm1.pid")
    sudo kill $PID 2>/dev/null && echo "VM1 detenida"
fi
if [ -f "$WORK_DIR/vm2.pid" ]; then
    PID=$(cat "$WORK_DIR/vm2.pid")
    sudo kill $PID 2>/dev/null && echo "VM2 detenida"
fi
EOF

sed -i "s|\$WORK_DIR|$WORK_DIR|g" "$WORK_DIR/stop_vms.sh"
chmod +x "$WORK_DIR/stop_vms.sh"
echo -e "${GREEN}✓ Script de detención: $WORK_DIR/stop_vms.sh${NC}"

echo ""

##############################################################################
# CONFIGURAR RED
##############################################################################

echo -e "${YELLOW}[4/5] Configurando permisos de red...${NC}"

# Permitir que QEMU use el bridge
if ! grep -q "allow $BRIDGE" /etc/qemu/bridge.conf 2>/dev/null; then
    echo "allow $BRIDGE" | sudo tee -a /etc/qemu/bridge.conf > /dev/null
    echo -e "${GREEN}✓ Bridge $BRIDGE permitido en QEMU${NC}"
else
    echo -e "${GREEN}✓ Bridge ya configurado${NC}"
fi

# Establecer permisos en helper de bridge
if [ -f /usr/lib/qemu/qemu-bridge-helper ]; then
    sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
    echo -e "${GREEN}✓ Permisos establecidos en qemu-bridge-helper${NC}"
fi

echo ""

##############################################################################
# RESUMEN
##############################################################################

echo -e "${YELLOW}[5/5] Resumen de configuración${NC}"
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              CONFIGURACIÓN COMPLETADA            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Discos creados:${NC}"
echo "  VM1: $VM1_DISK"
echo "  VM2: $VM2_DISK"
echo ""
echo -e "${GREEN}Scripts de control:${NC}"
echo "  Iniciar VM1: $WORK_DIR/start_vm1.sh"
echo "  Iniciar VM2: $WORK_DIR/start_vm2.sh"
echo "  Detener VMs: $WORK_DIR/stop_vms.sh"
echo ""
echo -e "${GREEN}Configuración de red:${NC}"
echo "  Bridge: $BRIDGE (192.168.100.1/24)"
echo "  VM1 MAC: $VM1_MAC"
echo "  VM2 MAC: $VM2_MAC"
echo ""
echo -e "${GREEN}Acceso VNC:${NC}"
echo "  VM1: localhost:$VM1_VNC_PORT (VNC display :1)"
echo "  VM2: localhost:$VM2_VNC_PORT (VNC display :2)"
echo ""
echo -e "${YELLOW}Especificaciones de cada VM:${NC}"
echo "  - RAM: 2 GB"
echo "  - CPUs: 2"
echo "  - Disco: 20 GB"
echo "  - Boot: CD-ROM (ISO de Ubuntu)"
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              SIGUIENTE PASO                      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo "Para iniciar las VMs, ejecuta:"
echo ""
echo -e "  ${GREEN}$WORK_DIR/start_vm1.sh${NC}"
echo -e "  ${GREEN}$WORK_DIR/start_vm2.sh${NC}"
echo ""
echo "Para conectar por VNC, usa un cliente VNC y conéctate a:"
echo ""
echo "  ${GREEN}localhost:$VM1_VNC_PORT${NC}  o  ${GREEN}localhost:1${NC} (para VM1)"
echo "  ${GREEN}localhost:$VM2_VNC_PORT${NC}  o  ${GREEN}localhost:2${NC} (para VM2)"
echo ""
echo "Clientes VNC recomendados:"
echo "  - vncviewer localhost:1"
echo "  - remmina"
echo "  - tigervnc"
echo ""
echo -e "${YELLOW}Instalar cliente VNC si no lo tienes:${NC}"
echo "  sudo apt install tigervnc-viewer"
echo ""
echo -e "${GREEN}¡Configuración completa!${NC}"
