# Guía Simplificada: Cluster Ceph

## 🎯 Descripción General
Ceph es un sistema de almacenamiento distribuido que proporciona escalabilidad, confiabilidad y alto rendimiento.

---

## 📦 Componentes Principales

### **1. Ceph-mon (Monitor)**
- **Función**: Mantiene y distribuye el mapa completo del cluster
- **Responsabilidades**:
  - Monitoreo de salud del cluster
  - Almacenar el algoritmo CRUSH
  - Gestionar la configuración centralizada
  - Garantizar consistencia

### **2. Ceph-osds (Object Storage Daemons)**
- **Función**: Proporcionar almacenamiento de datos real
- **Responsabilidades**:
  - Gestionar discos físicos
  - Crear y mantener storage pools
  - Implementar interfaces de acceso (RBD, CephFS, RGW)
  - Replicación y recuperación de datos

### **3. Ceph-admin (Administrador)**
- **Función**: Punto de administración centralizado
- **Responsabilidades**:
  - Configuración inicial del cluster
  - Gestión de usuarios y permisos
  - Monitoreo y troubleshooting

---

## � Alternativa: Deploy con Docker Compose

### **Ventajas de Docker**
✅ No requiere máquinas físicas ni VMs  
✅ Emulación completa de redes con Docker networks  
✅ Fácil de crear/destruir/reiniciar  
✅ Perfecto para desarrollo y testing  
✅ Los "switches" son emulados por Docker networks  

### **Archivo docker-compose.yml Completo**

```yaml
version: '3.8'

services:
  # Red de administración
  ceph-admin:
    image: ubuntu:22.04
    container_name: ceph-admin
    hostname: ceph-admin
    networks:
      admin_net:
        ipv4_address: 192.168.122.100
    volumes:
      - admin_data:/etc/ceph
      - admin_home:/root/.ssh
    environment:
      - DEBIAN_FRONTEND=noninteractive
    privileged: true
    stdin_open: true
    tty: true
    command: /bin/bash

  ceph-mon:
    image: ubuntu:22.04
    container_name: ceph-mon
    hostname: ceph-mon
    networks:
      admin_net:
        ipv4_address: 192.168.122.10
    volumes:
      - mon_data:/var/lib/ceph
      - mon_etc:/etc/ceph
    environment:
      - DEBIAN_FRONTEND=noninteractive
    privileged: true
    stdin_open: true
    tty: true
    command: /bin/bash

  ceph-1:
    image: ubuntu:22.04
    container_name: ceph-1
    hostname: ceph-1
    networks:
      admin_net:
        ipv4_address: 192.168.122.11
      data_net:
        ipv4_address: 192.168.5.1
    volumes:
      - osd1_etc:/etc/ceph
      - osd1_var:/var/lib/ceph
      - osd1_data:/data  # Simulación de disco adicional
    environment:
      - DEBIAN_FRONTEND=noninteractive
    privileged: true
    stdin_open: true
    tty: true
    command: /bin/bash

  ceph-2:
    image: ubuntu:22.04
    container_name: ceph-2
    hostname: ceph-2
    networks:
      admin_net:
        ipv4_address: 192.168.122.12
      data_net:
        ipv4_address: 192.168.5.2
    volumes:
      - osd2_etc:/etc/ceph
      - osd2_var:/var/lib/ceph
      - osd2_data:/data
    environment:
      - DEBIAN_FRONTEND=noninteractive
    privileged: true
    stdin_open: true
    tty: true
    command: /bin/bash

  ceph-3:
    image: ubuntu:22.04
    container_name: ceph-3
    hostname: ceph-3
    networks:
      admin_net:
        ipv4_address: 192.168.122.13
      data_net:
        ipv4_address: 192.168.5.3
    volumes:
      - osd3_etc:/etc/ceph
      - osd3_var:/var/lib/ceph
      - osd3_data:/data
    environment:
      - DEBIAN_FRONTEND=noninteractive
    privileged: true
    stdin_open: true
    tty: true
    command: /bin/bash

networks:
  # Emulación del "switch" de administración
  admin_net:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.122.0/24

  # Emulación del "switch" de datos
  data_net:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.5.0/24

volumes:
  # ========================================
  # VOLÚMENES DE ADMIN NODE
  # ========================================
  admin_data:          # Almacena: /etc/ceph (configuración principal, keyrings, credenciales)
  admin_home:          # Almacena: /root/.ssh (claves SSH para conectarse a otros nodos sin contraseña)
  
  # ========================================
  # VOLÚMENES DE MONITOR NODE
  # ========================================
  mon_data:            # Almacena: /var/lib/ceph (datos del monitor, estado del cluster, mapas)
  mon_etc:             # Almacena: /etc/ceph (configuración, keyrings compartidos del cluster)
  
  # ========================================
  # VOLÚMENES DE OSD NODE 1 (ceph-1)
  # ========================================
  osd1_etc:            # Almacena: /etc/ceph (configuración compartida del cluster)
  osd1_var:            # Almacena: /var/lib/ceph (estado OSD, keyrings específicos del OSD, metadatos)
  osd1_data:           # Almacena: /data (disco virtual simulado para almacenar datos replicados)
  
  # ========================================
  # VOLÚMENES DE OSD NODE 2 (ceph-2)
  # ========================================
  osd2_etc:            # Almacena: /etc/ceph (configuración compartida del cluster)
  osd2_var:            # Almacena: /var/lib/ceph (estado OSD, keyrings específicos del OSD, metadatos)
  osd2_data:           # Almacena: /data (disco virtual simulado para almacenar datos replicados)
  
  # ========================================
  # VOLÚMENES DE OSD NODE 3 (ceph-3)
  # ========================================
  osd3_etc:            # Almacena: /etc/ceph (configuración compartida del cluster)
  osd3_var:            # Almacena: /var/lib/ceph (estado OSD, keyrings específicos del OSD, metadatos)
  osd3_data:           # Almacena: /data (disco virtual simulado para almacenar datos replicados)
```

