# Ceph Cluster con Docker Compose - Setup Completo

## Resumen Rápido

Deploy un cluster Ceph completo con 3 OSDs usando Docker Compose en 3 pasos:

```bash
docker-compose up -d
sleep 15
bash scripts/setup-cluster.sh
```

Si necesitas la misma infraestructura sobre KVM/libvirt (separada de Docker), revisa:

- [ceph-kvm/README.md](ceph-kvm/README.md)

---

## Archivos Incluidos

### Guías
- **[GUIA_CEPH_COMPLETA.md](GUIA_CEPH_COMPLETA.md)** - Guía completa en formato simplificado
- **[GUIA_CEPH_CLUSTER.md](GUIA_CEPH_CLUSTER.md)** - Guía original (más detallada)

### Configuración Docker
- **[docker-compose.yml](docker-compose.yml)** - Define 5 contenedores y 2 redes virtuales

### Scripts de Inicialización
- **[scripts/init-admin.sh](scripts/init-admin.sh)** - Inicializa nodo administrador
- **[scripts/init-mon.sh](scripts/init-mon.sh)** - Inicializa monitor Ceph
- **[scripts/init-osd.sh](scripts/init-osd.sh)** - Inicializa OSDs
- **[scripts/setup-cluster.sh](scripts/setup-cluster.sh)** - Script maestro (EJECUTAR ESTE)
- **[scripts/README.md](scripts/README.md)** - Documentación detallada de cada script

### Estructura
```
.
├── docker-compose.yml
├── scripts/
│   ├── init-admin.sh
│   ├── init-mon.sh
│   ├── init-osd.sh
│   └── setup-cluster.sh
├── GUIA_CEPH_COMPLETA.md
├── GUIA_CEPH_CLUSTER.md
└── README.md (este archivo)
```

---

## Instalación Paso a Paso

### 1. Preparar Directorios

```bash
mkdir -p ~/ceph-docker/scripts
cd ~/ceph-docker
```

### 2. Copiar Archivos

Asegúrate de tener todos estos archivos en el directorio `~/ceph-docker/`:
- `docker-compose.yml`
- `scripts/init-admin.sh`
- `scripts/init-mon.sh`
- `scripts/init-osd.sh`
- `scripts/setup-cluster.sh`

Haz los scripts ejecutables:
```bash
chmod +x scripts/*.sh
```

### 3. Levantar Cluster

```bash
# Levantar contenedores
docker-compose up -d

# Esperar inicialización (10-15 segundos)
sleep 15

# Ejecutar setup automático
bash scripts/setup-cluster.sh

# Verificar que está listo
docker exec -it ceph-admin ceph status
```

---

## Verificación de Setup

Después de `setup-cluster.sh`, deberías ver:

```bash
$ docker exec -it ceph-admin ceph status

  cluster:
    id:     [cluster-id]
    health: HEALTH_OK
  
  services:
    mon: 1 daemons, quorum ceph-mon
    osd: 3 daemons, 3 up, 3 in
    
  data:
    pools:   1 pools
    objects: 0  objects
    usage:   [size] used, [available] avail
```

---

## Comandos Útiles

### Status y Monitoreo

```bash
# Ver status del cluster
docker exec -it ceph-admin ceph -s

# Ver árbol de OSDs
docker exec -it ceph-admin ceph osd tree

# Ver uso de almacenamiento
docker exec -it ceph-admin ceph df
```

### Acceso a Contenedores

```bash
# Terminal en nodo admin
docker exec -it ceph-admin bash

# Terminal en monitor
docker exec -it ceph-mon bash

# Terminal en OSD
docker exec -it ceph-1 bash
```

### Logs

```bash
# Ver logs de inicialización
docker logs ceph-admin

# Ver logs de Ceph en vivo
docker exec ceph-admin tail -f /var/log/ceph/ceph.log
```

### Control

```bash
# Detener todo
docker-compose down

# Reiniciar
docker-compose restart

# Recrear desde cero
docker-compose down -v
docker-compose up -d
sleep 15
bash scripts/setup-cluster.sh
```

---

## Qué Hace Cada Script

### init-admin.sh
- Prepara el nodo administrador con dependencias base y CLI de Ceph.
- Genera llaves SSH para orquestación entre contenedores.
- Instala paquetes de administración (`ceph`, `ceph-common`, `ceph-mon`, `ceph-osd`, `ceph-mgr`).

### init-mon.sh
- Prepara el contenedor monitor con paquetes y rutas requeridas.
- Crea estructura de monitor en `/var/lib/ceph/mon` y configuración en `/etc/ceph`.
- Se ejecuta automáticamente al levantar `ceph-mon`.

