#!/bin/bash

set -e

echo "=========================================="
echo "  INICIANDO CEPH-OSD"
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
    python3-packaging \
    udev \
    util-linux \
    kmod \
    vim \
    net-tools \
    htop \
    lvm2 \
    ceph-volume

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
# PASO 5: Instalar Ceph OSD
# ============================================
log_info "Paso 5: Instalando Ceph OSD..."
apt-get install -y -qq ceph ceph-osd ceph-common ceph-volume

# ============================================
# PASO 6: Crear directorios
# ============================================
log_info "Paso 6: Creando directorios..."

if ! id ceph > /dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin ceph
fi

mkdir -p /var/lib/ceph/osd
chmod 755 /var/lib/ceph/osd
mkdir -p /etc/ceph
chmod 755 /etc/ceph
mkdir -p /data
chmod 755 /data

# ============================================
# PASO 7: Crear volumen LVM simulado
# ============================================
log_info "Paso 7: Preparando almacenamiento..."
# En Docker, usamos /data como simulación de disco físico
# En producción, aquí se usarían discos reales

if [ ! -d "/data/osd" ]; then
    mkdir -p /data/osd
    log_info "Directorio de datos OSD creado: /data/osd"
fi

if [ ! -f "/data/osd-${OSD_ID:-0}.img" ]; then
    truncate -s "${OSD_DEVICE_SIZE:-5G}" "/data/osd-${OSD_ID:-0}.img"
    log_info "Archivo de disco OSD creado: /data/osd-${OSD_ID:-0}.img"
fi

# ============================================
# PASO 8: Limpiar
# ============================================
log_info "Paso 8: Limpiando..."
apt-get clean -qq
apt-get autoremove -y -qq

echo ""
log_info "=========================================="
log_info "  CEPH-OSD INICIALIZADO CORRECTAMENTE"
log_info "=========================================="
log_info "Hostname: $(hostname)"
log_info "OSD ID: ${OSD_ID}"
log_info "IP Admin: 192.168.122.$((11 + ${OSD_ID:-0}))"
log_info "IP Datos: 192.168.5.$((11 + ${OSD_ID:-0}))"
log_info "Directorio datos: /data/osd"
log_info "Disco simulado: /data/osd-${OSD_ID:-0}.img"
log_info ""
log_warn "Próximos pasos:"
log_info "1. Esperar a que ceph-admin copie ceph.conf y keyrings"
log_info "2. Ejecutar: losetup --find --show /data/osd-${OSD_ID:-0}.img"
log_info "3. Ejecutar: ceph-volume lvm prepare --bluestore --data /dev/loopX --no-systemd"
log_info "4. Iniciar daemon: ceph-osd -i ${OSD_ID} --setuser root --setgroup root -f"
echo ""
