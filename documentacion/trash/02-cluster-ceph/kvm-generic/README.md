# KVM Generic - Guia de uso

Este modulo permite crear VMs KVM con una configuracion estandar usando cloud-init.

Incluye:
- Zona horaria: `America/El_Salvador`
- Chrony instalado y configurado con `server ntp.ues.edu.sv iburst`
- Hostname, usuario y contrasenia por parametro o inventario
- Escritura de `/etc/hosts` por VM
- Copia de llaves SSH compartidas a todas las VMs
- Llave publica del anfitrion autorizada automaticamente (si existe en `~/.ssh/id_rsa.pub` o `~/.ssh/id_ed25519.pub`)
- Soporte para una o varias interfaces de red
- Script opcional `.sh` de primer arranque (se ejecuta una sola vez)

## Archivos

- `create-kvm-vm.sh`: crea una VM individual
- `create-kvm-vms.sh`: crea varias VMs usando inventario
- `delete-kvm-vm.sh`: elimina una VM y limpia sus artefactos asociados
- `vm-common.sh`: funciones compartidas (cloud-init, llaves, red, hosts)
- `vm-inventory.conf`: ejemplo de inventario para lote
- `first-boot-example.sh`: ejemplo de script opcional de primer arranque
- `ssh-keys/`: llaves compartidas usadas por todas las VMs (se crea automaticamente)

## Requisitos

Instalar KVM/libvirt y utilidades:

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst cloud-image-utils wget
```

Tener imagen base (por defecto):

```bash
sudo wget -O /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 \
  https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

Tener al menos una red libvirt activa (ejemplo `ceph-net`):

```bash
sudo virsh net-list --all
```

## Permisos de ejecucion

```bash
cd /home/uceda/Documents/cluster-ceph/kvm-generic
chmod +x vm-common.sh create-kvm-vm.sh create-kvm-vms.sh
```

Si usaras el borrado automatizado, agrega tambien:

```bash
chmod +x delete-kvm-vm.sh
```

## Crear una VM individual

Ejemplo:

```bash
cd /home/uceda/Documents/cluster-ceph/kvm-generic

bash create-kvm-vm.sh \
  --name ceph-admin \
  --hostname ceph-admin \
  --user ceph \
  --password 'Ceph1234!' \
  --ram 2048 \
  --vcpus 2 \
  --system-disk 20 \
  --data-disk 0 \
  --libvirt-nets "ceph-net" \
  --ifaces "enp1s0,192.168.5.40/24,192.168.5.1,8.8.8.8,8.8.4.4" \
  --extra-hosts "192.168.5.40 ceph-admin;192.168.5.41 ceph-mon;192.168.5.42 ceph-osd1" \
  --first-boot-script "/home/uceda/Documents/cluster-ceph/kvm-generic/first-boot-example.sh" \
  --primary-mac "52:54:00:aa:bb:cc"
```

### Parametros de `create-kvm-vm.sh`

- `--name` (obligatorio): nombre de la VM en libvirt
- `--hostname`: hostname dentro del SO (si no se envia, usa `--name`)
- `--user`: usuario administrador dentro de la VM (default `ceph`)
- `--password`: contrasenia del usuario de la VM (default `ceph1234`)
- `--ram`: RAM en MB (default `2048`)
- `--vcpus`: numero de vCPU (default `2`)
- `--system-disk`: tamano disco sistema en GB (default `20`)
- `--data-disk`: tamano disco de datos en GB (default `0`)
- `--libvirt-nets`: una o varias redes libvirt separadas por `;`
- `--ifaces`: una o varias interfaces separadas por `;`
- `--extra-hosts`: entradas extra para `/etc/hosts` separadas por `;`
- `--first-boot-script`: ruta a script `.sh` opcional para ejecutar en primer arranque
- `--primary-mac`: MAC de la NIC principal; mejora la aplicacion de IP estatica en cloud-init

Nota importante sobre IP fija:
- Si defines IP en `--ifaces`, se aplica en primer arranque por cloud-init.
- El script ahora fija la MAC de la primera NIC (automaticamente o por `--primary-mac`) y cloud-init hace `match` por MAC para que la IP estatica se aplique de forma confiable.
- Si la VM ya existia, cloud-init no vuelve a aplicar la red inicial; debes recrear la VM para cambiar IP de bootstrap.

## Formato de interfaces (`--ifaces`)

Formato por interfaz:

```text
nombre,ip_cidr,gateway,dns1,dns2
```

