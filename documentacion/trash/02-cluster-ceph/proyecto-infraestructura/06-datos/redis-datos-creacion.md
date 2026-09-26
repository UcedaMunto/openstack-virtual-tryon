# Redis - Datos de creacion y configuracion

Este documento centraliza los parametros usados para crear y configurar `redis-1` en el laboratorio.

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

## Provisionamiento de VM

- VM: `redis-1`
- Hostname: `redis-1`
- Usuario inicial: `admin`
- Password inicial cloud-init: `admin123`
- RAM: `2048` MB
- vCPU: `2`
- Disco sistema: `30` GB
- Disco de datos adicional: `0` GB
- Red libvirt: `net-192-168-3`
- MAC primaria: `52:54:00:cc:dd:56`

## Red aplicada en la VM

- Interfaz: `enp1s0`
- IP/CIDR: `192.168.3.56/24`
- Gateway: `192.168.3.1`
- DNS primario: `192.168.3.55`
- DNS secundario: `8.8.8.8`

## Mapeo de hosts inyectado

- `192.168.3.56 redis-1`
- `192.168.3.60 maxscale-1`
- `192.168.3.61 mariadb-1`
- `192.168.3.62 mariadb-2`
- `192.168.3.63 mariadb-3`
- `192.168.3.64 cephfs-1`

## Configuracion Redis aplicada por automatizacion

- Script: `06-redis.sh`
- Paquetes: `redis-server`, `redis-tools`
- Archivo gestionado: `/etc/redis/redis.conf`
- Puerto por defecto: `6379`
- Bind por defecto: `0.0.0.0 ::1`
- `protected-mode`: `yes`
- `appendonly`: `yes`
- Password de Redis (`requirepass`/`masterauth`): opcional via variable `REDIS_REQUIREPASS`

## Validaciones operativas esperadas

- Servicio: `systemctl status redis-server` en estado `active (running)`
- Socket: escucha en `0.0.0.0:6379` y `::1:6379`
- Salud basica: `redis-cli -p 6379 PING` devuelve `PONG`

## Variables sobrescribibles

- `REDIS_IP` (default `192.168.3.56`)
- `REDIS_PORT` (default `6379`)
- `REDIS_BIND` (default `0.0.0.0 ::1`)
- `REDIS_REQUIREPASS` (default vacio)
- `SSH_USER` (default `admin`)
- `SSH_KEY` (default `/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa`)