### **Paso 0: Crear Entorno Docker**

```bash
# 1. Crear directorio para docker-compose
mkdir -p ~/ceph-docker
cd ~/ceph-docker

# 2. Guardar el docker-compose.yml (copiar el archivo arriba)
# vim docker-compose.yml

# 3. Crear y iniciar contenedores
docker-compose up -d

# 4. Verificar que todos están corriendo
docker-compose ps

# 5. Acceder a un contenedor
docker exec -it ceph-admin bash
```

### **Paso 0.1: Preparar Contenedores (dentro de cada uno)**

```bash
# Ejecutar en cada contenedor: ceph-admin, ceph-mon, ceph-1, ceph-2, ceph-3

# Actualizar sistema
apt-get update

# Instalar SSH
apt-get install -y openssh-server openssh-client

# Instalar herramientas básicas
apt-get install -y vim curl wget net-tools htop

# Limpiar
apt-get clean
```

### **Paso 0.2: Configurar SSH entre Contenedores**

```bash
# En ceph-admin
docker exec -it ceph-admin bash

# Dentro del contenedor ceph-admin:
apt-get install -y openssh-server openssh-client
mkdir -p /root/.ssh
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa

# Salir del contenedor
exit

# Copiar clave a los otros contenedores
docker cp ceph-admin:/root/.ssh/id_rsa.pub /tmp/id_rsa.pub

# Pegar en cada OSD
docker exec -it ceph-1 bash
# Dentro del contenedor:
mkdir -p /root/.ssh
exit

# Desde host:
docker cp /tmp/id_rsa.pub ceph-1:/root/.ssh/authorized_keys
docker exec ceph-1 chmod 600 /root/.ssh/authorized_keys

# Repetir para ceph-2, ceph-3, ceph-mon
```

### **Paso 0.3: Agregar Repositorio Ceph (en todos)**

