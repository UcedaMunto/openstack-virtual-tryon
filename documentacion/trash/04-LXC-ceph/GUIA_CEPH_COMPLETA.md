# Guía Simplificada: Cluster Ceph con Docker Compose

> **📊 Estado Actual**: Monitor ✓ operativo | Cluster ID: `19a36932-f71f-4811-8911-777512b256ba` | [Ver detalles en ESTADO_FINAL.md](../../../ceph-docker/ESTADO_FINAL.md)

## Descripción General
Ceph es un sistema de almacenamiento distribuido que proporciona escalabilidad, confiabilidad y alto rendimiento.

---

## Componentes Principales

### **1. Ceph-mon (Monitor)**
- **Función**: Mantiene y distribuye el mapa completo del cluster
- **Responsabilidades**:
  - Monitoreo de salud del cluster
  - Almacenar el algoritmo CRUSH
  - Gestionar la configuración centralizada

### **2. Ceph-osds (Object Storage Daemons)**
- **Función**: Proporcionar almacenamiento de datos real
- **Responsabilidades**:
  - Gestionar discos físicos
  - Crear y mantener storage pools
  - Implementar interfaces de acceso (RBD, CephFS, RGW)

### **3. Ceph-admin (Administrador)**
- **Función**: Punto de administración centralizado
- **Responsabilidades**:
  - Configuración inicial del cluster
  - Gestión de usuarios y permisos
  - Monitoreo y troubleshooting

---

## INICIO RÁPIDO - 3 Comandos

```bash
# 1. Levantar contenedores
docker-compose up -d

# 2. Esperar y ejecutar setup (espera 15 segundos)
sleep 15
bash scripts/setup-cluster.sh

# 3. Verificar
docker exec -it ceph-admin ceph status
```

---

## Estructura de Archivos Necesarios

```
ceph-docker/
├── docker-compose.yml
├── scripts/
│   ├── init-admin.sh
│   ├── init-mon.sh
│   ├── init-osd.sh
│   └── setup-cluster.sh
└── GUIA_CEPH_CLUSTER.md
```

---

## Deploy Completo - Paso a Paso

### Paso 1: Preparar Directorio

```bash
mkdir -p ~/ceph-docker/scripts
cd ~/ceph-docker

# Descargar o copiar archivos:
# - docker-compose.yml
# - scripts/init-admin.sh
# - scripts/init-mon.sh
# - scripts/init-osd.sh
# - scripts/setup-cluster.sh
```

### Paso 2: Levantar Contenedores

```bash
docker-compose up -d

# Esperar a inicialización
sleep 10

# Verificar estado
docker-compose ps
```

Salida esperada:
```
CONTAINER ID   IMAGE          STATUS
ceph-admin     ubuntu:22.04   Up 1 minute
ceph-mon       ubuntu:22.04   Up 1 minute
ceph-1         ubuntu:22.04   Up 1 minute
ceph-2         ubuntu:22.04   Up 1 minute
ceph-3         ubuntu:22.04   Up 1 minute
```

### Paso 3: Ejecutar Script de Configuración

```bash
bash scripts/setup-cluster.sh
```

Este script automáticamente:
- Configura SSH entre contenedores
- Genera UUID del cluster
- Crea ceph.conf
- Genera keyrings y monmap
- Inicializa monitor
- Inicializa OSDs
- Crea pool RBD

Salida esperada al final:
```
================================================
  CLUSTER CEPH CONFIGURADO
================================================
UUID del Cluster: xxxxx-xxxxx-xxxxx
Próximas acciones:
1. Verificar salud: docker exec ceph-admin ceph status
2. Ver OSDs: docker exec ceph-admin ceph osd tree
```

### Paso 4: Verificar Cluster

```bash
# Ver estado general
docker exec -it ceph-admin ceph status

# Ver árbol de OSDs
docker exec -it ceph-admin ceph osd tree

# Ver pool creado
docker exec -it ceph-admin ceph osd lspools

# Ver uso de almacenamiento
docker exec -it ceph-admin ceph df
```

**Estado esperado:**
- health: HEALTH_OK
- 3 OSDs activos
- 1 pool (rbd)

---

## Verificar Redes (Emulación de Switches)

```bash
# Ver redes creadas
docker network ls | grep ceph

# Ver detalles de red admin (192.168.122.0/24)
docker network inspect ceph-docker_admin_net

# Ver detalles de red datos (192.168.5.0/24)
docker network inspect ceph-docker_data_net

# Probar conectividad
docker exec ceph-admin ping -c 1 192.168.122.10   # monitor
docker exec ceph-admin ping -c 1 192.168.5.1      # OSD1 (red datos)
```

---

## Comandos Útiles

### Acceder a Contenedores

```bash
# Acceder a ceph-admin
docker exec -it ceph-admin bash

# Acceder a cualquier otro
docker exec -it ceph-mon bash
docker exec -it ceph-1 bash
```

### Ver Logs

```bash
# Logs de inicialización
docker logs ceph-admin
docker logs ceph-mon
docker logs ceph-1

# Logs de Ceph en tiempo real
docker exec ceph-admin tail -f /var/log/ceph/ceph.log

# Logs de un servicio específico
docker logs -f ceph-mon 2>&1 | head -50
```

### Gestión de Contenedores

