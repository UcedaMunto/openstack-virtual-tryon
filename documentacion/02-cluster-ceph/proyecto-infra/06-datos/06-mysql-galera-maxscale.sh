#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-plan}"

SSH_USER="${SSH_USER:-admin}"
SSH_KEY="${SSH_KEY:-/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i "$SSH_KEY")

MAXSCALE_IP="${MAXSCALE_IP:-192.168.3.60}"
DB1_IP="${DB1_IP:-192.168.3.61}"
DB2_IP="${DB2_IP:-192.168.3.62}"
DB3_IP="${DB3_IP:-192.168.3.63}"

MAXSCALE_MONITOR_USER="${MAXSCALE_MONITOR_USER:-maxscale}"
MAXSCALE_MONITOR_PASS="${MAXSCALE_MONITOR_PASS:-MaxScalePass123!}"
MAXSCALE_AVAILABLE="false"

run_ssh() {
  local host="$1"
  shift
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$host" "$@"
}

run_scp() {
  local src="$1"
  local host="$2"
  local dst="$3"
  scp "${SSH_OPTS[@]}" "$src" "$SSH_USER@$host:$dst"
}

check_access() {
  for ip in "$MAXSCALE_IP" "$DB1_IP" "$DB2_IP" "$DB3_IP"; do
    echo "[INFO] Verificando SSH en $ip"
    run_ssh "$ip" "hostname >/dev/null"
  done
}

install_mariadb_packages() {
  for ip in "$DB1_IP" "$DB2_IP" "$DB3_IP"; do
    echo "[INFO] Instalando MariaDB/Galera en $ip"
    run_ssh "$ip" "sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server galera-4 rsync"
  done
}

generate_galera_cnf() {
  local node_name="$1"
  local node_ip="$2"
  local out_file="$3"

  cat > "$out_file" <<EOF
[mysqld]
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name=galera_cluster_lab
wsrep_cluster_address=gcomm://${DB1_IP},${DB2_IP},${DB3_IP}
wsrep_node_name=${node_name}
wsrep_node_address=${node_ip}
wsrep_sst_method=rsync
binlog_format=row
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0
EOF
}

configure_galera_nodes() {
  local tmp1 tmp2 tmp3
  tmp1="$(mktemp /tmp/galera-1-XXXX.cnf)"
  tmp2="$(mktemp /tmp/galera-2-XXXX.cnf)"
  tmp3="$(mktemp /tmp/galera-3-XXXX.cnf)"

  generate_galera_cnf mariadb-1 "$DB1_IP" "$tmp1"
  generate_galera_cnf mariadb-2 "$DB2_IP" "$tmp2"
  generate_galera_cnf mariadb-3 "$DB3_IP" "$tmp3"

  echo "[INFO] Copiando configuracion Galera"
  run_scp "$tmp1" "$DB1_IP" /tmp/60-galera.cnf
  run_scp "$tmp2" "$DB2_IP" /tmp/60-galera.cnf
  run_scp "$tmp3" "$DB3_IP" /tmp/60-galera.cnf

  run_ssh "$DB1_IP" "sudo install -o root -g root -m 0644 /tmp/60-galera.cnf /etc/mysql/mariadb.conf.d/60-galera.cnf"
  run_ssh "$DB2_IP" "sudo install -o root -g root -m 0644 /tmp/60-galera.cnf /etc/mysql/mariadb.conf.d/60-galera.cnf"
  run_ssh "$DB3_IP" "sudo install -o root -g root -m 0644 /tmp/60-galera.cnf /etc/mysql/mariadb.conf.d/60-galera.cnf"

  rm -f "$tmp1" "$tmp2" "$tmp3"
}

start_galera_cluster() {
  echo "[INFO] Deteniendo MariaDB en todos los nodos"
  run_ssh "$DB1_IP" "sudo systemctl stop mariadb || true"
  run_ssh "$DB2_IP" "sudo systemctl stop mariadb || true"
  run_ssh "$DB3_IP" "sudo systemctl stop mariadb || true"

  echo "[INFO] Bootstrap cluster en mariadb-1"
  run_ssh "$DB1_IP" "sudo galera_new_cluster"
  run_ssh "$DB1_IP" "sudo systemctl enable mariadb"

  echo "[INFO] Iniciando nodos secundarios"
  run_ssh "$DB2_IP" "sudo systemctl enable --now mariadb"
  run_ssh "$DB3_IP" "sudo systemctl enable --now mariadb"

  echo "[INFO] Verificando tamano de cluster"
  run_ssh "$DB1_IP" "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
  run_ssh "$DB2_IP" "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
  run_ssh "$DB3_IP" "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size';\""

  local c1 c2 c3
  c1="$(run_ssh "$DB1_IP" "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size'\" | tr -s '[:space:]' ' ' | cut -d' ' -f2")"
  c2="$(run_ssh "$DB2_IP" "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size'\" | tr -s '[:space:]' ' ' | cut -d' ' -f2")"
  c3="$(run_ssh "$DB3_IP" "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size'\" | tr -s '[:space:]' ' ' | cut -d' ' -f2")"

  if [[ "$c1" != "3" || "$c2" != "3" || "$c3" != "3" ]]; then
    echo "[ERROR] Cluster Galera no convergio a 3 nodos (valores: $c1/$c2/$c3)"
    exit 1
  fi
}

