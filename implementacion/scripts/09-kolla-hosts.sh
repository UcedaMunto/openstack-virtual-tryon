#!/usr/bin/env bash
# =============================================================================
# 09-kolla-hosts.sh — /etc/hosts con resolución ÚNICA + desactiva avahi (mDNS)
# -----------------------------------------------------------------------------
#  Kolla exige que cada hostname resuelva a UNA sola IP (api_interface). En
#  máquinas con Docker/k3s + avahi, el hostname resuelve a varias IPs y el
#  precheck de RabbitMQ falla. Este script lo corrige.
#  Idempotente.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes"
LOCAL_IP="$(hostname -I | awk '{print $1}')"
log() { echo -e "\n\033[1;34m===> $1\033[0m"; }
is_local() { [[ "$1" == "$LOCAL_IP" || "$1" == "localhost" || "$1" == "127.0.0.1" ]]; }

# Bloque a ejecutar en cada nodo (las variables $NODE0x_* se expanden aquí)
write_block() {
cat <<EOF
set -e
sudo -n cp -n /etc/hosts /etc/hosts.bak.kolla 2>/dev/null || true
sudo -n sed -i '/^127\\.0\\.1\\.1 /d' /etc/hosts
grep -qE '^$NODE01_IP[[:space:]]+$NODE01_NAME' /etc/hosts || echo '$NODE01_IP $NODE01_NAME' | sudo -n tee -a /etc/hosts >/dev/null
grep -qE '^$NODE02_IP[[:space:]]+$NODE02_NAME' /etc/hosts || echo '$NODE02_IP $NODE02_NAME' | sudo -n tee -a /etc/hosts >/dev/null
grep -qE '^$NODE03_IP[[:space:]]+$NODE03_NAME' /etc/hosts || echo '$NODE03_IP $NODE03_NAME' | sudo -n tee -a /etc/hosts >/dev/null
sudo -n systemctl disable --now avahi-daemon.socket avahi-daemon 2>/dev/null || true
sudo -n systemctl mask avahi-daemon.socket avahi-daemon 2>/dev/null || true
echo "hosts OK en \$(hostname)"
EOF
}

for ip in $ALL_NODES; do
  log "Corrigiendo /etc/hosts + avahi en $ip"
  if is_local "$ip"; then
    write_block | bash -s
  else
    write_block | ssh $SSH_OPTS "$SSH_USER@$ip" 'bash -s'
  fi
done

log "Verificación de resolución única:"
for h in $NODE01_NAME $NODE02_NAME $NODE03_NAME; do
  echo -n "  $h -> "
  getent ahostsv4 "$h" 2>/dev/null | awk 'NR==1{print $1}'
done
