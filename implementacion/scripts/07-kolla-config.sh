#!/usr/bin/env bash
# =============================================================================
# 07-kolla-config.sh — Genera el inventario Kolla (multinode) + globals.yml
# -----------------------------------------------------------------------------
#  Requiere: 03-kolla-ansible.sh. Idempotente.
#  Genera /etc/kolla/multinode y /etc/kolla/globals.yml a partir de nodes.env,
#  y luego ejecuta kolla-genpwd para crear /etc/kolla/passwords.yml.
#  NOTA: openstack_release y las VLANs (storage/tunnel/external) quedan como
#  decisión pendiente (ver implementacion/README.md).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

KOLLA_DIR="/etc/kolla"
INV="$KOLLA_DIR/multinode"
GLOBALS="$KOLLA_DIR/globals.yml"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

log "Generando inventario Kolla-Ansible: $INV"
sudo mkdir -p "$KOLLA_DIR"

# Grupos base (los únicos que cambian por red)
sudo tee "$INV" >/dev/null <<EOF
# Inventario Kolla-Ansible (generado por 07-kolla-config.sh desde nodes.env)
[control]
$NODE01_NAME ansible_host=$NODE01_IP network_interface=$NODE01_NIC

[network]
$NODE01_NAME ansible_host=$NODE01_IP network_interface=$NODE01_NIC

[compute]
$NODE01_NAME ansible_host=$NODE01_IP network_interface=$NODE01_NIC
$NODE02_NAME ansible_host=$NODE02_IP network_interface=$NODE02_NIC
$NODE03_NAME ansible_host=$NODE03_IP network_interface=$NODE03_NIC

[storage]
$NODE02_NAME ansible_host=$NODE02_IP network_interface=$NODE02_NIC

[monitoring]
$NODE01_NAME ansible_host=$NODE01_IP network_interface=$NODE01_NIC

[deployment]
localhost ansible_connection=local

EOF

# Anexa TODOS los mapeos :children estándar (loadbalancer, mariadb, nova, ...)
SRC_INV="/opt/kolla-ansible/share/kolla-ansible/ansible/inventory/multinode"
if [[ -f "$SRC_INV" ]]; then
  awk '/^\[baremetal:children\]/,0' "$SRC_INV" | sudo tee -a "$INV" >/dev/null
else
  echo "⚠ No se encontró $SRC_INV; los mapeos :children no se añadieron."
fi

# Variables de conexión
sudo tee -a "$INV" >/dev/null <<EOF

[all:vars]
ansible_user=$SSH_USER
ansible_become=true
ansible_private_key_file=$SSH_KEY
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes'
EOF
echo "Inventario escrito."

log "Generando globals.yml (esqueleto): $GLOBALS"
sudo tee "$GLOBALS" >/dev/null <<EOF
# globals.yml — generado por 07-kolla-config.sh
kolla_base_distro: "ubuntu"
kolla_install_type: "binary"
openstack_release: "2025.2"

# VIP interna (HAProxy) — IP libre de la red de management
kolla_internal_vip_address: "$KOLLA_VIP"

# network_interface se define POR HOST en el inventario (NICs distintas).
# TODO (decisión de red): definir storage_interface / tunnel_interface /
# neutron_external_interface cuando se decidan las VLANs (mgmt/storage/tunnel/external).
EOF
echo "globals.yml escrito."

log "Generando passwords (kolla-genpwd)"
if [[ -f "$KOLLA_VENV/bin/kolla-genpwd" ]]; then
  "$KOLLA_VENV/bin/kolla-genpwd" 2>/dev/null || echo "⚠ kolla-genpwd no se ejecutó"
else
  echo "⚠ kolla-genpwd no encontrado en $KOLLA_VENV/bin"
fi

log "Ajustando propietario de /etc/kolla a $SSH_USER"
sudo chown -R "$SSH_USER:$SSH_USER" /etc/kolla

log "Contenido de /etc/kolla:"
ls -la "$KOLLA_DIR" 2>/dev/null
