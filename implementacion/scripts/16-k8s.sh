#!/usr/bin/env bash
# =============================================================================
# 16-k8s.sh — Re-instala Kubernetes (k3s) + Dashboard Kubernetes
# -----------------------------------------------------------------------------
#  Levanta un clúster k3s (server en anfitrion, agents en asus-tuf y server),
#  copia el kubeconfig y despliega el Dashboard en NodePort 30443.
#  Así icc115.kubernetes.com:30443 vuelve a funcionar.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes"
log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

# ---- 1. Instalar k3s SERVER en anfitrion (192.168.0.10) ---------------------
log "1. Instalando k3s server en anfitrion ($NODE01_IP)"
if systemctl is-active k3s >/dev/null 2>&1; then
  echo "  k3s ya está activo"
else
  curl -sfL https://get.k3s.io | sh - 2>&1 | tail -5
fi

# Esperar a que el server esté listo
sleep 10
systemctl is-active k3s >/dev/null 2>&1 && echo "  k3s server activo" || { echo "  ❌ k3s no arrancó"; exit 1; }

# ---- 2. Obtener el token de nodo --------------------------------------------
log "2. Obteniendo token de nodo"
NODE_TOKEN=$(sudo -n cat /var/lib/rancher/k3s/server/node-token)
echo "  token obtenido (oculto)"

# ---- 3. Instalar k3s AGENT en asus-tuf (192.168.0.126) ----------------------
log "3. Instalando k3s agent en asus-tuf ($NODE02_IP)"
ssh $SSH_OPTS "$SSH_USER@$NODE02_IP" \
  "curl -sfL https://get.k3s.io | K3S_URL=https://$NODE01_IP:6443 K3S_TOKEN=$NODE_TOKEN sh -" 2>&1 | tail -3

# ---- 4. Instalar k3s AGENT en server (192.168.0.100) ------------------------
log "4. Instalando k3s agent en server ($NODE03_IP)"
ssh $SSH_OPTS "$SSH_USER@$NODE03_IP" \
  "curl -sfL https://get.k3s.io | K3S_URL=https://$NODE01_IP:6443 K3S_TOKEN=$NODE_TOKEN sh -" 2>&1 | tail -3

# ---- 5. Copiar kubeconfig al usuario ----------------------------------------
log "5. Copiando kubeconfig a ~/.kube/config"
mkdir -p "$HOME/.kube"
sudo -n cat /etc/rancher/k3s/k3s.yaml > "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
echo "  kubeconfig listo"

# ---- 6. Desplegar Dashboard Kubernetes (NodePort 30443) ---------------------
log "6. Desplegando Dashboard Kubernetes"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml 2>&1 | tail -5
kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard \
  -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8443,"nodePort":30443}]}}' 2>&1

# ---- 7. Crear admin-user + token --------------------------------------------
log "7. Creando admin-user y generando token"
kubectl apply -f - <<'EOF' 2>&1
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# ---- 8. Verificación --------------------------------------------------------
log "8. Verificación"
kubectl get nodes 2>&1
echo
echo "  Dashboard: https://icc115.kubernetes.com:30443"
echo "  Token:"
kubectl -n kubernetes-dashboard create token admin-user 2>&1
