#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-plan}"

SSH_USER="${SSH_USER:-admin}"
SSH_KEY="${SSH_KEY:-/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i "$SSH_KEY")

REDIS_IP="${REDIS_IP:-192.168.3.56}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_BIND="${REDIS_BIND:-0.0.0.0 ::1}"
REDIS_REQUIREPASS="${REDIS_REQUIREPASS:-}"

run_ssh() {
  local host="$1"
  shift
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$host" "$@"
}

check_access() {
  echo "[INFO] Verificando SSH en ${REDIS_IP}"
  run_ssh "$REDIS_IP" "hostname >/dev/null"
}

install_redis() {
  echo "[INFO] Instalando redis-server en ${REDIS_IP}"
  run_ssh "$REDIS_IP" "sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server redis-tools"
}

configure_redis() {
  echo "[INFO] Configurando Redis"
  run_ssh "$REDIS_IP" "sudo cp -n /etc/redis/redis.conf /etc/redis/redis.conf.bak.lab || true"
  run_ssh "$REDIS_IP" "sudo sed -i -E 's|^#?bind .*|bind ${REDIS_BIND}|g' /etc/redis/redis.conf"
  run_ssh "$REDIS_IP" "sudo sed -i -E 's|^#?port .*|port ${REDIS_PORT}|g' /etc/redis/redis.conf"
  run_ssh "$REDIS_IP" "sudo sed -i -E 's|^#?protected-mode .*|protected-mode yes|g' /etc/redis/redis.conf"
  run_ssh "$REDIS_IP" "sudo sed -i -E 's|^#?appendonly .*|appendonly yes|g' /etc/redis/redis.conf"

  if [[ -n "$REDIS_REQUIREPASS" ]]; then
    run_ssh "$REDIS_IP" "sudo sed -i -E 's|^#?requirepass .*|requirepass ${REDIS_REQUIREPASS}|g' /etc/redis/redis.conf"
    run_ssh "$REDIS_IP" "sudo sed -i -E 's|^#?masterauth .*|masterauth ${REDIS_REQUIREPASS}|g' /etc/redis/redis.conf"
  else
    run_ssh "$REDIS_IP" "sudo sed -i -E '/^#?requirepass /d;/^#?masterauth /d' /etc/redis/redis.conf"
  fi
}

restart_redis() {
  echo "[INFO] Reiniciando servicio Redis"
  run_ssh "$REDIS_IP" "sudo systemctl enable --now redis-server"
  run_ssh "$REDIS_IP" "sudo systemctl restart redis-server"
  run_ssh "$REDIS_IP" "sudo systemctl --no-pager --full status redis-server | sed -n '1,20p'"
}

validate_redis() {
  echo "[INFO] Validando Redis"
  run_ssh "$REDIS_IP" "ss -lntp | grep -E ':${REDIS_PORT}\\s' || true"
  if [[ -n "$REDIS_REQUIREPASS" ]]; then
    run_ssh "$REDIS_IP" "redis-cli -a '${REDIS_REQUIREPASS}' -p ${REDIS_PORT} PING"
  else
    run_ssh "$REDIS_IP" "redis-cli -p ${REDIS_PORT} PING"
  fi
}

plan() {
  cat <<EOF
[PLAN] Secuencia para Redis
1) Verificar acceso SSH a ${REDIS_IP}
2) Instalar redis-server y redis-tools
3) Configurar /etc/redis/redis.conf (bind, port, protected-mode, appendonly)
4) Opcional: configurar requirepass/masterauth con REDIS_REQUIREPASS
5) Habilitar y reiniciar redis-server
6) Validar estado del servicio y redis-cli PING
EOF
}

apply() {
  check_access
  install_redis
  configure_redis
  restart_redis
  validate_redis
  echo "[OK] Redis configurado en ${REDIS_IP}"
}

case "$MODE" in
  plan)
    plan
    ;;
  apply)
    apply
    ;;
  *)
    echo "Uso: bash 06-redis.sh [plan|apply]"
    exit 1
    ;;
esac