#!/usr/bin/env bash
set -euo pipefail

# Monitorizacion del cluster: VM monitor + Prometheus + Grafana + node_exporter.
#
# Uso:
#   bash configuraciones-grafana.sh 1   # Precheck: valida entorno y redes KVM
#   bash configuraciones-grafana.sh 2   # Crear VM monitor (4 NICs, 4GB RAM, 30GB)
#   bash configuraciones-grafana.sh 3   # Instalar Prometheus + Grafana en monitor
#   bash configuraciones-grafana.sh 4   # Instalar node_exporter en todos los servers
#   bash configuraciones-grafana.sh 5   # Configurar Prometheus scrape targets
#   bash configuraciones-grafana.sh 6   # Configurar Grafana datasource + dashboard
#   bash configuraciones-grafana.sh 7   # Validar monitoreo
#   bash configuraciones-grafana.sh all # Flujo completo (bloques 1..7)
#
# Variables de entorno configurables:
#   KEY_OVERRIDE           Ruta alternativa a la llave SSH privada
#   MONITOR_VM             Nombre de la VM (default: monitor)
#   MONITOR_IP             IP en red-principal (default: 192.168.10.30)
#   GRAFANA_ADMIN_PASSWORD Password de admin Grafana (default: GrafanaAdmin2620!)

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREATE_VM_SCRIPT="$BASE_DIR/create-kvm-vm.sh"
KEY="${KEY_OVERRIDE:-$BASE_DIR/ssh-keys/id_rsa}"
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8}"

VM_USER="${VM_USER:-userinfrakv}"
VM_PASSWORD="${VM_PASSWORD:-passphrase2620-07}"
WAIT_SSH_RETRIES="${WAIT_SSH_RETRIES:-80}"
WAIT_SSH_SLEEP="${WAIT_SSH_SLEEP:-5}"

# ── VM Monitor ────────────────────────────────────────────────────────────────
# La VM monitor tiene 4 NICs, una por cada red donde viven los servidores.
# enp1s0 → red-principal  (192.168.10.30) — primaria con NAT/internet
# enp2s0 → red-backend    (192.168.20.30) — para App servers WinterCMS
# enp3s0 → red-db-redis   (192.168.30.33) — para Redis/MariaDB/MaxScale
# enp4s0 → red-ceph-cluster (192.168.60.30) — para Ceph node
MONITOR_VM="${MONITOR_VM:-monitor}"
MONITOR_IP="${MONITOR_IP:-192.168.10.30}"
MONITOR_IP_BACKEND="${MONITOR_IP_BACKEND:-192.168.20.30}"
MONITOR_IP_DB="${MONITOR_IP_DB:-192.168.30.33}"
MONITOR_IP_CEPH="${MONITOR_IP_CEPH:-192.168.60.30}"

GRAFANA_PORT="${GRAFANA_PORT:-3000}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-GrafanaAdmin2620!}"

# ── Nodos objetivo agrupados por red ─────────────────────────────────────────
# Formato: "ip:nombre"
NODES_PRINCIPAL=(
  "192.168.10.10:dns-principal"
  "192.168.10.11:dns-delegado"
  "192.168.10.20:lb1"
  "192.168.10.21:lb2"
)

NODES_BACKEND=(
  "192.168.20.10:appWinter1"
  "192.168.20.11:appWinter2"
  "192.168.20.12:appWinter3"
)

NODES_DB=(
  "192.168.30.10:redis-1"
  "192.168.30.11:redis-2"
  "192.168.30.12:redis-3"
  "192.168.30.13:redis-4"
  "192.168.30.14:redis-5"
  "192.168.30.15:redis-6"
  "192.168.30.16:redis-7"
  "192.168.30.20:maxscale-1"
  "192.168.30.21:mariadb-1"
  "192.168.30.22:mariadb-2"
  "192.168.30.23:mariadb-3"
)

NODES_CEPH=(
  "192.168.60.11:ceph1"
)