```bash
# Script para ejecutar en todos los contenedores
for container in ceph-admin ceph-mon ceph-1 ceph-2 ceph-3; do
  docker exec -it $container bash -c "
    apt-get update && \
    apt-get install -y curl gnupg2 lsb-release ubuntu-keyring && \
    curl https://download.ceph.com/keys/release.asc | gpg --dearmor | tee /usr/share/keyrings/ceph-archive-keyring.gpg > /dev/null && \
    echo deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-quincy focal main | tee /etc/apt/sources.list.d/ceph.list && \
    apt-get update
  "
done
```

### **Paso 0.4: Instalar Ceph en Contenedores**

```bash
# En ceph-admin
docker exec -it ceph-admin apt-get install -y ceph ceph-common ceph-mon ceph-osd ceph-mgr ceph-deploy

# En ceph-mon
docker exec -it ceph-mon apt-get install -y ceph ceph-mon ceph-osd ceph-mgr

# En OSDs
docker exec -it ceph-1 apt-get install -y ceph ceph-osd ceph-common
docker exec -it ceph-2 apt-get install -y ceph ceph-osd ceph-common
docker exec -it ceph-3 apt-get install -y ceph ceph-osd ceph-common
```

### **Verificar Redes (Emulación de Switches)**

```bash
# Ver redes Docker creadas
docker network ls

# Ver detalles de la red de admin
docker network inspect ceph-docker_admin_net

# Ver detalles de la red de datos
docker network inspect ceph-docker_data_net

# Probar conectividad desde ceph-admin
docker exec -it ceph-admin ping 192.168.122.10  # ceph-mon
docker exec -it ceph-admin ping 192.168.5.1     # ceph-1 (data)
```

### **Comandos Útiles para Docker**

```bash
# Ver logs de un contenedor
docker-compose logs ceph-mon

# Detener todos
docker-compose down

# Reiniciar
docker-compose restart

# Ejecutar comando en contenedor
docker exec -it ceph-admin bash

# Ver uso de recursos
docker stats
```

---

## 🖥️ Configuración de Nodos (Máquinas Físicas/VMs)

### **Requisitos de Cada Nodo**

| Nodo | IP Admin | IP Datos | Rol | Requisitos |
|------|----------|----------|-----|-----------|
| ceph-admin | 192.168.122.x | - | Administración | SSH sin contraseña a otros nodos |
| ceph-mon | 192.168.122.10 | - | Monitor | 2GB RAM, 10GB disco |
| ceph-1 | 192.168.122.11 | 192.168.5.1 | OSD | 4GB RAM, Disco adicional |
| ceph-2 | 192.168.122.12 | 192.168.5.2 | OSD | 4GB RAM, Disco adicional |
| ceph-3 | 192.168.122.13 | 192.168.5.3 | OSD | 4GB RAM, Disco adicional |

### **Paso 0A: Configurar Hostname en Cada Nodo**

**En ceph-admin:**
```bash
sudo hostnamectl set-hostname ceph-admin
echo "127.0.0.1 localhost" | sudo tee /etc/hosts
echo "192.168.122.x ceph-admin" | sudo tee -a /etc/hosts
echo "192.168.122.10 ceph-mon" | sudo tee -a /etc/hosts
echo "192.168.122.11 ceph-1" | sudo tee -a /etc/hosts
echo "192.168.122.12 ceph-2" | sudo tee -a /etc/hosts
echo "192.168.122.13 ceph-3" | sudo tee -a /etc/hosts
```

**En ceph-mon:**
```bash
sudo hostnamectl set-hostname ceph-mon
echo "127.0.0.1 localhost" | sudo tee /etc/hosts
echo "192.168.122.10 ceph-mon" | sudo tee -a /etc/hosts
echo "192.168.122.11 ceph-1" | sudo tee -a /etc/hosts
echo "192.168.122.12 ceph-2" | sudo tee -a /etc/hosts
echo "192.168.122.13 ceph-3" | sudo tee -a /etc/hosts
echo "192.168.122.x ceph-admin" | sudo tee -a /etc/hosts
```

