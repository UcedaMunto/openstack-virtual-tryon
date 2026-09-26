# Guía revisada y detallada: instalación de un clúster Kubernetes con kubeadm en Ubuntu 24.04

> **Base:** Guía de Instalación Cluster Kubernetes, Curso de
> Especialización Infraestructura Cloud, Universidad de El Salvador,
> revisión 2026.
>
> **Objetivo de esta versión:** conservar la estructura y propósito del
> laboratorio, corregir pasos que pueden causar errores y dejar comandos
> completos y ejecutables para Kubernetes **v1.36**, Ubuntu **24.04**,
> `containerd` y Calico.
>
> **Topología de ejemplo**
>
>   Nodo   Hostname          IP de ejemplo Rol
>   ------ -------------- ---------------- ---------------
>   1      `k8-master`      `192.168.90.1` Control Plane
>   2      `k8-worker1`     `192.168.90.2` Worker
>   3      `k8-worker2`     `192.168.90.3` Worker
>   4      `k8-worker3`     `192.168.90.4` Worker
>
> Sustituye las IP por las de tus máquinas. El requerimiento final de la
> guía pide **1 master + 3 workers**.

------------------------------------------------------------------------

# 0. Correcciones importantes detectadas en la guía original

Antes de ejecutar los pasos, conviene tener presentes estas
correcciones:

1.  **Ubuntu 24.4 → Ubuntu 24.04.**
2.  La guía indica que Ubuntu 24.04 es **Jammy**. Esto es incorrecto:
    -   Ubuntu 22.04 = Jammy Jellyfish.
    -   Ubuntu 24.04 = Noble Numbat.
3.  **No es obligatorio instalar Docker** para disponer de `containerd`.
    Kubernetes utiliza un runtime compatible con CRI; en esta guía
    revisada se configura `containerd` directamente.
4.  La guía original muestra dos inicializaciones distintas:
    -   `kubeadm init --pod-network-cidr=...`
    -   `kubeadm init --control-plane-endpoint=...`

    **No deben ejecutarse ambas por separado.** El clúster debe
    inicializarse **una sola vez**, combinando los parámetros
    necesarios.
5.  La guía mezcla **Flannel y Calico**. No se recomienda instalar ambos
    CNI para resolver el mismo clúster. En esta versión utilizaremos
    **Calico únicamente**.
6.  Si se inicializa el clúster sin el `--pod-network-cidr` correcto, no
    se debe intentar ejecutar simplemente `kubeadm init` otra vez. Para
    rehacer el laboratorio hay que usar `kubeadm reset` y limpiar la
    configuración anterior.
7.  El repositorio moderno de Kubernetes es `pkgs.k8s.io`. Para
    Kubernetes 1.36 se usa la rama `v1.36`.
8.  El Kubernetes Dashboard actual se instala mediante **Helm**. Los
    manifiestos antiguos `recommended.yaml` de Dashboard v2.x que
    aparecen en la guía no deben mezclarse con la instalación moderna
    por Helm.
9.  El `port-forward` es apropiado para laboratorio/pruebas. No debe
    considerarse una exposición permanente de producción.
10. El `ClusterRole` `cluster-admin` para el usuario del Dashboard
    concede control total del clúster. Se conserva únicamente por
    tratarse de un laboratorio.

------------------------------------------------------------------------


# 0.1. Crear todas las máquinas virtuales del laboratorio con KVM/libvirt

La guía utiliza una topología de **1 Control Plane + 3 Workers**, por lo
que crearemos cuatro máquinas virtuales. Para un host físico con **32 GB
de RAM y 12 hilos de CPU**, una distribución equilibrada para este
laboratorio es:

| VM | vCPU | RAM | Disco | IP |
|---|---:|---:|---:|---|
| `k8-master` | 2 | 4 GB | 30 GB | `192.168.90.1` |
| `k8-worker1` | 2 | 5 GB | 40 GB | `192.168.90.2` |
| `k8-worker2` | 2 | 5 GB | 40 GB | `192.168.90.3` |
| `k8-worker3` | 2 | 5 GB | 40 GB | `192.168.90.4` |
| **Total asignado** | **8 vCPU** | **19 GB** | **150 GB virtuales** | |

Esto deja aproximadamente **13 GB de RAM y 4 hilos** disponibles para el
sistema anfitrión. Los discos QCOW2 son thin-provisioned, por lo que no
consumirán inmediatamente los 150 GB completos.

> **Nota sobre CephFS:** el requerimiento final pide asociar almacenamiento
> persistente a CephFS, pero la guía no define cuántas máquinas Ceph deben
> existir ni su topología. Por ello, esta sección crea únicamente las cuatro
> VMs Kubernetes explícitamente requeridas. Ceph puede conectarse después a
> un clúster existente o desplegarse como una fase separada.

## 0.1.0. Reinicio limpio (opcional, recomendado si ya hiciste intentos previos)

Si ya ejecutaste esta sección antes, limpia primero solo los recursos del
laboratorio Kubernetes (`k8-*` y `k8s-lab`) para empezar desde cero:

```bash
for vm in k8-master k8-worker1 k8-worker2 k8-worker3; do
  sudo virsh destroy "$vm" 2>/dev/null || true
  sudo virsh undefine "$vm" --nvram 2>/dev/null || sudo virsh undefine "$vm" 2>/dev/null || true
done

sudo virsh net-destroy k8s-lab 2>/dev/null || true
sudo virsh net-undefine k8s-lab 2>/dev/null || true

sudo rm -f /var/lib/libvirt/images/k8s-lab/k8-*.qcow2 \
           /var/lib/libvirt/images/k8s-lab/k8-*-seed.iso \
           /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img
sudo rmdir /var/lib/libvirt/images/k8s-lab 2>/dev/null || true
```

Verificar que el reset quedó aplicado:

```bash
sudo virsh list --all | grep -E 'k8-master|k8-worker' || true
sudo virsh net-list --all | grep k8s-lab || true
ls -lah /var/lib/libvirt/images/k8s-lab 2>/dev/null || echo "Sin carpeta k8s-lab"
```

## 0.1.1. Verificar virtualización en el host

Estos comandos comprueban que el host físico soporta virtualización por hardware antes de crear las VMs.

Ejecutar en tu equipo físico, **no dentro de las VMs**:

```bash
lscpu | grep -E 'Virtualization|Model name|CPU\(s\)'
```

Comprobar que el procesador expone AMD-V o Intel VT-x:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

Debe devolver un valor mayor que `0`.

También puedes verificar KVM:

```bash
lsmod | grep kvm
```

En AMD normalmente aparecerá:

```text
kvm_amd
kvm
```

En Intel:

```text
kvm_intel
kvm
```

## 0.1.2. Instalar KVM, libvirt y herramientas necesarias

Esta sección instala los paquetes que permiten crear, administrar y validar las máquinas virtuales del laboratorio.

En el host Ubuntu/Linux Mint:

```bash
sudo apt update
sudo apt install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  virtinst \
  virt-manager \
  bridge-utils \
  cloud-image-utils \
  qemu-utils \
  libosinfo-bin
```

Habilitar libvirt para que el host pueda administrar las VMs:

```bash
sudo systemctl enable --now libvirtd
```

Verificar que libvirt quedó activo y respondiendo:

```bash
sudo systemctl status libvirtd --no-pager
```

Agregar el usuario actual a los grupos necesarios para usar KVM y libvirt:

```bash
sudo usermod -aG libvirt,kvm "$USER"
```

Aplicar el grupo `libvirt` en la terminal actual sin cerrar sesión:

```bash
newgrp libvirt
```

Verificar que la sesión actual ya puede consultar libvirt:

```bash
virsh list --all
```

Verificar que el host soporta aceleración KVM por hardware:

```bash
virt-host-validate
```

> En este equipo es normal ver advertencias de LXC sobre `devices` y `freezer`.
> Mientras la parte de `QEMU` aparezca en `PASS`, KVM/libvirt puede seguir
> usándose para crear y arrancar las VMs del laboratorio.

## 0.1.3. Crear una red NAT exclusiva para Kubernetes

Aquí se define el bridge y el DHCP que usarán las VMs para comunicarse con el host y entre ellas.

El bridge `virbr90` funciona como un switch virtual interno: conecta el host con las cuatro VMs y permite que todas compartan la misma red privada del laboratorio. El NAT en `192.168.90.254` da salida hacia el exterior sin exponer directamente las VMs a la red física.

