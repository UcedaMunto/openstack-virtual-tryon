#!/bin/bash

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Credenciales por defecto del Dashboard (se pueden sobreescribir por variables de entorno)
DASHBOARD_USER="${DASHBOARD_USER:-admin}"
DASHBOARD_PASSWORD="${DASHBOARD_PASSWORD:-AdminCeph2026!}"

# Imprime mensajes informativos en color verde.
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Imprime mensajes de error en color rojo.
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Imprime advertencias en color amarillo.
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Imprime un separador visual para cada etapa del script.
log_title() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# Espera hasta que el cluster responda a 'ceph -s' o falla por timeout.
wait_for_ceph() {
    local description="$1"
    local attempts="${2:-30}"

    for attempt in $(seq 1 "$attempts"); do
        if docker exec ceph-admin ceph -s > /dev/null 2>&1; then
            log_info "✓ $description"
            return 0
        fi
        sleep 5
    done

    log_error "No fue posible contactar al cluster Ceph"
    return 1
}

# Espera hasta que el numero esperado de OSDs esté en estado up/in.
wait_for_osds() {
    local expected="$1"

    for attempt in $(seq 1 30); do
        local osd_status
        osd_status=$(docker exec ceph-admin ceph osd stat 2>/dev/null || true)

        if echo "$osd_status" | grep -q "${expected} osds: ${expected} up" && \
           echo "$osd_status" | grep -q "${expected} in"; then
            log_info "✓ Todos los OSDs están activos"
            return 0
        fi
        sleep 5
    done

    log_error "Los OSDs no alcanzaron el estado esperado"
    return 1
}

# Inicia el daemon ceph-mon si todavía no está ejecutándose.
ensure_monitor_running() {
    if docker exec ceph-mon pgrep -x ceph-mon > /dev/null 2>&1; then
        log_info "El monitor ya está corriendo"
        return 0
    fi

    log_info "Iniciando daemon del monitor..."
    docker exec -d ceph-mon bash -lc '/usr/bin/ceph-mon -i ceph-mon --setuser root --setgroup root -f'
}

# Inicia el daemon ceph-mgr si todavía no está ejecutándose.
ensure_mgr_running() {
    if docker exec ceph-admin pgrep -x ceph-mgr > /dev/null 2>&1; then
        log_info "El manager ya está corriendo"
        return 0
    fi

    log_info "Iniciando daemon del manager..."
    docker exec -d ceph-admin bash -lc '/usr/bin/ceph-mgr -i ceph-admin --setuser root --setgroup root -f'
}

