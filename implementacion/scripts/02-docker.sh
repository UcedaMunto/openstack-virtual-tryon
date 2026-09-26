#!/usr/bin/env bash
# =============================================================================
# 02-docker.sh — Docker CE + Compose + containerd en los 3 nodos
# -----------------------------------------------------------------------------
#  Requiere: 00-bootstrap.sh. Idempotente.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes"
LOCAL_IP="$(hostname -I | awk '{print $1}')"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }
is_local() { [[ "$1" == "$LOCAL_IP" || "$1" == "localhost" || "$1" == "127.0.0.1" ]]; }

run_node() {
  local ip="$1"; local block; block="$(cat)"
  if is_local "$ip"; then
    echo "----- [LOCAL] $ip -----"; printf '%s' "$block" | sudo -n bash -s
  else
    echo "----- [SSH] $ip -----"; printf '%s' "$block" | ssh $SSH_OPTS "$SSH_USER@$ip" 'sudo -n bash -s'
  fi
}

# ---- NODE-01: anfitrion (192.168.0.10) ------------------------------------
log "Instalando Docker CE en anfitrion ($NODE01_IP)"
run_node "$NODE01_IP" <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
if command -v docker >/dev/null 2>&1; then
  echo "Docker ya instalado: $(docker --version)"; exit 0
fi
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker "$(id -un 1000 2>/dev/null || echo "$SUDO_USER")" || true
echo "Docker instalado: $(docker --version)"
EOF

# ---- NODE-02: asus-tuf (192.168.0.126) ------------------------------------
log "Instalando Docker CE en asus-tuf ($NODE02_IP)"
run_node "$NODE02_IP" <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
if command -v docker >/dev/null 2>&1; then
  echo "Docker ya instalado: $(docker --version)"; exit 0
fi
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker "$(id -un 1000 2>/dev/null || echo "$SUDO_USER")" || true
echo "Docker instalado: $(docker --version)"
EOF

# ---- NODE-03: server (192.168.0.100) --------------------------------------
log "Instalando Docker CE en server ($NODE03_IP)"
run_node "$NODE03_IP" <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
if command -v docker >/dev/null 2>&1; then
  echo "Docker ya instalado: $(docker --version)"; exit 0
fi
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker "$(id -un 1000 2>/dev/null || echo "$SUDO_USER")" || true
echo "Docker instalado: $(docker --version)"
EOF

log "Docker completado"
