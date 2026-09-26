#!/usr/bin/env bash
# deploy-manifests.sh: aplica los manifiestos YAML del laboratorio (kubernetes/tmp/)
# en el orden correcto, con esperas y puntos de control.
#
# Prerrequisitos (ver scripts/bootstrap-cluster.sh):
#   - Cluster kubeadm funcionando (k8-master + workers).
#   - Calico (CNI) y MetalLB instalados.
#   - Operador Rook instalado (namespace rook-ceph, CRDs de Ceph).
#   - Helm instalado y Dashboard de Kubernetes desplegado (chart 7.14.0).
#
# Uso:
#   scripts/deploy-manifests.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$(dirname "$SCRIPT_DIR")/tmp"

export KUBECONFIG="${KUBECONFIG:-/home/uceda/.kube/config}"

# Espera hasta que un recurso alcance la fase indicada (para CRs de Rook).
wait_phase() {
  local kind="$1" name="$2" ns="$3" wanted="$4" tries="${5:-60}"
  echo "Esperando a que $kind/$name este $wanted..."
  for _ in $(seq 1 "$tries"); do
    local phase
    phase="$(kubectl -n "$ns" get "$kind" "$name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "$phase" == "$wanted" ]]; then
      echo "  -> $kind/$name esta $wanted"
      return 0
    fi
    sleep 10
  done
  echo "  -> AVISO: $kind/$name no llego a $wanted en el tiempo esperado" >&2
}

apply() {
  local f="$1"
  echo "==> kubectl apply -f $(basename "$f")"
  kubectl apply -f "$f"
}

echo "=== 1) Namespace y Secrets de WordPress ==="
apply "$MANIFESTS_DIR/01-wordpress-namespace.yaml"
apply "$MANIFESTS_DIR/02-wordpress-secrets.yaml"

echo
echo "=== 2) Rook-Ceph: CephCluster, CephFS y StorageClass ==="
apply "$MANIFESTS_DIR/03-rook-cluster.yaml"
wait_phase cephcluster rook-ceph rook-ceph Ready 90

apply "$MANIFESTS_DIR/04-rook-filesystem.yaml"
apply "$MANIFESTS_DIR/05-cephfs-storageclass.yaml"

echo
echo "=== 3) PVCs y WordPress (Deployment + Service) ==="
apply "$MANIFESTS_DIR/06-wordpress-pvcs.yaml"
kubectl -n wordpress wait --for=jsonpath='{.status.phase}'=Bound \
  pvc/wordpress-content pvc/wordpress-db pvc/wordpress-redis --timeout=300s || true

apply "$MANIFESTS_DIR/07-wordpress-cephfs.yaml"
kubectl -n wordpress rollout status deployment/wordpress --timeout=300s || true

echo
echo "=== 4) MetalLB + WordPress por HTTPS (ingress-nginx + TLS) ==="
apply "$MANIFESTS_DIR/08-metallb-k8s-lab-pool.yaml"

# Certificado autofirmado + Secret TLS (idempotente)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/wordpress-tls.key -out /tmp/wordpress-tls.crt \
  -subj "/CN=192.168.90.50" -addext "subjectAltName=IP:192.168.90.50" >/dev/null 2>&1
kubectl -n wordpress create secret tls wordpress-tls \
  --cert=/tmp/wordpress-tls.crt --key=/tmp/wordpress-tls.key --dry-run=client -o yaml \
  | kubectl apply -f -

apply "$MANIFESTS_DIR/13-wordpress-ingress.yaml"

echo
echo "=== 5) Dashboards y NGINX ==="
apply "$MANIFESTS_DIR/10-rook-ceph-mgr-dashboard-external.yaml"
apply "$MANIFESTS_DIR/12-nginx-app.yaml"

echo
echo "=== 6) Dashboard de Kubernetes: RBAC + NodePort 32000 ==="
apply "$MANIFESTS_DIR/11-kubernetes-dashboard-rbac.yaml"
kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard-kong-proxy \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"kong-proxy-tls","port":443,"protocol":"TCP","targetPort":8443,"nodePort":32000}]}}'

echo
echo "=== Resumen del despliegue ==="
kubectl get nodes -o wide
kubectl -n wordpress get pods,svc,pvc
kubectl -n rook-ceph get cephcluster cephfilesystem
kubectl -n metallb-system get ipaddresspool,l2advertisement
