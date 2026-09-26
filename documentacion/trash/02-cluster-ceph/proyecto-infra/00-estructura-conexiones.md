# Estructura y datos de conexion

Documento maestro de referencia para topologia, nodos, credenciales y endpoints del laboratorio.

## Topologia resumida

Capas principales:

1. Administracion/base
2. Red libvirt
3. DNS interno (CoreDNS)
4. Balanceo HTTP (Nginx)
5. Aplicacion (Django)
6. Datos (Redis, MariaDB Galera, MaxScale, CephFS base)

## Credenciales base del laboratorio

- Usuario inicial de VMs: `admin`
- Password inicial cloud-init: `admin123`
- Llave privada SSH compartida: `/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa`
- Llave publica SSH compartida: `/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa.pub`

Comando tipo de acceso SSH:

```bash
ssh -i /home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa admin@<IP_VM>
```

## Red principal

- Red libvirt: `net-192-168-3`
- Gateway: `192.168.3.1`
- Mascara: `255.255.255.0`
- DHCP usado en red: `192.168.3.200-192.168.3.254`

## Inventario de nodos

| Rol | VM | IP | Servicio principal | Puerto(s) | Estado |
|---|---|---|---|---|---|
| Base admin | ceph-admin | 192.168.3.10 | Administracion | 22 | Activo |
| DNS | dns-1 | 192.168.3.55 | CoreDNS | 53 | Activo |
| LB principal | lb1 | 192.168.3.50 | Nginx | 80 | Activo |
| LB contingencia | lb2 | 192.168.3.51 | Nginx | 80 | Activo |
| Backend 1 | app1 | 192.168.3.52 | Django/Gunicorn | 8000 | Activo |
| Backend 2 | app2 | 192.168.3.53 | Django/Gunicorn | 8000 | Activo |
| Backend 3 | app3 | 192.168.3.54 | Django/Gunicorn | 8000 | Activo |
| Cache | redis-1 | 192.168.3.56 | Redis | 6379 | Activo |
| SQL proxy | maxscale-1 | 192.168.3.60 | MaxScale | 3306 | Activo |
| DB Galera 1 | mariadb-1 | 192.168.3.61 | MariaDB Galera | 3306 | Activo |
| DB Galera 2 | mariadb-2 | 192.168.3.62 | MariaDB Galera | 3306 | Activo |
| DB Galera 3 | mariadb-3 | 192.168.3.63 | MariaDB Galera | 3306 | Activo |
| Filesystem base | cephfs-1 | 192.168.3.64 | Nodo CephFS base | - | Activo |

IPs reservadas en hosts de referencia inicial:

- `192.168.3.11 ceph-mon`
- `192.168.3.12 ceph-osd1`
- `192.168.3.13 ceph-osd2`
- `192.168.3.14 ceph-osd3`

## DNS interno esperado

Zona principal: `mimas.net`

Registros usados en guias:

- `lb1.mimas.net -> 192.168.3.50`
- `lb2.mimas.net -> 192.168.3.51`
- `app1.mimas.net -> 192.168.3.52`
- `app2.mimas.net -> 192.168.3.53`
- `app3.mimas.net -> 192.168.3.54`

## Datos de conexion por servicio

### Nginx

- `http://192.168.3.50`
- `http://192.168.3.51`

### Redis

- Host: `192.168.3.56`
- Puerto: `6379`
- Password: opcional (si se define `REDIS_REQUIREPASS`)

### MariaDB Galera

- Nodos directos:
  - `192.168.3.61:3306`
  - `192.168.3.62:3306`
  - `192.168.3.63:3306`
- Estado validado:
  - `wsrep_cluster_size=3`
  - `wsrep_cluster_status=Primary`
  - `wsrep_ready=ON`

### MaxScale

- Nodo objetivo: `192.168.3.60:3306`
- Usuario monitor configurado en Galera:
  - usuario: `maxscale`
  - password: `MaxScalePwd1_`
- Estado actual:
  - MaxScale `24.02.9` instalado y servicio activo.
  - Monitor Galera convergido (`Master, Synced, Running` + 2 `Slave, Synced, Running`).

## Comandos de verificacion rapida

Estado de cluster Galera:

```bash
for ip in 192.168.3.61 192.168.3.62 192.168.3.63; do
  echo "=== $ip ==="
  ssh -i /home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa admin@$ip \
    "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size'; SHOW STATUS LIKE 'wsrep_cluster_status'; SHOW STATUS LIKE 'wsrep_ready';\""
done
```

Validar Redis:

```bash
ssh -i /home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa admin@192.168.3.56 \
  "redis-cli -p 6379 PING"
```

Validar DNS:

```bash
dig @192.168.3.55 app1.mimas.net +short
dig @192.168.3.55 lb1.mimas.net +short
```
