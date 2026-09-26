#!/usr/bin/env bash
# =============================================================================
# 10-verificar.sh — Verificación integral de la instalación (solo lectura)
# -----------------------------------------------------------------------------
#  Comprueba el estado de los 3 nodos, Docker, Kubernetes (k3s), Kolla-Ansible,
#  OpenStack, GPU y red. No modifica nada. Genera un informe PASS/FAIL/WARN.
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"
export PATH="$KOLLA_VENV/bin:$PATH"   # openstack CLI / kolla-ansible para los checks

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=6 -o BatchMode=yes"
LOCAL_IP="$(hostname -I | awk '{print $1}')"
PASS=0; FAIL=0; WARN=0

ok()   { echo -e "  \033[32m✅ $1\033[0m"; PASS=$((PASS+1)); }
bad()  { echo -e "  \033[31m❌ $1\033[0m"; FAIL=$((FAIL+1)); }
warn() { echo -e "  \033[33m⚠️  $1\033[0m"; WARN=$((WARN+1)); }
sec()  { echo -e "\n\033[1;34m━━━ $1 ━━━\033[0m"; }

is_local() { [[ "$1" == "$LOCAL_IP" || "$1" == "localhost" || "$1" == "127.0.0.1" ]]; }

# Ejecuta un comando en un nodo (local o remoto) y devuelve stdout
run() {
  local ip="$1"; shift
  if is_local "$ip"; then bash -c "$*" 2>&1; else ssh $SSH_OPTS "$SSH_USER@$ip" "$*" 2>&1; fi
}

echo "========================================================================"
echo "  INFORME DE VERIFICACIÓN — openstack-virtual-tryon"
echo "  Fecha: $(date '+%Y-%m-%d %H:%M:%S') · Control: $(hostname) ($LOCAL_IP)"
echo "========================================================================"

# ---- 1. NODOS ----------------------------------------------------------------
sec "1. NODOS (conectividad, SO, sudo)"
for pair in "$NODE01_IP:$NODE01_NAME" "$NODE02_IP:$NODE02_NAME" "$NODE03_IP:$NODE03_NAME"; do
  ip="${pair%%:*}"; name="${pair##*:}"
  if ping -c1 -W2 "$ip" >/dev/null 2>&1; then
    ver=$(run "$ip" "grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '\"'")
    if run "$ip" "sudo -n true" >/dev/null 2>&1; then
      ok "$name ($ip) — Ubuntu $ver — sudo NOPASSWD OK"
    else
      warn "$name ($ip) — Ubuntu $ver — sudo NOPASSWD FALLA"
    fi
  else
    bad "$name ($ip) — no responde a ping"
  fi
done

# ---- 2. DOCKER / CONTAINERD --------------------------------------------------
sec "2. DOCKER + CONTAINERD"
for pair in "$NODE01_IP:$NODE01_NAME" "$NODE02_IP:$NODE02_NAME" "$NODE03_IP:$NODE03_NAME"; do
  ip="${pair%%:*}"; name="${pair##*:}"
  dv=$(run "$ip" "docker --version 2>/dev/null")
  ds=$(run "$ip" "systemctl is-active docker 2>/dev/null")
  if [[ "$dv" == Docker* ]] && [[ "$ds" == "active" ]]; then
    ok "$name — $dv (servicio active)"
  else
    bad "$name — docker: '${dv:-sin version}' servicio: '${ds:-inactive}'"
  fi
done

# ---- 3. KUBERNETES (k3s) -----------------------------------------------------
sec "3. KUBERNETES (k3s) + HERRAMIENTAS"
kubectl version --client >/dev/null 2>&1 && ok "kubectl: $(kubectl version --client 2>/dev/null | grep -o 'v[0-9.]*' | head -1)" || bad "kubectl no disponible"
helm version --short >/dev/null 2>&1 && ok "helm: $(helm version --short 2>/dev/null)" || bad "helm no disponible"

echo "  --- Nodos del clúster ---"
kubectl get nodes -o wide 2>/dev/null | sed 's/^/  /'
READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready')
NOTREADY=$(kubectl get nodes --no-headers 2>/dev/null | grep -cv ' Ready' || true)
[[ "$READY" -gt 0 ]] && ok "nodos Ready: $READY" || warn "sin nodos Ready (k3s no desplegado — opcional)"
[[ "$NOTREADY" -gt 0 ]] && warn "nodos NotReady: $NOTREADY (revisar)"

