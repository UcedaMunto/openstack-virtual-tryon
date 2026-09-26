# Guia - MySQL (MariaDB Galera + MaxScale)

Objetivo: montar cluster de base de datos (3 nodos Galera) y capa de acceso por MaxScale.

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

Para integrar toda la capa de datos en documentacion unica, complementar con Redis en:
- `redis-datos-creacion.md`

## Nodos

- maxscale-1: 192.168.3.60
- mariadb-1: 192.168.3.61
- mariadb-2: 192.168.3.62
- mariadb-3: 192.168.3.63

## Plan

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/06-datos
bash 06-mysql-galera-maxscale.sh plan
```

## Aplicar

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/06-datos
bash 06-mysql-galera-maxscale.sh apply
```

Correccion aplicada en esta iteracion:
- El archivo `60-galera.cnf` debe usar seccion `[mysqld]` (no `[galera]`) para que MariaDB aplique `wsrep_*` y `bind-address`.
- El archivo `60-galera.cnf` debe quedar como `root:root` y modo `0644`; con permisos `600` de usuario admin, MariaDB ignora el archivo.
- El script ahora valida que `wsrep_cluster_size=3` en los tres nodos y falla si no converge.
- Para MaxScale 24.x, `max_slave_connections` debe ser numerico (por ejemplo `255`), no porcentaje.
- El usuario monitor de MaxScale debe existir para IP y hostname del nodo (`192.168.3.60` y `maxscale-1`) para evitar `Auth Error`.

## Comandos verificados en ejecucion real (2026-05-01)

### 1) Habilitar repositorio MariaDB e instalar MaxScale en maxscale-1

```bash
SSH_KEY=/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" admin@192.168.3.60 \
	"curl -fsSL https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=10.11"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" admin@192.168.3.60 \
	"sudo DEBIAN_FRONTEND=noninteractive apt-get install -y maxscale"
```

### 2) Crear usuario monitor en Galera (mariadb-1)

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" admin@192.168.3.61 "sudo mysql -e \"
CREATE USER IF NOT EXISTS 'maxscale'@'192.168.3.60' IDENTIFIED BY 'MaxScalePwd1_';
CREATE USER IF NOT EXISTS 'maxscale'@'maxscale-1' IDENTIFIED BY 'MaxScalePwd1_';
GRANT RELOAD, PROCESS, SHOW DATABASES, REPLICATION SLAVE, BINLOG MONITOR, SLAVE MONITOR ON *.* TO 'maxscale'@'192.168.3.60';
GRANT RELOAD, PROCESS, SHOW DATABASES, REPLICATION SLAVE, BINLOG MONITOR, SLAVE MONITOR ON *.* TO 'maxscale'@'maxscale-1';
GRANT SELECT ON mysql.* TO 'maxscale'@'192.168.3.60';
GRANT SELECT ON mysql.* TO 'maxscale'@'maxscale-1';
FLUSH PRIVILEGES;
\""
```

### 3) Configuracion efectiva de /etc/maxscale.cnf

```ini
[maxscale]
threads=auto
log_info=false
log_warning=true

[mariadb-1]
type=server
address=192.168.3.61
port=3306
protocol=MariaDBBackend

[mariadb-2]
type=server
address=192.168.3.62
port=3306
protocol=MariaDBBackend

[mariadb-3]
type=server
address=192.168.3.63
port=3306
protocol=MariaDBBackend

[galera-monitor]
type=monitor
module=galeramon
servers=mariadb-1,mariadb-2,mariadb-3
user=maxscale
password=MaxScalePwd1_
monitor_interval=2000ms
root_node_as_master=true

[galera-service]
type=service
router=readwritesplit
servers=mariadb-1,mariadb-2,mariadb-3
user=maxscale
password=MaxScalePwd1_
max_slave_connections=255

[galera-listener]
type=listener
service=galera-service
protocol=MariaDBClient
port=3306
address=0.0.0.0
```

### 4) Activar y validar

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" admin@192.168.3.60 \
	"sudo systemctl enable --now maxscale && sudo maxctrl list servers"
```

## Verificaciones

Tamano de cluster en cada nodo MariaDB:

```bash
ssh -i /home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa admin@192.168.3.61 "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
ssh -i /home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa admin@192.168.3.62 "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
ssh -i /home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa admin@192.168.3.63 "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
```

Estado MaxScale:

```bash
ssh -i /home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa admin@192.168.3.60 "sudo systemctl --no-pager status maxscale"
ssh -i /home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa admin@192.168.3.60 "sudo maxctrl list servers"
```

## Estado de esta ejecucion

- Galera quedo operativo en 3 nodos (`wsrep_cluster_size=3`, `wsrep_cluster_status=Primary`, `wsrep_ready=ON`).
- MaxScale quedo instalado y activo en `maxscale-1` (version `24.02.9`).
- `maxctrl list servers` muestra convergencia completa:
	- `mariadb-1`: `Master, Synced, Running`
	- `mariadb-2`: `Slave, Synced, Running`
	- `mariadb-3`: `Slave, Synced, Running`

## Parametros editables

Puedes sobrescribir variables al ejecutar:

```bash
MAXSCALE_MONITOR_USER=maxscale \
MAXSCALE_MONITOR_PASS='TuPasswordSegura' \
bash 06-mysql-galera-maxscale.sh apply
```
