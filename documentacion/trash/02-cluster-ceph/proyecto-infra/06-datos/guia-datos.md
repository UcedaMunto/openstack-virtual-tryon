# Guia - Capa de datos

Objetivo: preparar nodos para Redis, MariaDB Galera, MaxScale y CephFS.

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

## Secuencia VM

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/06-datos
bash 06-datos.sh plan
bash 06-datos.sh apply
```

Nota operativa: `plan` genera comandos; `apply` ejecuta creacion directa de VMs para evitar errores de sintaxis en ciertos archivos generados por `--comandos`.

## Redis

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/06-datos
bash 06-redis.sh plan
bash 06-redis.sh apply
```

Guia detallada: `guia-redis.md`.
Inventario de creacion/configuracion: `redis-datos-creacion.md`.

## MariaDB Galera (en cada mariadb-X)

```bash
sudo apt update
sudo apt install -y mariadb-server galera-4 rsync
```

Configurar `/etc/mysql/mariadb.conf.d/60-galera.cnf` en cada nodo (ajustar `wsrep_node_address` y `wsrep_cluster_address`).

Implementacion completa automatizada:

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/06-datos
bash 06-mysql-galera-maxscale.sh plan
bash 06-mysql-galera-maxscale.sh apply
```

Resultado actual:
- Galera convergido a 3 nodos.
- MaxScale instalado y operativo en `maxscale-1` (`24.02.9`).
- Ver detalle en `guia-mysql-galera-maxscale.md`.

## MaxScale

```bash
sudo apt update
sudo apt install -y curl gnupg
curl -fsSL https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=10.11
sudo apt update
sudo apt install -y maxscale
sudo systemctl enable --now maxscale
sudo maxctrl list servers
```

Nota: en MaxScale 24.x, el parametro `max_slave_connections` se configura como entero (por ejemplo `255`), no como porcentaje.

## CephFS (nodo base)

Este nodo queda preparado para acople posterior con cluster Ceph. Si usaras Ceph en este mismo laboratorio, crear guia dedicada para MON/MGR/OSD antes de montar CephFS.
