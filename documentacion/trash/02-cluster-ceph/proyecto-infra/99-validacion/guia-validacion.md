# Guia - Validacion final

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

Ejecutar:

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/99-validacion
bash 99-validacion.sh
```

Checklist final:

1. Todas las VMs en estado `running` o `shut off` segun etapa.
2. Red `net-192-168-3` activa y en autostart.
3. Resolucion DNS interna operativa.
4. Nginx en ambos balanceadores en estado `active`.
5. Gunicorn/Django activo en `app1`, `app2`, `app3`.
6. Redis activo y escuchando.
7. MariaDB/MaxScale instalados y configurados.

Comandos de validacion de servicios (ejecutados en esta integracion):

```bash
SSH_KEY=/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -i $SSH_KEY"

# DNS
dig @192.168.3.55 app1.mimas.net +short
dig @192.168.3.55 lb1.mimas.net +short

# LB
curl -sSo /dev/null -w "lb1=%{http_code}\n" http://192.168.3.50
curl -sSo /dev/null -w "lb2=%{http_code}\n" http://192.168.3.51

# Backends app
for h in 192.168.3.52 192.168.3.53 192.168.3.54; do
	curl -sSo /dev/null -w "$h=%{http_code}\n" http://$h:8000
done

# Redis
ssh $SSH_OPTS admin@192.168.3.56 "redis-cli PING"

# Galera
for db in 192.168.3.61 192.168.3.62 192.168.3.63; do
	ssh $SSH_OPTS admin@$db "sudo mysql -Nse \"SHOW STATUS LIKE 'wsrep_cluster_size'; SHOW STATUS LIKE 'wsrep_ready';\""
done

# MaxScale
ssh $SSH_OPTS admin@192.168.3.60 "sudo systemctl is-active maxscale"
ssh $SSH_OPTS admin@192.168.3.60 "sudo maxctrl list servers"
```

Referencia de parametros Redis para integracion documental:
- `../06-datos/redis-datos-creacion.md`

Nota:
- Si `domifaddr` no muestra IP inmediatamente, esperar 1-3 minutos para que termine cloud-init y levante `qemu-guest-agent`.
