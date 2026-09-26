#!/bin/bash
# Script de Verificación Completa del Sistema
# Creado: 2026-03-15

echo "=========================================="
echo "  VERIFICACIÓN COMPLETA DEL SISTEMA"
echo "=========================================="
echo ""

echo "=== 1. BRIDGE BR0 ==="
ip addr show br0 | grep -E "br0:|inet " && echo "✓ Bridge activo" || echo "✗ Bridge no encontrado"
echo ""

echo "=== 2. INTERFACES CONECTADAS AL BRIDGE ==="
bridge link show | grep "master br0" && echo "✓ Interfaces conectadas" || echo "✗ Sin interfaces"
echo ""

echo "=== 3. VMs CORRIENDO ==="
if ps aux | grep -E "[q]emu.*vm1-practica" > /dev/null; then
    VM1_PID=$(ps aux | grep -E "[q]emu.*vm1-practica" | awk '{print $2}')
    echo "✓ VM1 corriendo (PID: $VM1_PID)"
else
    echo "✗ VM1 no está corriendo"
fi

if ps aux | grep -E "[q]emu.*vm2-practica" > /dev/null; then
    VM2_PID=$(ps aux | grep -E "[q]emu.*vm2-practica" | awk '{print $2}')
    echo "✓ VM2 corriendo (PID: $VM2_PID)"
else
    echo "✗ VM2 no está corriendo"
fi
echo ""

echo "=== 4. PUERTOS VNC ==="
if ss -tlnp 2>/dev/null | grep -q ":5901"; then
    echo "✓ VM1 VNC accesible en localhost:5901"
else
    echo "✗ VM1 VNC no accesible"
fi

if ss -tlnp 2>/dev/null | grep -q ":5902"; then
    echo "✓ VM2 VNC accesible en localhost:5902"
else
    echo "✗ VM2 VNC no accesible"
fi
echo ""

echo "=== 5. MÓDULOS KVM ==="
if lsmod | grep -q kvm; then
    echo "✓ KVM cargado: $(lsmod | grep kvm | awk '{print $1}' | tr '\n' ', ')"
else
    echo "✗ KVM no cargado"
fi
echo ""

echo "=== 6. DISCOS VIRTUALES ==="
if [ -f "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms/vm1-practica.qcow2" ]; then
    SIZE1=$(du -h "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms/vm1-practica.qcow2" | awk '{print $1}')
    echo "✓ Disco VM1: $SIZE1"
else
    echo "✗ Disco VM1 no encontrado"
fi

if [ -f "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms/vm2-practica.qcow2" ]; then
    SIZE2=$(du -h "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms/vm2-practica.qcow2" | awk '{print $1}')
    echo "✓ Disco VM2: $SIZE2"
else
    echo "✗ Disco VM2 no encontrado"
fi
echo ""

echo "=========================================="
echo "  RESUMEN"
echo "=========================================="
echo ""
echo "Bridge br0: 192.168.100.1/24"
echo "VM1: localhost:5901 (VNC)"
echo "VM2: localhost:5902 (VNC)"
echo ""
echo "Para conectar:"
echo "  vncviewer localhost:1"
echo "  vncviewer localhost:2"
echo ""
echo "=========================================="
