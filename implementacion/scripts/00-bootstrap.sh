#!/usr/bin/env bash
# =============================================================================
# 00-bootstrap.sh — Verifica Ubuntu 24.04 + habilita sudo NOPASSWD + SSH
# -----------------------------------------------------------------------------
#  Es el primer script de la secuencia. Deja los nodos listos para que el resto
#  de scripts corran con `sudo -n` (sin pedir contraseña).
#  Idempotente: re-ejecutable.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes"
LOCAL_IP="$(hostname -I | awk '{print $1}')"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

is_local() { [[ "$1" == "$LOCAL_IP" || "$1" == "localhost" || "$1" == "127.0.0.1" ]]; }

log "Verificando sistema operativo (debe ser Ubuntu 24.04)"
for ip in $ALL_NODES; do
  if is_local "$ip"; then
    ver=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    name=$(hostname)
  else
    ver=$(ssh $SSH_OPTS "$SSH_USER@$ip" "grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '\"'")
    name=$(ssh $SSH_OPTS "$SSH_USER@$ip" "hostname")
  fi
  echo "  $ip  ->  $name  (Ubuntu $ver)"
  [[ "$ver" == "24.04"* ]] || { echo "  ⚠ $ip no es 24.04 ($ver)"; }
done

log "Habilitando sudo NOPASSWD para $SSH_USER"
for ip in $ALL_NODES; do
  echo "----- $ip -----"
  # El heredoc envía: línea 1 = contraseña (sudo -S), resto = script (bash -s)
  if is_local "$ip"; then
    sudo -S -p '' bash -s <<EOF
$SUDO_PASSWORD
printf '%s\n' '$SSH_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$SSH_USER-nopasswd
chmod 440 /etc/sudoers.d/$SSH_USER-nopasswd
EOF
  else
    ssh $SSH_OPTS "$SSH_USER@$ip" "sudo -S -p '' bash -s" <<EOF
$SUDO_PASSWORD
printf '%s\n' '$SSH_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$SSH_USER-nopasswd
chmod 440 /etc/sudoers.d/$SSH_USER-nopasswd
EOF
  fi
done

log "Verificando sudo sin contraseña"
for ip in $ALL_NODES; do
  if is_local "$ip"; then
    sudo -n true && echo "  $ip: sudo NOPASSWD OK" || echo "  $ip: sudo FALLÓ"
  else
    ssh $SSH_OPTS "$SSH_USER@$ip" "sudo -n true" && echo "  $ip: sudo NOPASSWD OK" || echo "  $ip: sudo FALLÓ"
  fi
done

log "Bootstrap completado"
