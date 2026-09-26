#!/usr/bin/env bash
# =============================================================================
# 04-openstack-cli.sh — python-openstackclient en el venv de Kolla (control)
# -----------------------------------------------------------------------------
#  Requiere: 03-kolla-ansible.sh. Idempotente.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

log "Instalando python-openstackclient en el control ($CONTROL_NODE)"

block=$(cat <<'EOF'
set -e
/opt/kolla-ansible/bin/pip install -q python-openstackclient python-glanceclient python-neutronclient python-novaclient python-cinderclient
echo "openstack CLI: $(/opt/kolla-ansible/bin/openstack --version 2>/dev/null || echo 'pendiente')"
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

log "openstackclient completado"