La definición de red ya existe en el proyecto en [kubernetes/net/k8s-lab-network.xml](kubernetes/net/k8s-lab-network.xml), así que en esta guía solo la registramos en libvirt.

Crearemos una red libvirt llamada `k8s-lab` con:

- Red: `192.168.90.0/24`
- Gateway/NAT: `192.168.90.254`
- Master: `192.168.90.1`
- Worker 1: `192.168.90.2`
- Worker 2: `192.168.90.3`
- Worker 3: `192.168.90.4`
- DHCP dinámico adicional: `192.168.90.100-200`

Las IP `.1-.4` se asignarán siempre a las mismas MAC mediante DHCP
estático de libvirt.

Esto permite que cada nodo tenga una IP fija y predecible aunque el arranque ocurra en distinto orden, lo que simplifica `kubeadm`, los accesos por SSH y la resolución por nombre dentro del clúster.

Registrar la red NAT en libvirt solo si todavía no existe:

```bash
if ! sudo virsh net-info k8s-lab >/dev/null 2>&1; then
  sudo virsh net-define /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/net/k8s-lab-network.xml
else
  echo "La red k8s-lab ya existe; omitiendo net-define"
fi
```

Iniciar la red NAT solo si todavía no está activa:

```bash
if ! sudo virsh net-info k8s-lab | grep -q "Active:.*yes"; then
  sudo virsh net-start k8s-lab
else
  echo "La red k8s-lab ya está activa; omitiendo net-start"
fi
```

Marcar la red para que arranque automáticamente con el host:

```bash
sudo virsh net-autostart k8s-lab
```

Verificar que la red quedó activa y persistente:

```bash
sudo virsh net-list --all
```

Inspeccionar el XML final de la red:

```bash
sudo virsh net-dumpxml k8s-lab
```

Comprobar que el bridge quedó levantado en el host:

```bash
ip addr show virbr90
```

Deberá aparecer aproximadamente:

```text
192.168.90.254/24
```

## 0.1.4. Preparar el almacenamiento de las VMs

En esta parte se descarga la imagen base de Ubuntu y se crean los discos derivados de cada VM.

Crear directorio:

```bash
sudo mkdir -p /var/lib/libvirt/images/k8s-lab
```

Entrar:

```bash
cd /var/lib/libvirt/images/k8s-lab
```

Descargar la imagen oficial Ubuntu Server 24.04 LTS Cloud Image:

```bash
sudo curl -fL --retry 3 --retry-delay 2 \
  -o /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

Verificar que la imagen descargada sea valida:

```bash
sudo ls -lh /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img
sudo file /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img
```

Comprobar tamano minimo para evitar archivos invalidos (por ejemplo 512 bytes):

```bash
test "$(sudo stat -c%s /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img)" -gt 100000000 \
  || { echo "Descarga invalida: imagen demasiado pequena"; exit 1; }
```

Confirmar que la imagen base exista realmente en el directorio de libvirt
antes de crear los overlays:

```bash
sudo ls -lh /var/lib/libvirt/images/k8s-lab/
sudo test -f /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img \
  || { echo "Falta la imagen base en /var/lib/libvirt/images/k8s-lab/"; exit 1; }
```

Si en este punto el directorio solo muestra los archivos `*-seed.iso`, no
continues con `qemu-img create`: vuelve a ejecutar primero la descarga de la
imagen base.

Crear los discos QCOW2 derivados de la imagen base (usando el formato real de la imagen base):

Detectar el formato real de la imagen base (por ejemplo `qcow2` o `raw`) y
usarlo en `-F`:

```bash
BASE_IMG="/var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img"
BASE_FMT="$(sudo qemu-img info "$BASE_IMG" | awk -F': ' '/file format/ {print $2; exit}')"
echo "Formato detectado de imagen base: $BASE_FMT"
test -n "$BASE_FMT" || { echo "No se pudo detectar el formato de la imagen base"; exit 1; }
```

```bash
sudo qemu-img create \
  -f qcow2 \
  -F "$BASE_FMT" \
  -b /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img \
  /var/lib/libvirt/images/k8s-lab/k8-master.qcow2 \
  30G
```

```bash
sudo qemu-img create \
  -f qcow2 \
  -F "$BASE_FMT" \
  -b /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img \
  /var/lib/libvirt/images/k8s-lab/k8-worker1.qcow2 \
  40G
```

```bash
sudo qemu-img create \
  -f qcow2 \
  -F "$BASE_FMT" \
  -b /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img \
  /var/lib/libvirt/images/k8s-lab/k8-worker2.qcow2 \
  40G
```

```bash
sudo qemu-img create \
  -f qcow2 \
  -F "$BASE_FMT" \
  -b /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img \
  /var/lib/libvirt/images/k8s-lab/k8-worker3.qcow2 \
  40G
```

Verificar que la imagen descargada es válida:

```bash
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/k8-master.qcow2
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/k8-worker1.qcow2
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/k8-worker2.qcow2
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/k8-worker3.qcow2
```

## 0.1.5. Preparar una llave SSH para acceder a las VMs

Los comandos siguientes preparan la llave pública que cloud-init insertará en las cuatro VMs.

Verificar si ya tienes llave Ed25519:

```bash
ls -l ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
```

Si todavía no existe, crearla:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''
```

Mostrar la llave pública:

```bash
cat ~/.ssh/id_ed25519.pub
```

Guardar la llave en una variable:

```bash
PUBKEY="$(cat ~/.ssh/id_ed25519.pub)"
```

Verificar que los discos QCOW2 apuntan a la imagen base correcta:

```bash
echo "$PUBKEY"
```

Comprobar que la variable no este vacia antes de generar los archivos
`user-data`:

```bash
test -n "$PUBKEY" || { echo "PUBKEY esta vacia; revisa ~/.ssh/id_ed25519.pub"; exit 1; }
```

## 0.1.6. Crear los archivos cloud-init

En esta sección se generan los archivos `user-data`, `meta-data` y las ISO seed que leerán las VMs al arrancar.

Crearemos el usuario `uceda` en las cuatro VMs y autorizaremos la llave
SSH del host.

Crear directorio de trabajo dentro del proyecto:

```bash
PROJECT_DIR="$HOME/Documents/InstalacionOpenstack/openstack-ansible/kubernetes"
CLOUD_INIT_DIR="$PROJECT_DIR/cloud-init"
mkdir -p "$CLOUD_INIT_DIR"
cd "$CLOUD_INIT_DIR"
```

Si estas repitiendo el laboratorio, limpia primero artefactos anteriores de
cloud-init en esta carpeta:

```bash
rm -f k8-*-user-data k8-*-meta-data k8-*-seed.iso
```

Importante: en todos los bloques `cat <<EOF`, la palabra `EOF` final debe
quedar sola en su propia linea. No escribas comandos al final de esa misma
linea, porque el archivo quedaria truncado y cloud-init no recibira el bloque
completo.

### Cloud-init del master

```bash
cat <<EOF > k8-master-user-data
#cloud-config
hostname: k8-master
manage_etc_hosts: true

users:
  - default
  - name: uceda
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${PUBKEY}

ssh_pwauth: false

package_update: true
packages:
  - qemu-guest-agent

growpart:
  mode: auto
  devices: ['/']

resize_rootfs: true

runcmd:
  - systemctl enable --now qemu-guest-agent
EOF
```

Crear metadata:

```bash
cat <<'EOF' > k8-master-meta-data
instance-id: k8-master
local-hostname: k8-master
EOF
```

Crear ISO seed:

```bash
cloud-localds \
  k8-master-seed.iso \
  k8-master-user-data \
  k8-master-meta-data
```

### Cloud-init del worker 1

```bash
cat <<EOF > k8-worker1-user-data
#cloud-config
hostname: k8-worker1
manage_etc_hosts: true

users:
  - default
  - name: uceda
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${PUBKEY}

ssh_pwauth: false

package_update: true
packages:
  - qemu-guest-agent

growpart:
  mode: auto
  devices: ['/']

resize_rootfs: true

runcmd:
  - systemctl enable --now qemu-guest-agent
EOF
```

```bash
cat <<'EOF' > k8-worker1-meta-data
instance-id: k8-worker1
local-hostname: k8-worker1
EOF
```

```bash
cloud-localds \
  k8-worker1-seed.iso \
  k8-worker1-user-data \
  k8-worker1-meta-data
```