# Obtiene o crea un loop device asociado a la imagen de disco del OSD.
prepare_loop_device() {
    local container="$1"
    local osd_id="$2"

    docker exec "$container" bash -lc "
        set -e
        image=/data/osd-${osd_id}.img

        for stale_loop in \$(losetup -a | awk -F: '/\/osd-[0-9]+\\.img \(deleted\)/ {print \$1}'); do
            losetup -d \"\$stale_loop\" || true
        done

        if [ ! -f \"\$image\" ]; then
            truncate -s \"\${OSD_DEVICE_SIZE:-5G}\" \"\$image\"
        fi

        loop_device=\$(losetup -j \"\$image\" | cut -d: -f1 | head -n 1)
        if [ -n \"\$loop_device\" ]; then
            echo \"\$loop_device\"
        else
            candidate=\$(losetup --find)
            if [ ! -b \"\$candidate\" ]; then
                loop_number=\${candidate#/dev/loop}
                mknod -m 660 \"\$candidate\" b 7 \"\$loop_number\"
                chown root:disk \"\$candidate\" || true
            fi
            losetup \"\$candidate\" \"\$image\"
            echo \"\$candidate\"
        fi
    "
}

# Inicia el daemon ceph-osd para un OSD específico si no está activo.
start_osd_daemon() {
    local container="$1"
    local osd_id="$2"

    if docker exec "$container" pgrep -f "ceph-osd -i ${osd_id}" > /dev/null 2>&1; then
        log_info "OSD ${osd_id} ya está corriendo"
        return 0
    fi

    log_info "Iniciando daemon del OSD ${osd_id} en ${container}..."
    docker exec -d "$container" bash -lc "/usr/bin/ceph-osd -i ${osd_id} --setuser root --setgroup root -f"
}

# Verifica que todos los contenedores esperados estén en ejecución.
verify_containers() {
    log_info "Verificando contenedores..."
    
    for container in ceph-admin ceph-mon ceph-1 ceph-2 ceph-3; do
        if ! docker exec $container hostname > /dev/null 2>&1; then
            log_error "Contenedor $container no está corriendo"
            exit 1
        fi
    done
    log_info "✓ Todos los contenedores están corriendo"
}

# Espera a que cada contenedor complete su init y tenga binarios clave disponibles.
wait_for_initialization() {
    log_info "Esperando a que los contenedores terminen su inicialización interna..."

    for attempt in $(seq 1 60); do
        if docker exec ceph-admin test -f /root/.ssh/id_rsa.pub && \
           docker exec ceph-admin bash -lc 'command -v ceph > /dev/null 2>&1' && \
           docker exec ceph-mon bash -lc 'command -v ceph-mon > /dev/null 2>&1' && \
           docker exec ceph-1 bash -lc 'id ceph > /dev/null 2>&1 && command -v ceph-volume > /dev/null 2>&1 && command -v ceph-bluestore-tool > /dev/null 2>&1' && \
           docker exec ceph-2 bash -lc 'id ceph > /dev/null 2>&1 && command -v ceph-volume > /dev/null 2>&1 && command -v ceph-bluestore-tool > /dev/null 2>&1' && \
           docker exec ceph-3 bash -lc 'id ceph > /dev/null 2>&1 && command -v ceph-volume > /dev/null 2>&1 && command -v ceph-bluestore-tool > /dev/null 2>&1'; then
            log_info "✓ Dependencias y archivos base listos"
            return 0
        fi

        sleep 5
    done

    log_error "Los contenedores no completaron la inicialización a tiempo"
    return 1
}

# ============================================
# PASO 1: Esperar inicialización
# ============================================
log_title "PASO 1: Esperando inicialización de contenedores"
log_info "Esperando 10 segundos para que se complete la inicialización..."
sleep 10

verify_containers
wait_for_initialization

# ============================================
# PASO 2: Copiar claves SSH
# ============================================
log_title "PASO 2: Configurando SSH entre contenedores"

log_info "Copiando clave pública de ceph-admin..."
docker exec ceph-admin cat /root/.ssh/id_rsa.pub > /tmp/ceph_admin_key.pub

for container in ceph-mon ceph-1 ceph-2 ceph-3; do
    log_info "Agregando clave a $container..."
    docker cp /tmp/ceph_admin_key.pub $container:/tmp/id_rsa.pub
    docker exec $container bash -c "cat /tmp/id_rsa.pub >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
done

log_info "✓ SSH configurado"

# ============================================
# PASO 3: Generar UUID del cluster
# ============================================
log_title "PASO 3: Generando UUID del cluster"

FSID=$(uuidgen)
log_warn "UUID generado: $FSID"
log_warn "⚠️  GUARDAR ESTE UUID - Lo necesitarás"
echo $FSID > /tmp/fsid.txt

# ============================================
# PASO 4: Crear ceph.conf
# ============================================
log_title "PASO 4: Creando archivo ceph.conf"

cat > /tmp/ceph.conf << EOF
[global]
fsid = $FSID
mon_initial_members = ceph-mon
mon_host = 192.168.122.10
public_network = 192.168.122.0/24
cluster_network = 192.168.5.0/24
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
osd_pool_default_size = 3
osd_pool_default_min_size = 2
osd_crush_chooseleaf_type = 1

[mon.ceph-mon]
host = ceph-mon
addr = 192.168.122.10
priority = 10

[osd.0]
host = ceph-1
public_addr = 192.168.122.11
cluster_addr = 192.168.5.11

[osd.1]
host = ceph-2
public_addr = 192.168.122.12
cluster_addr = 192.168.5.12

[osd.2]
host = ceph-3
public_addr = 192.168.122.13
cluster_addr = 192.168.5.13
EOF

log_info "Copiando ceph.conf a todos los nodos..."
docker cp /tmp/ceph.conf ceph-admin:/etc/ceph/ceph.conf
docker cp /tmp/ceph.conf ceph-mon:/etc/ceph/ceph.conf
docker cp /tmp/ceph.conf ceph-1:/etc/ceph/ceph.conf
docker cp /tmp/ceph.conf ceph-2:/etc/ceph/ceph.conf
docker cp /tmp/ceph.conf ceph-3:/etc/ceph/ceph.conf

log_info "✓ ceph.conf creado y distribuido"

# ============================================
# PASO 5: Generar Keyrings
# ============================================
log_title "PASO 5: Generando keyrings"

log_info "Generando ceph.client.admin.keyring..."
docker exec ceph-admin bash -c "
  ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring \
    --gen-key -n client.admin \
    --cap mon 'allow *' \
    --cap osd 'allow *' \
        --cap mgr 'allow *' \
    --cap mds 'allow *'
"

log_info "Generando ceph.mon.keyring..."
docker exec ceph-admin bash -c "
  ceph-authtool --create-keyring /tmp/ceph.mon.keyring \
    --gen-key -n mon. \
    --cap mon 'allow *' && \
  ceph-authtool /tmp/ceph.mon.keyring \
    --import-keyring /etc/ceph/ceph.client.admin.keyring
"

log_info "Copiando keyrings..."
docker exec ceph-admin bash -c "cp /tmp/ceph.mon.keyring /etc/ceph/"
docker cp ceph-admin:/etc/ceph/ceph.client.admin.keyring /tmp/
docker cp ceph-admin:/etc/ceph/ceph.mon.keyring /tmp/

# Distribuir a cada nodo
docker cp /tmp/ceph.client.admin.keyring ceph-mon:/etc/ceph/
docker cp /tmp/ceph.mon.keyring ceph-mon:/etc/ceph/
docker cp /tmp/ceph.client.admin.keyring ceph-1:/etc/ceph/
docker cp /tmp/ceph.client.admin.keyring ceph-2:/etc/ceph/
docker cp /tmp/ceph.client.admin.keyring ceph-3:/etc/ceph/

log_info "✓ Keyrings generados y distribuidos"

# ============================================
# PASO 6: Generar Monmap
# ============================================
log_title "PASO 6: Generando monmap"

docker exec ceph-admin bash -c "
  monmaptool --create \
    --add ceph-mon 192.168.122.10 \
    --fsid $FSID \
    /tmp/monmap
"

docker cp ceph-admin:/tmp/monmap /tmp/
docker cp /tmp/monmap ceph-mon:/tmp/

log_info "✓ Monmap generado"

# ============================================
# PASO 7: Inicializar Monitor
# ============================================
log_title "PASO 7: Inicializando Monitor (ceph-mon)"

docker exec ceph-mon bash -c "
  mkdir -p /var/lib/ceph/mon/ceph-ceph-mon && \
  chmod 700 /var/lib/ceph/mon/ceph-ceph-mon && \
  ceph-mon --mkfs -i ceph-mon \
    --monmap /tmp/monmap \
    --keyring /etc/ceph/ceph.mon.keyring
"

ensure_monitor_running
wait_for_ceph "El monitor responde a comandos Ceph"

log_info "✓ Monitor inicializado"

# ============================================
# PASO 7.1: Inicializar Manager
# ============================================
log_title "PASO 7.1: Inicializando Manager (ceph-admin)"

docker exec ceph-admin bash -c "
    mkdir -p /var/lib/ceph/mgr/ceph-ceph-admin && \
    ceph auth get-or-create mgr.ceph-admin \
        mon 'allow profile mgr' \
        osd 'allow *' \
        mds 'allow *' \
        -o /var/lib/ceph/mgr/ceph-ceph-admin/keyring
"

ensure_mgr_running
wait_for_ceph "El manager quedó operativo"

log_info "✓ Manager inicializado"

# ============================================
# PASO 8: Generar Bootstrap OSD Key
# ============================================
# 
# ¿QUÉ ES EL BOOTSTRAP OSD KEY?
# 
# Es una credencial especial (keyring) que permite que los OSDs se 
# inicialicen y se registren automáticamente en el cluster sin necesidad
# de intervención manual.
# 
# FUNCIÓN:
# - Los nuevos OSDs usan este key para autenticarse con el monitor
# - El monitor verifica que es un OSD legítimo usando este key
# - Después de registrarse, el OSD obtiene su propio keyring individual
# - El monitor reemplaza automáticamente este key temporal por uno permanente
#
# PERMISOS:
# - 'profile bootstrap-osd': Permisos limitados SOLO para inicializarse
# - 'allow r': Lectura en el MGR (opcional, para reportes)
#
# ANALÓGÍA:
# Es como un "pase temporal" que dice "Soy un OSD nuevo, déjame entrar".
# Una vez dentro, el monitor te da un "pase permanente" (keyring del OSD).
#
# ============================================
log_title "PASO 8: Generando bootstrap OSD key"

docker exec ceph-admin bash -c "
  mkdir -p /var/lib/ceph/bootstrap-osd && \
    if ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring > /dev/null 2>&1; then \
        true; \
    else \
        ceph auth get-or-create client.bootstrap-osd \
            mon 'profile bootstrap-osd' \
            -o /var/lib/ceph/bootstrap-osd/ceph.keyring; \
    fi && \
    cp /var/lib/ceph/bootstrap-osd/ceph.keyring /etc/ceph/ceph.client.bootstrap-osd.keyring
"

# Copiar a cada OSD
docker cp ceph-admin:/etc/ceph/ceph.client.bootstrap-osd.keyring /tmp/bootstrap-osd.keyring

for container in ceph-1 ceph-2 ceph-3; do
    docker exec $container bash -c "
        mkdir -p /var/lib/ceph/bootstrap-osd && \
        chmod 700 /var/lib/ceph/bootstrap-osd
    "
        docker cp /tmp/bootstrap-osd.keyring $container:/var/lib/ceph/bootstrap-osd/ceph.keyring
        docker cp /tmp/bootstrap-osd.keyring $container:/etc/ceph/ceph.client.bootstrap-osd.keyring
done

log_info "✓ Bootstrap OSD key generado"

# ============================================
# PASO 9: Inicializar OSDs
# ============================================
log_title "PASO 9: Inicializando OSDs"

for i in 0 1 2; do
    container="ceph-$((i+1))"
    log_info "Preparando OSD $i en $container..."

    loop_device=$(prepare_loop_device "$container" "$i")
    log_info "Usando dispositivo ${loop_device} para OSD $i"

    docker exec "$container" bash -lc "
        set -e
        CEPH_VOLUME_ALLOW_LOOP_DEVICES=true ceph-volume raw prepare \
            --bluestore \
            --data ${loop_device} \
            --osd-id ${i}
    "

    log_info "Activando OSD $i en $container..."
    docker exec "$container" bash -lc "
        set -e
        CEPH_VOLUME_ALLOW_LOOP_DEVICES=true ceph-volume raw activate \
            --device ${loop_device} \
            --no-systemd \
            --no-tmpfs
    "

    start_osd_daemon "$container" "$i"
done

wait_for_osds 3

log_info "✓ OSDs inicializados"

# ============================================
# PASO 10: Crear Pool RBD
# ============================================
log_title "PASO 10: Creando pool de almacenamiento"

log_info "Esperando a que el cluster esté listo..."
wait_for_ceph "El cluster responde antes de crear el pool"

if ! docker exec ceph-admin ceph osd pool ls | grep -qx "rbd"; then
    docker exec ceph-admin ceph osd pool create rbd 128 128 replicated
    log_info "✓ Pool RBD creado"
else
    log_info "El pool RBD ya existe"
fi

docker exec ceph-admin rbd pool init rbd > /dev/null 2>&1 || true

# ============================================
# PASO 11: Configurar Dashboard Web
# ============================================
log_title "PASO 11: Configurando Dashboard Web"

docker exec ceph-admin bash -lc '
    set -e
    ceph mgr module enable dashboard
    ceph dashboard create-self-signed-cert
    ceph config set mgr mgr/dashboard/server_addr 0.0.0.0
    ceph config set mgr mgr/dashboard/server_port 8443
'

docker exec ceph-admin bash -lc "
    set -e
    if ceph dashboard ac-user-show ${DASHBOARD_USER} > /dev/null 2>&1; then
        ceph dashboard ac-user-set-password ${DASHBOARD_USER} -i <(printf '%s' '${DASHBOARD_PASSWORD}')
    else
        ceph dashboard ac-user-create ${DASHBOARD_USER} -i <(printf '%s' '${DASHBOARD_PASSWORD}') administrator
    fi
"

log_info "✓ Dashboard configurado"

# ============================================
# RESUMEN FINAL
# ============================================
log_title "✓ CLUSTER CEPH CONFIGURADO"

echo ""
log_info "UUID del Cluster: $FSID"
log_info ""
log_warn "Próximas acciones:"
log_info "1. Verificar salud: docker exec ceph-admin ceph status"
log_info "2. Ver OSDs: docker exec ceph-admin ceph osd tree"
log_info "3. Dashboard: https://localhost:8443"
log_info "4. Usuario dashboard: ${DASHBOARD_USER}"
log_info "5. Password dashboard: ${DASHBOARD_PASSWORD}"
log_info "6. Usar Ceph: docker exec ceph-admin bash"
log_info ""
log_warn "Para detener todo:"
log_info "docker-compose down"
log_info ""
log_warn "Para reanude:"
log_info "docker-compose up -d"
echo ""
