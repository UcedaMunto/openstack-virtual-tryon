#!/usr/bin/env bash
# =============================================================================
# 15-dns.sh — DNS local (dnsmasq) para resolver los dominios del proyecto
# -----------------------------------------------------------------------------
#  Levanta un DNS en el nodo de control (anfitrion) para que cualquier equipo
#  de la red pueda entrar por dominio:
#     icc115.openstack.com   -> 192.168.0.200  (Horizon, VIP)
#     icc115.kubernetes.com  -> 192.168.0.10   (Dashboard Kubernetes)
#
#  Ubicación elegida: anfitrion (nodo de control) — es la máquina principal,
#  siempre encendida, y ya aloja el VIP de OpenStack.
#
#  NOTA: los dominios apuntan a IPs (no puertos). El Dashboard de Kubernetes
#  se accede por https://icc115.kubernetes.com:30443 (NodePort).
# =============================================================================
set -euo pipefail

# ---- 1. Instalar dnsmasq -----------------------------------------------------
# dnsmasq es un DNS/DHCP ligero, ideal para este tipo de resolución local.
sudo -n apt-get install -y dnsmasq 2>&1 | tail -3

# ---- 2. Configurar los dominios del proyecto --------------------------------
# Escribimos el archivo de configuración de dnsmasq con los 2 dominios.
sudo -n tee /etc/dnsmasq.d/icc115.conf >/dev/null <<'EOF'
# ===== Dominios del proyecto ICC115 =====
# OpenStack Horizon (VIP interna de HAProxy/keepalived)
address=/icc115.openstack.com/192.168.0.200
# Kubernetes Dashboard (nodo de control)
address=/icc115.kubernetes.com/192.168.0.10
EOF

# ---- 3. Escuchar solo en la interfaz de red --------------------------------
# Evita conflicto con systemd-resolved (que usa 127.0.0.53). dnsmasq atenderá
# en 192.168.0.10:53 para toda la red.
sudo -n tee -a /etc/dnsmasq.d/icc115.conf >/dev/null <<'EOF'
# Escuchar únicamente en la NIC del control (192.168.0.10)
interface=enp2s0f0
bind-interfaces
EOF

# ---- 4. Arrancar y habilitar dnsmasq ----------------------------------------
sudo -n systemctl enable --now dnsmasq 2>&1
sudo -n systemctl restart dnsmasq 2>&1

# ---- 5. Entrada directa en /etc/hosts (resolución inmediata en anfitrion) ---
# Refuerzo: así el propio Lenovo resuelve los dominios aunque no use dnsmasq.
sudo -n sed -i '/icc115\./d' /etc/hosts
printf '%s\n' \
  '192.168.0.200  icc115.openstack.com' \
  '192.168.0.10   icc115.kubernetes.com' \
  | sudo -n tee -a /etc/hosts >/dev/null

# ---- 6. Verificación --------------------------------------------------------
echo "Verificación de resolución:"
echo "  OpenStack:   $(getent hosts icc115.openstack.com  | awk '{print $1}')"
echo "  Kubernetes:  $(getent hosts icc115.kubernetes.com | awk '{print $1}')"
echo
echo "Accesos:"
echo "  Horizon:     http://icc115.openstack.com/"
echo "  Dashboard:   https://icc115.kubernetes.com:30443"