EXTRA_HOSTS="192.168.10.10 ns1.mimas.net dns-principal;192.168.10.11 ns1.ti.mimas.net dns-delegado;192.168.10.20 lb1.ti.mimas.net lb1;192.168.10.21 lb2.ti.mimas.net lb2;192.168.20.10 app1.ti.mimas.net appWinter1;192.168.20.11 app2.ti.mimas.net appWinter2;192.168.20.12 app3.ti.mimas.net appWinter3;192.168.30.20 db.ti.mimas.net maxscale-1;192.168.30.10 redis1.ti.mimas.net redis-1;192.168.30.11 redis2.ti.mimas.net redis-2;192.168.30.12 redis3.ti.mimas.net redis-3;192.168.30.13 redis4.ti.mimas.net redis-4;192.168.30.14 redis5.ti.mimas.net redis-5;192.168.30.15 redis6.ti.mimas.net redis-6;192.168.30.16 redis7.ti.mimas.net redis-7;192.168.30.21 db1.ti.mimas.net mariadb-1;192.168.30.22 db2.ti.mimas.net mariadb-2;192.168.30.23 db3.ti.mimas.net mariadb-3;192.168.60.11 ceph1.ti.mimas.net ceph1;192.168.10.30 monitor.mimas.net monitor"

# ── Funciones comunes ─────────────────────────────────────────────────────────
ssh_cmd() {
  local ip="$1"
  shift
  ssh -i "$KEY" $SSH_OPTS "${VM_USER}@${ip}" "$@"
}

wait_for_ssh_node() {
  local ip="$1"
  local attempt=1
  while (( attempt <= WAIT_SSH_RETRIES )); do
    if ssh -i "$KEY" $SSH_OPTS "${VM_USER}@${ip}" "echo ready" >/dev/null 2>&1; then
      echo "[OK] SSH listo en $ip"
      return 0
    fi
    echo "[INFO] Esperando SSH en $ip (intento ${attempt}/${WAIT_SSH_RETRIES})..."
    sleep "$WAIT_SSH_SLEEP"
    attempt=$(( attempt + 1 ))
  done
  echo "[ERROR] SSH no estuvo listo en $ip tras ${WAIT_SSH_RETRIES} intentos"
  return 1
}

node_is_reachable() {
  local ip="$1"
  ssh -i "$KEY" $SSH_OPTS "${VM_USER}@${ip}" "echo ready" >/dev/null 2>&1
}

# ── BLOQUE 1: Precheck ────────────────────────────────────────────────────────
block_1_precheck() {
  echo
  echo "=================================================================="
  echo "[BLOQUE 1] Precheck de entorno"
  echo "=================================================================="

  if [[ ! -x "$CREATE_VM_SCRIPT" ]]; then
    echo "[ERROR] No se encontro script ejecutable: $CREATE_VM_SCRIPT"
    exit 1
  fi
  echo "[OK] create-kvm-vm.sh encontrado"

  if [[ ! -r "$KEY" ]]; then
    echo "[ERROR] No se puede leer la clave SSH: $KEY"
    echo "[INFO] Define KEY_OVERRIDE con una ruta valida y vuelve a ejecutar."
    exit 1
  fi
  echo "[OK] Clave SSH: $KEY"

  if ! command -v virsh >/dev/null 2>&1; then
    echo "[ERROR] virsh no esta disponible en el host"
    exit 1
  fi
  echo "[OK] virsh disponible"

  local ok=true
  for net in red-principal red-backend red-db-redis red-ceph-cluster; do
    if virsh net-info "$net" >/dev/null 2>&1; then
      echo "[OK] Red libvirt existe: $net"
    else
      echo "[WARN] Red libvirt NO existe: $net  (ejecuta el bloque de redes del stack primero)"
      ok=false
    fi
  done

  if [[ "$ok" == "false" ]]; then
    echo "[ERROR] Faltan redes KVM requeridas. Ejecuta primero configuraciones-dns.bash 1 o configuraciones-mysql.sh 1"
    exit 1
  fi

  echo "[OK] Precheck completado"
}

