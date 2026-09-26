#!/usr/bin/env bash
# =============================================================================
# 06-nvidia-runtime.sh — nvidia-container-toolkit SOLO en el nodo GPU
# -----------------------------------------------------------------------------
#  Requiere: 00-bootstrap.sh + 02-docker.sh. Idempotente.
#  Habilita el runtime NVIDIA en containerd para que Kubernetes pueda exponer
#  la GPU (nvidia.com/gpu) al worker de FASHN-VTON.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

log "Instalando nvidia-container-toolkit en el nodo GPU ($GPU_NODE)"

block=$(cat <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive

# Verificar driver NVIDIA
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "⚠ nvidia-smi no encontrado; instalar driver NVIDIA primero."
  exit 1
fi

if ! command -v nvidia-ctk >/dev/null 2>&1; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' > /etc/apt/sources.list.d/nvidia-container-toolkit.list
  apt-get update -y
  apt-get install -y nvidia-container-toolkit
fi

# Configurar el runtime por defecto de containerd (sistema) para usar nvidia
nvidia-ctk runtime configure --runtime=containerd || true
systemctl restart containerd 2>/dev/null || true

echo "nvidia-ctk: $(nvidia-ctk --version 2>/dev/null || echo 'ok')"
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo '?')"
EOF
)

LOCAL_IP="$(hostname -I | awk '{print $1}')"
if [[ "$GPU_NODE" == "$LOCAL_IP" || "$GPU_NODE" == "localhost" || "$GPU_NODE" == "127.0.0.1" ]]; then
  echo "----- [LOCAL] $GPU_NODE -----"
  printf '%s' "$block" | sudo -n bash -s
else
  echo "----- [SSH] $GPU_NODE -----"
  printf '%s' "$block" | ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER@$GPU_NODE" 'sudo -n bash -s'
fi

log "nvidia-runtime completado"
