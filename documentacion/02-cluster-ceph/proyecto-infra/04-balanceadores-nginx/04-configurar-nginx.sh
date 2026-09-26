#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-plan}"

SSH_USER="${SSH_USER:-admin}"
SSH_KEY="${SSH_KEY:-/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i "$SSH_KEY")

LB1_IP="${LB1_IP:-192.168.3.50}"
LB2_IP="${LB2_IP:-192.168.3.51}"

APP1_IP="${APP1_IP:-192.168.3.52}"
APP2_IP="${APP2_IP:-192.168.3.53}"
APP3_IP="${APP3_IP:-192.168.3.54}"
APP_PORT="${APP_PORT:-8000}"

UPSTREAM_NAME="${UPSTREAM_NAME:-django_cluster}"
SERVER_NAME="${SERVER_NAME:-mimas.net *.mimas.net lb1.mimas.net lb2.mimas.net}"
HEALTH_PATH="${HEALTH_PATH:-/}"
TMP_CONF=""

cleanup() {
  if [[ -n "${TMP_CONF:-}" && -f "$TMP_CONF" ]]; then
    rm -f "$TMP_CONF"
  fi
}

trap cleanup EXIT

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
  for ip in "$LB1_IP" "$LB2_IP"; do
    echo "[INFO] Verificando SSH en $ip"
    run_ssh "$ip" "hostname >/dev/null"
  done
}

generate_nginx_conf() {
  local out_file="$1"

  cat > "$out_file" <<EOF
upstream ${UPSTREAM_NAME} {
    least_conn;
    server ${APP1_IP}:${APP_PORT} max_fails=3 fail_timeout=10s;
    server ${APP2_IP}:${APP_PORT} max_fails=3 fail_timeout=10s;
    server ${APP3_IP}:${APP_PORT} max_fails=3 fail_timeout=10s;
    keepalive 32;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${SERVER_NAME};

    location / {
        proxy_pass http://${UPSTREAM_NAME};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
    }
}
EOF
}

install_nginx() {
  local host="$1"
  echo "[INFO] Instalando Nginx en $host"
  run_ssh "$host" "sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx curl"
}

deploy_nginx_conf() {
  local host="$1"
  local tmp_conf="$2"

  echo "[INFO] Desplegando configuracion Nginx en $host"
  run_scp "$tmp_conf" "$host" /tmp/django-lb.conf
  run_ssh "$host" "sudo mv /tmp/django-lb.conf /etc/nginx/sites-available/django-lb.conf"
  run_ssh "$host" "sudo ln -sf /etc/nginx/sites-available/django-lb.conf /etc/nginx/sites-enabled/django-lb.conf"
  run_ssh "$host" "sudo rm -f /etc/nginx/sites-enabled/default"
  run_ssh "$host" "sudo nginx -t"
  run_ssh "$host" "sudo systemctl enable --now nginx && sudo systemctl restart nginx"
}

check_upstream_reachability() {
  local host="$1"

  for backend in "$APP1_IP" "$APP2_IP" "$APP3_IP"; do
    if run_ssh "$host" "curl -fsS --max-time 4 http://${backend}:${APP_PORT}${HEALTH_PATH} >/dev/null"; then
      echo "[INFO] $host puede alcanzar backend ${backend}:${APP_PORT}${HEALTH_PATH}"
    else
      echo "[WARN] $host no pudo alcanzar backend ${backend}:${APP_PORT}${HEALTH_PATH}. Puede ser normal si Django aun no esta desplegado."
    fi
  done
}

validate_frontend() {
  for lb in "$LB1_IP" "$LB2_IP"; do
    local status
    echo "[INFO] Validando respuesta HTTP desde $lb"
    status="$(curl -sSI --max-time 5 "http://${lb}" | awk 'NR==1{print $2}')"
    if [[ -n "$status" ]]; then
      echo "[OK] Nginx responde en ${lb} (HTTP ${status})"
    else
      echo "[WARN] No hubo respuesta HTTP valida desde ${lb}"
    fi
  done
}

plan() {
  cat <<EOF
[PLAN] Configuracion de Nginx en balanceadores
1) Verificar acceso SSH a ${LB1_IP} y ${LB2_IP}
2) Instalar nginx/curl en ambos nodos
3) Desplegar /etc/nginx/sites-available/django-lb.conf
4) Activar sitio, desactivar default y validar 'nginx -t'
5) Reiniciar/activar servicio nginx
6) Probar alcance a backends ${APP1_IP}, ${APP2_IP}, ${APP3_IP} (warnings si app aun no esta lista)
7) Validar HTTP en http://${LB1_IP} y http://${LB2_IP}
EOF
}

apply() {
  TMP_CONF="$(mktemp /tmp/django-lb-XXXX.conf)"

  check_access
  generate_nginx_conf "$TMP_CONF"

  install_nginx "$LB1_IP"
  install_nginx "$LB2_IP"

  deploy_nginx_conf "$LB1_IP" "$TMP_CONF"
  deploy_nginx_conf "$LB2_IP" "$TMP_CONF"

  check_upstream_reachability "$LB1_IP"
  check_upstream_reachability "$LB2_IP"
  validate_frontend

  echo "[OK] Configuracion de Nginx aplicada en lb1/lb2"
}

case "$MODE" in
  plan)
    plan
    ;;
  apply)
    apply
    ;;
  *)
    echo "Uso: bash 04-configurar-nginx.sh [plan|apply]"
    exit 1
    ;;
esac
