#!/usr/bin/env bash
# =============================================================================
# 03-kolla-ansible.sh — Instala Kolla-Ansible (venv) SOLO en el nodo de control
# -----------------------------------------------------------------------------
#  Requiere: 00-bootstrap.sh + 02-docker.sh. Idempotente.
#  Crea el venv /opt/kolla-ansible y copia los ejemplos de configuración a
#  /etc/kolla (globals.yml, passwords.yml, inventario multinode).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

log "Instalando Kolla-Ansible en el nodo de control ($CONTROL_NODE)"

# Ejecuta en el control (puede ser local o remoto).
block=$(cat <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get install -y python3-venv python3-dev libffi-dev gcc libssl-dev

if [[ ! -d /opt/kolla-ansible ]]; then
  python3 -m venv /opt/kolla-ansible
fi
/opt/kolla-ansible/bin/pip install -q --upgrade pip
/opt/kolla-ansible/bin/pip install -q 'ansible-core>=2.16,<2.19' kolla-ansible

mkdir -p /etc/kolla
cp -r /opt/kolla-ansible/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/ 2>/dev/null || true
cp /opt/kolla-ansible/share/kolla-ansible/ansible/inventory/* /etc/kolla/ 2>/dev/null || true
chown -R "$SUDO_USER:$SUDO_USER" /etc/kolla 2>/dev/null || true

echo "Kolla-Ansible instalado: $(/opt/kolla-ansible/bin/kolla-ansible --version 2>/dev/null || echo 'kolla-ansible')"
echo "ansible-core: $(/opt/kolla-ansible/bin/ansible --version | head -1)"
EOF
)

LOCAL_IP="$(hostname -I | awk '{print $1}')"
if [[ "$CONTROL_NODE" == "$LOCAL_IP" || "$CONTROL_NODE" == "localhost" || "$CONTROL_NODE" == "127.0.0.1" ]]; then
  echo "----- [LOCAL] $CONTROL_NODE -----"
  printf '%s' "$block" | sudo -n bash -s
else
  echo "----- [SSH] $CONTROL_NODE -----"
  printf '%s' "$block" | ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER@$CONTROL_NODE" 'sudo -n bash -s'
fi

log "Kolla-Ansible completado (control)"
