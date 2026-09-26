#!/bin/bash

# Script de inicio para VM1 en bridge01dh
# Uso: ./start_vm1_bridge01.sh

DISK_PATH="/home/uceda/vm1-virtual-disk-bridge01.qcow2"
ISO_PATH="/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/alpine-virt.iso"
PID_DIR="/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms-bridge01"

# Crear directorio para PIDs si no existe
mkdir -p "$PID_DIR"

# Verificar que el disco existe
if [ ! -f "$DISK_PATH" ]; then
    echo "ERROR: No existe el disco $DISK_PATH"
    echo "Ejecuta primero: qemu-img create -f qcow2 $DISK_PATH 20G"
    exit 1
fi

# Verificar que el ISO existe
if [ ! -f "$ISO_PATH" ]; then
    echo "ERROR: No existe el ISO $ISO_PATH"
    exit 1
fi

echo "Iniciando VM1 en bridge01dh..."
echo "  Disco: $DISK_PATH"
echo "  Bridge: bridge01dh"
echo "  VNC: localhost:5911 (puerto :11)"
echo "  Monitor: telnet://127.0.0.1:5555"

sudo qemu-system-x86_64 \
    -name "vm1-bridge01" \
    -machine type=q35,accel=kvm \
    -cpu host \
    -smp 2 \
    -m 2048 \
    -drive file="$DISK_PATH",if=virtio,format=qcow2 \
    -cdrom "$ISO_PATH" \
    -boot d \
    -netdev bridge,id=net0,br=bridge01dh \
    -device virtio-net-pci,netdev=net0,mac=52:54:00:aa:bb:01 \
    -vnc :11 \
    -monitor telnet:127.0.0.1:5555,server,nowait \
    -daemonize \
    -pidfile "$PID_DIR/vm1.pid"

if [ $? -eq 0 ]; then
    echo "✓ VM1 iniciada correctamente"
    echo ""
    echo "Conectar por VNC:"
    echo "  vncviewer localhost:5911"
    echo ""
    echo "Conectar al monitor QEMU:"
    echo "  telnet localhost 5555"
    echo ""
    echo "PID guardado en: $PID_DIR/vm1.pid"
else
    echo "✗ Error al iniciar VM1"
    exit 1
fi
