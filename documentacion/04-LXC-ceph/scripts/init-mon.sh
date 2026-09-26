#!/bin/bash

set -e

echo "=========================================="
echo "  INICIANDO CEPH-MON"
echo "=========================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
    htop

# ============================================
# PASO 3: Configurar SSH
# ============================================
log_info "Paso 3: Configurando SSH..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh

mkdir -p /run/sshd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# ============================================
# PASO 4: Agregar repositorio de Ceph
# ============================================
log_info "Paso 4: Agregando repositorio de Ceph..."
curl -s https://download.ceph.com/keys/release.asc | gpg --dearmor | tee /usr/share/keyrings/ceph-archive-keyring.gpg > /dev/null

echo deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-quincy $(lsb_release -sc) main | tee /etc/apt/sources.list.d/ceph.list

apt-get update -qq

# ============================================
# PASO 5: Instalar Ceph Monitor
# ============================================
log_info "Paso 5: Instalando Ceph Monitor..."
apt-get install -y -qq ceph ceph-mon ceph-osd ceph-mgr ceph-common

# ============================================
# PASO 6: Crear directorios
# ============================================
log_info "Paso 6: Creando directorios..."
mkdir -p /var/lib/ceph/mon
chmod 700 /var/lib/ceph/mon
mkdir -p /etc/ceph
chmod 755 /etc/ceph

# ============================================
# PASO 7: Limpiar
# ============================================
log_info "Paso 7: Limpiando..."
apt-get clean -qq
apt-get autoremove -y -qq

echo ""
log_info "=========================================="
log_info "  CEPH-MON INICIALIZADO CORRECTAMENTE"
log_info "=========================================="
log_info "Hostname: $(hostname)"
log_info "IP Admin: 192.168.122.10"
log_info "Directorio datos: /var/lib/ceph/mon"
log_info ""
log_warn "Próximos pasos:"
log_info "1. Esperar a que ceph-admin copie los archivos de configuración"
log_info "2. Ejecutar: ceph-mon --mkfs"
log_info "3. Iniciar daemon: ceph-mon -i ceph-mon --setuser root --setgroup root -f"
echo ""
