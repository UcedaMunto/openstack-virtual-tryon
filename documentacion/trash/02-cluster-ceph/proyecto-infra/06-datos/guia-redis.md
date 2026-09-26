# Guia - Redis

Objetivo: instalar y configurar Redis en `redis-1` para cache de aplicaciones.

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

Datos base de creacion y parametros de integracion: `redis-datos-creacion.md`.

## Plan y aplicacion

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/06-datos
bash 06-redis.sh plan
bash 06-redis.sh apply
```

## Variables utiles

```bash
# Ejecutar sobre otro host
REDIS_IP=192.168.3.56 bash 06-redis.sh apply

# Cambiar puerto
REDIS_PORT=6379 bash 06-redis.sh apply

# Proteger con password
REDIS_REQUIREPASS='RedisPass123!' bash 06-redis.sh apply
```

## Validaciones recomendadas

Desde `redis-1`:

```bash
sudo systemctl status redis-server --no-pager
redis-cli -p 6379 PING
```

Si configuraste password:

```bash
redis-cli -a 'RedisPass123!' -p 6379 PING
```

Respuesta esperada: `PONG`.

## Notas

- El script deja `protected-mode yes` y activa `appendonly yes`.
- Si usas `REDIS_REQUIREPASS`, se configura tambien `masterauth` para facilitar replica futura.