**En ceph-1, ceph-2, ceph-3:**
```bash
# En ceph-1
sudo hostnamectl set-hostname ceph-1

# En ceph-2
sudo hostnamectl set-hostname ceph-2

# En ceph-3
sudo hostnamectl set-hostname ceph-3

# En todos los OSDs - Add same /etc/hosts
echo "127.0.0.1 localhost" | sudo tee /etc/hosts
echo "192.168.122.10 ceph-mon" | sudo tee -a /etc/hosts
echo "192.168.122.11 ceph-1" | sudo tee -a /etc/hosts
echo "192.168.122.12 ceph-2" | sudo tee -a /etc/hosts
echo "192.168.122.13 ceph-3" | sudo tee -a /etc/hosts
echo "192.168.122.x ceph-admin" | sudo tee -a /etc/hosts
```

### **Paso 0B: Configurar SSH sin Contraseña**

**En ceph-admin (generar claves):**
```bash
# Generar par de claves SSH
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

# Copiar clave pública a los otros nodos
ssh-copy-id -i ~/.ssh/id_rsa.pub ceph@192.168.122.10  # ceph-mon
ssh-copy-id -i ~/.ssh/id_rsa.pub ceph@192.168.122.11  # ceph-1
ssh-copy-id -i ~/.ssh/id_rsa.pub ceph@192.168.122.12  # ceph-2
ssh-copy-id -i ~/.ssh/id_rsa.pub ceph@192.168.122.13  # ceph-3

# Verificar conexión (sin contraseña)
ssh ceph@ceph-mon "hostname"
ssh ceph@ceph-1 "hostname"
ssh ceph@ceph-2 "hostname"
ssh ceph@ceph-3 "hostname"
```

### **Paso 0C: Agregar Repositorio de Ceph en Todos los Nodos**

**Ejecutar en: ceph-admin, ceph-mon, ceph-1, ceph-2, ceph-3**

```bash
# Instalar dependencias previas
sudo apt-get update
sudo apt-get install -y curl gnupg2 lsb-release ubuntu-keyring

# Descargar e instalar clave GPG de Ceph
curl https://download.ceph.com/keys/release.asc | gpg --dearmor | sudo tee /usr/share/keyrings/ceph-archive-keyring.gpg > /dev/null

# Agregar repositorio de Ceph
echo deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-quincy $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list

# Actualizar lista de paquetes
sudo apt-get update
```

### **Paso 0D: Instalar Paquetes en Cada Nodo**

**En ceph-admin:**
```bash
sudo apt-get install -y ceph ceph-common ceph-mon ceph-osd ceph-mgr ceph-deploy
```

**En ceph-mon:**
```bash
sudo apt-get install -y ceph ceph-mon ceph-osd ceph-mgr
```

**En ceph-1, ceph-2, ceph-3 (OSDs):**
```bash
sudo apt-get install -y ceph ceph-osd ceph-common
```

---

## 🏗️ Arquitectura de Red

```
                          Internet
                            |
                        Gateway
                            |
        ________________________________________________
        |                                              |
    ceph-mon                    Cluster Principal      ceph-admin
  192.168.122.x                                       192.168.122.x
    |                   ____________                    |
    |__________________|            |___________________|
                       |                       |
                   172.16.x.x             192.168.5.x
                       |
         ____________________
         |    |    |    |    |
       ceph-1 ceph-2 ceph-3
       (OSD1) (OSD2) (OSD3)
```

### **Redes Utilizadas**:
- **Red de Administración**: 192.168.122.0/24
- **Red de Datos**: 192.168.5.0/24

---

## 🚀 Flujo de Operación

1. **Cliente** se conecta a través del gateway
2. **Ceph-admin** gestiona la configuración
3. **Ceph-mon** coordina el cluster y distribuye mapas
4. **Ceph-osds** almacenan y replican datos en los nodos

---

## 💾 Características Clave

| Característica | Descripción |
|---|---|
| **Escalabilidad** | Agregar más nodos sin parar el servicio |
| **Redundancia** | Replicación automática de datos |
| **CRUSH** | Algoritmo para gestión inteligente de placement |
| **Multi-protocolo** | RBD, CephFS, RGW |
| **Auto-healing** | Recuperación automática ante fallos |

---

## � Guía Paso a Paso: Instalación y Configuración

