#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-plan}"

SSH_USER="${SSH_USER:-admin}"
SSH_KEY="${SSH_KEY:-/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i "$SSH_KEY")

APP1_IP="${APP1_IP:-192.168.3.52}"
APP2_IP="${APP2_IP:-192.168.3.53}"
APP3_IP="${APP3_IP:-192.168.3.54}"
APP_PORT="${APP_PORT:-8000}"

APP_USER="${APP_USER:-django}"
APP_BASE_DIR="${APP_BASE_DIR:-/opt/apps}"
VENV_DIR="${VENV_DIR:-/opt/apps/venv}"
PROJECT_DIR="${PROJECT_DIR:-/opt/apps/mi-proyecto}"
DJANGO_PROJECT_NAME="${DJANGO_PROJECT_NAME:-config}"
SYSTEMD_SERVICE="${SYSTEMD_SERVICE:-django-gunicorn.service}"

run_ssh() {
  local host="$1"
  shift
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$host" "$@"
}

check_access() {
  for ip in "$APP1_IP" "$APP2_IP" "$APP3_IP"; do
    echo "[INFO] Verificando SSH en $ip"
    run_ssh "$ip" "hostname >/dev/null"
  done
}

bootstrap_backend() {
  local host="$1"

  echo "[INFO] Configurando backend Django en $host"
  run_ssh "$host" "sudo Dapp1.mimas.net EBIAN_FRONTEND=noninteractive apt-get update"
  run_ssh "$host" "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv python3-pip git build-essential libmariadb-dev pkg-config curl"

  run_ssh "$host" "sudo mkdir -p '$APP_BASE_DIR'"
  run_ssh "$host" "id -u '$APP_USER' >/dev/null 2>&1 || sudo useradd -m -s /bin/bash '$APP_USER'"
  run_ssh "$host" "sudo chown -R '$APP_USER':'$APP_USER' '$APP_BASE_DIR'"

  run_ssh "$host" "sudo -u '$APP_USER' bash -lc '
set -euo pipefail
if [[ ! -d \"$VENV_DIR\" ]]; then
  python3 -m venv \"$VENV_DIR\"
fi
source \"$VENV_DIR/bin/activate\"
pip install --upgrade pip wheel
pip install django gunicorn mysqlclient redis
if [[ ! -f \"$PROJECT_DIR/manage.py\" ]]; then
  mkdir -p \"$PROJECT_DIR\"
  django-admin startproject \"$DJANGO_PROJECT_NAME\" \"$PROJECT_DIR\"
fi
'
"

  run_ssh "$host" "sudo sed -i -E \"s/^ALLOWED_HOSTS = .*/ALLOWED_HOSTS = ['*']/\" '$PROJECT_DIR/$DJANGO_PROJECT_NAME/settings.py'"

  run_ssh "$host" "cat <<'EOF' | sudo tee /etc/systemd/system/$SYSTEMD_SERVICE >/dev/null
[Unit]
Description=Gunicorn Django
After=network.target

[Service]
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$VENV_DIR/bin
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind 0.0.0.0:$APP_PORT $DJANGO_PROJECT_NAME.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOF
"

  run_ssh "$host" "sudo systemctl daemon-reload"
  run_ssh "$host" "sudo systemctl enable --now $SYSTEMD_SERVICE"
  run_ssh "$host" "sudo systemctl restart $SYSTEMD_SERVICE"
}

check_backend() {
  local host="$1"
  run_ssh "$host" "systemctl is-active ${SYSTEMD_SERVICE%.service} || systemctl is-active $SYSTEMD_SERVICE"
  run_ssh "$host" "curl -fsS --max-time 5 http://127.0.0.1:$APP_PORT >/dev/null"
}

validate_all() {
  for ip in "$APP1_IP" "$APP2_IP" "$APP3_IP"; do
    echo "[INFO] Validando backend en $ip"
    check_backend "$ip"
    echo "[OK] Backend $ip operativo en puerto $APP_PORT"
  done
}

plan() {
  cat <<EOF
[PLAN] Configuracion de Django/Gunicorn en backends
1) Verificar acceso SSH a ${APP1_IP}, ${APP2_IP}, ${APP3_IP}
2) Instalar paquetes base Python/compilacion
3) Crear usuario ${APP_USER} y directorio ${APP_BASE_DIR}
4) Crear venv en ${VENV_DIR} e instalar django/gunicorn/mysqlclient/redis
5) Crear proyecto Django base en ${PROJECT_DIR} (si no existe)
6) Crear servicio systemd ${SYSTEMD_SERVICE}
7) Activar servicio en puerto ${APP_PORT}
8) Validar HTTP local en cada backend
EOF
}

apply() {
  check_access
  bootstrap_backend "$APP1_IP"
  bootstrap_backend "$APP2_IP"
  bootstrap_backend "$APP3_IP"
  validate_all
  echo "[OK] Django/Gunicorn configurado en app1/app2/app3"
}

check_only() {
  check_access
  validate_all
  echo "[OK] Validaciones de backend completadas"
}

case "$MODE" in
  plan)
    plan
    ;;
  apply)
    apply
    ;;
  check)
    check_only
    ;;
  *)
    echo "Uso: bash 05-configurar-django.sh [plan|apply|check]"
    exit 1
    ;;
esac
