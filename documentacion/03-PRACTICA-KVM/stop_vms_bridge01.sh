#!/bin/bash

# Script para detener VMs de bridge01dh
# Uso: ./stop_vms_bridge01.sh

PID_DIR="/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms-bridge01"

echo "Deteniendo VMs de bridge01dh..."

# Función para detener una VM
stop_vm() {
    local vm_name=$1
    local pid_file="$PID_DIR/${vm_name}.pid"

    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        if ps -p $pid > /dev/null 2>&1; then
            echo "  Deteniendo $vm_name (PID: $pid)..."
            sudo kill $pid
            sleep 2

            # Verificar si se detuvo
            if ps -p $pid > /dev/null 2>&1; then
                echo "  ⚠ $vm_name no se detuvo, forzando..."
                sudo kill -9 $pid
            fi

            rm -f "$pid_file"
            echo "  ✓ $vm_name detenida"
        else
            echo "  ⚠ $vm_name no está corriendo (PID $pid no existe)"
            rm -f "$pid_file"
        fi
    else
        echo "  ⚠ No hay PID file para $vm_name ($pid_file)"
    fi
}

# Detener ambas VMs
stop_vm "vm1"
stop_vm "vm2"

echo ""
echo "Verificando interfaces TAP..."
ip link show | grep -E "tap[0-9]+" | grep "master bridge01dh"

echo ""
echo "Estado del bridge:"
ip addr show bridge01dh

echo ""
echo "✓ Proceso completado"