### init-osd.sh
- Prepara dependencias de OSD (`ceph-volume`, `lvm2`, `udev`, etc.).
- Garantiza usuario de sistema `ceph`.
- Crea imagen de disco simulada por nodo (`/data/osd-<id>.img`).
- Se ejecuta automáticamente al levantar cada nodo OSD.

### setup-cluster.sh (EL MAS IMPORTANTE)
Ejecuta en orden:
1. Verifica que todos los contenedores estén activos
2. Espera a que finalice la inicialización interna de cada contenedor
3. Genera UUID único del cluster
4. Crea `ceph.conf` con configuración
5. Genera keyrings de autenticación
6. Genera monmap
7. Inicializa monitor (`ceph-mon`)
8. Inicializa manager (`ceph-admin`)
9. Genera bootstrap keys para OSDs
10. Inicializa y activa los 3 OSDs
11. Espera OSDs en estado `up/in`
12. Configura Dashboard web (módulo, cert, usuario)
13. Crea pool RBD

---

## Redes Virtuales Creadas

Docker Compose crea 2 redes que emulan switches reales:

### Red de Administración (admin_net)
- Subnet: `192.168.122.0/24`
- Usado por: Comunicación admin y comandos
- Nodos:
  - ceph-admin: `192.168.122.100`
  - ceph-mon: `192.168.122.10`
  - ceph-1: `192.168.122.11`
  - ceph-2: `192.168.122.12`
  - ceph-3: `192.168.122.13`

### Red de Datos (data_net)
- Subnet: `192.168.5.0/24`
- Usado por: Replicación y tráfico de datos
- Nodos:
  - ceph-1: `192.168.5.11`
  - ceph-2: `192.168.5.12`
  - ceph-3: `192.168.5.13`

Esto emula la arquitectura real donde en producción tendrías switches físicos separados.

---

## Troubleshooting

### "Connection refused" en ceph status

**Problema**: Monitor no está listo

**Solución**:
```bash
# Esperar más tiempo
sleep 10
docker exec -it ceph-admin ceph status
```

### OSDs no aparecen en `ceph osd tree`

**Problema**: OSDs aún se están inicializando

**Solución**:
```bash
# Verificar logs
docker logs ceph-1

# Esperar más tiempo
sleep 20
docker exec -it ceph-admin ceph osd tree
```

### "Health WARN" o "HEALTH_ERR"

**Solución**:
```bash
# Ver detalles del problema
docker exec -it ceph-admin ceph health detail

# En la mayoría de casos es normal durante inicialización
# Esperar a que se estabilice (2-5 minutos)
```

### Recrear desde Cero

Si algo sale mal:
```bash
docker-compose down -v
docker-compose up -d
sleep 15
bash scripts/setup-cluster.sh
```

---

## Casos de Uso

### Recrear Cluster

```bash
docker-compose down -v
docker-compose up -d
sleep 15
bash scripts/setup-cluster.sh
```

### Pausar Cluster

```bash
docker-compose stop
# Los datos se mantienen en volúmenes
```

### Reanudar Cluster

```bash
docker-compose start
# El cluster se reinicia automáticamente
```

### Limpiar Todo

```bash
docker-compose down -v
# ADVERTENCIA: Borra todos los datos
```

---

## Requisitos del Sistema

- Docker y Docker Compose instalados
- Mínimo 4GB RAM disponible
- Mínimo 10GB espacio en disco
- Linux (kernel 4.13+)

---

## Recursos Adicionales

### Ver también en guías
- **GUIA_CEPH_COMPLETA.md**: Operaciones avanzadas, monitoreo, troubleshooting
- **GUIA_CEPH_CLUSTER.md**: Instalación manual en VMs

### Documentación Oficial
- [Ceph Docs](https://docs.ceph.com/)
- [Ceph Architecture](https://docs.ceph.com/Projects/ceph/en/latest/architecture/)

---

## Notas

- Los datos se persisten en volúmenes Docker, sobreviven a paradas
- SSH funciona sin contraseña entre contenedores después de setup
- El UUID del cluster se guarda en `/tmp/fsid.txt`
- Todos los logs están en `/var/log/ceph/ceph.log` dentro de los contenedores
- La configuración se replica automáticamente a todos los nodos

---

**¡Listo! Tu cluster Ceph está listo para usar.**

Para comenzar: `docker-compose up -d && sleep 15 && bash scripts/setup-cluster.sh`