### Cloud-init del worker 2

```bash
cat <<EOF > k8-worker2-user-data
#cloud-config
hostname: k8-worker2
manage_etc_hosts: true

users:
  - default
  - name: uceda
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${PUBKEY}

ssh_pwauth: false

package_update: true
packages:
  - qemu-guest-agent

growpart:
  mode: auto
  devices: ['/']

resize_rootfs: true

runcmd:
  - systemctl enable --now qemu-guest-agent
EOF
```

```bash
cat <<'EOF' > k8-worker2-meta-data
instance-id: k8-worker2
local-hostname: k8-worker2
EOF
```

```bash
cloud-localds \
  k8-worker2-seed.iso \
  k8-worker2-user-data \
  k8-worker2-meta-data
```

### Cloud-init del worker 3

```bash
cat <<EOF > k8-worker3-user-data
#cloud-config
hostname: k8-worker3
manage_etc_hosts: true

users:
  - default
  - name: uceda
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${PUBKEY}

ssh_pwauth: false

package_update: true
packages:
  - qemu-guest-agent

growpart:
  mode: auto
  devices: ['/']

resize_rootfs: true

runcmd:
  - systemctl enable --now qemu-guest-agent
EOF
```

```bash
cat <<'EOF' > k8-worker3-meta-data
instance-id: k8-worker3
local-hostname: k8-worker3
EOF
```

```bash
cloud-localds \
  k8-worker3-seed.iso \
  k8-worker3-user-data \
  k8-worker3-meta-data
```

Mover los seeds al directorio de libvirt:

```bash
sudo mkdir -p /var/lib/libvirt/images/k8s-lab/
sudo cp ./*-seed.iso /var/lib/libvirt/images/k8s-lab/
```

Verificar que la llave SSH se guardó correctamente:

```bash
ls -lh ./*-seed.iso
ls -lh /var/lib/libvirt/images/k8s-lab/
```

## 0.1.7. Verificar el identificador de Ubuntu 24.04 para virt-install

Este paso confirma el nombre exacto de la variante de Ubuntu que virt-install debe usar al registrar la VM.

Ejecutar:

```bash
osinfo-query os | grep -i 'Ubuntu 24.04'
```

En una instalación actual debería aparecer un identificador equivalente
a:

```text
ubuntu24.04
```

Las siguientes órdenes utilizan:

```text
--os-variant ubuntu24.04
```

## 0.1.7.1. Crear las cuatro VMs en una sola pasada

Este script automatiza la creación de las cuatro máquinas cuando ya existen la red, los discos y las seeds.

Si prefieres ejecutar la creación de las cuatro VMs con un solo bloque,
puedes usar este script en el host una vez que ya existan:

- la red `k8s-lab`,
- los discos QCOW2,
- y los archivos `*-seed.iso`.

En esta versión, el script y sus salidas se guardan dentro del proyecto
en `/home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes`,
para que todo el laboratorio quede centralizado en la misma carpeta.

```bash
PROJECT_DIR="/home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes"
mkdir -p "$PROJECT_DIR/scripts" "$PROJECT_DIR/logs"
```

```bash
cat <<'EOF' > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/scripts/create-k8s-lab-vms.sh
#!/usr/bin/env bash
set -euo pipefail

VM_DIR="/var/lib/libvirt/images/k8s-lab"

for vm in k8-master k8-worker1 k8-worker2 k8-worker3; do
  if sudo virsh dominfo "$vm" >/dev/null 2>&1; then
    echo "La VM $vm ya existe en libvirt; se omite"
    continue
  fi

  case "$vm" in
    k8-master)
      memory=4096
      vcpus=2
      disk="$VM_DIR/k8-master.qcow2"
      seed="$VM_DIR/k8-master-seed.iso"
      mac="52:54:00:90:00:01"
      ;;
    k8-worker1)
      memory=5120
      vcpus=2
      disk="$VM_DIR/k8-worker1.qcow2"
      seed="$VM_DIR/k8-worker1-seed.iso"
      mac="52:54:00:90:00:02"
      ;;
    k8-worker2)
      memory=5120
      vcpus=2
      disk="$VM_DIR/k8-worker2.qcow2"
      seed="$VM_DIR/k8-worker2-seed.iso"
      mac="52:54:00:90:00:03"
      ;;
    k8-worker3)
      memory=5120
      vcpus=2
      disk="$VM_DIR/k8-worker3.qcow2"
      seed="$VM_DIR/k8-worker3-seed.iso"
      mac="52:54:00:90:00:04"
      ;;
  esac

  sudo virt-install \
    --name "$vm" \
    --memory "$memory" \
    --vcpus "$vcpus" \
    --cpu host-passthrough \
    --import \
    --disk path="$disk",format=qcow2,bus=virtio \
    --disk path="$seed",device=cdrom \
    --network network=k8s-lab,model=virtio,mac="$mac" \
    --os-variant ubuntu24.04 \
    --graphics none \
    --noautoconsole
done
EOF
```

Dar permisos y ejecutarlo:

```bash
chmod +x /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/scripts/create-k8s-lab-vms.sh
/home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/scripts/create-k8s-lab-vms.sh
```

Verificar al finalizar:

```bash
sudo virsh list --all
sudo virsh net-dhcp-leases k8s-lab
sudo virsh list --all > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/logs/virsh-list-all.txt
sudo virsh net-dhcp-leases k8s-lab > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/logs/virsh-net-dhcp-leases-k8s-lab.txt
```

Si `virsh net-dhcp-leases k8s-lab` aparece vacío, verifica IP por dominio:

```bash
for vm in k8-master k8-worker1 k8-worker2 k8-worker3; do
  echo "===== $vm ====="
  sudo virsh domifaddr "$vm" --source lease || true
done
```

> Importante: si ejecutas esta sección `0.1.7.1`, **no repitas** luego los
> comandos de creación individual de `0.1.8` a `0.1.11`. Si los repites,
> `virt-install` mostrará errores como "Disk ... is already in use by other
> guests" porque esas VMs ya existen y están usando esos discos.

Si retomas el laboratorio en otro momento, usa este flujo de reanudación
en lugar de volver a ejecutar `virt-install`:

```bash
for vm in k8-master k8-worker1 k8-worker2 k8-worker3; do
  if sudo virsh dominfo "$vm" >/dev/null 2>&1; then
    state="$(sudo virsh domstate "$vm" | tr -d '[:space:]')"
    if [ "$state" != "running" ]; then
      sudo virsh start "$vm"
    fi
  else
    echo "La VM $vm no existe; debes crearla con 0.1.7.1 o 0.1.8-0.1.11"
  fi
done

sudo virsh list --all
for vm in k8-master k8-worker1 k8-worker2 k8-worker3; do
  sudo virsh domifaddr "$vm" --source lease || true
done
```

## 0.1.8. Crear VM `k8-master`

Aquí se crea la VM del plano de control con su disco, su ISO seed y su MAC fija.

> Ejecuta esta sección **solo** si no usaste `0.1.7.1` y la VM aún no existe.

```bash
sudo virt-install \
  --name k8-master \
  --memory 4096 \
  --vcpus 2 \
  --cpu host-passthrough \
  --import \
  --disk path=/var/lib/libvirt/images/k8s-lab/k8-master.qcow2,format=qcow2,bus=virtio \
  --disk path=/var/lib/libvirt/images/k8s-lab/k8-master-seed.iso,device=cdrom \
  --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:01 \
  --os-variant ubuntu24.04 \
  --graphics none \
  --noautoconsole
```

## 0.1.9. Crear VM `k8-worker1`

Esta orden crea el primer worker con la misma red y una asignación de recursos un poco mayor.

> Ejecuta esta sección **solo** si no usaste `0.1.7.1` y la VM aún no existe.

```bash
sudo virt-install \
  --name k8-worker1 \
  --memory 5120 \
  --vcpus 2 \
  --cpu host-passthrough \
  --import \
  --disk path=/var/lib/libvirt/images/k8s-lab/k8-worker1.qcow2,format=qcow2,bus=virtio \
  --disk path=/var/lib/libvirt/images/k8s-lab/k8-worker1-seed.iso,device=cdrom \
  --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:02 \
  --os-variant ubuntu24.04 \
  --graphics none \
  --noautoconsole
```

## 0.1.10. Crear VM `k8-worker2`

