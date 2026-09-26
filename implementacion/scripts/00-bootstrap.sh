#!/usr/bin/env bash
# =============================================================================
# 00-bootstrap.sh — Verifica Ubuntu 24.04 + habilita sudo NOPASSWD + SSH
# -----------------------------------------------------------------------------
#  Es el primer script de la secuencia. Deja los nodos listos para que el resto
#  de scripts corran con `sudo -n` (sin pedir contraseña).
#  Idempotente: re-ejecutable.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../inventory/nodes.env"

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes"
LOCAL_IP="$(hostname -I | awk '{print $1}')"

log() { echo -e "\n\033[1;34m===> $1\033[0m"; }

is_local() { [[ "$1" == "$LOCAL_IP" || "$1" == "localhost" || "$1" == "127.0.0.1" ]]; }

log "Verificando sistema operativo (debe ser Ubuntu 24.04)"

# ---- NODE-01: anfitrion (192.168.0.10) — LOCAL ----------------------------
ver=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
name=$(hostname)
echo "  $NODE01_IP  ->  $name  (Ubuntu $ver)"
[[ "$ver" == "24.04"* ]] || echo "  ⚠ $NODE01_IP no es 24.04 ($ver)"

# ---- NODE-02: asus-tuf (192.168.0.126) — REMOTO ---------------------------
ver=$(ssh $SSH_OPTS "$SSH_USER@$NODE02_IP" "grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '\"'")
name=$(ssh $SSH_OPTS "$SSH_USER@$NODE02_IP" "hostname")
echo "  $NODE02_IP  ->  $name  (Ubuntu $ver)"
[[ "$ver" == "24.04"* ]] || echo "  ⚠ $NODE02_IP no es 24.04 ($ver)"

# ---- NODE-03: server (192.168.0.100) — REMOTO -----------------------------
ver=$(ssh $SSH_OPTS "$SSH_USER@$NODE03_IP" "grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '\"'")
name=$(ssh $SSH_OPTS "$SSH_USER@$NODE03_IP" "hostname")
echo "  $NODE03_IP  ->  $name  (Ubuntu $ver)"
[[ "$ver" == "24.04"* ]] || echo "  ⚠ $NODE03_IP no es 24.04 ($ver)"

log "Habilitando sudo NOPASSWD para $SSH_USER"

# ---- NODE-01: anfitrion (LOCAL) -------------------------------------------
# El heredoc envía: línea 1 = contraseña (sudo -S), resto = script (bash -s)
echo "----- $NODE01_IP -----"
sudo -S -p '' bash -s <<EOF
$SUDO_PASSWORD
printf '%s\n' '$SSH_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$SSH_USER-nopasswd
chmod 440 /etc/sudoers.d/$SSH_USER-nopasswd
EOF

# ---- NODE-02: asus-tuf (REMOTO) -------------------------------------------
echo "----- $NODE02_IP -----"
ssh $SSH_OPTS "$SSH_USER@$NODE02_IP" "sudo -S -p '' bash -s" <<EOF
$SUDO_PASSWORD
printf '%s\n' '$SSH_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$SSH_USER-nopasswd
chmod 440 /etc/sudoers.d/$SSH_USER-nopasswd
EOF

# ---- NODE-03: server (REMOTO) ---------------------------------------------
echo "----- $NODE03_IP -----"
ssh $SSH_OPTS "$SSH_USER@$NODE03_IP" "sudo -S -p '' bash -s" <<EOF
$SUDO_PASSWORD
printf '%s\n' '$SSH_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$SSH_USER-nopasswd
chmod 440 /etc/sudoers.d/$SSH_USER-nopasswd
EOF

log "Verificando sudo sin contraseña"

# ---- NODE-01: anfitrion (LOCAL) -------------------------------------------
sudo -n true && echo "  $NODE01_IP: sudo NOPASSWD OK" || echo "  $NODE01_IP: sudo FALLÓ"

# ---- NODE-02: asus-tuf (REMOTO) -------------------------------------------
ssh $SSH_OPTS "$SSH_USER@$NODE02_IP" "sudo -n true" && echo "  $NODE02_IP: sudo NOPASSWD OK" || echo "  $NODE02_IP: sudo FALLÓ"

# ---- NODE-03: server (REMOTO) ---------------------------------------------
ssh $SSH_OPTS "$SSH_USER@$NODE03_IP" "sudo -n true" && echo "  $NODE03_IP: sudo NOPASSWD OK" || echo "  $NODE03_IP: sudo FALLÓ"

log "Bootstrap completado"