### **Paso 0: Agregar Repositorio de Ceph (REQUERIDO)**

```bash
# En todos los nodos (mon, osds, admin)
# Instalar dependencias previas
sudo apt-get update
sudo apt-get install -y curl gnupg2 lsb-release ubuntu-keyring

# Descargar e instalar clave GPG de Ceph
curl https://download.ceph.com/keys/release.asc | gpg --dearmor | sudo tee /usr/share/keyrings/ceph-archive-keyring.gpg > /dev/null

# Agregar repositorio de Ceph (Quincy - estable)
echo deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-quincy $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list

# Actualizar lista de paquetes
sudo apt-get update
```

**Nota**: Si necesitas otra versión de Ceph, reemplaza `debian-quincy` por:
- `debian-pacific` (versión anterior)
- `debian-reef` (versión más nueva)

---

### **Paso 1: Requisitos Previos - Instalar Paquetes**

```bash
# En todos los nodos (mon, osds, admin)
sudo apt-get install -y ceph ceph-mon ceph-osd ceph-mgr

# Verificar instalación
ceph --version
```

### **Paso 2: Crear Directorio de Cluster**

```bash
# En el nodo admin
mkdir -p /etc/ceph
cd /etc/ceph
```

### **Paso 3: Generar UUID y Fichero de Configuración**

```bash
# En el nodo admin - Generar UUID único para el cluster
fsid=$(uuidgen)
echo $fsid  # Guardar este UUID

# Crear fichero de configuración básico
cat > /etc/ceph/ceph.conf << EOF
[global]
fsid = $fsid
mon_initial_members = ceph-mon
mon_host = 192.168.122.0
public_network = 192.168.122.0/24
cluster_network = 192.168.5.0/24
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx

[mon.ceph-mon]
host = ceph-mon
addr = 192.168.122.10
priority = 10

[osd.0]
host = ceph-1

[osd.1]
host = ceph-2

[osd.2]
host = ceph-3
EOF
```

### **Paso 4: Generar Keyring de Administrador**

```bash
# En el nodo admin - Crear keyring admin
sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring \
  --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *'

# Ver el contenido (para backup)
sudo cat /etc/ceph/ceph.client.admin.keyring
```

### **Paso 5: Generar Keyring del Monitor**

```bash
# En el nodo admin
sudo ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'

# Copiar keyring admin al mon keyring
sudo ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring

# Ver resultado
sudo ceph-authtool /tmp/ceph.mon.keyring --list
```

### **Paso 6: Generar Monmap**

```bash
# En el nodo admin
sudo monmaptool --create --add ceph-mon 192.168.122.10 --fsid $fsid /tmp/monmap

# Verificar el monmap
sudo monmaptool /tmp/monmap --print
```

### **Paso 7: Crear Almacenamiento del Monitor**

```bash
# En el nodo ceph-mon
sudo mkdir -p /var/lib/ceph/mon/ceph-ceph-mon
sudo chmod 700 /var/lib/ceph/mon/ceph-ceph-mon

# Copiar ficheros desde admin a mon
# En admin:
sudo scp /etc/ceph/ceph.conf ceph@192.168.122.10:/etc/ceph/
sudo scp /tmp/ceph.mon.keyring ceph@192.168.122.10:/tmp/
sudo scp /tmp/monmap ceph@192.168.122.10:/tmp/

# En ceph-mon:
sudo ceph-mon --mkfs -i ceph-mon --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring
```

### **Paso 8: Iniciar Monitor**

```bash
# En ceph-mon
sudo systemctl start ceph-mon@ceph-mon
sudo systemctl enable ceph-mon@ceph-mon

# Verificar que está corriendo
sudo systemctl status ceph-mon@ceph-mon
sudo ceph -s  # Debe conectar al cluster
```

### **Paso 9: Generar Keyring Bootstrap OSD**

