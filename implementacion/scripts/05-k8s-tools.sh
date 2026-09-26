#!/usr/bin/env bash
# =============================================================================
# 05-k8s-tools.sh — kubectl + helm en los 3 nodos (control + computes)
# -----------------------------------------------------------------------------
#  Requiere: 00-bootstrap.sh. Idempotente.
#  NOTA: el clúster k3s ya existe; aquí solo se instalan las HERRAMIENTAS de
#  cliente (kubectl/helm) para poder operarlo desde cualquier nodo.
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

for ip in $ALL_NODES; do
  log "Instalando kubectl + helm en $ip"
  run_node "$ip" <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive

# kubectl vía repositorio oficial de Kubernetes
if ! command -v kubectl >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
  apt-get update -y
  apt-get install -y kubectl
fi

# helm
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "kubectl: $(kubectl version --client 2>/dev/null | head -1 || echo 'ok')"
echo "helm: $(helm version --short 2>/dev/null || echo 'ok')"
EOF
done

log "k8s-tools completado"