create_maxscale_monitor_user() {
  echo "[INFO] Creando usuario monitor para MaxScale en mariadb-1"
  run_ssh "$DB1_IP" "sudo mysql -e \"CREATE USER IF NOT EXISTS '${MAXSCALE_MONITOR_USER}'@'${MAXSCALE_IP}' IDENTIFIED BY '${MAXSCALE_MONITOR_PASS}'; GRANT RELOAD, PROCESS, SHOW DATABASES, REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO '${MAXSCALE_MONITOR_USER}'@'${MAXSCALE_IP}'; FLUSH PRIVILEGES;\""
}

install_maxscale() {
  echo "[INFO] Instalando MaxScale en ${MAXSCALE_IP}"
  run_ssh "$MAXSCALE_IP" "sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl gnupg apt-transport-https"

  if run_ssh "$MAXSCALE_IP" "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y maxscale"; then
    MAXSCALE_AVAILABLE="true"
    return
  fi

  echo "[WARN] maxscale no disponible en repo actual, agregando repo MariaDB"
  run_ssh "$MAXSCALE_IP" "curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash" || true
  run_ssh "$MAXSCALE_IP" "sudo DEBIAN_FRONTEND=noninteractive apt-get update" || true
  if run_ssh "$MAXSCALE_IP" "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y maxscale"; then
    MAXSCALE_AVAILABLE="true"
    return
  fi

  echo "[WARN] MaxScale no se pudo instalar desde repositorios disponibles en este entorno."
  MAXSCALE_AVAILABLE="false"
}

configure_maxscale() {
  if [[ "$MAXSCALE_AVAILABLE" != "true" ]]; then
    echo "[WARN] Se omite configuracion MaxScale porque el paquete no esta instalado."
    return
  fi

  local tmp
  tmp="$(mktemp /tmp/maxscale-XXXX.cnf)"

  cat > "$tmp" <<EOF
[maxscale]
threads=auto

[server1]
type=server
address=${DB1_IP}
port=3306
protocol=MariaDBBackend

[server2]
type=server
address=${DB2_IP}
port=3306
protocol=MariaDBBackend

[server3]
type=server
address=${DB3_IP}
port=3306
protocol=MariaDBBackend

[Galera-Monitor]
type=monitor
module=galeramon
servers=server1,server2,server3
user=${MAXSCALE_MONITOR_USER}
password=${MAXSCALE_MONITOR_PASS}
monitor_interval=2s

[RW-Service]
type=service
router=readwritesplit
servers=server1,server2,server3
user=${MAXSCALE_MONITOR_USER}
password=${MAXSCALE_MONITOR_PASS}

[RW-Listener]
type=listener
service=RW-Service
protocol=MariaDBClient
port=3306
EOF

  run_scp "$tmp" "$MAXSCALE_IP" /tmp/maxscale.cnf
  run_ssh "$MAXSCALE_IP" "sudo mv /tmp/maxscale.cnf /etc/maxscale.cnf"
  run_ssh "$MAXSCALE_IP" "sudo systemctl enable --now maxscale"
  run_ssh "$MAXSCALE_IP" "sudo systemctl restart maxscale && sudo systemctl --no-pager --full status maxscale"
  rm -f "$tmp"
}

plan() {
  cat <<EOF
[PLAN] Secuencia para montar MariaDB Galera + MaxScale
1) Verificar acceso SSH a ${MAXSCALE_IP}, ${DB1_IP}, ${DB2_IP}, ${DB3_IP}
2) Instalar paquetes mariadb-server/galera-4/rsync en nodos DB
3) Configurar /etc/mysql/mariadb.conf.d/60-galera.cnf en los 3 nodos
4) Bootstrap cluster en mariadb-1 con galera_new_cluster
5) Arrancar mariadb en mariadb-2 y mariadb-3
6) Validar wsrep_cluster_size=3
7) Crear usuario monitor de MaxScale en Galera
8) Instalar y configurar MaxScale en ${MAXSCALE_IP}
EOF
}

apply() {
  check_access
  install_mariadb_packages
  configure_galera_nodes
  start_galera_cluster
  create_maxscale_monitor_user
  install_maxscale
  configure_maxscale
  if [[ "$MAXSCALE_AVAILABLE" == "true" ]]; then
    echo "[OK] Galera + MaxScale configurados"
  else
    echo "[OK] Galera configurado; MaxScale pendiente por disponibilidad de repositorio"
  fi
}

case "$MODE" in
  plan)
    plan
    ;;
  apply)
    apply
    ;;
  *)
    echo "Uso: bash 06-mysql-galera-maxscale.sh [plan|apply]"
    exit 1
    ;;
esac