```bash
# En el nodo admin
sudo ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring \
  --gen-key -n client.bootstrap-osd \
  --cap mon 'profile bootstrap-osd' \
  --cap mgr 'allow r'

# Copiar keyring bootstrap a cada OSD
sudo scp /var/lib/ceph/bootstrap-osd/ceph.keyring ceph@192.168.5.1:/var/lib/ceph/bootstrap-osd/
sudo scp /var/lib/ceph/bootstrap-osd/ceph.keyring ceph@192.168.5.2:/var/lib/ceph/bootstrap-osd/
sudo scp /var/lib/ceph/bootstrap-osd/ceph.keyring ceph@192.168.5.3:/var/lib/ceph/bootstrap-osd/
```

### **Paso 10: Preparar Discos para OSDs**

```bash
# En cada nodo OSD (ceph-1, ceph-2, ceph-3)
# Listar discos disponibles
lsblk
sudo fdisk -l

# Preparar el disco (ejemplo: /dev/sdb)
sudo ceph-volume lvm prepare --data /dev/sdb
```

### **Paso 11: Activar OSDs**

```bash
# En cada nodo OSD
# Listar volúmenes preparados
sudo ceph-volume lvm list

# Activar volúmenes
sudo ceph-volume lvm activate 0 <uuid-generado>  # Para ceph-1 (OSD.0)
sudo ceph-volume lvm activate 1 <uuid-generado>  # Para ceph-2 (OSD.1)
sudo ceph-volume lvm activate 2 <uuid-generado>  # Para ceph-3 (OSD.2)

# Iniciar daemon OSD
sudo systemctl start ceph-osd@0
sudo systemctl enable ceph-osd@0
```

### **Paso 12: Crear Storage Pool**

```bash
# En admin o en un nodo con acceso al cluster
# Crear pool de replicación
sudo ceph osd pool create rbd 128 128 replicated

# Verificar pool creado
sudo ceph osd lspools
```

### **Paso 13: Verificar Salud del Cluster**

```bash
# Ver estado general
sudo ceph -s

# Ver detalles de salud
sudo ceph health detail

# Ver estado de OSDs
sudo ceph osd tree

# Ver uso de almacenamiento
sudo ceph df
```

---

## 🔍 Comandos Esenciales para Monitoreo

### **Estado General del Cluster**
```bash
# Ver estado resumido
ceph -s
ceph status

# Ver salud detallada
ceph health
ceph health detail

# Ver versión
ceph --version
```

### **Información de OSDs**
```bash
# Ver árbol de OSDs
ceph osd tree

# Ver uso por OSD
ceph osd df

# Ver estadísticas de OSD específico
ceph osd perf

# Marcar OSD como down (mantenimiento)
ceph osd down 0
ceph osd out 0

# Devolver OSD a normal
ceph osd in 0
```

### **Información de Monitors**
```bash
# Ver estado de monitors
ceph mon stat
ceph mon dump

# Ver quórum
ceph quorum_status
```

### **Información de Pools**
```bash
# Listar pools
ceph osd lspools

# Estadísticas de pool
ceph pool stats

# Ver detalles de pool
ceph osd pool get rbd all
```

### **Uso de Almacenamiento**
```bash
# Ver uso general
ceph df

# Ver detalles de uso
ceph df detail

# Ver bytes usados
ceph df type
```

### **Monitoring y Alertas**
```bash
# Ver logs
sudo tail -f /var/log/ceph/ceph.log

# Ver eventos
ceph event list

# Ver usuarios
ceph auth list

# Estadísticas de cluster
ceph status -f json  # Formato JSON para parsing
```

---

## 🛠️ Tareas Comunes

### **Crear Volumen RBD**
```bash
# Crear imagen
rbd create --size 10G myvolume --pool rbd

# Listar imágenes
rbd ls -p rbd

# Ver detalles
rbd info rbd/myvolume

# Mapear volumen a host
sudo rbd map rbd/myvolume

# Ver volúmenes mapeados
rbd showmapped
```

### **Expandir Pool de Almacenamiento**
```bash
# Aumentar PGs (placement groups)
ceph osd pool set rbd pg_num 256
ceph osd pool set rbd pgp_num 256

# Ver valores actuales
ceph osd pool get rbd pg_num
ceph osd pool get rbd pgp_num
```

