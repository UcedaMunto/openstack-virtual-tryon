# Comandos Ejecutados en las Máquinas Virtuales

Este documento detalla **exactamente qué comandos se ejecutan dentro de cada máquina virtual** durante el deploy del cluster Ceph.

---

## 📋 Índice

1. [Phase 1: Cloud-init (Boot)](#phase-1-cloud-init-boot)
2. [Phase 2: Instalación de Repos y Paquetes](#phase-2-instalación-de-repos-y-paquetes)
3. [Phase 3: Configuración de Red (OSDs)](#phase-3-configuración-de-red-osds)
4. [Phase 4: Verificación SSH](#phase-4-verificación-ssh)
5. [Phase 5: Configuración de Ceph](#phase-5-configuración-de-ceph)
6. [Phase 6: Dashboard](#phase-6-dashboard)
7. [Por Máquina](#por-máquina)

---

## Phase 1: Cloud-init (Boot)

**Dónde:** Se ejecuta automáticamente cuando cada VM arranca (host: Ubuntu 22.04 LTS)

**Máquinas afectadas:** TODAS (ceph-admin, ceph-mon, ceph-1, ceph-2, ceph-3)

### 1.1 Setup de Usuario SSH

```bash
# Crear usuario 'ubuntu' con permisos sudo
useradd -m -s /bin/bash -G sudo ubuntu
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Agregar clave SSH pública para acceso remoto
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
print > /home/ubuntu/.ssh/authorized_keys  # Tu clave SSH pública
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
```

### 1.2 Instalación de Herramientas Básicas

```bash
# Instalar agentes de VM y SSH
apt-get install -y qemu-guest-agent openssh-server

# Habilitar servicios
systemctl enable --now qemu-guest-agent
systemctl enable --now ssh
```

### 1.3 Configuración de Red (Admin Network)

```bash
# El archivo generado por cloud-init configura netplan:
# /etc/netplan/99-cloud-init.yaml

# Configuración estática de IP según máquina:
# - ceph-admin: 192.168.130.100/24
# - ceph-mon:   192.168.130.110/24
# - ceph-1:     192.168.130.11/24
# - ceph-2:     192.168.130.12/24
# - ceph-3:     192.168.130.13/24

# Aplicar configuración de red
netplan generate
netplan apply

# Resultado: Red admin funcional con gateway 192.168.130.1
```

---

## Phase 2: Instalación de Repos y Paquetes

**Dónde:** Scripts host ejecutan vía SSH cada comando en la VM

**Máquinas afectadas:**
- ceph-admin, ceph-mon (todas)
- ceph-1, ceph-2, ceph-3 (OSDs)

### 2.1 Esperar Locks de APT

```bash
# Esperar a que cloud-init termine de instalar paquetes base
# Timeout: máx 60 intentos, 5 segundos entre intentos
while ! fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
             /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1
do
    sleep 5
done
```

### 2.2 Actualizar APT e Instalar Dependencias

```bash
# Actualizar lista de paquetes
sudo apt-get -o DPkg::Lock::Timeout=300 update -qq

# Instalar dependencias básicas
sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y \
    curl \
    gnupg \
    ca-certificates \
    lsb-release \
    ubuntu-keyring
```

### 2.3 Agregar Repositorio Ceph

```bash
# Descargar y crear anillo de claves GPG de Ceph
curl -fsSL https://download.ceph.com/keys/release.asc -o /tmp/ceph-release.asc
sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/ceph-archive-keyring.gpg /tmp/ceph-release.asc
rm -f /tmp/ceph-release.asc

# Agregar repositorio oficial de Ceph Quincy
echo 'deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] \
    https://download.ceph.com/debian-quincy jammy main' | \
    sudo tee /etc/apt/sources.list.d/ceph.list >/dev/null

# Actualizar lista con nuevo repositorio
sudo apt-get -o DPkg::Lock::Timeout=300 update -qq
```

### 2.4 Instalar Paquetes Ceph Según Rol

**En ceph-admin (admin + mgr):**
```bash
sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y \
    ceph \
    ceph-common \
    ceph-mon \
    ceph-osd \
    ceph-mgr
```

**En ceph-mon (monitor):**
```bash
sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y \
    ceph \
    ceph-common \
    ceph-mon
```

**En ceph-1, ceph-2, ceph-3 (OSDs):**
```bash
sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y \
    ceph \
    ceph-common \
    ceph-osd \
    ceph-volume \
    lvm2
```

---

## Phase 3: Configuración de Red (OSDs)

**Dónde:** Solo en máquinas OSD

**Máquinas afectadas:** ceph-1, ceph-2, ceph-3

### 3.1 Crear Archivo Netplan para Red de Datos

```bash
# En ceph-1 (igual lógica para ceph-2 y ceph-3):
cat > /etc/netplan/60-ceph-data.yaml <<EOF
network:
  version: 2
  ethernets:
    data0:
      dhcp4: false
      match:
        macaddress: "52:54:00:14:00:11"  # MAC específica para ceph-1
      set-name: data0
      addresses:
        - 192.168.140.11/24  # IP específica para ceph-1
EOF

# Permisos restrictivos de seguridad
sudo chmod 600 /etc/netplan/60-ceph-data.yaml

# Generar y aplicar configuración
sudo netplan generate
sudo netplan apply

# Resultado: Una segunda interfaz (data0) con IP en red 192.168.140.0/24
# - ceph-1: 192.168.140.11
# - ceph-2: 192.168.140.12
# - ceph-3: 192.168.140.13
```

---

## Phase 4: Verificación SSH

**Dónde:** Host verifica conectividad

**Máquinas afectadas:** TODAS

```bash
# Host ejecuta (desde el host, NO en las VMs):
# Intenta conectar vía SSH hasta 200 veces (timeout ~17 minutos)
# Verifica que SSH responda en puerto 22 de cada IP

ssh -o ConnectTimeout=10 -o BatchMode=yes ubuntu@192.168.130.100 exit
# Repite para: 192.168.130.110, 192.168.130.11, etc.
```

**En las VMs NO hay comandos explícitos; solo receptan la conexión SSH.**

---

## Phase 5: Configuración de Ceph

**Dónde:** Principalmente en ceph-admin, con spreads a otros nodos

**Máquinas afectadas:** TODAS

### 5.1 Distribuir Archivo de Configuración

**En ceph-admin, ceph-mon, ceph-1, ceph-2, ceph-3:**
```bash
# Host copia archivo /etc/ceph/ceph.conf con:
sudo mkdir -p /etc/ceph
sudo mv /tmp/ceph.conf /etc/ceph/ceph.conf

# Contenido del archivo:
# - fsid: UUID del cluster (p.ej., ac1d91d2-3b3a-424c-8016-e474baeba918)
# - mon_initial_members: ceph-mon
# - mon_host: 192.168.130.110
# - public_network: 192.168.130.0/24
# - cluster_network: 192.168.140.0/24
# - auth_cluster_required: cephx
# - auth_service_required: cephx
# - auth_client_required: cephx
# - osd_pool_default_size: 3
# - osd_pool_default_min_size: 2
# - Definiciones por OSD con public/cluster addresses
```

### 5.2 Crear Keyrings (En ceph-admin)

```bash
# Crear keyring de administrador
sudo ceph-authtool /etc/ceph/ceph.client.admin.keyring \
    --create-keyring \
    --gen-key -n client.admin \
    --cap mon 'allow *' \
    --cap osd 'allow *' \
    --cap mgr 'allow *' \
    --cap mds 'allow *'

# Crear keyring de monitor
sudo ceph-authtool /tmp/ceph.mon.keyring \
    --create-keyring \
    --gen-key -n mon. \
    --cap mon 'allow *'

# Importar admin keyring en mon keyring
sudo ceph-authtool /tmp/ceph.mon.keyring \
    --import-keyring /etc/ceph/ceph.client.admin.keyring

# Crear monmap con ID del cluster
sudo monmaptool --clobber --create \
    --add ceph-mon 192.168.130.110 \
    --fsid ac1d91d2-3b3a-424c-8016-e474baeba918 \
    /tmp/monmap
```

### 5.3 Inicializar Monitor (En ceph-mon)

```bash
# Crear directorio del monitor
sudo mkdir -p /var/lib/ceph/mon/ceph-ceph-mon

# Inicializar datos del monitor (mkfs)
sudo ceph-mon --mkfs \
    -i ceph-mon \
    --monmap /tmp/monmap \
    --keyring /tmp/ceph.mon.keyring

# Cambiar propietario a usuario 'ceph'
sudo chown -R ceph:ceph /var/lib/ceph/mon/ceph-ceph-mon

# Iniciar el daemon de monitor
sudo systemctl enable --now ceph-mon@ceph-mon

# Verificar que está activo
sudo systemctl status ceph-mon@ceph-mon
```

### 5.4 Distribuir Admin Keyring

**En ceph-mon, ceph-1, ceph-2, ceph-3:**
```bash
# Host copia el keyring admin
sudo mkdir -p /etc/ceph
sudo mv /tmp/ceph.client.admin.keyring /etc/ceph/ceph.client.admin.keyring
```

### 5.5 Inicializar Manager (En ceph-admin)

```bash
# Crear directorio del manager
sudo mkdir -p /var/lib/ceph/mgr/ceph-ceph-admin

# Crear keyring para manager
sudo ceph auth get-or-create mgr.ceph-admin \
    mon 'allow profile mgr' \
    osd 'allow *' \
    mds 'allow *' \
    -o /var/lib/ceph/mgr/ceph-ceph-admin/keyring

# Cambiar propietario
sudo chown -R ceph:ceph /var/lib/ceph/mgr/ceph-ceph-admin

# Iniciar el daemon de manager
sudo systemctl enable --now ceph-mgr@ceph-admin
```

### 5.6 Crear Bootstrap OSD Keyring (En ceph-admin)

```bash
# Crear directorio bootstrap
sudo mkdir -p /var/lib/ceph/bootstrap-osd

# Crear keyring para bootstrap de OSDs
sudo ceph auth get-or-create client.bootstrap-osd \
    mon 'allow profile bootstrap-osd' \
    -o /var/lib/ceph/bootstrap-osd/ceph.keyring
```

### 5.7 Distribuir Bootstrap OSD Keyring

**En ceph-1, ceph-2, ceph-3:**
```bash
# Crear directorio
sudo mkdir -p /var/lib/ceph/bootstrap-osd

# Copiar keyring
sudo cp /tmp/bootstrap-osd.keyring /var/lib/ceph/bootstrap-osd/ceph.keyring

# También copiar en ubicación para cliente
sudo cp /tmp/bootstrap-osd.keyring /etc/ceph/ceph.client.bootstrap-osd.keyring
```

### 5.8 Preparar OSDs con LVM (En ceph-1, ceph-2, ceph-3)

```bash
# Limpiar el disco antes de crear LVM
sudo wipefs -a /dev/vdb

# Usar ceph-volume para preparar OSD
sudo ceph-volume lvm create \
    --bluestore \
    --data /dev/vdb

# Resultado: LVM volume creado, OSD inicializado y activado
# El daemon ceph-osd se inicia automáticamente

# Para verificar:
sudo ceph-volume lvm list
# Muestra: [ceph_data] --> [ceph_block] mappings
```

### 5.9 Esperar OSDs Operacionales

**En ceph-admin (verificación):**
```bash
# Loop hasta que los 3 OSDs estén up/in:
sudo ceph osd stat
# Salida esperada: "3 osds: 3 up, 3 in"

# Ver árbol de OSDs:
sudo ceph osd tree
# Muestra: ceph-1, ceph-2, ceph-3 como DOWN -> UP
```

### 5.10 Crear Pools (En ceph-admin)

```bash
# Crear pool RBD estándar
sudo ceph osd pool create rbd 128 128 replicated

# Inicializar pool para RBD
sudo rbd pool init rbd

# Verificar:
sudo ceph osd lspools
# Salida: 3 pools: .mgr, rbd, cephfs_metadata (si aplica)
```

---

## Phase 6: Dashboard

**Dónde:** ceph-admin

**Máquinas afectadas:** ceph-admin

### 6.1 Habilitar Módulo Dashboard

```bash
# Activar el módulo dashboard en el manager
sudo ceph mgr module enable dashboard
```

### 6.2 Crear Certificado SSL Autofirmado

```bash
# Generar certificado autofirmado para HTTPS
sudo ceph dashboard create-self-signed-cert

# Ubicación: /etc/ceph/dashboard-* o similar
```

### 6.3 Configurar IP y Puerto del Dashboard

```bash
# Configurar la IP del servidor dashboard
sudo ceph config set mgr mgr/dashboard/server_addr 192.168.130.100

# Configurar el puerto (default 8443)
sudo ceph config set mgr mgr/dashboard/server_port 8443
```

### 6.4 Configurar Usuario y Contraseña

```bash
# Crear archivo temporal con contraseña
printf '%s' 'AdminCeph2026!' | sudo tee /tmp/dashboard_password.txt >/dev/null

# Crear usuario admin en dashboard
sudo ceph dashboard ac-user-create admin \
    -i /tmp/dashboard_password.txt \
    administrator

# O actualizar si ya existe:
sudo ceph dashboard ac-user-set-password admin \
    -i /tmp/dashboard_password.txt

# Limpiar archivo temporal (seguridad)
sudo rm -f /tmp/dashboard_password.txt
```

### 6.5 Verificación Final

```bash
# Ver estado del cluster
sudo ceph -s

# Resultado esperado:
# - Cluster HEALTH_OK o HEALTH_WARN
# - 3 OSDs up/in
# - 1 monitor activo
# - 1 manager activo
# - Pools creados
```

---

## Por Máquina

### **ceph-admin**

| Fase | Comandos | Descripción |
|------|----------|-------------|
| Cloud-init | SSH setup, qemu-agent, openssh | Boot inicial |
| Instalación | curl, gnupg, lsb-release, ceph completo | Todos los roles de Ceph |
| Keyrings | ceph-authtool, monmaptool | Crear claves y monmap |
| Manager | ceph-mgr mkfs, start ceph-mgr@ceph-admin | Inicializar manager |
| Bootstrap OSD | ceph auth get-or-create bootstrap-osd | Crear keyring para OSDs |
| Pools | ceph osd pool create rbd | Crear storage pools |
| Dashboard | ceph mgr module enable, config set, ac-user-create | Configurar dashboard |

### **ceph-mon**

| Fase | Comandos | Descripción |
|------|----------|-------------|
| Cloud-init | SSH setup, qemu-agent, openssh | Boot inicial |
| Instalación | curl, gnupg, ceph-mon + deps | Solo monitor |
| Monitor mkfs | ceph-mon --mkfs | Inicializar datos del monitor |
| Start | systemctl enable --now ceph-mon@ceph-mon | Iniciar monitor daemon |

### **ceph-1, ceph-2, ceph-3** (OSDs)

| Fase | Comandos | Descripción |
|------|----------|-------------|
| Cloud-init | SSH setup, qemu-agent, openssh, netplan (admin) | Boot inicial + admin network |
| Config Red | netplan: agregar data0 con IP 192.168.140.x | Segunda interfaz para datos |
| Instalación | curl, gnupg, ceph-osd, ceph-volume, lvm2 | OSD y tools |
| Keyrings | cp bootstrap-osd.keyring | Recibir credentials para OSD |
| OSD Creation | ceph-volume lvm create --bluestore --data /dev/vdb | Crear y activar OSD |

---

## 🔍 Verificación de Comandos Ejecutados

### Verificar en ceph-admin:

```bash
# Ver todos los comandos ejecutados en la VM:
journalctl -u ceph-mon@ceph-mon -n 50          # Monitor logs
journalctl -u ceph-mgr@ceph-admin -n 50        # Manager logs
journalctl -u ceph-osd@0 -n 50                 # OSD logs (si aplica)

# Ver configuración de Ceph
cat /etc/ceph/ceph.conf

# Ver keyrings
sudo ls -l /etc/ceph/*.keyring

# Ver daemons en ejecución
ps aux | grep ceph

# Ver estado del cluster
sudo ceph -s
sudo ceph osd tree
sudo ceph mon status
```

### Verificar en ceph-1 (OSD):

```bash
# Ver configuración de redes
ip addr show

# Ver volúmenes LVM creados
sudo lvs

# Ver estado de OSD
sudo ceph-volume lvm list

# Ver logs del OSD
journalctl -u ceph-osd@* -n 50
```

---

## 📝 Notas Importantes

1. **Cloud-init ejecuta al boot una sola vez**: No se repite al reiniciar la VM
2. **SSH espera**: El script host reintenta hasta 200 veces (17 minutos)
3. **Locks de APT**: Se manejan con timeout de 300 segundos para evitar conflictos
4. **Redes**: Admin Network (eth0) se configura vía cloud-init; Data Network (eth1) se agrega post-boot
5. **Keyrings**: Se crean en ceph-admin y se distribuyen vía SCP
6. **OSDs**: Se preparan con `ceph-volume lvm create`, NO con comandos manuales
7. **Idempotencia**: El script verifica si componentes ya existen antes de recrearlos
8. **Dashboard**: Solo en ceph-admin, puerto 8443, usuario: admin

---

## 🚀 Próximos Pasos

Después que todos los comandos se han ejecutado exitosamente:

```bash
# Desde el host, acceder al cluster:
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 "sudo ceph -s"

# Acceder al dashboard:
# https://192.168.130.100:8443
# usuario: admin
# contraseña: AdminCeph2026!

# Crear un RBD volume de prueba:
ssh ubuntu@192.168.130.100 "sudo rbd create test-vol --pool rbd --size 1G"
```