Notas:
- Puedes dejar campos vacios, por ejemplo sin gateway: `enp7s0,10.10.10.12/24,,10.10.10.1`
- Si no envias `--ifaces`, la VM queda con `enp1s0` en DHCP.
- Compatibilidad: tambien acepta DNS con `|` (por ejemplo `8.8.8.8|8.8.4.4`).

Ejemplo de dos interfaces:

```bash
--ifaces "enp1s0,192.168.5.42/24,192.168.5.1,8.8.8.8,8.8.4.4;enp7s0,10.10.10.12/24,,10.10.10.1"
```

## Crear varias VMs (lote)

1. Editar inventario `vm-inventory.conf`.
2. Ejecutar:

```bash
cd /home/uceda/Documents/cluster-ceph/kvm-generic
bash create-kvm-vms.sh
```

Tambien puedes indicar otro inventario:

```bash
INVENTORY_FILE=/ruta/mi-inventario.conf bash create-kvm-vms.sh
```

### Formato de `vm-inventory.conf`

Separador de columnas: `|`

```text
name|hostname|ram_mb|vcpus|system_disk_gb|data_disk_gb|libvirt_nets|ifaces_spec|extra_hosts|vm_user|vm_password|first_boot_script|primary_mac
```

Ejemplo de una fila:

```text
ceph-osd1|ceph-osd1|2048|2|20|50|ceph-net|enp1s0,192.168.5.42/24,192.168.5.1,8.8.8.8,8.8.4.4|192.168.5.40 ceph-admin;192.168.5.41 ceph-mon|ceph|Ceph1234!|/home/uceda/Documents/cluster-ceph/kvm-generic/first-boot-example.sh|52:54:00:aa:bb:12
```

Si no deseas ejecutar script de primer arranque, deja la ultima columna vacia en el inventario.

## Eliminar una VM y su basura asociada

Ejemplo para borrar `n-admin`:

```bash
cd /home/uceda/Documents/cluster-ceph/kvm-generic
bash delete-kvm-vm.sh --name n-admin
```

Si tambien quieres limpiar la huella SSH del host para la IP actual de esa VM:

```bash
cd /home/uceda/Documents/cluster-ceph/kvm-generic
bash delete-kvm-vm.sh --name n-admin --remove-known-hosts
```

El script limpia:
- definicion libvirt de la VM
- discos adjuntos detectados desde libvirt
- `/tmp/user-data-<vm>.yaml`
- posibles archivos seed/cloud-init en `/var/lib/libvirt/images`

## Variables de entorno utiles

- `IMG_DIR`: directorio de discos (default `/var/lib/libvirt/images`)
- `BASE_IMG`: imagen base qcow2 (default `$IMG_DIR/ubuntu-22.04-base.qcow2`)
- `VM_USER`: usuario creado en la VM (default `ceph`)
- `VM_PASSWORD`: contrasenia por defecto para la VM (default `ceph1234`)
- `SSH_KEYS_DIR`: directorio de llaves compartidas (default `kvm-generic/ssh-keys`)
- `HOST_PUBLIC_KEY`: ruta a llave publica del anfitrion para autorizar SSH en las VMs

Ejemplo:

```bash
IMG_DIR=/var/lib/libvirt/images \
BASE_IMG=/var/lib/libvirt/images/ubuntu-22.04-base.qcow2 \
VM_USER=ceph \
VM_PASSWORD='Ceph1234!' \
bash create-kvm-vm.sh --name vm-demo --hostname vm-demo
```

## Conexion SSH desde el anfitrion

Las VMs quedan con `authorized_keys` incluyendo:
- llave publica compartida de `kvm-generic/ssh-keys/id_rsa.pub`
- llave publica del anfitrion (si existe)

Ejemplos de conexion:

```bash
ssh ceph@192.168.5.40
```

Si quieres forzar una llave concreta del anfitrion:

```bash
HOST_PUBLIC_KEY=$HOME/.ssh/id_ed25519.pub bash create-kvm-vm.sh --name vm-demo --password 'Ceph1234!'
```

## Verificacion posterior

```bash
sudo virsh list --all
sudo virsh domifaddr ceph-admin
```

## Seguridad sobre llaves compartidas

Este flujo copia la misma llave privada/publica a todas las VMs para facilitar administracion de laboratorio.

Para laboratorio funciona bien.
Para ambientes mas sensibles, se recomienda una llave distinta por VM o por rol.
