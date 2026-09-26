#!/usr/bin/env bash
# =============================================================================
# bootstrap-cluster.sh — prepara los nodos e instala el clúster Kubernetes del
# laboratorio (containerd + kubelet/kubeadm/kubectl + Calico + MetalLB +
# operador Rook + Helm + Dashboard de Kubernetes).
#
# Diseñado para reproducir el despliegue en un equipo externo desde cero.
#
# Ejecutar en k8-master (192.168.90.1). Requiere SSH sin contraseña hacia los
# workers (lo deja listo el cloud-init con la clave pública).
#
# Uso:
#   scripts/bootstrap-cluster.sh [etapa ...]
#   (sin argumentos ejecuta todas las etapas en orden)
#
# Etapas:
#   prereq       swap off + módulos kernel + sysctl (todos los nodos)
#   runtime      containerd con SystemdCgroup (todos los nodos)
#   packages     kubelet/kubeadm/kubectl v1.36 (todos los nodos)
#   init         kubeadm init + kubeconfig + Calico (master)
#   join         kubeadm join (workers)
#   metallb      MetalLB (master)
#   rook         operador Rook (master)
#   dashboard    Helm + Dashboard de Kubernetes (master)
# =============================================================================
set -euo pipefail

# --- Versiones y topología (ajustar al reproducir en otro entorno) ---
CALICO_VERSION="v3.32.1"
METALLB_VERSION="v0.16.1"
ROOK_VERSION="v1.20.6"
POD_CIDR="172.16.0.0/16"
WORKERS=(192.168.90.2 192.168.90.3 192.168.90.4 192.168.90.5)
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

STAGES=("${@:-prereq runtime packages init join metallb ingress rook dashboard}")

want() {
  local s
  for s in "${STAGES[@]}"; do
    [[ "$s" == "$1" ]] && return 0
  done
  return 1
}

# run_on_nodes: ejecuta el bloque bash recibido por stdin en master + workers.
run_on_nodes() {
  local script
  script="$(cat)"
  echo "===== k8-master (local) ====="
  printf '%s' "$script" | bash -s
  local ip
  for ip in "${WORKERS[@]}"; do
    echo "===== $ip ====="
    printf '%s' "$script" | ssh "${SSH_OPTS[@]}" "uceda@$ip" 'bash -s'
  done
}

# =============================================================================
if want prereq; then
  echo "===> ETAPA prereq (swap + módulos kernel + sysctl)"
  run_on_nodes <<'EOF'
set -e
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab || true
sudo modprobe overlay
sudo modprobe br_netfilter
printf '%s\n' overlay br_netfilter | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
printf '%s\n' \
  'net.bridge.bridge-nf-call-iptables  = 1' \
  'net.bridge.bridge-nf-call-ip6tables = 1' \
  'net.ipv4.ip_forward                 = 1' \
  | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
sudo sysctl --system >/dev/null
echo "prereq OK en $(hostname)"
EOF
fi

# =============================================================================
if want runtime; then
  echo "===> ETAPA runtime (containerd con SystemdCgroup)"
  run_on_nodes <<'EOF'
set -e
sudo apt-get update -y
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "containerd OK: $(containerd --version)"
EOF
fi

# =============================================================================
if want packages; then
  echo "===> ETAPA packages (kubelet/kubeadm/kubectl v1.36)"
  run_on_nodes <<'EOF'
set -e
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet
echo "k8s OK: $(kubeadm version -o short)"
EOF
fi

# =============================================================================
if want init; then
  echo "===> ETAPA init (kubeadm init + kubeconfig + Calico)"
  if kubectl cluster-info >/dev/null 2>&1; then
    echo "El cluster ya responde; se omite kubeadm init."
  else
    sudo kubeadm init \
      --control-plane-endpoint=k8-master \
      --pod-network-cidr="$POD_CIDR"
  fi

  mkdir -p "$HOME/.kube"
  sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
  sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
  chmod 600 "$HOME/.kube/config"
  export KUBECONFIG="$HOME/.kube/config"

  echo "-- Calico (tigera-operator + custom-resources)"
  kubectl apply --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
  curl -fL -o /tmp/custom-resources.yaml \
    "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"
  sed -i 's#cidr: 192\.168\.0\.0/16#cidr: 172.16.0.0/16#g' /tmp/custom-resources.yaml
  kubectl apply --server-side --force-conflicts -f /tmp/custom-resources.yaml
  kubectl wait --for=condition=Available deployment/tigera-operator \
    -n tigera-operator --timeout=180s || true
fi

# =============================================================================
if want join; then
  echo "===> ETAPA join (workers)"
  JOIN_CMD="$(sudo kubeadm token create --print-join-command)"
  echo "join command: $JOIN_CMD"
  local ip
  for ip in "${WORKERS[@]}"; do
    echo "===== $ip ====="
    ssh "${SSH_OPTS[@]}" "uceda@$ip" "sudo $JOIN_CMD"
  done
fi

# =============================================================================
if want metallb; then
  echo "===> ETAPA metallb (controlador; el pool se aplica en deploy-manifests.sh)"
  kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
  kubectl wait --for=condition=available deployment/controller \
    -n metallb-system --timeout=180s || true
fi

# =============================================================================
if want ingress; then
  echo "===> ETAPA ingress (ingress-nginx via Helm, LoadBalancer)"
  if ! command -v helm >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
  helm repo update
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --create-namespace --namespace ingress-nginx \
    --set controller.service.type=LoadBalancer
  echo "El Ingress + TLS de WordPress se aplica en scripts/deploy-manifests.sh"
fi

# =============================================================================
if want rook; then
  echo "===> ETAPA rook (operador Rook-Ceph)"
  BASE_URL="https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples"
  kubectl create -f "${BASE_URL}/crds.yaml" \
    -f "${BASE_URL}/common.yaml" \
    -f "${BASE_URL}/csi-operator.yaml"
  kubectl create -f "${BASE_URL}/operator.yaml"
  kubectl -n rook-ceph rollout status deployment/rook-ceph-operator --timeout=180s || true
  # Toolbox opcional (diagnostico de Ceph)
  kubectl create -f "${BASE_URL}/toolbox.yaml" || true
fi

# =============================================================================
if want dashboard; then
  echo "===> ETAPA dashboard (Helm + Dashboard de Kubernetes 7.14.0)"
  if ! command -v helm >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi
  curl -fsSL -o /tmp/kubernetes-dashboard-7.14.0.tgz \
    https://github.com/kubernetes/dashboard/releases/download/kubernetes-dashboard-7.14.0/kubernetes-dashboard-7.14.0.tgz
  helm upgrade --install kubernetes-dashboard \
    /tmp/kubernetes-dashboard-7.14.0.tgz \
    --create-namespace \
    --namespace kubernetes-dashboard
  echo "El RBAC (admin-user) y el NodePort 32000 se aplican en scripts/deploy-manifests.sh"
fi

echo
echo "=== bootstrap terminado. Continua con: scripts/deploy-manifests.sh ==="