### **Rebalanceo de Datos**
```bash
# Ver estado de rebalanceo
ceph -s  # Ver recovery ops

# Limitar velocidad de rebalanceo (si es muy lenta)
ceph tell osd.* injectargs '--osd-max-backfills 2'

# Restaurar valor default
ceph tell osd.* injectargs '--osd-max-backfills 10'
```

### **Añadir Nuevo OSD al Cluster**
```bash
# En el nuevo nodo:
sudo ceph-volume lvm prepare --data /dev/sdb

# Activar:
sudo ceph-volume lvm activate 3 <uuid>

# Iniciar:
sudo systemctl start ceph-osd@3
sudo systemctl enable ceph-osd@3

# Verificar en admin:
ceph osd tree
```

---

## 🚨 Troubleshooting Común

### **Error: Unable to locate package apt-ceph-release**

**Problema:**
```
E: Unable to locate package apt-ceph-release
```

**Solución:**
```bash
# Paso 1: Instalar dependencias previas
sudo apt-get update
sudo apt-get install -y curl gnupg2 lsb-release ubuntu-keyring

# Paso 2: Descargar e instalar clave GPG de Ceph
curl https://download.ceph.com/keys/release.asc | gpg --dearmor | sudo tee /usr/share/keyrings/ceph-archive-keyring.gpg > /dev/null

# Paso 3: Agregar repositorio oficial de Ceph
echo deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-quincy $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list

# Paso 4: Actualizar lista de paquetes
sudo apt-get update

# Paso 5: Instalar Ceph (ahora funcionará)
sudo apt-get install -y ceph ceph-mon ceph-osd ceph-mgr
```

**Versiones disponibles de Ceph** (reemplaza `quincy` en el comando):
- `debian-pacific` - Versión anterior (2021)
- `debian-quincy` - Versión estable (2022) ✅ **Recomendado**
- `debian-reef` - Versión nueva (2023)

---

### **Cluster sin Quórum**
```bash
# Forzar elección de quórum (solo si es necesario)
ceph mon force-create-initial

# Ver que monitor tiene el problema
ceph quorum_status
```

### **OSD Lento o Caído**
```bash
# Diagnosticar OSD específico
ceph daemon osd.0 perf dump

# Ver logs del OSD
sudo journalctl -u ceph-osd@0 -n 100

# Reconstruir OSD (destructivo)
sudo ceph osd crush remove osd.0
sudo ceph auth del osd.0
sudo ceph osd rm 0
```

### **Warnings de Degraded**
```bash
# Ver PGs degradados
ceph pg dump_json | grep degraded

# Forzar recuperación (cuidado - usa más recursos)
ceph health detail  # Identifica qué PGs están degradados
ceph pg deep-scrub <pg_id>
```

### **Sin Espacio en Disco**
```bash
# Ver uso:
ceph df

# Opción 1: Agregar más OSDs
# Opción 2: Aumentar pool replication (menos espacio libre)
ceph osd pool set rbd size 2
```

---

## ⚡ Notas Importantes

✅ **Mantener replicación mínima de 3** para producción  
✅ **CRUSH map** es crítico - hacer backup regularmente  
✅ **Usar monitoreo proactivo** para detectar problemas antes  
✅ **Realizar backups** periódicos del cluster state  
✅ **Segmentar tráfico**: administración vs datos  
✅ **No desactivar múltiples OSDs** simultáneamente  
✅ **Validar salud antes** de operaciones de mantenimiento  

---

## 📝 Archivos de Configuración Importantes

| Archivo | Ubicación | Propósito |
|---------|-----------|----------|
| ceph.conf | `/etc/ceph/` | Configuración principal |
| ceph.client.admin.keyring | `/etc/ceph/` | Credenciales admin |
| monmap | `/tmp/` o `/var/lib/ceph/` | Mapa de monitors |
| crushdump | `/etc/ceph/` | Algoritmo CRUSH |

---

**Última actualización**: Abril 2026  
**Versión Ceph**: Quincy o posterior recomendado
