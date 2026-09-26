#!/bin/bash
# Script: info_nic.sh
# Propósito: Mostrar información completa de la NIC física

NIC="enp2s0f0"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║            INFORMACIÓN COMPLETA DE TU NIC (Ethernet)             ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

echo "=== 1. CONFIGURACIÓN IP Y RED ==="
echo "Interfaz: $NIC"
MAC=$(ip link show $NIC | grep ether | awk '{print $2}')
IP=$(ip addr show $NIC | grep "inet " | awk '{print $2}')
echo "MAC: $MAC"
echo "IP: $IP"
echo "Estado: $(ip link show $NIC | grep -oP 'state \K\w+')"
echo ""

echo "=== 2. VELOCIDAD Y CONEXIÓN ==="
sudo ethtool $NIC 2>/dev/null | grep -E "Speed|Duplex|Link detected|Auto-negotiation"
echo ""

echo "=== 3. DRIVER Y HARDWARE ==="
echo "Driver: $(ethtool -i $NIC 2>/dev/null | grep driver | awk '{print $2}')"
echo "Hardware: $(lspci | grep -i ethernet | cut -d: -f3-)"
echo "Bus PCI: $(ethtool -i $NIC 2>/dev/null | grep bus-info | awk '{print $2}')"
echo ""

echo "=== 4. ESTADÍSTICAS DE TRÁFICO ==="
ip -s link show $NIC | grep -A 2 "RX:" | tail -2
echo ""
ip -s link show $NIC | grep -A 2 "TX:" | tail -2
echo ""

echo "=== 5. ESTADO DEL SISTEMA ==="
if ip link show $NIC | grep -q "state UP"; then
    echo "✓ Interfaz: ACTIVA"
else
    echo "✗ Interfaz: INACTIVA"
fi

if sudo ethtool $NIC 2>/dev/null | grep -q "Link detected: yes"; then
    echo "✓ Cable: CONECTADO"
else
    echo "✗ Cable: DESCONECTADO"
fi

if ip addr show $NIC | grep -q "inet "; then
    echo "✓ IP: ASIGNADA"
else
    echo "✗ IP: NO ASIGNADA"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICACIÓN COMPLETADA                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
