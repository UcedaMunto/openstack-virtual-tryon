# Guia - Bases

Objetivo: crear nodo administrativo inicial para orquestar el resto de la plataforma.

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

## Pre-requisitos

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst cloud-image-utils wget openssl
```

Verificar imagen base:

```bash
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || \
sudo wget -O /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 \
https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

## Secuencia de comandos

Desde esta carpeta:

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/01-bases
```

Generar comandos reproducibles:

```bash
bash 01-bases.sh plan
```

Aplicar creacion de VM:

```bash
bash 01-bases.sh apply
```

Nota operativa:
- `plan` genera archivo de comandos para auditoria.
- `apply` ejecuta creacion directa con `create-kvm-vm.sh` para evitar un bug actual en algunos archivos generados por `--comandos`.

## Comando directo equivalente

```bash
bash /home/uceda/Documents/cluster-ceph/kvm-generic/create-kvm-vm.sh \
  --name ceph-admin \
  --hostname ceph-admin \
  --user admin \
  --password admin123 \
  --ram 2048 \
  --vcpus 2 \
  --system-disk 20 \
  --data-disk 0 \
  --libvirt-nets "net-192-168-3" \
  --ifaces "enp1s0,192.168.3.10/24,192.168.3.1,8.8.8.8,8.8.4.4" \
  --extra-hosts "192.168.3.10 ceph-admin;192.168.3.11 ceph-mon;192.168.3.12 ceph-osd1;192.168.3.13 ceph-osd2;192.168.3.14 ceph-osd3" \
  --primary-mac "52:54:00:cc:dd:10" \
  --comandos
```

Nota: las IP son editables en el script `01-bases.sh`.