```bash
# Detener todo
docker-compose down

# Reiniciar todo
docker-compose restart

# Limpiar todo (borrar volúmenes)
docker-compose down -v

# Recrear desde cero
docker-compose down -v
docker-compose up -d
sleep 15
bash scripts/setup-cluster.sh
```

### Estadísticas

```bash
# Ver uso de recursos
docker stats

# Ver detalles de un contenedor
docker inspect ceph-admin

# Ver volúmenes
docker volume ls | grep ceph
```

---

## Troubleshooting

### Error: Unable to locate package apt-ceph-release

**Solución:** Los scripts init-*.sh ya lo resuelven automáticamente agregando el repositorio correcto.

### Cluster without quorum

```bash
# Verificar monitors
docker exec ceph-admin ceph mon stat

# Forzar liderazgo (solo si es necesario)
docker exec ceph-admin ceph mon force-create-initial
```

### OSDs no aparecen

```bash
# Verificar logs de OSD
docker logs ceph-1
docker logs ceph-2
docker logs ceph-3

# Ver estado de OSD
docker exec ceph-admin ceph osd tree

# Marcar OSD como down
docker exec ceph-admin ceph osd down 0
docker exec ceph-admin ceph osd out 0
```

### Cluster degradado

```bash
# Ver detalles
docker exec ceph-admin ceph health detail

# Ver PGs degradados
docker exec ceph-admin ceph pg dump_json | grep degraded

# Forzar recuperación
docker exec ceph-admin ceph pg deep-scrub <pg_id>
```

---

## Operaciones Comunes

### Crear Volumen RBD

```bash
# Crear imagen
docker exec ceph-admin rbd create --size 10G myvolume --pool rbd

# Listar imágenes
docker exec ceph-admin rbd ls -p rbd

# Ver detalles
docker exec ceph-admin rbd info rbd/myvolume

# Mapear volumen
docker exec ceph-admin rbd map rbd/myvolume

# Ver mapeados
docker exec ceph-admin rbd showmapped
```

### Agregar Nuevo OSD

```bash
# Crear nuevo contenedor (no incluido en este setup)
# Preparar disco
docker exec ceph-new-osd ceph-volume lvm prepare --data /data

# Activar
docker exec ceph-new-osd ceph-volume lvm activate 3

# Iniciar
docker exec ceph-new-osd systemctl start ceph-osd@3
```

### Expandir Pool

```bash
# Aumentar Placement Groups
docker exec ceph-admin ceph osd pool set rbd pg_num 256
docker exec ceph-admin ceph osd pool set rbd pgp_num 256
```

---

## Monitoreo y Mantenimiento

### Comandos de Estado

```bash
# Status general
docker exec ceph-admin ceph -s

# Salud detallada
docker exec ceph-admin ceph health detail

# Version
docker exec ceph-admin ceph --version

# Información de cluster
docker exec ceph-admin ceph status -f json
```

### Información de OSDs

```bash
# Árbol de OSDs
docker exec ceph-admin ceph osd tree

# Uso por OSD
docker exec ceph-admin ceph osd df

# Performance
docker exec ceph-admin ceph osd perf
```

### Información de Monitors

```bash
# Estado
docker exec ceph-admin ceph mon stat

# Dump config
docker exec ceph-admin ceph mon dump

# Quórum
docker exec ceph-admin ceph quorum_status
```

### Información General

```bash
# Uso de almacenamiento
docker exec ceph-admin ceph df

# Uso detallado
docker exec ceph-admin ceph df detail

# Listar usuarios
docker exec ceph-admin ceph auth list

# Listar pools
docker exec ceph-admin ceph osd lspools
```

---

## Estructura de Redes (Docker Networks)

```
Internet (Host)
    |
docker-compose networks:
    |
    +-- admin_net (192.168.122.0/24) - Switch de Admin
    |       ├── ceph-admin (192.168.122.100)
    |       ├── ceph-mon (192.168.122.10)
    |       ├── ceph-1 (192.168.122.11)
    |       ├── ceph-2 (192.168.122.12)
    |       └── ceph-3 (192.168.122.13)
    |
    +-- data_net (192.168.5.0/24) - Switch de Datos
            ├── ceph-1 (192.168.5.1)
            ├── ceph-2 (192.168.5.2)
            └── ceph-3 (192.168.5.3)
```

---

## Archivos de Configuración

Ubicación dentro de contenedores:
- `/etc/ceph/ceph.conf` - Configuración principal
- `/etc/ceph/ceph.client.admin.keyring` - Credenciales admin
- `/etc/ceph/ceph.mon.keyring` - Keyring de monitor
- `/var/lib/ceph/mon/` - Datos del monitor
- `/var/lib/ceph/osd/` - Datos de OSDs
- `/var/log/ceph/ceph.log` - Logs principales

---

## Notas Importantes

- **Replicación**: Mínimo 3 réplicas para producción
- **CRUSH map**: Crítico - hacer backup regularmente
- **Scaling**: Los scripts permiten agregar OSDs adicionales
- **Persistencia**: Los volúmenes Docker persisten entre reinicios
- **Limpieza**: `docker-compose down -v` borra TODO

---

## Próximos Pasos

1. Crear volúmenes RBD para aplicaciones
2. Configurar RGW (Ceph Object Gateway) para S3
3. Configurar CephFS para almacenamiento de archivos
4. Implementar backups regulares
5. Configurar monitoreo (Prometheus + Grafana)

---

**Última actualización**: Abril 2026
**Versión Ceph**: Quincy (recomendado)