Esta orden registra el segundo worker con la misma topología de red del laboratorio.

> Ejecuta esta sección **solo** si no usaste `0.1.7.1` y la VM aún no existe.

```bash
sudo virt-install \
  --name k8-worker2 \
  --memory 5120 \
  --vcpus 2 \
  --cpu host-passthrough \
  --import \
  --disk path=/var/lib/libvirt/images/k8s-lab/k8-worker2.qcow2,format=qcow2,bus=virtio \
  --disk path=/var/lib/libvirt/images/k8s-lab/k8-worker2-seed.iso,device=cdrom \
  --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:03 \
  --os-variant ubuntu24.04 \
  --graphics none \
  --noautoconsole
```

## 0.1.11. Crear VM `k8-worker3`

Esta orden registra el tercer worker para completar la topología de 1 master y 3 workers.

> Ejecuta esta sección **solo** si no usaste `0.1.7.1` y la VM aún no existe.

```bash
sudo virt-install \
  --name k8-worker3 \
  --memory 5120 \
  --vcpus 2 \
  --cpu host-passthrough \
  --import \
  --disk path=/var/lib/libvirt/images/k8s-lab/k8-worker3.qcow2,format=qcow2,bus=virtio \
  --disk path=/var/lib/libvirt/images/k8s-lab/k8-worker3-seed.iso,device=cdrom \
  --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:04 \
  --os-variant ubuntu24.04 \
  --graphics none \
  --noautoconsole
```

## 0.1.12. Hacer que las cuatro VMs arranquen con el host

Estos comandos marcan las VMs para que se inicien automáticamente con el servicio libvirt.

```bash
sudo virsh autostart k8-master
sudo virsh autostart k8-worker1
sudo virsh autostart k8-worker2
sudo virsh autostart k8-worker3
```

## 0.1.13. Verificar estado de las VMs

Aquí se valida que las VMs estén encendidas y que DHCP ya les haya entregado dirección.

```bash
sudo virsh list --all
```

Debe observarse algo parecido a:

```text
 Name          State
-------------------------
 k8-master     running
 k8-worker1    running
 k8-worker2    running
 k8-worker3    running
```

Ver las concesiones DHCP:

```bash
sudo virsh net-dhcp-leases k8s-lab
```

Si esta salida aparece vacia, significa que las VMs todavia no han pedido
direccion por DHCP en `k8s-lab`. En ese caso, no continúes con SSH todavia:
primero revisa la consola de la VM y confirma que el sistema termino de
arrancar y que la interfaz de red obtuvo direccion.

Ver interfaces de cada VM:

```bash
sudo virsh domifaddr k8-master
sudo virsh domifaddr k8-worker1
sudo virsh domifaddr k8-worker2
sudo virsh domifaddr k8-worker3
```

## 0.1.14. Esperar a que termine cloud-init

Esta parte espera a que cloud-init termine de crear el usuario y configurar la VM antes de intentar entrar por SSH.

La primera inicialización puede tardar unos minutos porque cada VM
actualiza paquetes e instala `qemu-guest-agent`.

Probar primero conectividad:

```bash
ping -c 2 192.168.90.1
ping -c 2 192.168.90.2
ping -c 2 192.168.90.3
ping -c 2 192.168.90.4
```

Conectarse al master:

```bash
ssh uceda@192.168.90.1
```

Si aparece `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`, elimina la
clave anterior del host recreado y vuelve a conectar:

```bash
ssh-keygen -f "$HOME/.ssh/known_hosts" -R 192.168.90.1
ssh -o StrictHostKeyChecking=accept-new uceda@192.168.90.1
```

Si recreaste todas las VMs, limpia las cuatro entradas y vuelve a confiar:

```bash
for ip in 192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4; do
  ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$ip" || true
done
```

Dentro de la VM comprobar cloud-init:

```bash
cloud-init status --wait
```

Salir:

```bash
exit
```

Repetir la comprobación remotamente:

```bash
ssh uceda@192.168.90.1 'cloud-init status --wait'
ssh uceda@192.168.90.2 'cloud-init status --wait'
ssh uceda@192.168.90.3 'cloud-init status --wait'
ssh uceda@192.168.90.4 'cloud-init status --wait'
```

No ejecutes `cloud-init status --wait` en el host fisico esperando ver el
estado de estas VMs. Ese comando solo muestra el estado de cloud-init del
sistema donde lo ejecutas. Si lo corres en el host y ves `status: disabled`,
ese resultado describe al host, no a `k8-master` ni a los workers.

Si `virsh net-dhcp-leases k8s-lab` y `virsh domifaddr` siguen vacios, entra a
la consola de la VM desde el host:

```bash
sudo virsh console k8-master
```

Y dentro de la VM revisa:

```bash
cloud-init status --wait
ip -br addr
journalctl -u systemd-networkd -b --no-pager | tail -50
```

## 0.1.15. Verificar recursos desde el host

Estos comandos permiten revisar cuánta CPU y memoria consumen las VMs desde el host.

```bash
sudo virsh dominfo k8-master
sudo virsh dominfo k8-worker1
sudo virsh dominfo k8-worker2
sudo virsh dominfo k8-worker3
```

Memoria consumida por las VMs:

```bash
sudo virsh list --name | while read vm; do
  [ -n "$vm" ] && sudo virsh dommemstat "$vm" | awk -v vm="$vm" '/actual/ {printf "%-15s %.2f GiB\n", vm, $2/1024/1024}'
done
```

Ver consumo del host:

```bash
free -h
```

Y CPU:

```bash
top
```

## 0.1.16. Comandos cotidianos de administración

Los siguientes comandos muestran cómo operar las VMs de forma diaria con virsh.

Listar:

```bash
sudo virsh list --all
```

Apagar una VM correctamente:

```bash
sudo virsh shutdown k8-worker1
```

Encender:

```bash
sudo virsh start k8-worker1
```

Reiniciar:

```bash
sudo virsh reboot k8-worker1
```

Forzar apagado solamente si la VM no responde:

```bash
sudo virsh destroy k8-worker1
```

Acceder a la consola:

```bash
sudo virsh console k8-master
```

Salir de la consola de `virsh` con:

```text
Ctrl + ]
```

## 0.1.17. Verificación final antes de instalar Kubernetes

Con estas pruebas se confirma que las VMs responden por red y están listas para instalar Kubernetes.

Desde el host:

```bash
for ip in 192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4; do
  ping -c 1 "$ip"
done
```

Verificar hostname y sistema operativo de todas las VMs:

```bash
for ip in 192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4; do
  echo "===== $ip ====="
  ssh -o StrictHostKeyChecking=accept-new uceda@"$ip" \
    'hostname; grep PRETTY_NAME /etc/os-release; nproc; free -h | head -2'
done
```

Cuando las cuatro máquinas respondan por SSH, continuar con la sección
**1. Requisitos previos** y ejecutar la preparación de Kubernetes en
todos los nodos.

------------------------------------------------------------------------

# 1. Requisitos previos

Esta sección deja cada nodo en un estado mínimo y consistente antes de instalar Kubernetes.

Definir la lista de nodos una vez y reutilizarla en esta sección:

``` bash
set -euo pipefail

if hostname | grep -Eq '^k8-(master|worker[0-9]+)$'; then
  echo "ERROR: este bloque debe ejecutarse en el host fisico, no dentro de una VM." >&2
  echo "Sal de la VM con: exit" >&2
  exit 1
fi

NODES=(192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4)
SSH_OPTS='-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10'
```

> Importante: estos bloques con `for` se ejecutan en el **host físico** del
> laboratorio, no dentro de `k8-master` ni de los workers. No copies ni pegues
> la **salida** de comandos como si fuera entrada: ejecuta solo las líneas de
> los bloques `bash`.

Actualizar e instalar paquetes en **todos los nodos** con un `for`:

``` bash
for ip in "${NODES[@]}"; do
  cmd='sudo apt update && sudo apt upgrade -y && sudo apt install -y curl ca-certificates gpg chrony'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Verificar sistema operativo e IP en **todos los nodos**:

``` bash
for ip in "${NODES[@]}"; do
  cmd='hostname; grep PRETTY_NAME /etc/os-release; ip -br addr'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Verificar conectividad desde el host hacia todos los nodos:

``` bash
for ip in "${NODES[@]}"; do
  ping -c 4 "$ip"
done
```

Requisitos mínimos recomendados para el laboratorio:

