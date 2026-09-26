# Documentacion de Scripts

Este directorio contiene los scripts que automatizan el laboratorio Ceph sobre Docker Compose.

## Resumen Rapido

- `init-admin.sh`: prepara el nodo administrador (`ceph-admin`) con Ceph CLI, SSH y utilidades base.
- `init-mon.sh`: prepara el nodo monitor (`ceph-mon`) con paquetes de monitor y estructura de directorios.
- `init-osd.sh`: prepara cada nodo OSD (`ceph-1`, `ceph-2`, `ceph-3`) con dependencias, usuario `ceph` y disco simulado.
- `setup-cluster.sh`: orquesta todo el bootstrap del cluster (MON, MGR, OSDs, pool y dashboard web).
- `SECUENCIA_COMANDOS_ADMIN_OSD.md`: secuencia exacta de comandos ejecutados para ceph-admin y para cada OSD.

## scripts/init-admin.sh

### Para que sirve

Inicializa el nodo administrador para que pueda ejecutar comandos Ceph y coordinar la configuracion del cluster.

### Que hace

1. Actualiza paquetes del sistema.
2. Instala dependencias base (`curl`, `ssh`, utilidades de red y proceso).
3. Genera par de llaves SSH en `/root/.ssh`.
4. Agrega el repositorio oficial de Ceph Quincy.
5. Instala paquetes Ceph de administracion (`ceph`, `ceph-common`, `ceph-mon`, `ceph-osd`, `ceph-mgr`).
6. Limpia cache de paquetes.

### Cuando se ejecuta

Se ejecuta automaticamente al iniciar el contenedor `ceph-admin` por `docker-compose`.

## scripts/init-mon.sh

### Para que sirve

Prepara el contenedor monitor para poder ser inicializado luego por el script maestro.

### Que hace

1. Actualiza paquetes.
2. Instala dependencias de monitor y utilidades base.
3. Configura SSH basico para acceso entre nodos.
4. Agrega repositorio de Ceph e instala `ceph-mon` y componentes relacionados.
5. Crea directorios de monitor (`/var/lib/ceph/mon`) y configuracion (`/etc/ceph`).
6. Limpia cache de paquetes.

### Cuando se ejecuta

Se ejecuta automaticamente al iniciar `ceph-mon`.

## scripts/init-osd.sh

### Para que sirve

Prepara cada nodo OSD para que `setup-cluster.sh` pueda aprovisionar y activar OSDs sin systemd.

### Que hace

1. Actualiza paquetes.
2. Instala dependencias para OSD y almacenamiento (`ceph-volume`, `lvm2`, `udev`, `util-linux`, etc.).
3. Configura SSH basico en el contenedor.
4. Agrega repositorio e instala paquetes Ceph OSD.
5. Garantiza que exista el usuario de sistema `ceph`.
6. Crea rutas de datos y configuracion (`/var/lib/ceph/osd`, `/etc/ceph`, `/data`).
7. Crea un archivo de disco simulado por OSD (`/data/osd-<id>.img`, 5G por defecto).
8. Limpia cache de paquetes.

### Variables relevantes

- `OSD_ID`: identificador del OSD (0, 1, 2 en este laboratorio).
- `OSD_DEVICE_SIZE`: tamano del disco simulado (default: `5G`).

### Cuando se ejecuta

Se ejecuta automaticamente al iniciar `ceph-1`, `ceph-2` y `ceph-3`.

## scripts/setup-cluster.sh

### Para que sirve

Es el script maestro. Realiza el bootstrap completo del cluster Ceph y deja lista la interfaz web.

### Que hace (alto nivel)

1. Espera a que todos los contenedores terminen su inicializacion interna.
2. Configura SSH trust desde `ceph-admin` hacia los demas nodos.
3. Genera `FSID` del cluster.
4. Construye y distribuye `ceph.conf`.
5. Genera y distribuye keyrings (`client.admin`, `mon`, `bootstrap-osd`).
6. Genera `monmap` e inicializa monitor.
7. Inicia el daemon manager.
8. Prepara y activa 3 OSDs usando `ceph-volume raw` con loop devices.
9. Espera a que los OSDs esten `up/in`.
10. Crea e inicializa el pool `rbd`.
11. Habilita y configura Ceph Dashboard (certificado, puerto y usuario admin).

### Variables relevantes

- `DASHBOARD_USER`: usuario del dashboard (default: `admin`).
- `DASHBOARD_PASSWORD`: password del dashboard (default: `AdminCeph2026!`).
- `OSD_DEVICE_SIZE`: tamano de imagen por OSD (heredado por `init-osd.sh`).

### Ejecucion recomendada

```bash
docker compose down -v --remove-orphans
docker compose up -d
bash scripts/setup-cluster.sh
```

### Resultado esperado

- `ceph status` responde con monitor y manager activos.
- `ceph osd tree` muestra 3 OSDs `up`.
- Dashboard disponible en `https://localhost:8443`.