# ── BLOQUE 2: Crear VM monitor ────────────────────────────────────────────────
block_2_crear_monitor() {
  echo
  echo "=================================================================="
  echo "[BLOQUE 2] Crear VM monitor"
  echo "=================================================================="

  if virsh list --all --name 2>/dev/null | grep -qx "$MONITOR_VM"; then
    echo "[WARN] VM '$MONITOR_VM' ya existe en libvirt. Omitiendo creacion."
    echo "[INFO] Si necesitas recrearla: virsh destroy $MONITOR_VM && virsh undefine $MONITOR_VM --remove-all-storage"
    wait_for_ssh_node "$MONITOR_IP"
    return 0
  fi

  echo "[INFO] Creando VM $MONITOR_VM con 4 NICs (red-principal/backend/db-redis/ceph)..."
  bash "$CREATE_VM_SCRIPT" \
    --name "$MONITOR_VM" \
    --hostname "monitor" \
    --user "$VM_USER" \
    --password "$VM_PASSWORD" \
    --ram 4096 \
    --vcpus 2 \
    --system-disk 30 \
    --data-disk 0 \
    --libvirt-nets "red-principal;red-backend;red-db-redis;red-ceph-cluster" \
    --ifaces "enp1s0,${MONITOR_IP}/24,192.168.10.1,8.8.8.8,1.1.1.1;enp2s0,${MONITOR_IP_BACKEND}/24,,8.8.8.8,1.1.1.1;enp3s0,${MONITOR_IP_DB}/24,,8.8.8.8,1.1.1.1;enp4s0,${MONITOR_IP_CEPH}/24,,8.8.8.8,1.1.1.1" \
    --extra-hosts "$EXTRA_HOSTS"

  echo "[INFO] Esperando que la VM arranque y SSH este listo..."
  wait_for_ssh_node "$MONITOR_IP"

  echo "[INFO] Preparando apt en monitor (limpiando bloqueos post cloud-init)..."
  ssh_cmd "$MONITOR_IP" "sudo bash -s" <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
cloud-init status --wait >/dev/null 2>&1 || true
systemctl stop apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
pkill -9 apt apt-get unattended-upgrade 2>/dev/null || true
rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
rm -f /var/lib/dpkg/updates/*
dpkg --configure -a || true
apt-get -y -f install || true
echo "[OK] apt listo en monitor"
REMOTE

  echo "[OK] VM monitor creada y lista"
}

# ── BLOQUE 3: Instalar Prometheus + Grafana en monitor ───────────────────────
block_3_instalar_prometheus_grafana() {
  echo
  echo "=================================================================="
  echo "[BLOQUE 3] Instalar Prometheus + Grafana en monitor"
  echo "=================================================================="

  wait_for_ssh_node "$MONITOR_IP"

  local grafana_pass="$GRAFANA_ADMIN_PASSWORD"

  ssh_cmd "$MONITOR_IP" "sudo bash -s" <<REMOTE
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[INFO] Actualizando lista de paquetes..."
apt-get update -qq

echo "[INFO] Instalando prometheus y node_exporter para el propio monitor..."
apt-get install -y prometheus prometheus-node-exporter
systemctl enable --now prometheus
systemctl enable --now prometheus-node-exporter
echo "[OK] Prometheus y node_exporter activos en monitor"

echo "[INFO] Instalando dependencias para Grafana..."
apt-get install -y apt-transport-https software-properties-common wget curl gnupg ca-certificates

echo "[INFO] Agregando repositorio oficial de Grafana..."
if [[ ! -f /usr/share/keyrings/grafana.key ]]; then
  wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
fi
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" \
  > /etc/apt/sources.list.d/grafana.list
apt-get update -qq
apt-get install -y grafana
echo "[OK] Grafana instalado"

echo "[INFO] Configurando password de admin Grafana en grafana.ini..."
if grep -q '^;admin_password' /etc/grafana/grafana.ini 2>/dev/null; then
  sed -i "s|^;admin_password = .*|admin_password = ${grafana_pass}|" /etc/grafana/grafana.ini
elif grep -q '^admin_password' /etc/grafana/grafana.ini 2>/dev/null; then
  sed -i "s|^admin_password = .*|admin_password = ${grafana_pass}|" /etc/grafana/grafana.ini
else
  echo "admin_password = ${grafana_pass}" >> /etc/grafana/grafana.ini
fi

systemctl enable --now grafana-server
echo "[INFO] Esperando que Grafana responda en :${GRAFANA_PORT}..."
for i in \$(seq 1 30); do
  if curl -sf http://localhost:${GRAFANA_PORT}/api/health >/dev/null 2>&1; then
    echo "[OK] Grafana activo"
    break
  fi
  sleep 4
done

echo "[OK] Prometheus + Grafana instalados y activos en monitor"
REMOTE

  echo "[OK] Bloque 3 completado"
}

# ── BLOQUE 4: Instalar node_exporter en servidores objetivo ──────────────────
# Esta funcion es SEGURA y ADITIVA: solo instala el paquete y agrega
# una regla UFW. No toca ningun servicio existente.
install_node_exporter_on_node() {
  local ip="$1"
  local label="$2"
  local monitor_source_ip="$3"   # IP del monitor en la misma red que este nodo

  if ! node_is_reachable "$ip"; then
    echo "[WARN] $label ($ip): no accesible via SSH — saltando"
    return 0
  fi

  echo "[INFO] Configurando node_exporter en $label ($ip)..."
  ssh_cmd "$ip" "sudo bash -s" <<REMOTE
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if ! dpkg -l prometheus-node-exporter 2>/dev/null | grep -q '^ii'; then
  apt-get update -qq 2>/dev/null || true
  apt-get install -y prometheus-node-exporter
fi

systemctl enable --now prometheus-node-exporter 2>/dev/null || true

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow from ${monitor_source_ip} to any port ${NODE_EXPORTER_PORT} proto tcp \
    comment 'node_exporter monitor' 2>/dev/null || true
fi

systemctl is-active prometheus-node-exporter >/dev/null 2>&1 \
  && echo "[OK] node_exporter activo en \$(hostname) ($ip)" \
  || echo "[WARN] node_exporter no activo en \$(hostname) ($ip)"
REMOTE
}

block_4_instalar_node_exporter() {
  echo
  echo "=================================================================="
  echo "[BLOQUE 4] Instalar node_exporter en servidores del cluster"
  echo "=================================================================="
  echo "[INFO] Operacion SEGURA: solo instala node_exporter y agrega regla UFW."
  echo "[INFO] Servers inaccesibles seran saltados automaticamente."
  echo

  local entry ip label

  echo "--- Red principal: DNS + Load Balancers (192.168.10.x) ---"
  for entry in "${NODES_PRINCIPAL[@]}"; do
    ip="${entry%%:*}"
    label="${entry##*:}"
    install_node_exporter_on_node "$ip" "$label" "$MONITOR_IP"
  done

  echo
  echo "--- Red backend: App servers WinterCMS (192.168.20.x) ---"
  for entry in "${NODES_BACKEND[@]}"; do
    ip="${entry%%:*}"
    label="${entry##*:}"
    install_node_exporter_on_node "$ip" "$label" "$MONITOR_IP_BACKEND"
  done

  echo
  echo "--- Red db-redis: Redis + MaxScale + MariaDB (192.168.30.x) ---"
  for entry in "${NODES_DB[@]}"; do
    ip="${entry%%:*}"
    label="${entry##*:}"
    install_node_exporter_on_node "$ip" "$label" "$MONITOR_IP_DB"
  done

  echo
  echo "--- Red ceph-cluster: Ceph (192.168.60.x) ---"
  for entry in "${NODES_CEPH[@]}"; do
    ip="${entry%%:*}"
    label="${entry##*:}"
    install_node_exporter_on_node "$ip" "$label" "$MONITOR_IP_CEPH"
  done

  echo
  echo "[OK] node_exporter desplegado en todos los servidores accesibles"
}

# ── BLOQUE 5: Configurar Prometheus scrape targets ───────────────────────────
block_5_configurar_prometheus() {
  echo
  echo "=================================================================="
  echo "[BLOQUE 5] Configurar Prometheus con todos los scrape targets"
  echo "=================================================================="

  wait_for_ssh_node "$MONITOR_IP"

  ssh_cmd "$MONITOR_IP" "sudo bash -s" <<'REMOTE'
set -euo pipefail

cat > /etc/prometheus/prometheus.yml <<'PROMCFG'
global:
  scrape_interval:     30s
  evaluation_interval: 30s
  scrape_timeout:      10s

alerting:
  alertmanagers: []

rule_files: []

scrape_configs:

  # Prometheus self-monitoring
  - job_name: prometheus
    static_configs:
      - targets:
          - 'localhost:9090'
        labels:
          group: monitor
          instance: prometheus

  # Monitor VM (node_exporter local)
  - job_name: node_monitor
    static_configs:
      - targets:
          - 'localhost:9100'
        labels:
          group: monitor
          node: monitor

  # DNS + Load Balancers (red-principal 192.168.10.x)
  - job_name: principal
    static_configs:
      - targets:
          - '192.168.10.10:9100'
          - '192.168.10.11:9100'
          - '192.168.10.20:9100'
          - '192.168.10.21:9100'
        labels:
          group: principal
    relabel_configs:
      - source_labels: [__address__]
        regex: '192\.168\.10\.10:.*'
        target_label: node
        replacement: dns-principal
      - source_labels: [__address__]
        regex: '192\.168\.10\.11:.*'
        target_label: node
        replacement: dns-delegado
      - source_labels: [__address__]
        regex: '192\.168\.10\.20:.*'
        target_label: node
        replacement: lb1
      - source_labels: [__address__]
        regex: '192\.168\.10\.21:.*'
        target_label: node
        replacement: lb2

  # App servers WinterCMS (red-backend 192.168.20.x)
  - job_name: backend
    static_configs:
      - targets:
          - '192.168.20.10:9100'
          - '192.168.20.11:9100'
          - '192.168.20.12:9100'
        labels:
          group: backend
    relabel_configs:
      - source_labels: [__address__]
        regex: '192\.168\.20\.10:.*'
        target_label: node
        replacement: appWinter1
      - source_labels: [__address__]
        regex: '192\.168\.20\.11:.*'
        target_label: node
        replacement: appWinter2
      - source_labels: [__address__]
        regex: '192\.168\.20\.12:.*'
        target_label: node
        replacement: appWinter3

  # Redis cluster (red-db-redis 192.168.30.10-16)
  - job_name: redis
    static_configs:
      - targets:
          - '192.168.30.10:9100'
          - '192.168.30.11:9100'
          - '192.168.30.12:9100'
          - '192.168.30.13:9100'
          - '192.168.30.14:9100'
          - '192.168.30.15:9100'
          - '192.168.30.16:9100'
        labels:
          group: redis
    relabel_configs:
      - source_labels: [__address__]
        regex: '(192\.168\.30\.\d+):.*'
        target_label: node
        replacement: 'redis-${1}'

  # MaxScale + MariaDB Galera (red-db-redis 192.168.30.20-23)
  - job_name: database
    static_configs:
      - targets:
          - '192.168.30.20:9100'
          - '192.168.30.21:9100'
          - '192.168.30.22:9100'
          - '192.168.30.23:9100'
        labels:
          group: database
    relabel_configs:
      - source_labels: [__address__]
        regex: '192\.168\.30\.20:.*'
        target_label: node
        replacement: maxscale-1
      - source_labels: [__address__]
        regex: '192\.168\.30\.21:.*'
        target_label: node
        replacement: mariadb-1
      - source_labels: [__address__]
        regex: '192\.168\.30\.22:.*'
        target_label: node
        replacement: mariadb-2
      - source_labels: [__address__]
        regex: '192\.168\.30\.23:.*'
        target_label: node
        replacement: mariadb-3

  # Ceph cluster (red-ceph-cluster 192.168.60.x)
  - job_name: ceph
    static_configs:
      - targets:
          - '192.168.60.11:9100'
        labels:
          group: ceph
          node: ceph1
PROMCFG

if command -v promtool >/dev/null 2>&1; then
  promtool check config /etc/prometheus/prometheus.yml \
    && echo "[OK] prometheus.yml sintaxis valida" \
    || { echo "[ERROR] prometheus.yml invalido"; exit 1; }
fi

systemctl restart prometheus
sleep 3
systemctl is-active prometheus && echo "[OK] Prometheus reiniciado correctamente" || exit 1
REMOTE

  echo "[OK] Prometheus configurado con todos los scrape targets"
}

# ── BLOQUE 6: Configurar Grafana datasource + dashboard ──────────────────────
block_6_configurar_grafana() {
  echo
  echo "=================================================================="
  echo "[BLOQUE 6] Configurar Grafana datasource + dashboard"
  echo "=================================================================="

  wait_for_ssh_node "$MONITOR_IP"

  local grafana_pass="$GRAFANA_ADMIN_PASSWORD"
  local grafana_port="$GRAFANA_PORT"
  local prometheus_port="$PROMETHEUS_PORT"

  ssh_cmd "$MONITOR_IP" "sudo bash -s" <<REMOTE
set -euo pipefail

GRAFANA_URL="http://localhost:${grafana_port}"
GRAFANA_AUTH="admin:${grafana_pass}"

echo "[INFO] Verificando que Grafana API este lista..."
for i in \$(seq 1 24); do
  if curl -sf "\${GRAFANA_URL}/api/health" >/dev/null 2>&1; then
    echo "[OK] Grafana API lista"
    break
  fi
  echo "[INFO] Esperando Grafana... (intento \${i}/24)"
  sleep 5
done

echo "[INFO] Escribiendo provisioning de datasource Prometheus..."
mkdir -p /etc/grafana/provisioning/datasources
cat > /etc/grafana/provisioning/datasources/prometheus.yaml <<'DATASRC'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:${prometheus_port}
    access: proxy
    isDefault: true
    editable: true
    jsonData:
      timeInterval: 30s
DATASRC

systemctl reload grafana-server 2>/dev/null || systemctl restart grafana-server
sleep 5
echo "[OK] Datasource Prometheus provisionado via archivo"

echo "[INFO] Importando dashboard Node Exporter Full (grafana.com ID 1860)..."
DS_UID=\$(curl -sf "\${GRAFANA_URL}/api/datasources/name/Prometheus" \
  -u "\${GRAFANA_AUTH}" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('uid',''))" 2>/dev/null || echo "")

if [[ -n "\${DS_UID}" ]]; then
  DASH_JSON=\$(curl -sf "https://grafana.com/api/dashboards/1860/revisions/37/download" 2>/dev/null || echo "")
  if [[ -n "\${DASH_JSON}" ]]; then
    IMPORT_PAYLOAD=\$(python3 - <<'PY'
import sys, json
dash = json.loads(sys.stdin.read())
dash['id'] = None
payload = {
  "dashboard": dash,
  "overwrite": True,
  "folderId": 0,
  "inputs": [{
    "name": "DS_PROMETHEUS",
    "type": "datasource",
    "pluginId": "prometheus",
    "value": "Prometheus"
  }]
}
print(json.dumps(payload))
PY
    <<< "\${DASH_JSON}")
    curl -sf -X POST "\${GRAFANA_URL}/api/dashboards/import" \
      -u "\${GRAFANA_AUTH}" \
      -H "Content-Type: application/json" \
      -d "\${IMPORT_PAYLOAD}" 2>/dev/null \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print('[OK] Dashboard importado:', d.get('title','?'), '— uid:', d.get('uid','?'))" 2>/dev/null \
      || echo "[WARN] Importacion de dashboard fallo (posible falta de internet)"
  else
    echo "[WARN] No se pudo descargar el dashboard de grafana.com (sin internet?)"
    echo "[INFO] Importalo manualmente: Grafana > Dashboards > Import > ID 1860"
  fi
else
  echo "[WARN] No se encontro UID del datasource Prometheus"
fi

echo "[OK] Configuracion Grafana completada"
REMOTE

  echo ""
  echo "=================================================================="
  echo "  GRAFANA CONFIGURADO"
  echo "  URL:      http://${MONITOR_IP}:${GRAFANA_PORT}"
  echo "  Usuario:  admin"
  echo "  Password: ${GRAFANA_ADMIN_PASSWORD}"
  echo "=================================================================="
}

# ── BLOQUE 7: Validar monitoreo ───────────────────────────────────────────────
block_7_validar() {
  echo
  echo "=================================================================="
  echo "[BLOQUE 7] Validar estado del monitoreo"
  echo "=================================================================="

  wait_for_ssh_node "$MONITOR_IP"

  echo "[INFO] Estado de servicios en monitor..."
  ssh_cmd "$MONITOR_IP" "sudo systemctl is-active prometheus \
    && echo '[OK] prometheus: activo' \
    || echo '[WARN] prometheus: inactivo'"
  ssh_cmd "$MONITOR_IP" "sudo systemctl is-active prometheus-node-exporter \
    && echo '[OK] prometheus-node-exporter: activo' \
    || echo '[WARN] prometheus-node-exporter: inactivo'"
  ssh_cmd "$MONITOR_IP" "sudo systemctl is-active grafana-server \
    && echo '[OK] grafana-server: activo' \
    || echo '[WARN] grafana-server: inactivo'"

  echo
  echo "[INFO] Consultando targets de Prometheus..."
  ssh_cmd "$MONITOR_IP" "curl -sf http://localhost:${PROMETHEUS_PORT}/api/v1/targets 2>/dev/null \
    | python3 -c \"
import sys, json
d = json.load(sys.stdin)
targets = d.get('data', {}).get('activeTargets', [])
up   = [t for t in targets if t.get('health') == 'up']
down = [t for t in targets if t.get('health') != 'up']
print(f'[OK] Targets UP:   {len(up)}/{len(targets)}')
if down:
    print(f'[WARN] Targets DOWN: {len(down)}')
    for t in down:
        inst = t.get('labels', {}).get('instance', '?')
        job  = t.get('labels', {}).get('job', '?')
        print(f'      [{job}] {inst}')
\" 2>/dev/null || echo '[WARN] No se pudo consultar Prometheus API'"

  echo
  echo "[INFO] Verificando Grafana API..."
  ssh_cmd "$MONITOR_IP" "curl -sf http://localhost:${GRAFANA_PORT}/api/health \
    | python3 -c \"import sys,json; d=json.load(sys.stdin); \
      print('[OK] Grafana', d.get('version','?'), '-', d.get('database','?'))\" \
    2>/dev/null || echo '[WARN] Grafana API no responde'"

  echo
  echo "=================================================================="
  echo "  MONITOREO ACTIVO"
  echo "=================================================================="
  echo "  Grafana:    http://${MONITOR_IP}:${GRAFANA_PORT}"
  echo "  Prometheus: http://${MONITOR_IP}:${PROMETHEUS_PORT}"
  echo "  Usuario:    admin"
  echo "  Password:   ${GRAFANA_ADMIN_PASSWORD}"
  echo ""
  echo "  Dashboard recomendado: Node Exporter Full (ID 1860)"
  echo "  Importar manualmente si fallo la descarga:"
  echo "    Grafana > Dashboards > Import > grafana.com ID: 1860"
  echo "=================================================================="
}

# ── Dispatcher ────────────────────────────────────────────────────────────────
case "${1:-}" in
  1) block_1_precheck ;;
  2) block_2_crear_monitor ;;
  3) block_3_instalar_prometheus_grafana ;;
  4) block_4_instalar_node_exporter ;;
  5) block_5_configurar_prometheus ;;
  6) block_6_configurar_grafana ;;
  7) block_7_validar ;;
  all)
    block_1_precheck
    block_2_crear_monitor
    block_3_instalar_prometheus_grafana
    block_4_instalar_node_exporter
    block_5_configurar_prometheus
    block_6_configurar_grafana
    block_7_validar
    ;;
  *)
    cat <<'HELP'
Uso: bash configuraciones-grafana.sh {1|2|3|4|5|6|7|all}

  1  - Precheck: valida SSH, virsh y redes KVM requeridas
  2  - Crear VM monitor (4 NICs, 4GB RAM, 30GB disco)
       IPs: 192.168.10.30 / 20.30 / 30.33 / 60.30
  3  - Instalar Prometheus + Grafana en monitor VM
  4  - Instalar node_exporter en TODOS los servers del cluster
       (operacion segura: solo agrega paquete + regla UFW, no toca servicios)
  5  - Configurar prometheus.yml con todos los scrape targets del cluster
  6  - Configurar Grafana: datasource Prometheus + dashboard Node Exporter Full
  7  - Validar: estado de servicios, targets UP/DOWN, Grafana API
  all - Ejecutar flujo completo (bloques 1 a 7)

Variables configurables:
  KEY_OVERRIDE           Clave SSH privada alternativa
  MONITOR_VM             Nombre de la VM  (default: monitor)
  MONITOR_IP             IP en red-principal  (default: 192.168.10.30)
  GRAFANA_ADMIN_PASSWORD Password de Grafana  (default: GrafanaAdmin2620!)

Acceso post-despliegue:
  Grafana:    http://192.168.10.30:3000  (admin / GrafanaAdmin2620!)
  Prometheus: http://192.168.10.30:9090
HELP
    ;;
esac