-   Control Plane: 2 CPU o más.
-   RAM: 2 GiB o más por nodo.
-   Comunicación IP entre todos los nodos.
-   Cada nodo debe tener hostname, MAC y `product_uuid` únicos.

Verificar UUID de cada nodo con `for`:

``` bash
for ip in "${NODES[@]}"; do
  cmd='sudo cat /sys/class/dmi/id/product_uuid'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

------------------------------------------------------------------------

# 2. Configuración de hora y NTP

Aquí se asegura que todos los nodos compartan la misma hora para evitar errores de certificados y sincronización.

## 2.1 Configurar zona horaria

Primero se ajusta la zona horaria local en cada nodo para que los registros coincidan con el entorno del laboratorio.

Aplicar zona horaria en **todos los nodos** con `for`:

``` bash
for ip in "${NODES[@]}"; do
  cmd='sudo timedatectl set-timezone America/El_Salvador && timedatectl && date'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

## 2.2 Habilitar Chrony

Después se activa el servicio de sincronización horaria en todos los nodos.

Habilitar y verificar Chrony en **todos los nodos** con `for`:

``` bash
for ip in "${NODES[@]}"; do
  cmd='sudo systemctl enable --now chrony && sudo systemctl status chrony --no-pager'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

## 2.3 Configuración opcional del master como referencia NTP

Si prefieres una referencia local, esta parte configura al master como servidor NTP para los workers.

La guía original propone que los workers consulten al master.

Servidor donde ejecutar: **host del laboratorio** (este comando actúa sobre `k8-master` por SSH).

Agregar o ajustar en `k8-master` el servidor NTP institucional (si realmente está disponible):

``` bash
for ip in 192.168.90.1; do
  cmd="sudo sed -i '/^server ntp\\.ues\\.edu\\.sv iburst$/d' /etc/chrony/chrony.conf; echo 'server ntp.ues.edu.sv iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null"
  echo "===== $ip (k8-master) ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Servidor donde ejecutar: **host del laboratorio** (aplica y valida por SSH sobre `k8-master`).

Aplicar y validar Chrony en el master:

``` bash
for ip in 192.168.90.1; do
  cmd='sudo systemctl restart chrony && chronyc sources -v && chronyc tracking'
  echo "===== $ip (k8-master) ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Servidores donde ejecutar: **host del laboratorio** (este comando actúa sobre `k8-worker1`, `k8-worker2`, `k8-worker3` por SSH).

Agregar `server k8-master iburst` en los workers:

``` bash
for ip in 192.168.90.2 192.168.90.3 192.168.90.4; do
  cmd="sudo sed -i '/^server k8-master iburst$/d' /etc/chrony/chrony.conf; echo 'server k8-master iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null"
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Servidores donde ejecutar: **host del laboratorio** (aplica y valida por SSH sobre workers).

Aplicar y validar Chrony en cada worker:

``` bash
for ip in 192.168.90.2 192.168.90.3 192.168.90.4; do
  cmd='sudo systemctl restart chrony && chronyc sources -v'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Si prefieres hacerlo en un solo bloque completo desde el host,
ejecuta este flujo (edita + reinicia/valida workers):

``` bash
for ip in 192.168.90.2 192.168.90.3 192.168.90.4; do
  cmd="sudo sed -i '/^server k8-master iburst$/d' /etc/chrony/chrony.conf; echo 'server k8-master iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null; sudo systemctl restart chrony; chronyc sources -v"
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

> Si `ntp.ues.edu.sv` no responde desde tu red, utiliza servidores NTP
> accesibles o la sincronización NTP de tu infraestructura.

------------------------------------------------------------------------

# 3. Configuración de hostname y `/etc/hosts`

Los nodos necesitan nombres coherentes y resolución local para que kubeadm y kubectl funcionen sin fricción.

## 3.1 Master

Se asigna el hostname definitivo al nodo de control plane.

En el master:

``` bash
sudo hostnamectl set-hostname k8-master
exec bash
```

## 3.2 Worker 1

Se asigna el hostname al primer worker.

``` bash
sudo hostnamectl set-hostname k8-worker1
exec bash
```

## 3.3 Worker 2

Se asigna el hostname al segundo worker.

``` bash
sudo hostnamectl set-hostname k8-worker2
exec bash
```

## 3.4 Worker 3

Se asigna el hostname al tercer worker.

``` bash
sudo hostnamectl set-hostname k8-worker3
exec bash
```

## 3.5 Configurar `/etc/hosts`

Con esta tabla se evita depender de DNS para resolver los nombres internos del clúster.

Aplicar en **todos los nodos** desde el **host físico** del laboratorio:

``` bash
for ip in "${NODES[@]}"; do
  cmd=$'sudo cp /etc/hosts /etc/hosts.bak && sudo sed -i \'/ k8-master$/d;/ k8-worker1$/d;/ k8-worker2$/d;/ k8-worker3$/d\' /etc/hosts && printf \'192.168.90.1 k8-master\\n192.168.90.2 k8-worker1\\n192.168.90.3 k8-worker2\\n192.168.90.4 k8-worker3\\n\' | sudo tee -a /etc/hosts >/dev/null && tail -n 8 /etc/hosts'
  echo "===== $ip ====="
  echo "+ actualizar /etc/hosts"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Este bloque respalda `/etc/hosts`, elimina entradas previas de los nodos del lab y agrega la tabla actualizada:

``` text
192.168.90.1 k8-master
192.168.90.2 k8-worker1
192.168.90.3 k8-worker2
192.168.90.4 k8-worker3
```

Comprobar que la resolución local funciona en todos los nodos:

``` bash
for ip in "${NODES[@]}"; do
  cmd='getent hosts k8-master && getent hosts k8-worker1 && getent hosts k8-worker2 && getent hosts k8-worker3'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

También:

``` bash
for ip in "${NODES[@]}"; do
  cmd='ping -c 2 k8-master'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

------------------------------------------------------------------------

# 4. Deshabilitar Swap

Kubernetes requiere swap deshabilitada para que la memoria del nodo se administre de forma predecible.

Kubelet requiere una configuración compatible con el manejo de memoria
del nodo. Para este laboratorio deshabilitaremos swap.

Deshabilitar swap en caliente en **todos los nodos** desde el **host físico**:

``` bash
for ip in "${NODES[@]}"; do
  cmd='sudo swapoff -a && swapon --show && free -h'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Verificar nuevamente el estado de swap en **todos los nodos**:

``` bash
for ip in "${NODES[@]}"; do
  cmd='swapon --show; free -h'
  echo "===== $ip ====="
  echo "+ revisar swap"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Si `swapon --show` no devuelve entradas, swap está desactivada
actualmente.

## 4.1 Deshabilitar swap permanentemente

Además de apagarla en caliente, también se elimina del arranque para que no reaparezca tras reiniciar.

Aplicar en **todos los nodos** desde el **host físico**:

``` bash
for ip in "${NODES[@]}"; do
  cmd=$'sudo cp /etc/fstab /etc/fstab.bak && sudo sed -ri \'/^([^#].*\\sswap\\s.*)$/s/^/#/\' /etc/fstab && echo "--- entradas swap en /etc/fstab ---" && grep -nE \'\\sswap\\s\' /etc/fstab || true'
  echo "===== $ip ====="
  echo "+ deshabilitar swap en /etc/fstab"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Este bloque hace respaldo de `/etc/fstab`, comenta las líneas activas que contienen `swap` y muestra el resultado.

Si quieres revisar primero qué entradas detectará antes de modificar, usa:

``` bash
for ip in "${NODES[@]}"; do
  cmd='grep -nE "\\sswap\\s" /etc/fstab || true'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

> El `sed` usado aquí no depende de `swap.img`: comenta cualquier línea no comentada de `/etc/fstab` que contenga el campo `swap`. Si un nodo usa un formato poco común, revísalo antes con el bloque de comprobación.

------------------------------------------------------------------------

# 5. Módulos del kernel y parámetros sysctl

Estos ajustes habilitan el paso de tráfico entre pods y permiten que el sistema operativo filtre paquetes como espera Kubernetes.

Ejecutar en **todos los nodos**.

## 5.1 Cargar módulos automáticamente

Estos módulos permiten a Kubernetes enrutar tráfico de pods a través de bridges y filtrado de red.

Servidor donde ejecutar: **dentro de cada nodo del clúster** (`k8-master`, `k8-worker1`, `k8-worker2` y `k8-worker3`).

``` bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

