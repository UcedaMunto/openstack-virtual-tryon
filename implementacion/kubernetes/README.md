# kubernetes/ — Manifiestos de Kubernetes (futuro)

Aquí irán los manifiestos YAML de las aplicaciones gestionadas por
**Argo CD / GitOps** (según ARQUITECTURA §61-62), una vez que el clúster
Kubernetes esté dentro de las VMs de OpenStack.

Por ahora, el clúster k3s (bare metal) y su Dashboard se despliegan con:
- `ansible/playbooks/16_k8s_cluster.yml`
- `scripts/16b-k8s-dashboard-ingress.yaml` (IngressRouteTCP del Dashboard)
