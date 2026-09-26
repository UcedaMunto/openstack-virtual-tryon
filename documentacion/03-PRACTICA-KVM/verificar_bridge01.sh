#!/bin/bash

# Script para verificar el estado del entorno bridge01dh
# Uso: ./verificar_bridge01.sh

echo "==========================================="
echo "  VERIFICACIÓN ENTORNO BRIDGE01DH"
echo "==========================================="
echo ""

echo "=== 1. ESTADO DEL BRIDGE ==="
if ip link show bridge01dh &> /dev/null; then
    ip addr show bridge01dh
    echo ""
    echo "Interfaces conectadas al bridge:"
    bridge link show | grep bridge01dh || echo "  (ninguna)"
else
    echo "✗ El bridge bridge01dh no existe"
fi

echo ""
echo "=== 2. ARCHIVOS DE DISCO ==="
echo "VM1 disk:"
if [ -f "/home/uceda/vm1-virtual-disk-bridge01.qcow2" ]; then
    ls -lh "/home/uceda/vm1-virtual-disk-bridge01.qcow2"
else
    echo "  ✗ NO EXISTE - Crear con: qemu-img create -f qcow2 /home/uceda/vm1-virtual-disk-bridge01.qcow2 20G"
fi

echo ""
echo "VM2 disk:"
if [ -f "/home/uceda/vm2-virtual-disk-bridge01.qcow2" ]; then
    ls -lh "/home/uceda/vm2-virtual-disk-bridge01.qcow2"
else
    echo "  ✗ NO EXISTE"
fi

echo ""
echo "=== 3. ISO DE INSTALACIÓN ==="
ISO_PATH="/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/alpine-virt.iso"
if [ -f "$ISO_PATH" ]; then
    ls -lh "$ISO_PATH"
else
    echo "  ✗ NO EXISTE"
fi

echo ""
echo "=== 4. PERMISOS QEMU BRIDGE ==="
if [ -f "/etc/qemu/bridge.conf" ]; then
    echo "Contenido de /etc/qemu/bridge.conf:"
    sudo cat /etc/qemu/bridge.conf | grep bridge01dh || echo "  ⚠ bridge01dh NO está en bridge.conf"
else
    echo "  ✗ /etc/qemu/bridge.conf no existe"
fi

echo ""
echo "=== 5. VMs EN EJECUCIÓN ==="
PID_DIR="/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms-bridge01"

if [ -f "$PID_DIR/vm1.pid" ]; then
    pid=$(cat "$PID_DIR/vm1.pid")
    if ps -p $pid > /dev/null 2>&1; then
        echo "VM1: ✓ CORRIENDO (PID: $pid)"
        echo "  VNC: localhost:5911"
        echo "  Monitor: telnet://127.0.0.1:5555"
    else
        echo "VM1: ✗ No está corriendo (PID file obsoleto)"
    fi
else
    echo "VM1: ✗ No iniciada"
fi

echo ""
if [ -f "$PID_DIR/vm2.pid" ]; then
    pid=$(cat "$PID_DIR/vm2.pid")
    if ps -p $pid > /dev/null 2>&1; then
        echo "VM2: ✓ CORRIENDO (PID: $pid)"
        echo "  VNC: localhost:5912"
        echo "  Monitor: telnet://127.0.0.1:5556"
    else
        echo "VM2: ✗ No está corriendo (PID file obsoleto)"
    fi
else
    echo "VM2: ✗ No iniciada"
fi

echo ""
echo "=== 6. INTERFACES TAP ==="
ip link show | grep -E "tap[0-9]+" | grep "master bridge01dh" || echo "  (ninguna TAP conectada a bridge01dh)"

echo ""
echo "==========================================="