Cargar los módulos del kernel inmediatamente:

``` bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

Verificar que los módulos quedaron cargados:

``` bash
lsmod | grep overlay
lsmod | grep br_netfilter
```

## 5.2A Configurar parámetros de red con `foreach`

Estos parámetros habilitan el reenvío de tráfico y el filtrado requerido por Kubernetes.

Aplicar en **todos los nodos** desde el **host físico** del laboratorio:

``` bash
for ip in "${NODES[@]}"; do
  cmd=$'cat <<\'EOF\' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF'
  echo "===== $ip ====="
  echo "+ escribir /etc/sysctl.d/k8s.conf"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Aplicar la configuración sysctl al sistema:

``` bash
for ip in "${NODES[@]}"; do
  cmd='sudo sysctl --system'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Verificar que los parámetros del kernel quedaron activos:

``` bash
for ip in "${NODES[@]}"; do
  cmd='sysctl net.bridge.bridge-nf-call-iptables && sysctl net.bridge.bridge-nf-call-ip6tables && sysctl net.ipv4.ip_forward'
  echo "===== $ip ====="
  echo "+ verificar sysctl"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Los valores deben ser `1`.

## 5.2B Configurar parámetros de red manualmente

Esta alternativa hace lo mismo que 5.2A, pero sin utilizar `foreach`. Ejecuta
los siguientes comandos manualmente dentro de cada nodo.

### k8-master

``` bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

### k8-worker1

``` bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

### k8-worker2

``` bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

### k8-worker3

``` bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

En cada nodo, los tres valores verificados deben ser `1`.

------------------------------------------------------------------------

# 6. Instalar y configurar containerd

containerd será el runtime de contenedores que usará kubelet para arrancar los pods.

Ejecutar en **todos los nodos**.

## 6.1 Instalar containerd

Esta instalación deja el runtime de contenedores base que usará kubelet.

Servidor donde ejecutar: **dentro de cada nodo del clúster** (`k8-master`, `k8-worker1`, `k8-worker2` y `k8-worker3`).

Para un laboratorio Ubuntu 24.04 puede instalarse desde los repositorios
del sistema:

``` bash
sudo apt update
sudo apt install -y containerd
```

Verificar que containerd quedó activo después de instalarlo:

``` bash
containerd --version
sudo systemctl status containerd --no-pager
```

## 6.2 Crear configuración de containerd

Generar la configuración completa por defecto facilita dejar containerd alineado con Kubernetes.

``` bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
```

## 6.3 Activar `SystemdCgroup`

Cambiar el driver de cgroups para que Kubernetes y containerd usen systemd.

Aplicar en **todos los nodos** desde el **host físico** del laboratorio:

``` bash
for ip in "${NODES[@]}"; do
  cmd="sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml && grep -n 'SystemdCgroup' /etc/containerd/config.toml"
  echo "===== $ip ====="
  echo "+ activar SystemdCgroup"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Verificar que `SystemdCgroup` quedó habilitado:

``` bash
for ip in "${NODES[@]}"; do
  cmd='grep -n "SystemdCgroup" /etc/containerd/config.toml'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Debe mostrar:

``` text
SystemdCgroup = true
```

## 6.4 Reiniciar y habilitar containerd

Se reinicia el runtime y se deja habilitado para el arranque automático.

Aplicar en **todos los nodos** desde el **host físico** del laboratorio:

``` bash
for ip in "${NODES[@]}"; do
  cmd='sudo systemctl restart containerd && sudo systemctl enable containerd && sudo systemctl status containerd --no-pager'
  echo "===== $ip ====="
  echo "+ reiniciar/habilitar containerd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

> Kubernetes requiere que el runtime y kubelet utilicen una
> configuración de cgroups compatible. `systemd` es la opción
> recomendada para este entorno.

------------------------------------------------------------------------

# 7. Instalar Kubernetes 1.36

En esta sección se agrega el repositorio oficial e instala la versión 1.36 de kubelet, kubeadm y kubectl.

Ejecutar en **todos los nodos**.

## 7.1 Instalar dependencias

Primero se instalan las utilidades mínimas para trabajar con repositorios HTTPS y llaves GPG.

``` bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```

## 7.2 Crear directorio de llaves

Crear el directorio estándar donde APT guardará la llave del repositorio de Kubernetes.

``` bash
sudo mkdir -p -m 755 /etc/apt/keyrings
```

## 7.3 Agregar llave del repositorio Kubernetes v1.36

Importar la llave usada para validar los paquetes descargados desde el repositorio oficial.

``` bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

## 7.4 Agregar repositorio

Registrar el repositorio oficial para que apt pueda encontrar los paquetes de Kubernetes 1.36.

``` bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

## 7.5 Instalar kubelet, kubeadm y kubectl

Instalar los binarios del nodo y fijar su versión para evitar cambios inesperados.

``` bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
```

Bloquear actualización automática de estos paquetes:

``` bash
sudo apt-mark hold kubelet kubeadm kubectl
```

Habilitar kubelet:

``` bash
sudo systemctl enable --now kubelet
```

Verificar versiones:

``` bash
kubeadm version
kubelet --version
kubectl version --client
```

> Es normal que `kubelet` reinicie o aparezca temporalmente con errores
> antes de ejecutar `kubeadm init` o `kubeadm join`.

------------------------------------------------------------------------

# 8. Verificaciones antes de inicializar

Antes de inicializar el clúster conviene revisar que la configuración base esté consistente en todos los nodos.

En **todos los nodos**:

``` bash
swapon --show
```

Debe estar vacío.

``` bash
sysctl net.ipv4.ip_forward
```

Debe devolver:

``` text
net.ipv4.ip_forward = 1
```

Verificar containerd:

``` bash
sudo systemctl is-active containerd
```

Debe devolver:

``` text
active
```

En el master:

``` bash
getent hosts k8-master
hostname
ip -br addr
```

------------------------------------------------------------------------

# 9. Inicializar el Control Plane

Ahora se crea el primer nodo del clúster y se define el CIDR interno de los pods.

> Ejecutar **solamente en `k8-master`**.

La guía original utiliza `172.16.0.0/16` para la red de Pods.
Mantendremos ese CIDR.

Antes de usarlo, comprueba que no choque con la red física, VPN u otra
red de tu infraestructura:

``` bash
ip route
```

Antes de inicializar, ejecuta este bloque **una sola vez** en `k8-master`.
El bloque detecta si `kubeadm init` ya fue ejecutado y evita repetirlo:

``` bash
if [[ -f /etc/kubernetes/admin.conf || \
      -f /etc/kubernetes/manifests/kube-apiserver.yaml || \
      -d /var/lib/etcd ]]; then
  echo "El control plane ya está inicializado. No ejecutes kubeadm init otra vez."
  echo "Continúa con la sección 9.1 y después instala Calico en la sección 10."
else
  echo "El control plane todavía no está inicializado. Ejecutando kubeadm init..."
  sudo kubeadm init \
    --control-plane-endpoint=k8-master \
    --pod-network-cidr=172.16.0.0/16
fi
```

Si aparece cualquiera de estos errores:

``` text
Port-6443 is in use
FileAvailable--etc-kubernetes-manifests-*.yaml already exists
DirAvailable--var-lib-etcd: /var/lib/etcd is not empty
```

significa que el control plane ya fue inicializado. No uses
`--ignore-preflight-errors` ni repitas `kubeadm init`. Continúa con la
sección 9.1. Si necesitas reconstruir el clúster desde cero, utiliza la
sección 18 completa antes de volver a esta sección.

## 9.1 Configurar kubectl para el usuario normal

Copiar la configuración administrativa para que el usuario actual pueda usar kubectl sin sudo.

Después de que `kubeadm init` termine correctamente:

``` bash
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
```

Verificar que kubectl ya puede consultar el clúster:

``` bash
kubectl cluster-info
kubectl get nodes
```

En este momento el master puede aparecer como `NotReady`. Es esperado
mientras todavía no exista un CNI funcional.

## 9.2 Guardar el comando `kubeadm join`

Guardar el comando de unión para poder agregar después los workers al clúster.

Al finalizar `kubeadm init` aparecerá un comando parecido a este, que luego se ejecutará en los workers:

``` bash
sudo kubeadm join k8-master:6443 \
  --token TOKEN_GENERADO \
  --discovery-token-ca-cert-hash sha256:HASH_GENERADO
