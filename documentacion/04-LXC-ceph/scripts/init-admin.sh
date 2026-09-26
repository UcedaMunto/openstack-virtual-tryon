#!/bin/bash

set -e

echo "=========================================="
echo "  INICIANDO CEPH-ADMIN"
echo "=========================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============================================
# PASO 1: Actualizar sistema
# ============================================
log_info "Paso 1: Actualizando sistema..."
apt-get update -qq

# ============================================
# PASO 2: Instalar dependencias
# ============================================
log_info "Paso 2: Instalando dependencias..."
apt-get install -y -qq \
    curl \
    gnupg2 \
    iputils-ping \
    lsb-release \
    ubuntu-keyring \
    openssh-server \
    openssh-client \
    procps \
    vim \
    net-tools \
    htop \
    wget

# ============================================
# PASO 3: Configurar SSH
# ============================================
log_info "Paso 3: Configurando SSH..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Generar claves SSH si no existen
if [ ! -f /root/.ssh/id_rsa ]; then
    log_info "Generando claves SSH..."
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa -q
fi

# Configurar SSH para no pedir contraseña
mkdir -p /run/sshd
echo "StrictHostKeyChecking no" > /root/.ssh/config
echo "UserKnownHostsFile=/dev/null" >> /root/.ssh/config
chmod 600 /root/.ssh/config

# ============================================
# PASO 4: Agregar repositorio de Ceph
# ============================================
log_info "Paso 4: Agregando repositorio de Ceph..."
curl -s https://download.ceph.com/keys/release.asc | gpg --dearmor | tee /usr/share/keyrings/ceph-archive-keyring.gpg > /dev/null

echo deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-quincy $(lsb_release -sc) main | tee /etc/apt/sources.list.d/ceph.list

apt-get update -qq

# ============================================
# PASO 5: Instalar Ceph
# ============================================
log_info "Paso 5: Instalando Ceph (admin)..."
apt-get install -y -qq ceph ceph-common ceph-mon ceph-osd ceph-mgr

# ============================================
# PASO 6: Limpiar
# ============================================
log_info "Paso 6: Limpiando..."
apt-get clean -qq
apt-get autoremove -y -qq

echo ""
log_info "=========================================="
log_info "  CEPH-ADMIN INICIALIZADO CORRECTAMENTE"
log_info "=========================================="
log_info "Hostname: $(hostname)"
log_info "IP Admin: 192.168.122.100"
log_info "SSH Key: /root/.ssh/id_rsa.pub"
log_info ""
log_warn "Próximos pasos:"
log_info "1. Generar UUID del cluster"
log_info "2. Crear ceph.conf"
log_info "3. Generar keyrings"
log_info "4. Copiar archivos a ceph-mon"
log_info "5. Inicializar monitors"
echo ""
