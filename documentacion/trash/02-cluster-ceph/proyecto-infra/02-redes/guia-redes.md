# Guia - Redes

Objetivo: crear la red libvirt principal para toda la infraestructura.

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

## Secuencia de comandos

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/02-redes
```

Vista previa de comandos:

```bash
bash 02-redes.sh plan
```

Aplicar red:

```bash
bash 02-redes.sh apply
```

## Verificaciones

```bash
sudo virsh net-list --all
sudo virsh net-dumpxml net-192-168-3
```

## Personalizacion

Puedes cambiar parametros por variables de entorno:

```bash
NET_NAME=net-192-168-3 \
NET_GW=192.168.3.1 \
NET_MASK=255.255.255.0 \
DHCP_START=192.168.3.200 \
DHCP_END=192.168.3.254 \
bash 02-redes.sh apply
```