```

**No copies los tokens de ejemplo de la guía original.** Debes utilizar
los generados por tu propio clúster.

Si perdiste el comando:

``` bash
kubeadm token create --print-join-command
```

------------------------------------------------------------------------

# 10. Instalar Calico como CNI

Calico se usará como único plugin de red para que los pods puedan comunicarse entre nodos.

> Ejecutar solamente desde el master, utilizando el `kubectl`
> configurado.

**Importante:** esta versión de la guía utiliza **Calico solamente**. No
instalar Flannel además de Calico.

La documentación actual de Calico utiliza el Tigera Operator. Al momento
de esta revisión, la documentación oficial muestra Calico `v3.32.1`.

## 10.1 Instalar CRDs

Primero se instalan las definiciones personalizadas que Calico necesita.

``` bash
kubectl apply --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/v1_crd_projectcalico_org.yaml
```

## 10.2 Instalar Tigera Operator

Después se instala el operador que despliega y administra Calico.

``` bash
kubectl apply --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml
```

> En algunas versiones de Calico, las anotaciones de las CRD superan el
> límite permitido por `kubectl apply` tradicional. Si aparece un error como
> `metadata.annotations: Too long`, utiliza `--server-side` como en estos
> comandos.

## 10.3 Descargar `custom-resources.yaml`

Descargar el manifiesto que define los recursos finales de Calico.

``` bash
curl -LO https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/custom-resources.yaml
```

Respaldarlo:

``` bash
cp custom-resources.yaml custom-resources.yaml.bak
```

Revisar el CIDR actual:

``` bash
grep -n -A5 -B5 "cidr:" custom-resources.yaml
```

Cambiar el CIDR predeterminado de Calico por el mismo utilizado en
`kubeadm init`:

``` bash
sed -i 's#cidr: 192\.168\.0\.0/16#cidr: 172.16.0.0/16#g' custom-resources.yaml
```

Confirmar:

``` bash
grep -n "cidr:" custom-resources.yaml
```

## 10.4 Crear recursos de Calico

Aplicar la configuración ajustada para que Calico cree la red del clúster.

``` bash
kubectl apply --server-side --force-conflicts -f custom-resources.yaml
```

## 10.5 Monitorear Calico

Vigilar el estado de los pods de Tigera hasta que todo quede listo.

``` bash
watch kubectl get tigerastatus
```

Salir con `Ctrl+C`.

También:

``` bash
kubectl get pods -A
kubectl get nodes -o wide
```

Esperar hasta que el master aparezca:

``` text
Ready
```

------------------------------------------------------------------------

# 11. Agregar los Workers

Una vez activo el plano de control y el CNI, se unen los tres workers al clúster.

El comando `kubeadm token create --print-join-command` se ejecuta
**solamente en `k8-master`**. El comando `kubeadm join` se ejecuta
**solamente dentro de cada worker** (`k8-worker1`, `k8-worker2` y
`k8-worker3`). No se ejecuta en el host físico `anfitrion` ni nuevamente
en `k8-master`.

En el master obtener un comando actualizado:

``` bash
kubeadm token create --print-join-command
```

Ejemplo de estructura:

``` bash
sudo kubeadm join k8-master:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

Ejecutar **el comando real generado** dentro de cada worker que todavía no
se haya unido. El endpoint siempre debe ser el del master:
`192.168.90.1:6443`.

-   `k8-worker1`
-   `k8-worker2`
-   `k8-worker3`

Si un worker muestra un mensaje como:

``` text
This node has joined the cluster
```

ese worker ya está unido. No vuelvas a ejecutar `kubeadm join` allí. Si se
repite, aparecerán errores como `kubelet.conf already exists`,
`ca.crt already exists` o `Port-10250 is in use`.

Para comprobar si un worker ya tiene la configuración de unión antes de
repetir el comando:

``` bash
test -f /etc/kubernetes/kubelet.conf && echo "Ya unido; no ejecutar join" || echo "Pendiente de join"
```

El host físico `anfitrion` solo se utiliza para conectarse por SSH:

``` bash
ssh uceda@192.168.90.2
ssh uceda@192.168.90.3
ssh uceda@192.168.90.4
```

Después, en el master:

``` bash
kubectl get nodes
```

Y:

``` bash
kubectl get nodes -o wide
```

El objetivo es obtener cuatro nodos `Ready`:

``` text
k8-master    Ready   control-plane
k8-worker1   Ready   <none>
k8-worker2   Ready   <none>
k8-worker3   Ready   <none>
```

## 11.1 Si el token expiró

Si el comando de unión caducó, genera uno nuevo antes de seguir.

En el master:

``` bash
kubeadm token list
```

Generar uno nuevo y mostrar directamente el `join`:

``` bash
kubeadm token create --print-join-command
```

------------------------------------------------------------------------

# 12. Prueba del clúster con NGINX

NGINX sirve como prueba rápida para confirmar que pods, scheduler y servicios funcionan.

En el master:

``` bash
kubectl create deployment nginx-app --image=nginx --replicas=2
```

Verificar que Calico quedó disponible y que el clúster progresa a `Ready`:

``` bash
kubectl get deployment nginx-app
kubectl get pods -o wide
```

Esperar a que las réplicas estén disponibles:

``` bash
kubectl rollout status deployment/nginx-app
```

Exponer mediante NodePort:

``` bash
kubectl expose deployment nginx-app --type=NodePort --port=80
```

Ver servicio:

``` bash
kubectl get svc nginx-app
```

Ver detalles:

``` bash
kubectl describe svc nginx-app
```

Obtener solamente el NodePort:

``` bash
kubectl get svc nginx-app -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'
```

Obtener IP de nodos:

``` bash
kubectl get nodes -o wide
```

Probar desde una máquina con acceso a la red:

``` bash
curl http://IP_DE_UN_NODO:NODEPORT
```

Por ejemplo:

``` bash
curl http://192.168.90.2:31396
```

> El NodePort exacto puede ser diferente en cada instalación.

------------------------------------------------------------------------

# 13. Instalar Helm

Helm se usa para desplegar charts empaquetados como el Dashboard.

> Ejecutar en el master.

En esta guía se instala Helm desde Snap. El repositorio APT tradicional de
Helm puede devolver errores de certificado o dejar de publicar su índice.

## 13.1 Instalar Helm

``` bash
sudo snap install helm --classic
```

Verificar:

``` bash
helm version
```

------------------------------------------------------------------------

# 14. Instalar Kubernetes Dashboard con Helm

Con Helm se instala el Dashboard oficial en un namespace dedicado.

> El repositorio Helm histórico `https://kubernetes.github.io/dashboard/`
> puede devolver `404`. Para conservar el procedimiento del laboratorio,
> se utiliza el paquete oficial publicado del chart `7.14.0`.

``` bash
curl -fsSL -o "$HOME/kubernetes-dashboard-7.14.0.tgz" \
  https://github.com/kubernetes/dashboard/releases/download/kubernetes-dashboard-7.14.0/kubernetes-dashboard-7.14.0.tgz
```

Instalar el chart del Dashboard en su namespace dedicado:

``` bash
helm upgrade --install kubernetes-dashboard \
  "$HOME/kubernetes-dashboard-7.14.0.tgz" \
  --create-namespace \
  --namespace kubernetes-dashboard
```

Verificar que el Dashboard quedó desplegado correctamente:

``` bash
helm list -n kubernetes-dashboard
kubectl get pods -n kubernetes-dashboard
kubectl get svc -n kubernetes-dashboard
```

Esperar hasta que los Pods estén `Running`/`Ready`.

------------------------------------------------------------------------

# 15. Acceder al Dashboard mediante port-forward

Esta forma de acceso es útil para pruebas locales sin exponer el servicio al exterior.

La forma recomendada para una prueba local es abrir un port-forward hacia el servicio del Dashboard:

``` bash
kubectl -n kubernetes-dashboard port-forward \
  svc/kubernetes-dashboard-kong-proxy 8443:443
```

Desde la misma máquina:

``` text
https://localhost:8443
```

Si el comando se ejecuta directamente dentro de una VM remota y
necesitas acceso desde otro equipo, una alternativa de laboratorio es
escuchar en una interfaz concreta o en todas las interfaces:

