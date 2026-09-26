#!/usr/bin/env bash
# =============================================================================
# 01-base.sh — Paquetes base + chrony (NTP) en los 3 nodos
# -----------------------------------------------------------------------------
#  Requiere: 00-bootstrap.sh (sudo NOPASSWD).
#  Idempotente: re-ejecutable.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes"
LOCAL_IP="$(hostname -I | awk '{print $1}')"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }
is_local() { [[ "$1" == "$LOCAL_IP" || "$1" == "localhost" || "$1" == "127.0.0.1" ]]; }

# Bloque que se ejecuta en cada nodo (por stdin), ya con sudo.
run_node() {
  local ip="$1"
  local block; block="$(cat)"
  if is_local "$ip"; then
    echo "----- [LOCAL] $ip -----"
    printf '%s' "$block" | sudo -n bash -s
  else
    echo "----- [SSH] $ip -----"
    printf '%s' "$block" | ssh $SSH_OPTS "$SSH_USER@$ip" 'sudo -n bash -s'
  fi
}

# ---- NODE-01: anfitrion (192.168.0.10) ------------------------------------
log "Instalando paquetes base en anfitrion ($NODE01_IP)"
run_node "$NODE01_IP" <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl wget git vim htop net-tools ca-certificates gnupg lsb-release software-properties-common chrony python3 python3-pip python3-venv jq unzip bash-completion
systemctl enable --now chrony || systemctl enable --now chronyd 2>/dev/null || true
echo "base OK en $(hostname)"
EOF

# ---- NODE-02: asus-tuf (192.168.0.126) ------------------------------------
log "Instalando paquetes base en asus-tuf ($NODE02_IP)"
run_node "$NODE02_IP" <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl wget git vim htop net-tools ca-certificates gnupg lsb-release software-properties-common chrony python3 python3-pip python3-venv jq unzip bash-completion
systemctl enable --now chrony || systemctl enable --now chronyd 2>/dev/null || true
echo "base OK en $(hostname)"
EOF

# ---- NODE-03: server (192.168.0.100) --------------------------------------
log "Instalando paquetes base en server ($NODE03_IP)"
run_node "$NODE03_IP" <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl wget git vim htop net-tools ca-certificates gnupg lsb-release software-properties-common chrony python3 python3-pip python3-venv jq unzip bash-completion
systemctl enable --now chrony || systemctl enable --now chronyd 2>/dev/null || true
echo "base OK en $(hostname)"
EOF

log "Base completada en todos los nodos"