echo "  --- Dashboard Kubernetes ---"
DPOD=$(kubectl -n kubernetes-dashboard get pods 2>/dev/null | grep -c Running)
if [[ "$DPOD" -ge 1 ]]; then
  NP=$(kubectl -n kubernetes-dashboard get svc kubernetes-dashboard -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
  ok "Dashboard: $DPOD pod(s) Running — URL https://$LOCAL_IP:${NP:-30443}"
else
  warn "Dashboard no desplegado (k3s no desplegado — opcional)"
fi

# ---- 4. KOLLA-ANSIBLE + OPENSTACK --------------------------------------------
sec "4. KOLLA-ANSIBLE + OPENSTACK"
if [[ -x "$KOLLA_VENV/bin/kolla-ansible" ]]; then
  ok "kolla-ansible: $($KOLLA_VENV/bin/kolla-ansible --version 2>/dev/null | head -1)"
else
  bad "kolla-ansible no encontrado en $KOLLA_VENV/bin"
fi
[[ -x "$KOLLA_VENV/bin/openstack" ]] && ok "openstack CLI: $($KOLLA_VENV/bin/openstack --version 2>/dev/null)" || warn "openstack CLI no instalado"

echo "  --- Configuración /etc/kolla ---"
for f in multinode globals.yml passwords.yml; do
  [[ -f "/etc/kolla/$f" ]] && ok "/etc/kolla/$f presente" || bad "falta /etc/kolla/$f"
done

echo "  --- Estado del despliegue OpenStack ---"
OSC=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -cE 'keystone|horizon|nova|neutron|glance|mariadb|rabbitmq|placement|cinder')
if [[ "$OSC" -gt 0 ]]; then
  ok "OpenStack DESPLEGADO ($OSC contenedores activos)"
else
  warn "OpenStack NO desplegado todavía (solo bootstrap+prechecks)"
fi

echo "  --- Cinder (almacenamiento en bloque) ---"
if [[ -f /etc/kolla/admin-openrc.sh ]] && command -v openstack >/dev/null 2>&1; then
  source /etc/kolla/admin-openrc.sh 2>/dev/null
  CVOL=$(openstack volume service list -f value -c State 2>/dev/null | grep -c '^up$')
  [[ "$CVOL" -ge 1 ]] && ok "cinder-volume up ($CVOL servicio(s) up)" || warn "cinder: sin backend up (o no habilitado)"
else
  warn "cinder: openstack CLI / admin-openrc no disponible"
fi

# ---- 5. GPU / NVIDIA ---------------------------------------------------------
sec "5. GPU / NVIDIA (solo $NODE03_NAME)"
if ping -c1 -W2 "$GPU_NODE" >/dev/null 2>&1; then
  gpu=$(run "$GPU_NODE" "nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null")
  [[ -n "$gpu" ]] && ok "GPU: $gpu" || bad "nvidia-smi sin salida (driver?)"
  ctk=$(run "$GPU_NODE" "nvidia-ctk --version 2>/dev/null")
  [[ -n "$ctk" ]] && ok "nvidia-container-toolkit: ${ctk%% *}" || warn "nvidia-container-toolkit no detectado"
else
  bad "nodo GPU ($GPU_NODE) no responde"
fi

# ---- 6. RED / HOSTS / AVAHI --------------------------------------------------
sec "6. RED (resolución única + avahi)"
for name in $NODE01_NAME $NODE02_NAME $NODE03_NAME; do
  ips=$(getent ahostsv4 "$name" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ')
  n=$(echo "$ips" | wc -w)
  if [[ "$n" -eq 1 ]]; then ok "$name -> $ips (única)"; else warn "$name -> [$ips] (múltiples)"; fi
done
for pair in "$NODE01_IP:$NODE01_NAME" "$NODE02_IP:$NODE02_NAME" "$NODE03_IP:$NODE03_NAME"; do
  ip="${pair%%:*}"; name="${pair##*:}"
  av=$(run "$ip" "systemctl is-active avahi-daemon 2>/dev/null")
  [[ "$av" == "inactive" || "$av" == "failed" ]] && ok "$name: avahi desactivado" || warn "$name: avahi ACTIVO (revisar)"
done

# ---- RESUMEN ----------------------------------------------------------------
echo -e "\n\033[1;34m━━━ RESUMEN ━━━\033[0m"
echo -e "  \033[32m✅ OK:   $PASS\033[0m"
echo -e "  \033[33m⚠️  WARN: $WARN\033[0m"
echo -e "  \033[31m❌ FAIL: $FAIL\033[0m"
echo