``` bash
kubectl -n kubernetes-dashboard port-forward \
  --address 0.0.0.0 \
  svc/kubernetes-dashboard-kong-proxy 8443:443
```

Entonces se accede usando la IP del master y el puerto publicado:

``` text
https://IP_DEL_MASTER:8443
```

> **Advertencia:** `--address 0.0.0.0` expone el port-forward a la red.
> Úsalo solamente en un laboratorio controlado y protegido por firewall.
> Para una instalación estable utiliza un método de exposición diseñado
> para ello, por ejemplo Ingress.

------------------------------------------------------------------------

# 16. Crear usuario de laboratorio para Dashboard

Se crea un usuario de ejemplo con privilegios completos para simplificar la práctica.

> Este usuario tendrá privilegios `cluster-admin`. No es una
> configuración recomendada para producción.

## 16.1 Crear ServiceAccount

``` bash
cat <<'EOF' > admin-user.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF
```

Aplicar el ServiceAccount al clúster:

``` bash
kubectl apply -f admin-user.yml
```

## 16.2 Crear ClusterRoleBinding

``` bash
cat <<'EOF' > admin-rbac.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin-user
    namespace: kubernetes-dashboard
EOF
```

Aplicar el ClusterRoleBinding al clúster:

``` bash
kubectl apply -f admin-rbac.yml
```

Verificar que la cuenta y el enlace de permisos quedaron creados:

``` bash
kubectl get serviceaccount admin-user -n kubernetes-dashboard
kubectl get clusterrolebinding admin-user
```

## 16.3 Crear token

``` bash
kubectl -n kubernetes-dashboard create token admin-user
```

Copiar el token y utilizarlo en el Dashboard.

------------------------------------------------------------------------

# 17. Diagnóstico rápido

Estas órdenes ayudan a identificar fallos en nodos, pods, red o runtime.

## 17.1 Ver todos los nodos

``` bash
kubectl get nodes -o wide
```

## 17.2 Ver todos los Pods

``` bash
kubectl get pods -A -o wide
```

## 17.3 Ver eventos recientes

``` bash
kubectl get events -A --sort-by='.lastTimestamp'
```

## 17.4 Estado de kubelet

En el nodo problemático:

``` bash
sudo systemctl status kubelet --no-pager
```

Logs:

``` bash
sudo journalctl -u kubelet -n 200 --no-pager
```

Logs en tiempo real:

``` bash
sudo journalctl -u kubelet -f
```

## 17.5 Estado de containerd

``` bash
sudo systemctl status containerd --no-pager
```

Logs:

``` bash
sudo journalctl -u containerd -n 200 --no-pager
```

## 17.6 Verificar CNI/Calico

``` bash
kubectl get tigerastatus
kubectl get pods -A | grep -Ei 'calico|tigera'
```

## 17.7 Inspeccionar un Pod problemático

``` bash
kubectl describe pod NOMBRE_POD -n NAMESPACE
```

Logs:

``` bash
kubectl logs NOMBRE_POD -n NAMESPACE
```

Para un Pod con varios contenedores:

``` bash
kubectl logs NOMBRE_POD -n NAMESPACE -c NOMBRE_CONTENEDOR
```

------------------------------------------------------------------------

# 18. Cómo reiniciar el laboratorio si `kubeadm init` salió mal

Si la inicialización quedó a medias, esta sección limpia el nodo para reconstruirlo desde cero.

> Esto destruye la configuración Kubernetes del nodo. Utilizar
> únicamente si quieres reconstruir el laboratorio.

En el master:

``` bash
sudo kubeadm reset -f
```

Eliminar kubeconfig local:

``` bash
rm -rf "$HOME/.kube"
```

Limpiar restos de CNI si estás reconstruyendo completamente:

``` bash
sudo rm -rf /etc/cni/net.d
```

Reiniciar containerd y kubelet:

``` bash
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

En workers que ya se hubieran unido y también deban reiniciarse:

``` bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

Después vuelve a ejecutar la sección **9. Inicializar el Control
Plane**.

------------------------------------------------------------------------

# 19. Checklist final del clúster base

La lista final confirma que el clúster base quedó en un estado funcional antes de seguir con WordPress o Ceph.

``` bash
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
kubectl get svc -A
```

Debe cumplirse:

-   [ ] `k8-master` está `Ready`.
-   [ ] `k8-worker1` está `Ready`.
-   [ ] `k8-worker2` está `Ready`.
-   [ ] `k8-worker3` está `Ready`.
-   [ ] CoreDNS está `Running`.
-   [ ] Calico/Tigera está saludable.
-   [ ] `containerd` está activo en todos los nodos.
-   [ ] Swap está deshabilitada.
-   [ ] El deployment de NGINX tiene sus réplicas disponibles.
-   [ ] El servicio NGINX responde mediante NodePort.
-   [ ] Helm está instalado.
-   [ ] Dashboard está desplegado mediante Helm.

------------------------------------------------------------------------

# 20. Requerimientos del laboratorio original

Aquí se resume lo que pide la guía académica para que no se pierda el objetivo final.

La guía solicita finalmente:

1.  Desplegar un clúster Kubernetes con al menos:
    -   1 nodo master/control-plane.
    -   3 nodos worker.
2.  Desplegar una interfaz web de administración.
3.  Desplegar WordPress incluyendo:
    -   aplicación,
    -   base de datos,
    -   Redis Cache.
4.  Asociar almacenamiento persistente respaldado por CephFS.
5.  Exponer WordPress mediante una IP diferente a la del master y
    directamente por HTTPS/443.

> **Observación técnica importante:** el punto de "Aplicación, Base de
> datos y Redis Cache agrupados en un Pod" puede reproducirse para
> cumplir literalmente un laboratorio, pero no representa la
> arquitectura Kubernetes recomendada. Normalmente WordPress, base de
> datos y Redis deberían desplegarse como workloads/servicios separados,
> permitiendo escalado, actualizaciones y persistencia independientes.

------------------------------------------------------------------------

# 21. Siguiente fase recomendada del laboratorio

Con el clúster base listo, estos son los pasos lógicos para continuar con almacenamiento y aplicaciones.

Una vez que este clúster base esté completamente funcional, continuar en
este orden:

1.  Instalar/configurar CephFS o conectar Kubernetes con un clúster Ceph
    existente mediante CSI.
2.  Crear `StorageClass`.
3.  Crear `PersistentVolumeClaim`.
4.  Desplegar la base de datos con almacenamiento persistente.
5.  Desplegar Redis.
6.  Desplegar WordPress.
7.  Crear `Service` para cada componente.
8.  Instalar/configurar un Ingress Controller o un LoadBalancer para la
    red local.
9.  Asociar una IP dedicada/flotante.
10. Configurar TLS y publicar WordPress por `https://IP/` o,
    preferiblemente, por un nombre DNS.

------------------------------------------------------------------------

# 22. Fuentes utilizadas para la revisión

Esta lista deja trazabilidad de la documentación oficial usada para corregir la guía.

## Documento base

-   **Universidad de El Salvador - Guía Instalación Cluster Kubernetes -
    Revisión 2026**, proporcionada como base de este documento.

## Documentación oficial consultada

-   Kubernetes - Installing kubeadm:\
    https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

-   Kubernetes - Creating a cluster with kubeadm:\
    https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

-   Kubernetes - Dashboard:\
    https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

-   Calico - Kubernetes Quickstart:\
    https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart

-   Ubuntu Cloud Images - Ubuntu Server 24.04 LTS:\
    https://cloud-images.ubuntu.com/releases/24.04/release/

-   libvirt - Network XML format:\
    https://libvirt.org/formatnetwork.html

-   Ubuntu - virt-install manual:\
    https://manpages.ubuntu.com/manpages/jammy/man1/virt-install.1.html

------------------------------------------------------------------------

# 23. Nota sobre Kubernetes Dashboard en 2026

La nota final aclara el contexto actual del Dashboard y la alternativa Headlamp.

Aunque la guía académica pide Kubernetes Dashboard y la documentación
todavía describe su instalación con Helm, el ecosistema está
evolucionando. Kubernetes publicó en julio de 2026 una guía de migración
de **Kubernetes Dashboard a Headlamp**.

Para cumplir el laboratorio, puedes mantener Dashboard. Para una
plataforma nueva o de mayor duración, conviene evaluar Headlamp por
separado después de completar los requerimientos académicos.

------------------------------------------------------------------------

**Fin de la guía revisada.**
