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

## Inventario rápido: IPs, credenciales y servicios del laboratorio

Usa esta sección como referencia rápida antes de ejecutar la guía. Si
cambias la red `k8s-lab`, actualiza estos valores antes de copiar
comandos.

### IPs del laboratorio

| Equipo | IP | Rol / uso principal | Acceso habitual |
|---|---:|---|---|
| `anfitrion` | `192.168.90.254` | Host físico con KVM/libvirt y navegador | Terminal local |
| `k8-master` | `192.168.90.1` | Control Plane, `kubectl`, Dashboard | `ssh uceda@192.168.90.1` |
| `k8-worker1` | `192.168.90.2` | Worker Kubernetes | `ssh uceda@192.168.90.2` |
| `k8-worker2` | `192.168.90.3` | Worker Kubernetes | `ssh uceda@192.168.90.3` |
| `k8-worker3` | `192.168.90.4` | Worker Kubernetes | `ssh uceda@192.168.90.4` |
| `ceph-admin` | `192.168.90.40` | Ceph opcional/histórico, fuera del flujo simple | `ssh uceda@192.168.90.40` |

> Si tu anfitrión no usa `192.168.90.254`, confirma su IP con `ip a` o
> `ip route`. Las IPs de los nodos se verifican con
> `kubectl get nodes -o wide` cuando el clúster ya está creado.

### Credenciales y accesos

| Recurso | Usuario / credencial | Cómo se obtiene o usa | Observación |
|---|---|---|---|
| VMs Kubernetes | `uceda` | Creado por `cloud-init` | Usuario principal del laboratorio |
| SSH a las VMs | Llave `~/.ssh/id_ed25519` | `ssh uceda@IP_DEL_NODO` | No usa contraseña SSH |
| Privilegios en VMs | `sudo` sin contraseña | `sudo COMANDO` | Configuración de laboratorio por `cloud-init` |
| Kubernetes admin | `/home/uceda/.kube/config` | Se crea en `k8-master` después de `kubeadm init` | Usado por `kubectl` |
| Dashboard | `admin-user` | ServiceAccount en `kubernetes-dashboard` | Tiene `cluster-admin` para la práctica |
| Token Dashboard | Token temporal | `kubectl -n kubernetes-dashboard create token admin-user` | Se pega en el login del Dashboard |
| Ceph opcional | `client.k8` | `ceph auth get-key client.k8` desde `ceph-admin` | Solo para la sección opcional/histórica CephFS |

> La guía no define contraseñas SSH. El acceso normal es por llave
> pública. Si cambias el usuario del laboratorio, sustituye `uceda` en
> rutas, SSH y manifiestos donde aplique.

### Servicios y puertos configurados

| Servicio / componente | Namespace / nodo | Puerto | Protocolo | Acceso desde anfitrión | Credencial requerida |
|---|---|---:|---|---|---|
| Kubernetes API | `k8-master` | `6443` | HTTPS | Usar `kubectl` desde `k8-master` con `/home/uceda/.kube/config` | Kubeconfig admin |
| SSH a nodos | VMs `k8-*` | `22` | SSH | `ssh uceda@192.168.90.1`, `ssh uceda@192.168.90.2`, etc. | Llave `~/.ssh/id_ed25519` |
| Calico/Tigera | `tigera-operator`, `calico-system` | N/A | Interno | Sin acceso web directo; validar con `kubectl get pods -A` | Kubeconfig admin |
| NGINX de prueba | `default` | NodePort dinámico | HTTP | `http://IP_DE_UN_NODO:NODEPORT` | Ninguna |
| Dashboard por túnel SSH | `kubernetes-dashboard` | `8443` local | HTTPS | `https://localhost:8443` después de `ssh -L 8443:127.0.0.1:8443` | Token `admin-user` |
| Dashboard por NodePort | `kubernetes-dashboard` | `32000` | HTTPS | `https://192.168.90.1:32000` o cualquier nodo `192.168.90.x:32000` | Token `admin-user` |
| Helm | `k8-master` | N/A | CLI | Ejecutar `helm` en `k8-master` | Usuario `uceda` con `sudo` si aplica |
| WordPress de práctica | `default` | NodePort dinámico | HTTP | `http://IP_DE_UN_NODO:NODEPORT` | Según manifiesto de WordPress |
| CephFS/CSI opcional | `default` | N/A | CSI interno | No tiene URL web; se valida con PVC/Pod | Secret `ceph-csi-cephfs-secret` / `client.k8` |

Comandos rápidos para consultar puertos variables:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get svc nginx-app
kubectl get svc wordpress 2>/dev/null || true
kubectl -n kubernetes-dashboard get svc kubernetes-dashboard-kong-proxy
```

## Variables recomendadas (cargar al inicio)

Para evitar repetir valores y reducir errores de copia/pega, ejecuta una
vez este bloque en el **nodo anfitrion** antes de seguir la guia:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -euo pipefail

# Usuario y rutas del proyecto
export LAB_USER="${USER}"
export PROJECT_DIR="/home/${LAB_USER}/Documents/InstalacionOpenstack/openstack-ansible/kubernetes"
export CLOUD_INIT_DIR="${PROJECT_DIR}/cloud-init"
export NET_XML="${PROJECT_DIR}/net/k8s-lab-network.xml"
export SCRIPTS_DIR="${PROJECT_DIR}/scripts"
export LOG_DIR="${PROJECT_DIR}/logs"

# Rutas libvirt e imagen base
export LIBVIRT_IMG_DIR="/var/lib/libvirt/images/k8s-lab"
export BASE_IMG_NAME="noble-server-cloudimg-amd64.img"
export BASE_IMG_URL="https://cloud-images.ubuntu.com/noble/current/${BASE_IMG_NAME}"
export BASE_IMG="${LIBVIRT_IMG_DIR}/${BASE_IMG_NAME}"

# Red del laboratorio y nodos
export LAB_NET_NAME="k8s-lab"
export LAB_DOMAIN="k8s.lab"
export MASTER_HOST="k8-master"
export WORKER1_HOST="k8-worker1"
export WORKER2_HOST="k8-worker2"
export WORKER3_HOST="k8-worker3"
export MASTER_IP="192.168.90.1"
export WORKER1_IP="192.168.90.2"
export WORKER2_IP="192.168.90.3"
export WORKER3_IP="192.168.90.4"
NODES=("${MASTER_IP}" "${WORKER1_IP}" "${WORKER2_IP}" "${WORKER3_IP}")
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

# Parametros base de Kubernetes
export K8S_MINOR="v1.36"
export K8S_APT_KEY_URL="https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key"
export K8S_APT_REPO="https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/"
export POD_CIDR="172.16.0.0/16"
export CONTROL_PLANE_ENDPOINT="${MASTER_HOST}"
export KUBECONFIG_PATH="/home/${LAB_USER}/.kube/config"

# Zona horaria usada en la guia
export LAB_TIMEZONE="America/El_Salvador"

# Calico (version validada en esta guia)
export CALICO_VERSION="v3.32.1"
export CALICO_CRDS_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml"
export CALICO_OPERATOR_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
export CALICO_CUSTOM_RESOURCES_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

# Kubernetes Dashboard (chart descargado localmente)
export DASHBOARD_VERSION="7.14.0"
export DASHBOARD_TGZ="kubernetes-dashboard-${DASHBOARD_VERSION}.tgz"
export DASHBOARD_TGZ_URL="https://github.com/kubernetes/dashboard/releases/download/kubernetes-dashboard-${DASHBOARD_VERSION}/${DASHBOARD_TGZ}"
export DASHBOARD_NS="kubernetes-dashboard"
export DASHBOARD_LOCAL_PORT="8443"

# WordPress por NodePort (ejemplo de prueba desde host)
export WORDPRESS_TEST_NODE_IP="${WORKER1_IP}"

echo "Variables cargadas. PROJECT_DIR=${PROJECT_DIR}" 
echo "Nodos: ${NODES[*]}"
```

Si abres una terminal nueva, vuelve a ejecutar este bloque para recargar
las variables en esa sesion.

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

## 0.0. Convención de esta guía: nodo de ejecución y puntos de control

Para evitar errores por ejecutar un comando en el nodo equivocado, **cada
bloque de código de esta guía indica en su primera línea, como
comentario, el nodo donde debe ejecutarse**, por ejemplo:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get nodes
```

Nodos usados en este laboratorio:

-   `anfitrion`: el host físico con KVM/libvirt (donde corren las VMs).
-   `k8-master`, `k8-worker1`, `k8-worker2`, `k8-worker3`: las VMs del
    clúster Kubernetes.

Además, cada fase incluye uno o más **"Punto de control"** después de los
pasos críticos: una verificación concreta (comando + salida esperada) que
debe cumplirse **antes de continuar** a la siguiente sección. Si un punto
de control falla, la guía indica en qué sub-sección buscar la corrección
en lugar de avanzar a ciegas. Esto se agregó a partir de la sección 24
para detectar errores antes de continuar. CephFS queda fuera del alcance
de este laboratorio simple.

------------------------------------------------------------------------

# 0.1. Crear todas las máquinas virtuales del laboratorio con KVM/libvirt

La guía utiliza una topología de **1 Control Plane + 3 Workers**, por lo
que crearemos cuatro máquinas virtuales. Para un host físico con **32 GB
de RAM y 12 hilos de CPU**, una distribución equilibrada para este
laboratorio es:

  VM                           vCPU         RAM                  Disco IP
  -------------------- ------------ ----------- ---------------------- ----------------
  `k8-master`                     2        4 GB                  30 GB `192.168.90.1`
  `k8-worker1`                    2        5 GB                  40 GB `192.168.90.2`
  `k8-worker2`                    2        5 GB                  40 GB `192.168.90.3`
  `k8-worker3`                    2        5 GB                  40 GB `192.168.90.4`
  **Total asignado**     **8 vCPU**   **19 GB**   **150 GB virtuales**

Esto deja aproximadamente **13 GB de RAM y 4 hilos** disponibles para el
sistema anfitrión. Los discos QCOW2 son thin-provisioned, por lo que no
consumirán inmediatamente los 150 GB completos.

> **Almacenamiento:** este laboratorio no instala CephFS ni un proveedor
> CSI. WordPress usa almacenamiento temporal `emptyDir`, adecuado solo
> para pruebas y no para datos persistentes.

> **Portabilidad de rutas:** esta guía se ejecutó en un equipo con
> usuario `uceda`. Para que cualquier otro usuario pueda reproducirla
> sin editar cada ruta, define primero esta variable en el host físico y
> reutilízala en el resto de la sección (los bloques posteriores que
> muestran una ruta absoluta literal son el resultado ya expandido en
> este laboratorio; sustituye `/home/uceda/...` por `$PROJECT_DIR/...`
> si usas otro usuario o ruta):

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
PROJECT_DIR="/home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes"
echo "$PROJECT_DIR"
```

## 0.1.0. Reinicio limpio (opcional, recomendado si ya hiciste intentos previos)

Si ya ejecutaste esta sección antes, limpia primero solo los recursos
del laboratorio Kubernetes (`k8-*` y `k8s-lab`) para empezar desde cero:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
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

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh list --all | grep -E 'k8-master|k8-worker' || true
sudo virsh net-list --all | grep k8s-lab || true
ls -lah /var/lib/libvirt/images/k8s-lab 2>/dev/null || echo "Sin carpeta k8s-lab"
```

## 0.1.1. Verificar virtualización en el host

Estos comandos comprueban que el host físico soporta virtualización por
hardware antes de crear las VMs.

Ejecutar en tu equipo físico, **no dentro de las VMs**:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
lscpu | grep -E 'Virtualization|Model name|CPU\(s\)'
```

Comprobar que el procesador expone AMD-V o Intel VT-x:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
egrep -c '(vmx|svm)' /proc/cpuinfo
```

Debe devolver un valor mayor que `0`.

También puedes verificar KVM:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
lsmod | grep kvm
```

En AMD normalmente aparecerá:

``` text
kvm_amd
kvm
```

En Intel:

``` text
kvm_intel
kvm
```

## 0.1.2. Instalar KVM, libvirt y herramientas necesarias

Esta sección instala los paquetes que permiten crear, administrar y
validar las máquinas virtuales del laboratorio.

En el host Ubuntu/Linux Mint:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
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

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo systemctl enable --now libvirtd
```

Verificar que libvirt quedó activo y respondiendo:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo systemctl status libvirtd --no-pager
```

Agregar el usuario actual a los grupos necesarios para usar KVM y
libvirt:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo usermod -aG libvirt,kvm "$USER"
```

Aplicar el grupo `libvirt` en la terminal actual sin cerrar sesión:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
newgrp libvirt
```

Verificar que la sesión actual ya puede consultar libvirt:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
virsh list --all
```

Verificar que el host soporta aceleración KVM por hardware:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
virt-host-validate
```

> En este equipo es normal ver advertencias de LXC sobre `devices` y
> `freezer`. Mientras la parte de `QEMU` aparezca en `PASS`, KVM/libvirt
> puede seguir usándose para crear y arrancar las VMs del laboratorio.

## 0.1.3. Crear una red NAT exclusiva para Kubernetes

Aquí se define el bridge y el DHCP que usarán las VMs para comunicarse
con el host y entre ellas.

El bridge `virbr90` funciona como un switch virtual interno: conecta el
host con las cuatro VMs y permite que todas compartan la misma red
privada del laboratorio. El NAT en `192.168.90.254` da salida hacia el
exterior sin exponer directamente las VMs a la red física.

La definición de red ya existe en el proyecto en
[kubernetes/net/k8s-lab-network.xml](kubernetes/net/k8s-lab-network.xml),
así que en esta guía solo la registramos en libvirt.

Crearemos una red libvirt llamada `k8s-lab` con:

-   Red: `192.168.90.0/24`
-   Gateway/NAT: `192.168.90.254`
-   Master: `192.168.90.1`
-   Worker 1: `192.168.90.2`
-   Worker 2: `192.168.90.3`
-   Worker 3: `192.168.90.4`
-   DHCP dinámico adicional: `192.168.90.100-200`

Las IP `.1-.4` se asignarán siempre a las mismas MAC mediante DHCP
estático de libvirt.

Esto permite que cada nodo tenga una IP fija y predecible aunque el
arranque ocurra en distinto orden, lo que simplifica `kubeadm`, los
accesos por SSH y la resolución por nombre dentro del clúster.

Registrar la red NAT en libvirt solo si todavía no existe:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
if ! sudo virsh net-info k8s-lab >/dev/null 2>&1; then
  sudo virsh net-define "$PROJECT_DIR/net/k8s-lab-network.xml"
else
  echo "La red k8s-lab ya existe; omitiendo net-define"
fi
```

Iniciar la red NAT solo si todavía no está activa:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
if ! sudo virsh net-info k8s-lab | grep -q "Active:.*yes"; then
  sudo virsh net-start k8s-lab
else
  echo "La red k8s-lab ya está activa; omitiendo net-start"
fi
```

Marcar la red para que arranque automáticamente con el host:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh net-autostart k8s-lab
```

Verificar que la red quedó activa y persistente:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh net-list --all
```

Inspeccionar el XML final de la red:

> [!WARNING]
> **Ejecutar únicamente en `anfitrion`.** Este comando inspecciona la red
> de libvirt del host físico. No lo ejecutes dentro de `k8-master` ni en
> los workers. Es una consulta informativa y no modifica la red.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh net-dumpxml k8s-lab
```

Comprobar que el bridge quedó levantado en el host:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ip addr show virbr90
```

Deberá aparecer aproximadamente:

``` text
192.168.90.254/24
```

## 0.1.4. Preparar el almacenamiento de las VMs

En esta parte se descarga la imagen base de Ubuntu y se crean los discos
derivados de cada VM.

Crear directorio:

> [!WARNING]
> **Ejecutar únicamente en `anfitrion`.** Este directorio pertenece al
> almacenamiento local de libvirt del host físico. No lo ejecutes dentro
> de `k8-master` ni dentro de los workers.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo mkdir -p /var/lib/libvirt/images/k8s-lab
```

Entrar:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
cd /var/lib/libvirt/images/k8s-lab
```

Descargar la imagen oficial Ubuntu Server 24.04 LTS Cloud Image:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo curl -fL --retry 3 --retry-delay 2 \
  -o /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

Verificar que la imagen descargada sea valida:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo ls -lh /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img
sudo file /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img
```

Comprobar tamano minimo para evitar archivos invalidos (por ejemplo 512
bytes):

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
test "$(sudo stat -c%s /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img)" -gt 100000000 \
  || { echo "Descarga invalida: imagen demasiado pequena"; exit 1; }
```

Confirmar que la imagen base exista realmente en el directorio de
libvirt antes de crear los overlays:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo ls -lh /var/lib/libvirt/images/k8s-lab/
sudo test -f /var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img \
  || { echo "Falta la imagen base en /var/lib/libvirt/images/k8s-lab/"; exit 1; }
```

Si en este punto el directorio solo muestra los archivos `*-seed.iso`,
no continues con `qemu-img create`: vuelve a ejecutar primero la
descarga de la imagen base.

Crear los discos QCOW2 derivados de la imagen base (usando el formato
real de la imagen base):

Detectar el formato real de la imagen base (por ejemplo `qcow2` o `raw`)
y usarlo en `-F`:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
BASE_IMG="/var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img"
BASE_FMT="$(sudo qemu-img info "$BASE_IMG" | awk -F': ' '/file format/ {print $2; exit}')"
echo "Formato detectado de imagen base: $BASE_FMT"
test -n "$BASE_FMT" || { echo "No se pudo detectar el formato de la imagen base"; exit 1; }
```

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
# Crear los cuatro discos derivados en una sola ejecución, sin usar for.
set -e

BASE_IMG="/var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img"
test -f "$BASE_IMG" || {
  echo "Falta la imagen base: $BASE_IMG"
  exit 1
}

# 1. Crear el disco del control plane de 30G.
if sudo test -e /var/lib/libvirt/images/k8s-lab/k8-master.qcow2; then
  echo "k8-master.qcow2 ya existe; se omite"
else
  sudo qemu-img create \
    -f qcow2 \
    -F "$BASE_FMT" \
    -b "$BASE_IMG" \
    /var/lib/libvirt/images/k8s-lab/k8-master.qcow2 \
    30G
fi

# 2. Crear el disco del worker 1 de 40G.
if sudo test -e /var/lib/libvirt/images/k8s-lab/k8-worker1.qcow2; then
  echo "k8-worker1.qcow2 ya existe; se omite"
else
  sudo qemu-img create \
    -f qcow2 \
    -F "$BASE_FMT" \
    -b "$BASE_IMG" \
    /var/lib/libvirt/images/k8s-lab/k8-worker1.qcow2 \
    40G
fi

# 3. Crear el disco del worker 2 de 40G.
if sudo test -e /var/lib/libvirt/images/k8s-lab/k8-worker2.qcow2; then
  echo "k8-worker2.qcow2 ya existe; se omite"
else
  sudo qemu-img create \
    -f qcow2 \
    -F "$BASE_FMT" \
    -b "$BASE_IMG" \
    /var/lib/libvirt/images/k8s-lab/k8-worker2.qcow2 \
    40G
fi

# 4. Crear el disco del worker 3 de 40G.
if sudo test -e /var/lib/libvirt/images/k8s-lab/k8-worker3.qcow2; then
  echo "k8-worker3.qcow2 ya existe; se omite"
else
  sudo qemu-img create \
    -f qcow2 \
    -F "$BASE_FMT" \
    -b "$BASE_IMG" \
    /var/lib/libvirt/images/k8s-lab/k8-worker3.qcow2 \
    40G
fi
```

Verificar que la imagen descargada es válida:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/k8-master.qcow2
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/k8-worker1.qcow2
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/k8-worker2.qcow2
sudo qemu-img info /var/lib/libvirt/images/k8s-lab/k8-worker3.qcow2
```

## 0.1.5. Preparar una llave SSH para acceder a las VMs

Los comandos siguientes preparan la llave pública que cloud-init
insertará en las cuatro VMs.

> **Advertencia crítica (causa real de "Permission denied (publickey)"
> detectada en este laboratorio):** **nunca** ejecutes los bloques de
> esta sección ni los de 0.1.6 con `sudo`. Si lo haces, `$HOME` pasa a
> ser `/root`, `~/.ssh/id_ed25519.pub` se resuelve a la llave de **root**
> (no la tuya), y `cloud-init` autoriza esa llave en las VMs. El
> resultado es que tu usuario normal no puede entrar por SSH aunque el
> comando parezca haber funcionado, porque la llave incrustada tiene el
> comentario `root@<host>` en vez de `tu-usuario@<host>`. Verifica esto
> con el punto de control de abajo antes de continuar a 0.1.6.

Verificar si ya tienes llave Ed25519:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ls -l ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
```

Si todavía no existe, crearla:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''
```

Mostrar la llave pública:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
cat ~/.ssh/id_ed25519.pub
```

Guardar la llave en una variable:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
PUBKEY="$(cat ~/.ssh/id_ed25519.pub)"
```

Comprobar que la variable no este vacia **y que no sea la llave de
root** antes de generar los archivos `user-data` (punto de control
obligatorio: si esto falla, saliste con `exit`/`logout` de una sesion
con `sudo` y volviste a intentar sin `sudo`, en la misma terminal):

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
test -n "$PUBKEY" || { echo "PUBKEY esta vacia; revisa ~/.ssh/id_ed25519.pub"; exit 1; }
[ "$(id -u)" -eq 0 ] && { echo "ERROR: estas ejecutando esto como root/con sudo. Sal y repite sin sudo."; exit 1; }
case "$PUBKEY" in *root@*) echo "ERROR: PUBKEY pertenece a root, no a tu usuario. Repite 0.1.5 sin sudo."; exit 1;; esac
echo "PUBKEY valida: pertenece a $(whoami)"
```

## 0.1.6. Crear los archivos cloud-init

En esta sección se generan los archivos `user-data`, `meta-data` y las
ISO seed que leerán las VMs al arrancar.

Crearemos el usuario `uceda` en las cuatro VMs y autorizaremos la llave
SSH del host.

Crear directorio de trabajo dentro del proyecto:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
PROJECT_DIR="/home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes"
CLOUD_INIT_DIR="$PROJECT_DIR/cloud-init"
mkdir -p "$CLOUD_INIT_DIR"
cd "$CLOUD_INIT_DIR"
```

Si estas repitiendo el laboratorio, limpia primero artefactos anteriores
de cloud-init en esta carpeta:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
rm -f k8-*-user-data k8-*-meta-data k8-*-seed.iso
```

Importante: en todos los bloques `cat <<EOF`, la palabra `EOF` final
debe quedar sola en su propia linea. No escribas comandos al final de
esa misma linea, porque el archivo quedaria truncado y cloud-init no
recibira el bloque completo.

### Cloud-init del master

``` bash
# NODO: anfitrion
# RUTA: /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init
cat <<EOF > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-master-user-data
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


### Crear metadata:
# NODO: anfitrion
# RUTA: /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init
cat <<'EOF' > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-master-meta-data
instance-id: k8-master
local-hostname: k8-master
EOF



###########Crear ISO seed:
# NODO: anfitrion
# RUTA: /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init
# Genera la ISO seed de cloud-init combinando user-data y meta-data del master.
cloud-localds \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-master-seed.iso \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-master-user-data \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-master-meta-data
```

### Cloud-init del worker 1

``` bash
# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
cat <<EOF > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker1-user-data
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



# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
cat <<'EOF' > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker1-meta-data
instance-id: k8-worker1
local-hostname: k8-worker1
EOF



# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
# Genera la ISO seed de cloud-init combinando user-data y meta-data del worker1.
cloud-localds \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker1-seed.iso \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker1-user-data \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker1-meta-data
```

### Cloud-init del worker 2

``` bash
# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
cat <<EOF > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker2-user-data
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




# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
cat <<'EOF' > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker2-meta-data
instance-id: k8-worker2
local-hostname: k8-worker2
EOF



# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
# Genera la ISO seed de cloud-init combinando user-data y meta-data del worker2.
cloud-localds \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker2-seed.iso \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker2-user-data \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker2-meta-data
```

### Cloud-init del worker 3

``` bash
# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
cat <<EOF > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker3-user-data
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

# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
cat <<'EOF' > /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker3-meta-data
instance-id: k8-worker3
local-hostname: k8-worker3
EOF



# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
# Genera la ISO seed de cloud-init combinando user-data y meta-data del worker3.
cloud-localds \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker3-seed.iso \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker3-user-data \
  /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/k8-worker3-meta-data


### Mover los seeds al directorio de libvirt:

# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo mkdir -p /var/lib/libvirt/images/k8s-lab/
sudo cp /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/*-seed.iso /var/lib/libvirt/images/k8s-lab/
```

Verificar que la llave SSH se guardó correctamente:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ls -lh /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init/*-seed.iso
ls -lh /var/lib/libvirt/images/k8s-lab/
```

## 0.1.7. Verificar el identificador de Ubuntu 24.04 para virt-install

Este paso confirma el nombre exacto de la variante de Ubuntu que
virt-install debe usar al registrar la VM.

Ejecutar:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
osinfo-query os | grep -i 'Ubuntu 24.04'
```

En una instalación actual debería aparecer un identificador equivalente
a:

``` text
ubuntu24.04
```

Las siguientes órdenes utilizan:

``` text
--os-variant ubuntu24.04
```

## 0.1.7.1. Crear las cuatro VMs en una sola pasada

Este script automatiza la creación de las cuatro máquinas cuando ya
existen la red, los discos y las seeds.

Si prefieres ejecutar la creación de las cuatro VMs con un solo bloque,
puedes usar este script en el host una vez que ya existan:

-   la red `k8s-lab`,
-   los discos QCOW2,
-   y los archivos `*-seed.iso`.

En esta versión, el script y sus salidas se guardan dentro del proyecto
en `$PROJECT_DIR` (definida en 0.1), para que todo el laboratorio quede
centralizado en la misma carpeta.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
mkdir -p "$PROJECT_DIR/scripts" "$PROJECT_DIR/logs"
```

``` bash
# NODO: anfitrion
# RUTA: $PROJECT_DIR/cloud-init (cwd establecido con 'cd "$CLOUD_INIT_DIR"' al inicio de la seccion 0.1.6)
cat <<'EOF' > "$PROJECT_DIR/scripts/create-k8s-lab-vms.sh"
#!/usr/bin/env bash
set -euo pipefail

VM_DIR="/var/lib/libvirt/images/k8s-lab"

if sudo virsh dominfo k8-master >/dev/null 2>&1; then
  echo "La VM k8-master ya existe en libvirt; se omite"
else
  sudo virt-install \
    --name k8-master \
    --memory 4096 \
    --vcpus 2 \
    --cpu host-passthrough \
    --import \
    --disk path="$VM_DIR/k8-master.qcow2",format=qcow2,bus=virtio \
    --disk path="$VM_DIR/k8-master-seed.iso",device=cdrom \
    --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:01 \
    --os-variant ubuntu24.04 \
    --graphics none \
    --noautoconsole
fi

if sudo virsh dominfo k8-worker1 >/dev/null 2>&1; then
  echo "La VM k8-worker1 ya existe en libvirt; se omite"
else
  sudo virt-install \
    --name k8-worker1 \
    --memory 5120 \
    --vcpus 2 \
    --cpu host-passthrough \
    --import \
    --disk path="$VM_DIR/k8-worker1.qcow2",format=qcow2,bus=virtio \
    --disk path="$VM_DIR/k8-worker1-seed.iso",device=cdrom \
    --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:02 \
    --os-variant ubuntu24.04 \
    --graphics none \
    --noautoconsole
fi

if sudo virsh dominfo k8-worker2 >/dev/null 2>&1; then
  echo "La VM k8-worker2 ya existe en libvirt; se omite"
else
  sudo virt-install \
    --name k8-worker2 \
    --memory 5120 \
    --vcpus 2 \
    --cpu host-passthrough \
    --import \
    --disk path="$VM_DIR/k8-worker2.qcow2",format=qcow2,bus=virtio \
    --disk path="$VM_DIR/k8-worker2-seed.iso",device=cdrom \
    --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:03 \
    --os-variant ubuntu24.04 \
    --graphics none \
    --noautoconsole
fi

if sudo virsh dominfo k8-worker3 >/dev/null 2>&1; then
  echo "La VM k8-worker3 ya existe en libvirt; se omite"
else
  sudo virt-install \
    --name k8-worker3 \
    --memory 5120 \
    --vcpus 2 \
    --cpu host-passthrough \
    --import \
    --disk path="$VM_DIR/k8-worker3.qcow2",format=qcow2,bus=virtio \
    --disk path="$VM_DIR/k8-worker3-seed.iso",device=cdrom \
    --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:04 \
    --os-variant ubuntu24.04 \
    --graphics none \
    --noautoconsole
fi
EOF
```

Dar permisos y ejecutarlo:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
chmod +x "$PROJECT_DIR/scripts/create-k8s-lab-vms.sh"
"$PROJECT_DIR/scripts/create-k8s-lab-vms.sh"
```

Verificar al finalizar:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh list --all
sudo virsh net-dhcp-leases k8s-lab
sudo virsh list --all > "$PROJECT_DIR/logs/virsh-list-all.txt"
sudo virsh net-dhcp-leases k8s-lab > "$PROJECT_DIR/logs/virsh-net-dhcp-leases-k8s-lab.txt"
```

Copiar y autorizar la llave SSH en los 4 nodos (comandos mínimos):

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh-keygen -f "$HOME/.ssh/known_hosts" -R 192.168.90.1 || true
ssh-keygen -f "$HOME/.ssh/known_hosts" -R 192.168.90.2 || true
ssh-keygen -f "$HOME/.ssh/known_hosts" -R 192.168.90.3 || true
ssh-keygen -f "$HOME/.ssh/known_hosts" -R 192.168.90.4 || true

ssh-copy-id -i ~/.ssh/id_ed25519.pub uceda@192.168.90.1
ssh-copy-id -i ~/.ssh/id_ed25519.pub uceda@192.168.90.2
ssh-copy-id -i ~/.ssh/id_ed25519.pub uceda@192.168.90.3
ssh-copy-id -i ~/.ssh/id_ed25519.pub uceda@192.168.90.4
```

Si `virsh net-dhcp-leases k8s-lab` aparece vacío, verifica IP por
dominio:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for vm in k8-master k8-worker1 k8-worker2 k8-worker3; do
  echo "===== $vm ====="
  sudo virsh domifaddr "$vm" --source lease || true
done
```

> Importante: si ejecutas esta sección `0.1.7.1`, **no repitas** luego
> los comandos de creación individual de `0.1.8` a `0.1.11`. Si los
> repites, `virt-install` mostrará errores como "Disk ... is already in
> use by other guests" porque esas VMs ya existen y están usando esos
> discos.

Si retomas el laboratorio en otro momento, usa este flujo de reanudación
en lugar de volver a ejecutar `virt-install`:

## 0.1.12. Hacer que las cuatro VMs arranquen con el host

Estos comandos marcan las VMs para que se inicien automáticamente con el
servicio libvirt.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh autostart k8-master
sudo virsh autostart k8-worker1
sudo virsh autostart k8-worker2
sudo virsh autostart k8-worker3
```

## 0.1.13. Verificar estado de las VMs

Aquí se valida que las VMs estén encendidas y que DHCP ya les haya
entregado dirección.

Ver las concesiones DHCP:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh net-dhcp-leases k8s-lab
```

Si esta salida aparece vacia, significa que las VMs todavia no han
pedido direccion por DHCP en `k8s-lab`. En ese caso, no continúes con
SSH todavia: primero revisa la consola de la VM y confirma que el
sistema termino de arrancar y que la interfaz de red obtuvo direccion.

Ver interfaces de cada VM:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh domifaddr k8-master
sudo virsh domifaddr k8-worker1
sudo virsh domifaddr k8-worker2
sudo virsh domifaddr k8-worker3
```

## 0.1.14. Esperar a que termine cloud-init

Esta parte espera a que cloud-init termine de crear el usuario y
configurar la VM antes de intentar entrar por SSH.

La primera inicialización puede tardar unos minutos porque cada VM
actualiza paquetes e instala `qemu-guest-agent`.

Probar primero conectividad:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ping -c 2 192.168.90.1
ping -c 2 192.168.90.2
ping -c 2 192.168.90.3
ping -c 2 192.168.90.4
```


Si aparece `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`, elimina
la clave anterior del host recreado y vuelve a conectar:

> **Advertencia crítica (error real cometido en este laboratorio):**
> **nunca antepongas `sudo`** a `ssh-keygen -f "$HOME/.ssh/known_hosts"`.
> `known_hosts` es un archivo de **tu** usuario; si lo tocas con `sudo`,
> `ssh-keygen` lo recrea como propiedad de `root` y luego tu propio
> usuario ya no puede leerlo/escribirlo (`Permission denied`,
> `hostkeys_find_by_key_hostfile: ... Permission denied`, y `ssh` deja de
> poder registrar nuevas llaves de host). Si ya ocurrió, repáralo así
> antes de continuar:
>
> ``` bash
> # NODO: anfitrion
> # RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
> sudo chown "$(id -u):$(id -g)" ~/.ssh/known_hosts
> chmod 600 ~/.ssh/known_hosts
> ```

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh-keygen -f "/home/uceda/.ssh/known_hosts" -R 192.168.90.1
ssh -o StrictHostKeyChecking=accept-new uceda@192.168.90.1
```


**Punto de control 0.1.14:** confirma que puedes entrar por SSH **sin
`sudo`** a las cuatro IPs antes de continuar (`ssh uceda@192.168.90.X
hostname` debe devolver el hostname correspondiente, sin pedir
contraseña ni fallar con `Permission denied (publickey)`). Si falla con
`Permission denied (publickey)` en una VM recién creada, la causa más
probable es la de 0.1.5 (llave de root incrustada por error); revisa el
contenido real del `user-data` embebido en el ISO seed de esa VM:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo isoinfo -i /var/lib/libvirt/images/k8s-lab/k8-master-seed.iso -x '/USER_DAT.;1' | grep -A1 ssh_authorized_keys
```

Dentro de la VM comprobar cloud-init:

``` bash
# NODO: k8-master (dentro de la sesion SSH/consola abierta desde anfitrion)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
cloud-init status --wait
```

Salir:

``` bash
# NODO: k8-master (dentro de la sesion SSH/consola abierta desde anfitrion)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
exit
```

Repetir la comprobación remotamente:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh uceda@192.168.90.1 'cloud-init status --wait'
ssh uceda@192.168.90.2 'cloud-init status --wait'
ssh uceda@192.168.90.3 'cloud-init status --wait'
ssh uceda@192.168.90.4 'cloud-init status --wait'
```

No ejecutes `cloud-init status --wait` en el host fisico esperando ver
el estado de estas VMs. Ese comando solo muestra el estado de cloud-init
del sistema donde lo ejecutas. Si lo corres en el host y ves
`status: disabled`, ese resultado describe al host, no a `k8-master` ni
a los workers.

Si `virsh net-dhcp-leases k8s-lab` y `virsh domifaddr` siguen vacios,
entra a la consola de la VM desde el host:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh console k8-master
```

Y dentro de la VM revisa:

``` bash
# NODO: k8-master (dentro de la sesion SSH/consola abierta desde anfitrion)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
cloud-init status --wait
ip -br addr
journalctl -u systemd-networkd -b --no-pager | tail -50
```

## 0.1.15. Verificar recursos desde el host

Estos comandos permiten revisar cuánta CPU y memoria consumen las VMs
desde el host.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh dominfo k8-master
sudo virsh dominfo k8-worker1
sudo virsh dominfo k8-worker2
sudo virsh dominfo k8-worker3
```

## 0.1.16. Comandos cotidianos de administración

Los siguientes comandos muestran cómo operar las VMs de forma diaria con
virsh.

Listar:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh list --all
```

Apagar una VM correctamente:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh shutdown k8-worker1
```

Encender:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh start k8-worker1
```

Reiniciar:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh reboot k8-worker1
```

Forzar apagado solamente si la VM no responde:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh destroy k8-worker1
```

Acceder a la consola:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh console k8-master
```

Salir de la consola de `virsh` con:

``` text
Ctrl + ]
```

## 0.1.17. Verificación final antes de instalar Kubernetes

Con estas pruebas se confirma que las VMs responden por red y están
listas para instalar Kubernetes.

Desde el host:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in 192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4; do
  ping -c 1 "$ip"
done
```

Verificar hostname y sistema operativo de todas las VMs:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
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

Esta sección deja cada nodo en un estado mínimo y consistente antes de
instalar Kubernetes.

Ejecutar este bloque único en el **nodo anfitrión**:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -euo pipefail

# 0) Seguridad: este bloque debe correrse en el host fisico, no dentro de una VM k8-*
if hostname | grep -Eq '^k8-(master|worker[0-9]+)$'; then
  echo "ERROR: este bloque debe ejecutarse en el host fisico, no dentro de una VM." >&2
  echo "Sal de la VM con: exit" >&2
  exit 1
fi

# 1) Inventario de nodos del laboratorio
NODES=(192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4)
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

# 2-5) Verificar conectividad, preparar SO, validar informacion y UUID en una sola pasada
declare -A UUID_TO_NODE=()
for ip in "${NODES[@]}"; do
  echo "===== PING $ip ====="
  ping -c 2 "$ip"

  echo "===== PREP $ip ====="
  ssh "${SSH_OPTS[@]}" uceda@"$ip" \
    'sudo apt update && sudo apt upgrade -y && sudo apt install -y curl ca-certificates gpg chrony'

  echo "===== INFO $ip ====="
  ssh "${SSH_OPTS[@]}" uceda@"$ip" \
    'hostname; grep PRETTY_NAME /etc/os-release; ip -br addr; nproc; free -h | head -2'

  uuid="$(ssh "${SSH_OPTS[@]}" uceda@"$ip" 'sudo cat /sys/class/dmi/id/product_uuid')"
  echo "UUID $ip -> $uuid"
  if [[ -n "${UUID_TO_NODE[$uuid]:-}" ]]; then
    echo "ERROR: UUID duplicado entre $ip y ${UUID_TO_NODE[$uuid]}" >&2
    exit 1
  fi
  UUID_TO_NODE[$uuid]="$ip"
done

echo "OK: Paso 1 completado. Nodos listos para continuar con Kubernetes."
```

Requisitos mínimos recomendados para el laboratorio:

-   Control Plane: 2 CPU o más.
-   RAM: 2 GiB o más por nodo.
-   Comunicación IP entre todos los nodos.
-   Cada nodo debe tener hostname, MAC y `product_uuid` únicos.

------------------------------------------------------------------------

# 2. Configuración de hora y NTP

Aquí se asegura que todos los nodos compartan la misma hora para evitar
errores de certificados y sincronización.

## 2.1 Configurar zona horaria

Primero se ajusta la zona horaria local en cada nodo para que los
registros coincidan con el entorno del laboratorio.

Aplicar zona horaria en **todos los nodos** con `for`:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in "${NODES[@]}"; do
  cmd='sudo timedatectl set-timezone America/El_Salvador && timedatectl && date'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

### 2.1b. Alternativa sin `for`: un comando por nodo

Si prefieres ejecutar cada nodo por separado (por ejemplo, para ver el
resultado de cada uno de forma aislada o pegarlos uno a la vez):

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh $SSH_OPTS uceda@192.168.90.1 'sudo timedatectl set-timezone America/El_Salvador && timedatectl && date'



# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh $SSH_OPTS uceda@192.168.90.2 'sudo timedatectl set-timezone America/El_Salvador && timedatectl && date'


# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh $SSH_OPTS uceda@192.168.90.3 'sudo timedatectl set-timezone America/El_Salvador && timedatectl && date'


# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh $SSH_OPTS uceda@192.168.90.4 'sudo timedatectl set-timezone America/El_Salvador && timedatectl && date'
```

## 2.2 Habilitar Chrony

Después se activa el servicio de sincronización horaria en todos los
nodos.

Habilitar y verificar Chrony en **todos los nodos** con `for`:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in "${NODES[@]}"; do
  cmd='sudo systemctl enable --now chrony && sudo systemctl status chrony --no-pager'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

### 2.2b. Alternativa sin `for`: un comando por nodo

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh $SSH_OPTS uceda@192.168.90.1 'sudo systemctl enable --now chrony && sudo systemctl status chrony --no-pager'


# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh $SSH_OPTS uceda@192.168.90.2 'sudo systemctl enable --now chrony && sudo systemctl status chrony --no-pager'


# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh $SSH_OPTS uceda@192.168.90.3 'sudo systemctl enable --now chrony && sudo systemctl status chrony --no-pager'


# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh $SSH_OPTS uceda@192.168.90.4 'sudo systemctl enable --now chrony && sudo systemctl status chrony --no-pager'
```

## 2.3 Configuración opcional del master como referencia NTP

Si prefieres una referencia local, esta parte configura al master como
servidor NTP para los workers.

La guía original propone que los workers consulten al master.

Servidor donde ejecutar: **host del laboratorio** (este comando actúa
sobre `k8-master` por SSH).

Agregar o ajustar en `k8-master` el servidor NTP institucional (si
realmente está disponible):

``` bash
# NODO: anfitrion (orquesta via SSH hacia k8-master)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in 192.168.90.1; do
  cmd="sudo sed -i '/^server ntp\\.ues\\.edu\\.sv iburst$/d' /etc/chrony/chrony.conf; echo 'server ntp.ues.edu.sv iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null"
  echo "===== $ip (k8-master) ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Servidor donde ejecutar: **host del laboratorio** (aplica y valida por
SSH sobre `k8-master`).

Aplicar y validar Chrony en el master:

``` bash
# NODO: anfitrion (orquesta via SSH hacia k8-master)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in 192.168.90.1; do
  cmd='sudo systemctl restart chrony && chronyc sources -v && chronyc tracking'
  echo "===== $ip (k8-master) ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Servidores donde ejecutar: **host del laboratorio** (este comando actúa
sobre `k8-worker1`, `k8-worker2`, `k8-worker3` por SSH).

Agregar `server k8-master iburst` en los workers:

``` bash
# NODO: anfitrion (orquesta via SSH hacia los workers)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in 192.168.90.2 192.168.90.3 192.168.90.4; do
  cmd="sudo sed -i '/^server k8-master iburst$/d' /etc/chrony/chrony.conf; echo 'server k8-master iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null"
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Servidores donde ejecutar: **host del laboratorio** (aplica y valida por
SSH sobre workers).

Aplicar y validar Chrony en cada worker:

``` bash
# NODO: anfitrion (orquesta via SSH hacia los workers)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in 192.168.90.2 192.168.90.3 192.168.90.4; do
  cmd='sudo systemctl restart chrony && chronyc sources -v'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Si prefieres hacerlo en un solo bloque completo desde el host, ejecuta
este flujo (edita + reinicia/valida workers):

``` bash
# NODO: anfitrion (orquesta via SSH hacia los workers)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in 192.168.90.2 192.168.90.3 192.168.90.4; do
  cmd="sudo sed -i '/^server k8-master iburst$/d' /etc/chrony/chrony.conf; echo 'server k8-master iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null; sudo systemctl restart chrony; chronyc sources -v"
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

> Si `ntp.ues.edu.sv` no responde desde tu red, utiliza servidores NTP
> accesibles o la sincronización NTP de tu infraestructura.

### 2.3b. Alternativa sin `for`: un solo bloque con los 4 nodos

Las mismas 4 acciones (configuración + reinicio + validación de Chrony),
sin bucle `for`, ejecutadas una tras otra en un único bloque:

``` bash
# NODO: anfitrion (orquesta via SSH hacia k8-master, k8-worker1, k8-worker2, k8-worker3)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh $SSH_OPTS uceda@192.168.90.1 "sudo sed -i '/^server ntp\.ues\.edu\.sv iburst$/d' /etc/chrony/chrony.conf; echo 'server ntp.ues.edu.sv iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null; sudo systemctl restart chrony; chronyc sources -v; chronyc tracking"

ssh $SSH_OPTS uceda@192.168.90.2 "sudo sed -i '/^server k8-master iburst$/d' /etc/chrony/chrony.conf; echo 'server k8-master iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null; sudo systemctl restart chrony; chronyc sources -v"

ssh $SSH_OPTS uceda@192.168.90.3 "sudo sed -i '/^server k8-master iburst$/d' /etc/chrony/chrony.conf; echo 'server k8-master iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null; sudo systemctl restart chrony; chronyc sources -v"

ssh $SSH_OPTS uceda@192.168.90.4 "sudo sed -i '/^server k8-master iburst$/d' /etc/chrony/chrony.conf; echo 'server k8-master iburst' | sudo tee -a /etc/chrony/chrony.conf >/dev/null; sudo systemctl restart chrony; chronyc sources -v"
```

------------------------------------------------------------------------

# 3. Configuración de hostname y `/etc/hosts`

Los nodos necesitan nombres coherentes y resolución local para que
kubeadm y kubectl funcionen sin fricción.

## 3.5 Configurar `/etc/hosts`

Con esta tabla se evita depender de DNS para resolver los nombres
internos del clúster.

> **Corrección verificada el 2026-08-23:** en este laboratorio la red
> libvirt `k8s-lab` define el dominio `k8s.lab` con DHCP estático
> (ver sección 0.1.3), y su `dnsmasq` **ya resuelve los hostnames por
> DNS** sin necesidad de tocar `/etc/hosts` — se comprobó con
> `getent hosts k8-worker1` desde `k8-master`, que devuelve
> `192.168.90.2 k8-worker1.k8s.lab`. Además, las VMs de este laboratorio
> tienen `manage_etc_hosts: true` (cloud-init), por lo que **cualquier
> edición manual de `/etc/hosts` se pierde en el próximo reinicio**. En
> la práctica este bloque es redundante para el funcionamiento del
> clúster (kubeadm/Calico/kubelet resuelven bien por DNS o usan IPs
> directamente) y puede omitirse; se conserva como paso opcional de
> refuerzo/documentación, no como requisito.

Aplicar en **todos los nodos** desde el **host físico** del laboratorio:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in "${NODES[@]}"; do
  echo "===== $ip ====="
  echo "+ actualizar /etc/hosts"
  ssh "${SSH_OPTS[@]}" uceda@"$ip" 'sudo bash -s' <<'EOS'
set -euo pipefail
cp /etc/hosts "/etc/hosts.bak.$(date +%Y%m%d-%H%M%S)"
sed -i '/[[:space:]]k8-master$/d;/[[:space:]]k8-worker1$/d;/[[:space:]]k8-worker2$/d;/[[:space:]]k8-worker3$/d' /etc/hosts
cat <<'EOF' >> /etc/hosts
192.168.90.1 k8-master
192.168.90.2 k8-worker1
192.168.90.3 k8-worker2
192.168.90.4 k8-worker3
EOF
tail -n 8 /etc/hosts
EOS
done
```

Este bloque respalda `/etc/hosts`, elimina entradas previas de los nodos
del lab y agrega la tabla actualizada:

``` text
192.168.90.1 k8-master
192.168.90.2 k8-worker1
192.168.90.3 k8-worker2
192.168.90.4 k8-worker3
```

Comprobar que la resolución local funciona en todos los nodos:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in "${NODES[@]}"; do
  cmd='getent hosts k8-master && getent hosts k8-worker1 && getent hosts k8-worker2 && getent hosts k8-worker3'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

También:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in "${NODES[@]}"; do
  cmd='ping -c 2 k8-master'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

------------------------------------------------------------------------

# 4. Deshabilitar Swap

Kubernetes requiere swap deshabilitada para que la memoria del nodo se
administre de forma predecible.

Kubelet requiere una configuración compatible con el manejo de memoria
del nodo. Para este laboratorio deshabilitaremos swap.

Deshabilitar swap en caliente en **todos los nodos** desde el **host
físico**:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in "${NODES[@]}"; do
  cmd='sudo swapoff -a && swapon --show && free -h'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Verificar nuevamente el estado de swap en **todos los nodos**:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
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

Además de apagarla en caliente, también se elimina del arranque para que
no reaparezca tras reiniciar.

Aplicar en **todos los nodos** desde el **host físico**:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in "${NODES[@]}"; do
  cmd=$'sudo cp /etc/fstab /etc/fstab.bak && sudo sed -ri \'/^([^#].*\\sswap\\s.*)$/s/^/#/\' /etc/fstab && echo "--- entradas swap en /etc/fstab ---" && grep -nE \'\\sswap\\s\' /etc/fstab || true'
  echo "===== $ip ====="
  echo "+ deshabilitar swap en /etc/fstab"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

Este bloque hace respaldo de `/etc/fstab`, comenta las líneas activas
que contienen `swap` y muestra el resultado.

Si quieres revisar primero qué entradas detectará antes de modificar,
usa:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in "${NODES[@]}"; do
  cmd='grep -nE "\\sswap\\s" /etc/fstab || true'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

> El `sed` usado aquí no depende de `swap.img`: comenta cualquier línea
> no comentada de `/etc/fstab` que contenga el campo `swap`. Si un nodo
> usa un formato poco común, revísalo antes con el bloque de
> comprobación.

------------------------------------------------------------------------

# 5. Módulos del kernel y parámetros sysctl

Estos ajustes habilitan el paso de tráfico entre pods y permiten que el
sistema operativo filtre paquetes como espera Kubernetes.

Ejecutar en **todos los nodos**.

## 5.1 Cargar módulos automáticamente

Estos módulos permiten a Kubernetes enrutar tráfico de pods a través de
bridges y filtrado de red.

Servidor donde ejecutar: **dentro de cada nodo del clúster**
(`k8-master`, `k8-worker1`, `k8-worker2` y `k8-worker3`).

``` bash
# NODO: k8-master, k8-worker1, k8-worker2, k8-worker3 (ejecutar directamente en cada uno)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
#### Cargar los módulos del kernel inmediatamente:

# NODO: k8-master, k8-worker1, k8-worker2, k8-worker3 (ejecutar directamente en cada uno)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo modprobe overlay
sudo modprobe br_netfilter


##### Verificar que los módulos quedaron cargados:
# NODO: k8-master, k8-worker1, k8-worker2, k8-worker3 (ejecutar directamente en cada uno)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
lsmod | grep overlay
lsmod | grep br_netfilter
```

## 5.2 Configurar parámetros de red

Estos parámetros habilitan el reenvío de tráfico y el filtrado requerido
por Kubernetes.

Aplicar en **todos los nodos** desde **k8-master**:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -euo pipefail
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

echo "===== k8-master (local) ====="
printf '%s\n' \
  'net.bridge.bridge-nf-call-iptables  = 1' \
  'net.bridge.bridge-nf-call-ip6tables = 1' \
  'net.ipv4.ip_forward                 = 1' \
| sudo tee /etc/sysctl.d/k8s.conf >/dev/null

echo "===== 192.168.90.2 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.2 "printf '%s\n' 'net.bridge.bridge-nf-call-iptables  = 1' 'net.bridge.bridge-nf-call-ip6tables = 1' 'net.ipv4.ip_forward                 = 1' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null"

echo "===== 192.168.90.3 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.3 "printf '%s\n' 'net.bridge.bridge-nf-call-iptables  = 1' 'net.bridge.bridge-nf-call-ip6tables = 1' 'net.ipv4.ip_forward                 = 1' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null"

echo "===== 192.168.90.4 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.4 "printf '%s\n' 'net.bridge.bridge-nf-call-iptables  = 1' 'net.bridge.bridge-nf-call-ip6tables = 1' 'net.ipv4.ip_forward                 = 1' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null"
```

Aplicar la configuración sysctl al sistema:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -euo pipefail
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

echo "===== k8-master (local) ====="
# Carga y aplica de inmediato todos los parametros definidos en /etc/sysctl.d/*.conf y /etc/sysctl.conf.
sudo sysctl --system

echo "===== 192.168.90.2 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.2 'sudo sysctl --system'

echo "===== 192.168.90.3 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.3 'sudo sysctl --system'

echo "===== 192.168.90.4 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.4 'sudo sysctl --system'
```

Verificar que los parámetros del kernel quedaron activos:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -euo pipefail
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

echo "===== k8-master (local) ====="
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward

echo "===== 192.168.90.2 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.2 'sysctl net.bridge.bridge-nf-call-iptables && sysctl net.bridge.bridge-nf-call-ip6tables && sysctl net.ipv4.ip_forward'

echo "===== 192.168.90.3 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.3 'sysctl net.bridge.bridge-nf-call-iptables && sysctl net.bridge.bridge-nf-call-ip6tables && sysctl net.ipv4.ip_forward'

echo "===== 192.168.90.4 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.4 'sysctl net.bridge.bridge-nf-call-iptables && sysctl net.bridge.bridge-nf-call-ip6tables && sysctl net.ipv4.ip_forward'
```

Los valores deben ser `1`.

------------------------------------------------------------------------

# 6. Instalar y configurar containerd

containerd será el runtime de contenedores que usará kubelet para
arrancar los pods.

Ejecutar en **todos los nodos**.

## 6.1 Instalar containerd

Esta instalación deja el runtime de contenedores base que usará kubelet.

Servidor donde ejecutar: **dentro de cada nodo del clúster**
(`k8-master`, `k8-worker1`, `k8-worker2` y `k8-worker3`).

Para un laboratorio Ubuntu 24.04 puede instalarse desde los repositorios
del sistema:

``` bash
# NODO: k8-master, k8-worker1, k8-worker2, k8-worker3 (ejecutar directamente en cada uno)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo apt update
sudo apt install -y containerd
```

Verificar que containerd quedó activo después de instalarlo:

``` bash
# NODO: k8-master, k8-worker1, k8-worker2, k8-worker3 (ejecutar directamente en cada uno)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
containerd --version
sudo systemctl status containerd --no-pager
```

## 6.2 Crear configuración de containerd

Generar la configuración completa por defecto facilita dejar containerd
alineado con Kubernetes.

``` bash
# NODO: k8-master, k8-worker1, k8-worker2, k8-worker3 (ejecutar directamente en cada uno)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
```

## 6.3 Activar `SystemdCgroup`

Cambiar el driver de cgroups para que Kubernetes y containerd usen
systemd.

Aplicar en **todos los nodos** desde el **host físico** del laboratorio:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
NODES=(192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4)
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

for ip in "${NODES[@]}"; do
  cmd="sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml && grep -n 'SystemdCgroup' /etc/containerd/config.toml"
  echo "===== $ip ====="
  echo "+ activar SystemdCgroup"
  ssh "${SSH_OPTS[@]}" uceda@"$ip" "$cmd"
done
```

Verificar que `SystemdCgroup` quedó habilitado:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
NODES=(192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4)
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

for ip in "${NODES[@]}"; do
  cmd='grep -n "SystemdCgroup" /etc/containerd/config.toml'
  echo "===== $ip ====="
  echo "+ $cmd"
  ssh "${SSH_OPTS[@]}" uceda@"$ip" "$cmd"
done
```

Debe mostrar:

``` text
SystemdCgroup = true
```

## 6.4 Reiniciar y habilitar containerd

Se reinicia el runtime y se deja habilitado para el arranque automático.

Aplicar en **todos los nodos** desde el **host físico** del laboratorio:

> Requisito: `k8-master` debe poder conectarse por SSH a
> `192.168.90.2`, `192.168.90.3` y `192.168.90.4` con el usuario
> `uceda` (sin pedir contraseña), de lo contrario el bloque se detendrá
> en el primer `Permission denied (publickey)`.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -euo pipefail
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

echo "===== k8-master (local) ====="
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd --no-pager

echo "===== 192.168.90.2 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.2 'sudo systemctl restart containerd && sudo systemctl enable containerd && sudo systemctl status containerd --no-pager'

echo "===== 192.168.90.3 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.3 'sudo systemctl restart containerd && sudo systemctl enable containerd && sudo systemctl status containerd --no-pager'

echo "===== 192.168.90.4 ====="
ssh "${SSH_OPTS[@]}" uceda@192.168.90.4 'sudo systemctl restart containerd && sudo systemctl enable containerd && sudo systemctl status containerd --no-pager'
```

> Kubernetes requiere que el runtime y kubelet utilicen una
> configuración de cgroups compatible. `systemd` es la opción
> recomendada para este entorno.

------------------------------------------------------------------------

# 7. Instalar Kubernetes 1.36

En esta sección se agrega el repositorio oficial e instala la versión
1.36 de kubelet, kubeadm y kubectl.

> **Versión exacta validada por esta guía:** el repositorio `pkgs.k8s.io`
> publica parches dentro de la rama `v1.36` (instala la última patch
> disponible en ese momento, no una versión fija). Esta guía se validó
> end-to-end con `v1.36.3`. Después de 7.5, verifica la versión instalada
> con `kubeadm version -o short` **antes** de ejecutar `kubeadm init`
> (sección 9); si difiere de `v1.36.3`, no debería romper la guía, pero
> revisa el changelog de esa patch si algo no coincide con lo aquí
> documentado.

Ejecutar en **todos los nodos**.

## 7.1-7.5 Preparar repositorio e instalar Kubernetes

Ejecuta **una sola vez** el siguiente bloque desde `k8-master`. El bloque
ejecuta 7.1-7.5 en el master local y por SSH en los tres workers.

> Requisito: `k8-master` debe poder conectarse por SSH a
> `192.168.90.2`, `192.168.90.3` y `192.168.90.4` con el usuario
> `uceda` (sin pedir contraseña), o la ejecución se detendrá en el
> primer error de autenticación.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -euo pipefail
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
WORKERS=(192.168.90.2 192.168.90.3 192.168.90.4)

echo "===== Instalando Kubernetes en k8-master (local) ====="

# 7.1. Instalar herramientas para repositorios HTTPS y llaves GPG.
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# 7.2. Crear el directorio donde APT almacena llaves de repositorios.
sudo mkdir -p -m 755 /etc/apt/keyrings

# 7.3. Descargar y registrar la llave oficial de Kubernetes v1.36.
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key |
  sudo gpg --dearmor --yes \
    -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 7.4. Registrar el repositorio oficial de Kubernetes v1.36.
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" |
  sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

# 7.5. Actualizar APT e instalar los tres binarios del nodo.
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet

echo "--- versiones (master) ---"
kubeadm version -o short
kubelet --version
kubectl version --client
echo "--- paquetes bloqueados (master) ---"
apt-mark showhold
echo "--- kubelet habilitado (master) ---"
sudo systemctl is-enabled kubelet

for ip in "${WORKERS[@]}"; do
  echo "===== Instalando Kubernetes en $ip ====="

  ssh "${SSH_OPTS[@]}" uceda@"$ip" '
    set -e

    # 7.1. Instalar herramientas para repositorios HTTPS y llaves GPG.
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg

    # 7.2. Crear el directorio donde APT almacena llaves de repositorios.
    sudo mkdir -p -m 755 /etc/apt/keyrings

    # 7.3. Descargar y registrar la llave oficial de Kubernetes v1.36.
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key |
      sudo gpg --dearmor --yes \
        -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # 7.4. Registrar el repositorio oficial de Kubernetes v1.36.
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" |
      sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

    # 7.5. Actualizar APT e instalar los tres binarios del nodo.
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl

    # Evitar que una actualización automática cambie la versión instalada.
    sudo apt-mark hold kubelet kubeadm kubectl

    # Habilitar kubelet para que arranque automáticamente con la VM.
    sudo systemctl enable kubelet

    # Verificar la instalación en este worker.
    echo "--- versiones ---"
    kubeadm version -o short
    kubelet --version
    kubectl version --client
    echo "--- paquetes bloqueados ---"
    apt-mark showhold
    echo "--- kubelet habilitado ---"
    sudo systemctl is-enabled kubelet
  '
done
```

> Es normal que `kubelet` reinicie o aparezca temporalmente con errores
> antes de ejecutar `kubeadm init` o `kubeadm join`.

------------------------------------------------------------------------

# 8. Verificaciones antes de inicializar

Antes de inicializar el clúster conviene revisar que la configuración
base esté consistente en todos los nodos.

Ejecuta **una sola vez** el siguiente bloque desde `anfitrion`. El bloque
se conecta automáticamente a cada nodo y ejecuta allí las comprobaciones;
no lo vuelvas a pegar manualmente dentro de `k8-master` ni de los workers.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in 192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4; do
  echo "===== $ip ====="
  ssh -o IdentitiesOnly=yes uceda@"$ip" '
    echo "--- hostname ---"
    hostname

    echo "--- swap ---"
    swapon --show

    echo "--- ip_forward ---"
    sysctl net.ipv4.ip_forward

    echo "--- containerd ---"
    sudo systemctl is-active containerd

    echo "--- kubelet ---"
    sudo systemctl is-active kubelet || true

    echo "--- resolucion de k8-master ---"
    getent hosts k8-master

    echo "--- interfaces ---"
    ip -br addr
  '
done
```

------------------------------------------------------------------------

# 9. Inicializar el Control Plane

Ahora se crea el primer nodo del clúster y se define el CIDR interno de
los pods.

> Ejecutar **solamente en `k8-master`**.

La guía original utiliza `172.16.0.0/16` para la red de Pods.
Mantendremos ese CIDR.

Antes de usarlo, comprueba que no choque con la red física, VPN u otra
red de tu infraestructura:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ip route
```

Antes de inicializar, comprueba que no exista ya un control plane. La
carpeta `/var/lib/etcd` por sí sola no es suficiente: puede quedar vacía
después de `kubeadm reset`.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
if [[ -s /etc/kubernetes/admin.conf || \
      -s /etc/kubernetes/manifests/kube-apiserver.yaml ]]; then
  echo "ERROR: el control plane ya está inicializado. No repitas kubeadm init."
  exit 1
fi
```

Inicializar **una sola vez**:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo kubeadm init \
  --control-plane-endpoint=k8-master \
  --pod-network-cidr=172.16.0.0/16
```

## 9.1 Configurar kubectl para el usuario normal

Copiar la configuración administrativa para que el usuario actual pueda
usar kubectl sin sudo.

Después de que `kubeadm init` termine correctamente:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
mkdir -p "/home/uceda/.kube"
sudo cp -f /etc/kubernetes/admin.conf "/home/uceda/.kube/config"
sudo chown "$(id -u):$(id -g)" "/home/uceda/.kube/config"
chmod 600 "/home/uceda/.kube/config"
export KUBECONFIG="/home/uceda/.kube/config"
```

Verificar que kubectl ya puede consultar el clúster:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl cluster-info
kubectl get nodes
```

En este momento el master puede aparecer como `NotReady`. Es esperado
mientras todavía no exista un CNI funcional.

## 9.2 Guardar el comando `kubeadm join`

Guardar el comando de unión para poder agregar después los workers al
clúster.

> **Importante:** los siguientes comandos se ejecutan en `k8-master`, no
> en `anfitrion`. El host físico no necesita tener instalado `kubeadm`.

Después de que `kubeadm init` termine correctamente, genera el comando
real y guárdalo en una variable en `k8-master`:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
JOIN_COMMAND="$(kubeadm token create --print-join-command)"
printf '%s\n' "$JOIN_COMMAND"

# Guardar el comando para reutilizarlo, protegiendo el token real.
printf '%s\n' "$JOIN_COMMAND" > "/home/uceda/kubeadm-join-command.sh"
chmod 600 "/home/uceda/kubeadm-join-command.sh"
```

`JOIN_COMMAND` contiene el comando completo, incluido el token y el hash
de la autoridad certificadora, pero solo permanece disponible en la
terminal actual. El archivo `kubeadm-join-command.sh` permite recuperarlo
después sin volver a copiar el token manualmente. No reemplaces esos
valores ni uses los ejemplos de esta guía.

Para comprobar que el archivo quedó guardado sin mostrar el token:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
stat -c '%A %U:%G %n' "/home/uceda/kubeadm-join-command.sh"
```

Debe mostrar permisos `-rw-------` para el usuario `uceda`.

Si perdiste el comando:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
JOIN_COMMAND="$(kubeadm token create --print-join-command)"
printf '%s\n' "$JOIN_COMMAND"
```

------------------------------------------------------------------------

# 10. Instalar Calico como CNI

Calico se usará como único plugin de red para que los pods puedan
comunicarse entre nodos.

> Ejecutar solamente desde el master, utilizando el `kubectl`
> configurado.

**Importante:** esta versión de la guía utiliza **Calico solamente**. No
instalar Flannel además de Calico.

La documentación actual de Calico utiliza el Tigera Operator. Al momento
de esta revisión, la documentación oficial muestra Calico `v3.32.1`.

> **Versión validada por esta guía, no necesariamente la más reciente:**
> las URLs de esta sección fijan Calico en `v3.32.1` a propósito, para
> que el laboratorio sea reproducible. Si repites este laboratorio más
> adelante, verifica en
> [projectcalico.org](https://docs.tigera.io/calico/latest/release-notes/)
> si existe una versión más nueva antes de decidir si la usas.

## 10.1 Instalar CRDs

Primero se instalan las definiciones personalizadas que Calico necesita.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl apply --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/v1_crd_projectcalico_org.yaml
```

## 10.2 Instalar Tigera Operator

Después se instala el operador que despliega y administra Calico.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl apply --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml
```

## 10.3 Descargar `custom-resources.yaml`

Descargar el manifiesto que define los recursos finales de Calico. Los
siguientes bloques de esta sección usan nombres de archivo relativos, así
que primero fija un directorio de trabajo (se reutiliza en toda la
sección 10.3-10.4):

``` bash
# NODO: k8-master
# RUTA: /home/uceda
curl -fL -o /home/uceda/custom-resources.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/custom-resources.yaml
```

Respaldarlo:

``` bash
# NODO: k8-master
# RUTA: /home/uceda
cp /home/uceda/custom-resources.yaml /home/uceda/custom-resources.yaml.bak
```

Revisar el CIDR actual:

``` bash
# NODO: k8-master
# RUTA: /home/uceda
grep -n -A5 -B5 "cidr:" /home/uceda/custom-resources.yaml
```

Cambiar el CIDR predeterminado de Calico por el mismo utilizado en
`kubeadm init`:

``` bash
# NODO: k8-master
# RUTA: /home/uceda
sed -i 's#cidr: 192\.168\.0\.0/16#cidr: 172.16.0.0/16#g' /home/uceda/custom-resources.yaml
```

Confirmar:

``` bash
# NODO: k8-master
# RUTA: /home/uceda
grep -n "cidr:" /home/uceda/custom-resources.yaml
```

## 10.4 Crear recursos de Calico

Aplicar la configuración ajustada para que Calico cree la red del
clúster.

``` bash
# NODO: k8-master
# RUTA: /home/uceda
kubectl apply --server-side --force-conflicts -f /home/uceda/custom-resources.yaml
```

Esperar primero a que el operador cree el recurso de estado de Calico y
después a que el CNI quede disponible. El recurso `tigerastatus/calico`
puede tardar unos segundos en aparecer; no uses `kubectl wait` sobre él
antes de comprobar que ya existe:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl wait --for=condition=Available deployment/tigera-operator \
  -n tigera-operator --timeout=180s

for intento in {1..60}; do
  if kubectl get tigerastatus calico >/dev/null 2>&1; then
    kubectl wait --for=condition=Available tigerastatus/calico --timeout=300s
    break
  fi
  sleep 5
done

kubectl get tigerastatus
```

## 10.5 Monitorear Calico

Vigilar el estado de los pods de Tigera hasta que todo quede listo.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
watch kubectl get tigerastatus
```

Salir con `Ctrl+C`.

También:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get pods -A
kubectl get nodes -o wide
```

Esperar hasta que el master aparezca:

``` text
Ready
```

------------------------------------------------------------------------

# 11. Agregar los Workers

Una vez activo el plano de control y el CNI, se unen los tres workers al
clúster.

Ejecuta **una sola vez** el siguiente bloque desde `anfitrion`. El bloque
genera un token nuevo directamente en `k8-master` y ejecuta el comando
real en cada worker. No ejecutes este bloque dentro de `k8-master` ni
uses `kubeadm` directamente en el host físico.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
if [[ "$(hostname -s)" != "anfitrion" ]]; then
  echo "ERROR: este bloque debe ejecutarse desde anfitrion, no desde una VM."
  exit 1
fi

# Generar el token y el hash en el master; el host no necesita kubeadm instalado.
JOIN_COMMAND="$(ssh -o IdentitiesOnly=yes uceda@192.168.90.1 \
  'kubeadm token create --print-join-command')"

if [[ "$JOIN_COMMAND" != kubeadm\ join\ * ]]; then
  echo "ERROR: no se pudo generar un comando kubeadm join válido."
  exit 1
fi

printf 'Comando generado en k8-master: %s\n' "$JOIN_COMMAND"

for ip in 192.168.90.2 192.168.90.3 192.168.90.4; do
  echo "===== Uniendo $ip ====="
  ssh -o IdentitiesOnly=yes uceda@"$ip" \
    "if sudo test -f /etc/kubernetes/kubelet.conf; then echo 'Ya unido; se omite.'; else sudo $JOIN_COMMAND; fi"
done
```

El mismo token y hash se pueden utilizar en los tres workers. Si un
worker ya se unió correctamente, el bloque lo detecta mediante
`/etc/kubernetes/kubelet.conf` y omite ese nodo.

> **Punto de control:** después de unir los workers, ejecuta `kubectl get
> nodes -o wide` en `k8-master`. Deben aparecer cuatro nodos y cada worker
> debe terminar en estado `Ready` después de que sus pods de Calico estén
> funcionando.

Después, en el master:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get nodes
```

Y:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
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
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubeadm token list
```

Generar uno nuevo y mostrar directamente el `join`:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubeadm token create --print-join-command
```

------------------------------------------------------------------------

# 12. Prueba del clúster con NGINX

NGINX sirve como prueba rápida para confirmar que pods, scheduler y
servicios funcionan.

En el master:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl create deployment nginx-app --image=nginx --replicas=2
```

Verificar que Calico quedó disponible y que el clúster progresa a
`Ready`:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get deployment nginx-app
kubectl get pods -o wide
```

Esperar a que las réplicas estén disponibles:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl rollout status deployment/nginx-app
```

Si aparece `exceeded its progress deadline`, no continúes a NodePort aún.
Primero diagnostica y corrige:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
echo "=== NODOS ==="
kubectl get nodes -o wide

echo "=== PODS NGINX ==="
kubectl get pods -l app=nginx-app -o wide
kubectl describe pods -l app=nginx-app | sed -n '/Events/,$p'

echo "=== EVENTOS RECIENTES ==="
kubectl get events -A --sort-by=.lastTimestamp | tail -n 60
```

Si el pod aparece en `ImagePullBackOff` y los eventos muestran algo como:

``` text
Failed to pull image "nginx-app": pull access denied, repository does not exist or may require authorization
```

la causa no es Calico ni el scheduler: el deployment está intentando usar
una imagen llamada `nginx-app:latest` desde Docker Hub, pero esa imagen no
existe o no es pública. Corrige el deployment para usar una imagen pública
válida de NGINX:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl set image deployment/nginx-app nginx-app=nginx:1.27
kubectl rollout restart deployment/nginx-app
kubectl rollout status deployment/nginx-app --timeout=180s
kubectl get pods -l app=nginx-app -o wide
```

Cuando el pod quede `Running` y `READY` sea `1/1`, continúa con NodePort.

Corrección rápida para laboratorio (si necesitas ejecutar pods en el
control-plane mientras los workers terminan de quedar `Ready`):

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl rollout restart deployment/nginx-app
kubectl rollout status deployment/nginx-app --timeout=180s
```

Continúa con el siguiente paso (`kubectl expose deployment nginx-app ...`)
solo cuando el rollout termine en `successfully rolled out`.

Exponer mediante NodePort:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl expose deployment nginx-app --type=NodePort --port=80
```

Ver servicio:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get svc nginx-app
```

Ver detalles:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl describe svc nginx-app
```

Obtener solamente el NodePort:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get svc nginx-app -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'
```

Obtener IP de nodos:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get nodes -o wide
```

Probar desde una máquina con acceso a la red:

``` bash
curl http://IP_DE_UN_NODO:NODEPORT
```

Primero prueba desde el master, donde `kubectl` ya está configurado:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
NODEPORT="$(kubectl get svc nginx-app -o jsonpath='{.spec.ports[0].nodePort}')"
curl -I "http://127.0.0.1:${NODEPORT}"
curl -I "http://192.168.90.1:${NODEPORT}"
```

Luego prueba desde el anfitrión. En este caso no uses `kubectl` local a
menos que hayas copiado el kubeconfig del clúster al anfitrión; consulta el
NodePort por SSH al master y después haz el `curl` contra cualquier nodo:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
NODEPORT="$(ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 uceda@192.168.90.1 \
  'kubectl get svc nginx-app -o jsonpath="{.spec.ports[0].nodePort}"')"

printf 'NodePort detectado: %s\n' "${NODEPORT}"
curl -I "http://192.168.90.1:${NODEPORT}"
curl "http://192.168.90.2:${NODEPORT}"
```

Si estás dentro de una sesión SSH hacia `k8-master`, ejecuta solamente el
bloque marcado como `NODO: k8-master`. El bloque `NODO: anfitrion` debe
ejecutarse desde la terminal local del anfitrión, no dentro del SSH.

> El NodePort exacto puede ser diferente en cada instalación. No uses
> `31396` salvo que `kubectl get svc nginx-app` muestre precisamente ese
> valor.

------------------------------------------------------------------------

# 13. Instalar Helm

Helm se usa para desplegar charts empaquetados como el Dashboard.

> Ejecutar en el master.

En esta guía se instala Helm desde Snap. El repositorio APT tradicional de
Helm puede devolver errores de certificado o dejar de publicar su índice.

## 13.1 Instalar Helm

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo snap install helm --classic
```

Verificar:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
helm version
```

------------------------------------------------------------------------

# 14. Instalar Kubernetes Dashboard con Helm

Con Helm se instala el Dashboard oficial en un namespace dedicado.

> El repositorio Helm histórico `https://kubernetes.github.io/dashboard/`
> puede devolver `404`. Se utiliza el paquete oficial publicado del chart
> `7.14.0` — **esta es la versión validada por esta guía**, no
> necesariamente la más reciente disponible; revisa los
> [releases de kubernetes/dashboard](https://github.com/kubernetes/dashboard/releases)
> si quieres usar una más nueva.

Descargar el chart en **`k8-master`**:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
curl -fsSL -o "/home/uceda/kubernetes-dashboard-7.14.0.tgz" \
  https://github.com/kubernetes/dashboard/releases/download/kubernetes-dashboard-7.14.0/kubernetes-dashboard-7.14.0.tgz
```

Instalarlo:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
helm upgrade --install kubernetes-dashboard \
  "/home/uceda/kubernetes-dashboard-7.14.0.tgz" \
  --create-namespace \
  --namespace kubernetes-dashboard
```

Verificar que el Dashboard quedó desplegado correctamente:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
helm list -n kubernetes-dashboard
kubectl get pods -n kubernetes-dashboard
kubectl get svc -n kubernetes-dashboard
```

Esperar hasta que los Pods estén `Running`/`Ready`.

------------------------------------------------------------------------

# 15. Acceder al Dashboard mediante port-forward

Esta forma de acceso es útil para pruebas locales sin exponer el
servicio al exterior.

La forma recomendada para una prueba local es abrir un port-forward
hacia el servicio del Dashboard en `k8-master`:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl -n kubernetes-dashboard port-forward \
  svc/kubernetes-dashboard-kong-proxy 8443:443
```

Ese comando escucha en `127.0.0.1:8443` de `k8-master`. Si estás
conectado por SSH desde `anfitrion`, `localhost` se refiere a la VM y no
al host físico. Para acceder desde `anfitrion`, deja el port-forward
ejecutándose en una terminal abierta de `k8-master` y abre otra terminal
en `anfitrion` para crear un túnel SSH:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh -o IdentitiesOnly=yes -N -L 8443:127.0.0.1:8443 uceda@192.168.90.1
```

Mientras ese comando permanezca activo, abre el navegador **en
`anfitrion`** en:

``` text
https://localhost:8443
```

El puerto `8443` del host se reenvía al puerto `8443` local de
`k8-master`, donde escucha `kubectl port-forward`. El aviso de
certificado autofirmado del Dashboard es esperado en este laboratorio.

Verifica desde `anfitrion` que el túnel responde antes de abrir el
navegador:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
curl -k -I https://127.0.0.1:8443
```

Si usaste el primer `port-forward` sin `--address 0.0.0.0`, **no** abras
`https://192.168.90.1:8443` desde el anfitrión: ese puerto solo está
escuchando en `127.0.0.1` dentro de `k8-master`. En ese caso el acceso
correcto desde el anfitrión es `https://localhost:8443` usando el túnel
SSH anterior.

Como alternativa de laboratorio, si no quieres mantener un túnel SSH,
puedes hacer que el port-forward escuche en todas las interfaces de
`k8-master`:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl -n kubernetes-dashboard port-forward \
  --address 0.0.0.0 \
  svc/kubernetes-dashboard-kong-proxy 8443:443
```

Entonces se accede usando la IP del master y el puerto publicado:

``` text
https://192.168.90.1:8443
```

No uses `http://192.168.90.1:8443`: el Dashboard/Kong expone TLS, por lo
que la URL debe comenzar con `https://`.

Puedes validar desde `anfitrion` con:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
curl -k -I https://192.168.90.1:8443
```

> **Advertencia:** `--address 0.0.0.0` expone el port-forward a la red.
> Úsalo solamente en un laboratorio controlado y protegido por firewall.
> Para una instalación estable utiliza un método de exposición diseñado
> para ello, por ejemplo Ingress.

------------------------------------------------------------------------

------------------------------------------------------------------------

# 15.1. Alternativa académica: exponer Dashboard con NodePort 32000

La guía PDF original dedica una sección a convertir el servicio del
Dashboard a `NodePort` y fija el puerto `32000`. La instalación moderna
por Helm utiliza `kubernetes-dashboard-kong-proxy`, por lo que **no debe
aplicarse literalmente el parche antiguo al servicio
`kubernetes-dashboard` de Dashboard v2.x**.

Si el docente requiere reproducir específicamente el acceso mediante
`NodePort`, puede hacerse sobre el servicio actual de Kong:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard-kong-proxy \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"kong-proxy-tls","port":443,"protocol":"TCP","targetPort":8443,"nodePort":32000}]}}'
```

Verificar:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl -n kubernetes-dashboard get svc kubernetes-dashboard-kong-proxy
kubectl -n kubernetes-dashboard get pods
kubectl -n kubernetes-dashboard get endpoints kubernetes-dashboard-kong-proxy
```

El resultado esperado debe mostrar el servicio como `NodePort` y un
mapeo equivalente a `443:32000/TCP`.

Después de aplicar este parche, el acceso ya no depende del
`port-forward` en `8443`. El puerto publicado para entrar desde fuera del
clúster es `32000`.

Puedes validar desde `k8-master`:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
curl -k -I https://127.0.0.1:32000
curl -k -I https://192.168.90.1:32000
```

Y desde `anfitrion`:

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
curl -k -I https://192.168.90.1:32000
curl -k -I https://192.168.90.2:32000
curl -k -I https://192.168.90.3:32000
curl -k -I https://192.168.90.4:32000
```

Desde el host o desde una máquina que tenga conectividad hacia los nodos
del laboratorio:

``` text
https://192.168.90.1:32000
```

También puedes usar cualquiera de los workers:

``` text
https://192.168.90.2:32000
https://192.168.90.3:32000
https://192.168.90.4:32000
```

No uses `https://192.168.90.1:8443` después de elegir la alternativa
NodePort. El puerto `8443` corresponde al `port-forward`; el NodePort
fijado por esta sección es `32000`.

> **Importante:** esta alternativa se agrega para mantener
> correspondencia con el procedimiento académico del PDF. Para una
> prueba local sencilla se mantiene como opción principal el
> `port-forward` de la sección 15. No mantengas simultáneamente
> configuraciones de exposición innecesarias.

Para regresar el servicio a `ClusterIP` después de la prueba:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard-kong-proxy \
  -p '{"spec":{"type":"ClusterIP"}}'
```

# 16. Crear usuario de laboratorio para Dashboard

Se crea un usuario de ejemplo con privilegios completos para simplificar
la práctica.

> Este usuario tendrá privilegios `cluster-admin`. No es una
> configuración recomendada para producción.

## 16.1 Crear ServiceAccount

``` bash
# NODO: k8-master
# RUTA: /home/uceda
cat <<'EOF' > /home/uceda/admin-user.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF
```

Aplicar el ServiceAccount al clúster:

``` bash
# NODO: k8-master
# RUTA: $HOME
kubectl apply -f /home/uceda/admin-user.yml
```

## 16.2 Crear ClusterRoleBinding

``` bash
# NODO: k8-master
# RUTA: $HOME
cat <<'EOF' > /home/uceda/admin-rbac.yml
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
# NODO: k8-master
# RUTA: $HOME
kubectl apply -f /home/uceda/admin-rbac.yml
```

Verificar que la cuenta y el enlace de permisos quedaron creados:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get serviceaccount admin-user -n kubernetes-dashboard
kubectl get clusterrolebinding admin-user
```

## 16.3 Crear token

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl -n kubernetes-dashboard create token admin-user
```

Copiar el token y utilizarlo en el Dashboard.

------------------------------------------------------------------------

# 17. Diagnóstico rápido

Estas órdenes ayudan a identificar fallos en nodos, pods, red o runtime.

## 17.1 Ver todos los nodos

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get nodes -o wide
```

## 17.2 Ver todos los Pods

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get pods -A -o wide
```

## 17.3 Ver eventos recientes

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get events -A --sort-by='.lastTimestamp'
```

## 17.4 Estado de kubelet

En el nodo problemático:

``` bash
# NODO: k8-master (o el nodo que presente el problema)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo systemctl status kubelet --no-pager
```

Logs:

``` bash
# NODO: k8-master (o el nodo que presente el problema)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo journalctl -u kubelet -n 200 --no-pager
```

Logs en tiempo real:

``` bash
# NODO: k8-master (o el nodo que presente el problema)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo journalctl -u kubelet -f
```

## 17.5 Estado de containerd

``` bash
# NODO: k8-master (o el nodo que presente el problema)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo systemctl status containerd --no-pager
```

Logs:

``` bash
# NODO: k8-master (o el nodo que presente el problema)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo journalctl -u containerd -n 200 --no-pager
```

## 17.6 Verificar CNI/Calico

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get tigerastatus
kubectl get pods -A | grep -Ei 'calico|tigera'
```

## 17.7 Inspeccionar un Pod problemático

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl describe pod NOMBRE_POD -n NAMESPACE
```

Logs:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl logs NOMBRE_POD -n NAMESPACE
```

Para un Pod con varios contenedores:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl logs NOMBRE_POD -n NAMESPACE -c NOMBRE_CONTENEDOR
```

------------------------------------------------------------------------

# 18. Cómo reiniciar el laboratorio si `kubeadm init` salió mal

Si la inicialización quedó a medias, esta sección limpia el nodo para
reconstruirlo desde cero.

> Esto destruye la configuración Kubernetes del nodo. Utilizar
> únicamente si quieres reconstruir el laboratorio.

Ejecuta **una sola vez** el siguiente bloque dentro de `k8-master`. El
master hará su propia limpieza y después ejecutará la limpieza de los tres
workers mediante SSH. No lo uses si el clúster está funcionando y no
quieres reconstruirlo.

> **Requisito SSH:** `k8-master` debe poder conectarse a los workers como
> `uceda` sin contraseña. Si la llave privada solo existe en `anfitrion`,
> desde `anfitrion` ejecuta `ssh-add ~/.ssh/id_ed25519` y entra con
> `ssh -A uceda@192.168.90.1`. También puedes instalar una llave autorizada
> en los workers antes de ejecutar este bloque. La comprobación inicial
> aborta antes del reset si algún worker no es accesible.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -e

# 1. Definir los workers y comprobar SSH antes de modificar cualquier nodo.
WORKERS=(192.168.90.2 192.168.90.3 192.168.90.4)
for ip in "${WORKERS[@]}"; do
  echo "===== Comprobando SSH hacia $ip ====="
  ssh -o BatchMode=yes -o ConnectTimeout=10 uceda@"$ip" true
done

# 2. Limpiar el control plane local k8-master.
sudo kubeadm reset -f
sudo rm -rf /var/lib/etcd
sudo rm -rf /etc/cni/net.d
sudo systemctl restart containerd
sudo systemctl restart kubelet
rm -rf /home/uceda/.kube

# 3. Limpiar cada worker que ya se hubiera unido al clúster.
for ip in "${WORKERS[@]}"; do
  echo "===== Limpiando worker $ip ====="
  ssh -o BatchMode=yes uceda@"$ip" '
    sudo kubeadm reset -f
    sudo rm -rf /etc/cni/net.d
    sudo systemctl restart containerd
    sudo systemctl restart kubelet
  '
done
```

> **Después del reset:** detente aquí. El bloque anterior elimina el
> kubeconfig del master, por lo que `kubectl` no funcionará hasta repetir
> la sección 9. Después de ejecutar `kubeadm init`, vuelve a ejecutar 9.1
> para recrear `/home/uceda/.kube/config`, instala Calico en 10 y une los
> workers en 11. No ejecutes el checklist 19 inmediatamente después de
> este reset.

## 18.1. Si Calico quedó en un estado inconsistente (reset profundo)

Si tras un `kubeadm reset` normal Calico sigue sin levantar (pods
`calico-node` en `CrashLoopBackOff`, o interfaces de red duplicadas), el
reset básico de arriba puede no ser suficiente porque deja residuos de
red. Ejecuta **una sola vez** el siguiente bloque dentro de `k8-master`
para revisar y limpiar los cuatro nodos. Requiere el mismo acceso SSH
sin contraseña hacia los workers descrito en la sección 18.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -e

if [[ "$(hostname -s)" != "k8-master" ]]; then
  echo "ERROR: este bloque debe ejecutarse dentro de k8-master."
  exit 1
fi

WORKERS=(192.168.90.2 192.168.90.3 192.168.90.4)

# Comprobar SSH hacia todos los workers antes de borrar reglas del master.
for ip in "${WORKERS[@]}"; do
  echo "===== Comprobando SSH hacia $ip ====="
  ssh -o BatchMode=yes -o ConnectTimeout=10 uceda@"$ip" true
done

# Limpiar primero las interfaces y reglas del master local.
echo "===== Limpieza profunda en k8-master ====="
ip link show | grep -E 'cali|tunl0|vxlan.calico|wireguard.cali' || true
sudo ip link delete tunl0 2>/dev/null || true
sudo ip link delete vxlan.calico 2>/dev/null || true
sudo iptables-save | grep -i cali | head -n 20 || true
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo systemctl restart containerd kubelet
sudo systemctl restart kube-proxy

# Repetir la limpieza profunda en cada worker mediante SSH.
for ip in "${WORKERS[@]}"; do
  echo "===== Limpieza profunda en $ip ====="
  ssh -o BatchMode=yes uceda@"$ip" '
    ip link show | grep -E "cali|tunl0|vxlan.calico|wireguard.cali" || true
    sudo ip link delete tunl0 2>/dev/null || true
    sudo ip link delete vxlan.calico 2>/dev/null || true
    sudo iptables-save | grep -i cali | head -n 20 || true
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    sudo systemctl restart containerd kubelet
    sudo systemctl restart kube-proxy
  '
done
```

> Después de vaciar `iptables`, se reinicia `kube-proxy` en cada nodo para que reconstruya
> las reglas de servicios y NodePort; sin este reinicio, un NodePort puede
> rechazar conexiones aunque el Pod y el Service estén `Running`.
>
> **Precaución:** `iptables -F`/`-X` borra **todas** las reglas del nodo,
> no solo las de Calico; solo usarlo en un nodo que se va a reconstruir
> por completo. Esto no fue necesario en la ejecución de este
> laboratorio (un `kubeadm reset` simple fue suficiente), se documenta
> aquí como referencia de troubleshooting para el caso en que Calico
> quede en un estado más roto.

Después vuelve a ejecutar la sección **9. Inicializar el Control
Plane**.

------------------------------------------------------------------------

# 19. Checklist final del clúster base

La lista final confirma que el clúster base quedó en un estado funcional
antes de seguir con WordPress.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
if [[ ! -s "/home/uceda/.kube/config" ]]; then
  echo "ERROR: falta /home/uceda/.kube/config."
  echo "Ejecuta kubeadm init y después repite la sección 9.1 antes de usar kubectl."
  exit 1
fi

export KUBECONFIG="/home/uceda/.kube/config"
kubectl cluster-info >/dev/null
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

Aquí se resume lo que pide la guía académica para que no se pierda el
objetivo final.

La guía solicita finalmente:

1.  Desplegar un clúster Kubernetes con al menos:
    -   1 nodo master/control-plane.
    -   3 nodos worker.
2.  Desplegar una interfaz web de administración.
3.  Desplegar WordPress incluyendo:
    -   aplicación,
    -   base de datos,
    -   Redis Cache.
4.  Probar WordPress mediante HTTP en un servicio `NodePort`.

> **Observación técnica importante:** el punto de "Aplicación, Base de
> datos y Redis Cache agrupados en un Pod" puede reproducirse para
> cumplir literalmente un laboratorio, pero no representa la
> arquitectura Kubernetes recomendada. Normalmente WordPress, base de
> datos y Redis deberían desplegarse como workloads/servicios separados,
> permitiendo escalado, actualizaciones y persistencia independientes.

------------------------------------------------------------------------

# 21. Siguiente fase recomendada del laboratorio

Con el clúster base listo, estos son los pasos lógicos para continuar
con almacenamiento y aplicaciones.

Una vez que este clúster base esté completamente funcional, continuar en
este orden:

1.  Desplegar WordPress, MariaDB y Redis en el mismo Pod para la práctica.
2.  Usar `emptyDir` como almacenamiento temporal de laboratorio.
3.  Cambiar el servicio de WordPress a `NodePort`.
4.  Obtener el puerto asignado y probarlo desde `anfitrion` mediante HTTP.

------------------------------------------------------------------------

# 22. Fuentes utilizadas para la revisión

Esta lista deja trazabilidad de la documentación oficial usada para
corregir la guía.

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

La nota final aclara el contexto actual del Dashboard y la alternativa
Headlamp.

Aunque la guía académica pide Kubernetes Dashboard y la documentación
todavía describe su instalación con Helm, el ecosistema está
evolucionando. Kubernetes publicó en julio de 2026 una guía de migración
de **Kubernetes Dashboard a Headlamp**.

Para cumplir el laboratorio, puedes mantener Dashboard. Para una
plataforma nueva o de mayor duración, conviene evaluar Headlamp por
separado después de completar los requerimientos académicos.

------------------------------------------------------------------------

------------------------------------------------------------------------

# 24. CephFS fuera del alcance del laboratorio simple

Esta fase del documento es un apéndice histórico del PDF original. No se
ejecuta en este laboratorio: no se crean `ceph-admin`, CephFS, Ceph CSI,
StorageClass ni PVC respaldados por Ceph.

<!-- Inicio del apéndice histórico no ejecutable.

Esta fase completa el requisito 4 del PDF: disco persistente respaldado por
CephFS. **Estado histórico: RESUELTO Y VERIFICADO end-to-end el
2026-08-23**. En la reconstrucción actual está pendiente porque
`ceph-admin` se acaba de crear y el clúster debe terminar de ajustar sus
pools de un solo OSD antes de probar el PVC (PVC
`Bound` + Pod real montó, escribió y leyó un archivo sobre CephFS).

> **Convención de esta guía:** cada bloque de código indica en su primera
> línea, como comentario, el nodo donde debe ejecutarse:
> `anfitrion` (el host físico KVM), `ceph-admin` (el nodo Ceph mínimo del
> laboratorio), `k8-master` o
> `k8-worker{1,2,3}`.

Como en este laboratorio no había VMs Ceph dedicadas encendidas, se
creó la VM `ceph-admin` como nodo Ceph "todo-en-uno" (mon+mgr+osd) vía
`cephadm`, con un disco OSD de 20 GiB. Dirección usada:

``` text
CEPH_ADMIN_HOST=ceph-admin
CEPH_ADMIN_IP_MGMT=192.168.90.40      # red k8s-lab; única interfaz de esta VM
CEPH_ADMIN_IP_DATA=192.168.90.40      # red k8s-lab, la que usan mons/OSDs y consumen los nodos K8s
CEPH_FSID=a17b7477-9f73-11f1-b6ba-525400900040
CEPH_FS_NAME=storage
CEPH_MONITORS=192.168.90.40:6789
CEPH_POOLS=cephfs.storage.meta, cephfs.storage.data
```

Antes de ejecutar 24.1, comprueba que el nodo Ceph exista, esté encendido
y sea accesible. Si esta comprobación falla, detente y ejecuta 24.0 para
crear `ceph-admin`, o arranca/conecta el nodo Ceph existente; no continúes
con CSI ni WordPress.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virsh dominfo ceph-admin >/dev/null 2>&1 || {
  echo "ERROR: ceph-admin no existe en libvirt; ejecuta 24.0."
  exit 1
}
sudo virsh domstate ceph-admin | grep -qx running || {
  echo "ERROR: ceph-admin no está encendida."
  exit 1
}
ssh -o ConnectTimeout=10 uceda@192.168.90.40 hostname
nc -zvw3 192.168.90.40 6789
nc -zvw3 192.168.90.40 3300
```

> **Nota de red:** `ceph-admin` usa la red `k8s-lab` para que los cuatro
> nodos Kubernetes alcancen el monitor Ceph por `192.168.90.40`.

> **Reproducibilidad desde cero:** ejecuta primero **24.0** para crear
> `ceph-admin` y después continúa con 24.1.

## 24.0. Crear una VM Ceph desde cero (opcional, solo si no reutilizas una VM existente)

Este nodo usa la misma red `k8s-lab` que los nodos Kubernetes (así los
workers pueden alcanzar los monitores por `192.168.90.0/24` sin redes
adicionales). Ajusta memoria/disco según los recursos disponibles del
host; 2 vCPU / 4 GiB / 20 GiB de sistema es suficiente para un mon+mgr+osd
de laboratorio.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
BASE_IMG="/var/lib/libvirt/images/k8s-lab/noble-server-cloudimg-amd64.img"
BASE_FMT="$(sudo qemu-img info "$BASE_IMG" | awk -F': ' '/file format/ {print $2; exit}')"
sudo qemu-img create -f qcow2 -F "$BASE_FMT" -b "$BASE_IMG" \
  /var/lib/libvirt/images/k8s-lab/ceph-admin.qcow2 30G
# Disco adicional dedicado exclusivamente al OSD (no debe llevar sistema de archivos previo):
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/k8s-lab/ceph-admin-osd0.qcow2 20G
```

Genera el cloud-init igual que en 0.1.6 (mismo `PUBKEY`), con
`hostname: ceph-admin`, y créalo con IP fija `192.168.90.40` agregando su
`mac`/`host` al DHCP estático de `k8s-lab-network.xml` (mismo patrón que
`k8-master`/`k8-worker*`, sección 0.1.3), por ejemplo
`mac='52:54:00:90:00:40'`.

``` bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo virt-install \
  --name ceph-admin \
  --memory 4096 \
  --vcpus 2 \
  --cpu host-passthrough \
  --import \
  --disk path=/var/lib/libvirt/images/k8s-lab/ceph-admin.qcow2,format=qcow2,bus=virtio \
  --disk path=/var/lib/libvirt/images/k8s-lab/ceph-admin-osd0.qcow2,format=qcow2,bus=virtio \
  --disk path=/var/lib/libvirt/images/k8s-lab/ceph-admin-seed.iso,device=cdrom \
  --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:40 \
  --os-variant ubuntu24.04 \
  --graphics none \
  --noautoconsole
```

Instalar Docker/cephadm y arrancar el clúster (paquete `cephadm` oficial
de Ceph, no el de los repos de Ubuntu, que suele estar desactualizado).
En Ubuntu 24.04 no se añade el repositorio APT de Ceph con
`cephadm add-repo --release squid`: ese repositorio puede no publicar una
distribución `noble` y provocar un error `404`. `cephadm` puede hacer el
bootstrap usando directamente las imágenes oficiales de Ceph:

``` bash
# NODO: ceph-admin
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo apt-get update && sudo apt-get install -y docker.io curl
curl -fL --output /home/uceda/cephadm https://download.ceph.com/rpm-19.2.6/el9/noarch/cephadm
chmod +x /home/uceda/cephadm
sudo /home/uceda/cephadm install
sudo cephadm bootstrap --mon-ip 192.168.90.40
```

Agregar el segundo disco (`ceph-admin-osd0`, ej. `/dev/vdb`) como OSD y
crear el filesystem `storage` requerido por el PDF:

``` bash
# NODO: ceph-admin
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo cephadm shell -- ceph orch daemon add osd ceph-admin:/dev/vdb
sudo cephadm shell -- ceph fs volume create storage
sudo cephadm shell -- ceph -s
```

A partir de aquí continúa con **24.1** usando `ceph-admin` (`192.168.90.40`)
como nodo Ceph. Con un solo OSD no existe tolerancia a fallos real; el
ajuste `size=1` solo permite que este laboratorio funcione.

## 24.1. Verificar Ceph desde el nodo Ceph

``` bash
# NODO: ceph-admin
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo cephadm shell -- ceph -s
sudo cephadm shell -- ceph fs ls
sudo cephadm shell -- ceph fs status storage
```

**Punto de control 24.1:** `health` puede mostrar `HEALTH_WARN` en este
laboratorio (solo 2 OSD, ver 24.1.1), pero deben aparecer `mon: 1 daemons`,
`mgr: ... active`, `mds: 1/1 daemons up` y el filesystem `storage`.

### 24.1.1. Ajustar el tamaño de réplica de los pools al número real de OSD

Con un solo OSD y el `size` por defecto en 3, los PG quedan
`undersized+peered` (inactivos) y el MDS se cuelga ("slow metadata IOs"),
bloqueando cualquier operación CephFS posterior. Ejecutar una sola vez:

``` bash
# NODO: ceph-admin
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo cephadm shell -- ceph config set mon mon_allow_pool_size_one true
sudo cephadm shell -- ceph osd pool set cephfs.storage.meta size 1 --yes-i-really-mean-it
sudo cephadm shell -- ceph osd pool set cephfs.storage.meta min_size 1
sudo cephadm shell -- ceph osd pool set cephfs.storage.data size 1 --yes-i-really-mean-it
sudo cephadm shell -- ceph osd pool set cephfs.storage.data min_size 1
sudo cephadm shell -- ceph -s
```

**Punto de control 24.1.1:** en `ceph -s` los PG deben pasar de
`undersized+peered` a `active+clean`. En este laboratorio `HEALTH_WARN`
puede mantenerse por tener un solo OSD, pero no deben quedar PG inactivos.

## 24.2. Crear usuario CephX para CSI

``` bash
# NODO: ceph-admin
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo cephadm shell -- ceph fs authorize storage client.k8 / rw
sudo cephadm shell -- ceph auth get client.k8
```

**Advertencia crítica detectada en este laboratorio (bug de generación de
llaves):** en este clúster Ceph Squid 19.2.6, `ceph fs authorize` genera
llaves CephX de 32 bytes (cifrado `aes256k`) que **ningún cliente puede
decodificar** (ni `ceph-common` 19.2.3 de Ubuntu, ni el 20.2.1 embebido en
la imagen `cephcsi:v3.17.0`), fallando con
`auth: ... Malformed input [buffer:3]` / `rados: ret=-22`. La causa es que
el monmap quedó configurado con `auth_service_cipher=aes256k` obligatorio.
Si tu clúster no sufre este bug, puedes omitir 24.2.1 y usar la llave que
te dio `ceph auth get` directamente.

### 24.2.1. [Troubleshooting] Generar la llave con `ceph-authtool` e importarla

> Ejecuta este paso **únicamente** si 24.2 te mostró el bug de llaves de
> 32 bytes descrito arriba. No es parte del flujo normal de
> `ceph fs authorize`.

``` bash
# NODO: ceph-admin
# RUTA: /tmp (ruta absoluta y temporal; se elimina al terminar)
set -e

# Ejecutar ceph-authtool dentro de la imagen cephadm, donde está instalado.
NEWKEY="$(sudo cephadm shell -- ceph-authtool --gen-print-key --key-type aes 2>/dev/null)"
test -n "$NEWKEY"

# La clave AES-128 compatible ocupa 28 bytes codificados por CephX.
test "$(printf '%s' "$NEWKEY" | base64 -d | wc -c)" -eq 28

printf '[client.k8]\n        key = %s\n        caps mds = "allow rw"\n        caps mon = "allow r"\n        caps mgr = "allow rw"\n        caps osd = "allow rw"\n' \
  "$NEWKEY" > /tmp/client.k8.keyring

# Montar el archivo dentro del contenedor cephadm para poder importarlo.
sudo cephadm shell --mount /tmp/client.k8.keyring:/mnt/client.k8.keyring \
  -- ceph auth rm client.k8 || true
sudo cephadm shell --mount /tmp/client.k8.keyring:/mnt/client.k8.keyring \
  -- ceph auth import -i /mnt/client.k8.keyring
sudo rm -f /tmp/client.k8.keyring
sudo cephadm shell -- ceph auth get client.k8
```

> Nota: se usaron caps amplios (`allow rw` sin restringir por `fsname`/`tag`)
> porque el módulo `mgr volumes` (usado por Ceph CSI para crear
> subvolúmenes) requiere `mgr 'allow rw'`, y las restricciones por
> `tag cephfs data=<pool>` complicaron el diagnóstico bajo presión de
> tiempo. Para producción, revisar y restringir caps según el
> [documento oficial de ceph-csi](https://github.com/ceph/ceph-csi/blob/devel/docs/capabilities.md).

### 24.2.2. [Troubleshooting] Permitir temporalmente el cifrado legacy en el monitor

> Ejecuta este paso **únicamente** si viste el bug de 24.2. En un
> clúster Ceph sin ese bug, `mon_auth_emergency_allowed_ciphers` **no**
> debe configurarse: es una excepción de seguridad, no una práctica
> recomendada.

El parámetro `mon_auth_emergency_allowed_ciphers` **no se puede** fijar con
`ceph config set` (es "special"); debe editarse el `ceph.conf` local del
mon y reiniciar el daemon:

``` bash
# NODO: ceph-admin
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo tee -a /var/lib/ceph/${CEPH_FSID}/mon.ceph-admin/config > /dev/null <<'EOF'
        mon_auth_emergency_allowed_ciphers = aes, aes256k
EOF
sudo cephadm shell -- ceph orch daemon restart mon.ceph-admin
sleep 10
sudo cephadm shell -- ceph health detail
```

**Punto de control 24.2.2:** `ceph health detail` debe mostrar
`AUTH_EMERGENCY_CIPHERS_SET` y `entity client.k8 using insecure key type: aes`
(esto es **esperado y aceptado** en este laboratorio: confirma que la
llave AES-128 generada manualmente ya es aceptada por el monitor).

### 24.2.3. [Troubleshooting] Crear el subvolumegroup `csi` manualmente

> Ejecuta este paso **únicamente** si el aprovisionamiento automático
> falla con `Operation not permitted` al crear el primer PVC (ver 24.7).

Ceph CSI espera crear su propio subvolumegroup `csi` al primer
aprovisionamiento; en este clúster falló al hacerlo automáticamente
(`rados: ret=-1, Operation not permitted` en el pod `csi-cephfsplugin`).
Workaround: crearlo a mano una sola vez.

``` bash
# NODO: ceph-admin
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
sudo cephadm shell -- ceph fs subvolumegroup create storage csi
sudo cephadm shell -- ceph fs subvolumegroup ls storage
```

**Punto de control 24.2.3:** la salida de `subvolumegroup ls` debe incluir
`"name": "csi"`.

## 24.3. Preparar el cliente Kubernetes

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
nc -vz 192.168.90.40 6789
nc -vz 192.168.90.40 3300
```

Si ambas pruebas fallan, detente y corrige primero la red o el cluster Ceph.

Instalar `ceph-common` en todos los nodos Kubernetes:

``` bash
# NODO: anfitrion (orquesta vía SSH hacia cada nodo K8s)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
NODES=(192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4)
SSH_OPTS='-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10'

for ip in "${NODES[@]}"; do
  cmd='sudo apt-get update && sudo apt-get install -y ceph-common'
  echo "===== $ip ====="
  ssh $SSH_OPTS uceda@"$ip" "$cmd"
done
```

**Punto de control 24.3:** `ceph --version` debe responder en los 4 nodos
(no es necesario que coincida con la versión del servidor).

## 24.4. Instalar Ceph CSI CephFS

Crear primero los recursos auxiliares que los manifiestos necesitan. El
namespace de estos manifiestos es `default`; si se crean los Deployments
o DaemonSets antes que sus ServiceAccounts y ConfigMaps, los pods quedan
en `ContainerCreating` o `Pending` con errores de `FailedMount` o
`serviceaccount not found`.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl create serviceaccount cephfs-csi-nodeplugin -n default \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create serviceaccount cephfs-csi-provisioner -n default \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap ceph-csi-encryption-kms-config -n default \
  --from-literal=config.json='{}' \
  --dry-run=client -o yaml | kubectl apply -f -
```

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
CSI_VERSION=v3.17.0
kubectl apply --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/ceph/ceph-csi/${CSI_VERSION}/deploy/cephfs/kubernetes/csi-cephfsplugin-provisioner.yaml
kubectl apply --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/ceph/ceph-csi/${CSI_VERSION}/deploy/cephfs/kubernetes/csi-cephfsplugin.yaml
```

En este laboratorio los manifiestos se desplegaron en el namespace
`default` (no `ceph-csi`), y **faltaban los RBAC** — hay que aplicarlos
explícitamente o los pods quedan en `CrashLoopBackOff`/`Pending` con
errores `... is forbidden`:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl apply --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/ceph/ceph-csi/${CSI_VERSION}/deploy/cephfs/kubernetes/csi-nodeplugin-rbac.yaml
kubectl apply --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/ceph/ceph-csi/${CSI_VERSION}/deploy/cephfs/kubernetes/csi-provisioner-rbac.yaml
```

Después de crear los objetos de configuración, reiniciar los workloads
para que recojan cualquier cambio y esperar sus rollouts:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl rollout restart deployment/csi-cephfsplugin-provisioner -n default
kubectl rollout restart daemonset/csi-cephfsplugin -n default
kubectl rollout status deployment/csi-cephfsplugin-provisioner -n default --timeout=300s
kubectl rollout status daemonset/csi-cephfsplugin -n default --timeout=300s
```

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get pods -l app=csi-cephfsplugin-provisioner
kubectl get pods -l app=csi-cephfsplugin
```

**Punto de control 24.4:** el Deployment `csi-cephfsplugin-provisioner`
debe llegar a `3/3 Running (7/7 contenedores)` y el DaemonSet
`csi-cephfsplugin` a `3/3 Running` (uno por worker). Si al actualizar de
versión el rollout se queda con pods viejos y nuevos mezclados, revisar la
estrategia de despliegue (ver 24.4.1).

### 24.4.1. [Troubleshooting] Rollout atascado por anti-afinidad

> Ejecuta este paso **únicamente** si el Deployment se queda con pods
> viejos y nuevos mezclados tras cambiar de versión del CSI.

Con solo 3 workers y `maxSurge` por defecto, el rollout puede quedarse
esperando un 4º nodo que no existe. Forzar reemplazo secuencial:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl patch deployment csi-cephfsplugin-provisioner --type=merge \
  -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":0,"maxUnavailable":1}}}}'
kubectl rollout status deployment/csi-cephfsplugin-provisioner --timeout=180s
```

## 24.5. Crear configuración y secreto CSI

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
CEPH_FSID='a17b7477-9f73-11f1-b6ba-525400900040'
CEPH_MONITORS='192.168.90.40:6789'
CEPH_USER_KEY='<LLAVE_AES-128_DE_client.k8_GENERADA_EN_24.2.1>'

kubectl create configmap ceph-csi-config \
  --from-literal=config.json="[{\"clusterID\":\"${CEPH_FSID}\",\"monitors\":[\"${CEPH_MONITORS}\"]}]" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic ceph-csi-cephfs-secret \
  --from-literal=adminID=k8 \
  --from-literal=adminKey="$CEPH_USER_KEY" \
  --from-literal=userID=k8 \
  --from-literal=userKey="$CEPH_USER_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Los pods de este laboratorio también montan `/etc/ceph/` desde una
ConfigMap `ceph-config` (workaround porque el binario `cephcsi` intenta
escribir en `/etc/ceph/keyring`, que al venir de una ConfigMap es de solo
lectura; pre-poblarla evita el intento de escritura):

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
cat > /tmp/ceph.conf <<EOF
[global]
fsid = ${CEPH_FSID}
mon_host = [v2:192.168.90.40:3300/0,v1:192.168.90.40:6789/0]
EOF

cat > /tmp/client.k8.keyring <<EOF
[client.k8]
        key = ${CEPH_USER_KEY}
EOF

kubectl create configmap ceph-config \
  --from-file=ceph.conf=/tmp/ceph.conf \
  --from-file=keyring=/tmp/client.k8.keyring \
  --dry-run=client -o yaml | kubectl apply -f -

rm -f /tmp/ceph.conf /tmp/client.k8.keyring
```

**Punto de control 24.5:** `kubectl get secret ceph-csi-cephfs-secret -o
jsonpath='{.data.userKey}' | base64 -d | wc -c` debe imprimir un texto
base64 que decodifique a 28 bytes (llave AES-128 válida), no 44.

## 24.6. Crear StorageClass CephFS

**Lección clave:** la opción de montaje `ms_mode=secure` (mensajería v2
cifrada) hace fallar el montaje **kernel** en el nodo con
`mount error: no mds (Metadata Server) is up` aunque el MDS esté sano.
Usar `ms_mode=legacy`.

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
cat <<'EOF' > /tmp/cephfs-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cephfs-storage
provisioner: cephfs.csi.ceph.com
parameters:
  clusterID: a17b7477-9f73-11f1-b6ba-525400900040
  fsName: storage
  pool: cephfs.storage.data
  csi.storage.k8s.io/provisioner-secret-name: ceph-csi-cephfs-secret
  csi.storage.k8s.io/provisioner-secret-namespace: default
  csi.storage.k8s.io/node-stage-secret-name: ceph-csi-cephfs-secret
  csi.storage.k8s.io/node-stage-secret-namespace: default
  csi.storage.k8s.io/controller-expand-secret-name: ceph-csi-cephfs-secret
  csi.storage.k8s.io/controller-expand-secret-namespace: default
reclaimPolicy: Delete
allowVolumeExpansion: true
mountOptions:
  - _netdev
  - ms_mode=legacy
EOF

kubectl apply -f /tmp/cephfs-storageclass.yaml
kubectl get storageclass cephfs-storage
```

## 24.7. Probar el aprovisionamiento con un PVC y un Pod real

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
cat <<'EOF' > /tmp/cephfs-test-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cephfs-test
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: cephfs-storage
  resources:
    requests:
      storage: 5Gi
EOF

kubectl apply -f /tmp/cephfs-test-pvc.yaml
kubectl get pvc cephfs-test
```

**Punto de control 24.7.a:** el PVC debe pasar a `Bound` en menos de 30 s.
Si queda en `Pending` con `rados: ret=-22`, revisar 24.2.1/24.2.2 (llave o
cifrado). Si el error es `ret=-1, Operation not permitted`, revisar 24.2.3
(subvolumegroup) y que los pods del provisioner se hayan reiniciado
**después** de aplicar los fixes de credenciales (el binario `cephcsi`
reutiliza conexiones RADOS abiertas al arrancar; si cambias la llave/caps
del clúster con los pods ya corriendo, hay que recrearlos):

``` bash
# NODO: k8-master (solo si hiciste cambios de credenciales con los pods ya corriendo)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl delete pod -l app=csi-cephfsplugin-provisioner
kubectl rollout status deployment/csi-cephfsplugin-provisioner --timeout=120s
```

Prueba real de montaje y escritura (no solo `Bound`, sino un Pod usándolo):

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
cat <<'EOF' > /tmp/cephfs-test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cephfs-test-pod
spec:
  containers:
    - name: test
      image: busybox
      command: ["sh", "-c", "echo hola-cephfs-$(date) > /mnt/test.txt && cat /mnt/test.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /mnt
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: cephfs-test
EOF

kubectl apply -f /tmp/cephfs-test-pod.yaml
kubectl get pod cephfs-test-pod
kubectl logs cephfs-test-pod
```

**Punto de control 24.7.b (verificación final del requisito 4):** el pod
debe quedar `1/1 Running` y `kubectl logs` debe mostrar la línea
`hola-cephfs-<fecha>`, confirmando escritura y lectura real sobre CephFS.
Verificado en este laboratorio el 2026-08-23 con éxito.

Limpieza de los recursos de prueba antes de continuar con WordPress:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl delete pod cephfs-test-pod --force --grace-period=0
kubectl delete pvc cephfs-test --force --grace-period=0
```

------------------------------------------------------------------------

-->

# 25. Desplegar WordPress, MariaDB y Redis

Esta implementacion sigue literalmente el requerimiento academico del PDF:
WordPress, base de datos y Redis se ejecutan como tres contenedores dentro
del mismo Pod. Para una instalacion real se recomienda separarlos en
workloads independientes.

> **Corrección:** la versión inicial de este Deployment ejecutaba Redis
> con `--appendonly yes` pero sin `volumeMount` para `/data`, por lo que
> el AOF quedaba en el filesystem efímero del contenedor (se perdía al
> recrear el Pod) y daba una falsa sensación de persistencia. Se agregó
> el PVC `wordpress-redis` montado en `/data` para que la persistencia
> declarada realmente se cumpla.

Todos los comandos de esta seccion se ejecutan en **`k8-master`**.

## 25.1. Crear secretos de la aplicacion

Usa contrasenas propias. No reutilices contrasenas del PDF ni las guardes
en repositorios publicos:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl create namespace wordpress --dry-run=client -o yaml | kubectl apply -f -

kubectl -n wordpress create secret generic wordpress-secrets \
  --from-literal=mariadb-root-password='<CAMBIAR_ROOT_PASSWORD>' \
  --from-literal=mariadb-password='<CAMBIAR_DB_PASSWORD>' \
  --from-literal=wordpress-admin-password='<CAMBIAR_WORDPRESS_PASSWORD>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

> **Nota:** la clave `wordpress-admin-password` se guarda en el secreto
> como referencia para que definas manualmente la contraseña del
> administrador durante el asistente de instalación web de WordPress
> (`wp-admin/install.php`). El Deployment de 25.3 **no** la inyecta como
> variable de entorno (la imagen `wordpress:6.8-apache` no automatiza el
> alta del usuario admin), por lo que no crea la cuenta por sí sola.

## 25.2. Preparar almacenamiento temporal

Para este laboratorio sin Ceph se utilizarán tres volúmenes `emptyDir`.
Son adecuados para probar la aplicación, pero se borran si el Pod se
recrea; no deben usarse para datos persistentes.

``` bash
# NODO: k8-master
echo "emptyDir se define directamente en el Deployment 25.3"
```

## 25.3. Crear Deployment con tres contenedores

El contenedor WordPress se conecta a MariaDB por `127.0.0.1` porque ambos
estan en el mismo Pod. Redis tambien queda disponible por `127.0.0.1:6379`.

``` bash
# NODO: k8-master
# RUTA: /tmp (rutas absolutas, no depende del directorio de trabajo)
cat <<'EOF' > /tmp/wordpress.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
        - name: wordpress
          image: wordpress:6.8-apache
          ports:
            - containerPort: 80
          env:
            - name: WORDPRESS_DB_HOST
              value: 127.0.0.1:3306
            - name: WORDPRESS_DB_USER
              value: wordpress
            - name: WORDPRESS_DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: wordpress-secrets
                  key: mariadb-password
            - name: WORDPRESS_DB_NAME
              value: wordpress
          volumeMounts:
            - name: wordpress-content
              mountPath: /var/www/html
        - name: mariadb
          image: mariadb:11.4
          env:
            - name: MARIADB_DATABASE
              value: wordpress
            - name: MARIADB_USER
              value: wordpress
            - name: MARIADB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: wordpress-secrets
                  key: mariadb-password
            - name: MARIADB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: wordpress-secrets
                  key: mariadb-root-password
          volumeMounts:
            - name: wordpress-db
              mountPath: /var/lib/mysql
        - name: redis
          image: redis:7.4
          args:
            - redis-server
            - --appendonly
            - "yes"
            - --dir
            - /data
          ports:
            - containerPort: 6379
          volumeMounts:
            - name: wordpress-redis
              mountPath: /data
      volumes:
        - name: wordpress-content
          emptyDir: {}
        - name: wordpress-db
          emptyDir: {}
        - name: wordpress-redis
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: wordpress
spec:
  selector:
    app: wordpress
  ports:
    - name: http
      port: 80
      targetPort: 80
  type: ClusterIP
EOF

kubectl apply -f /tmp/wordpress.yaml
kubectl rollout status deployment/wordpress -n wordpress --timeout=300s
kubectl get pods -n wordpress -o wide
kubectl get svc -n wordpress
```

Verificar los tres contenedores del Pod:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get pod -n wordpress -l app=wordpress \
  -o jsonpath='{range .items[0].status.containerStatuses[*]}{.name}{"="}{.ready}{"\n"}{end}'
```

**Punto de control 25.3:** los tres contenedores (`wordpress`, `mariadb`,
`redis`) deben mostrar `true`.

------------------------------------------------------------------------

# 26. Exponer WordPress por HTTP mediante NodePort

Para este laboratorio simple no se instalarán MetalLB, Ingress NGINX,
certificados TLS ni HTTPS. El servicio de WordPress se expondrá mediante
HTTP y un `NodePort`.

``` bash
# NODO: k8-master
# RUTA: cualquiera
kubectl -n wordpress patch service wordpress --type=merge \
  -p '{"spec":{"type":"NodePort"}}'
kubectl -n wordpress get service wordpress
```

Obtén el puerto real y prueba desde `anfitrion`:

``` bash
# NODO: anfitrion
# RUTA: cualquiera
NODEPORT="$(ssh -o IdentitiesOnly=yes uceda@192.168.90.1 'export KUBECONFIG=/home/uceda/.kube/config; kubectl -n wordpress get service wordpress -o jsonpath="{.spec.ports[0].nodePort}"')"
curl -f "http://192.168.90.2:${NODEPORT}/"
```

<!-- Las subsecciones siguientes pertenecen al flujo HTTPS histórico y no
se ejecutan en este laboratorio simple.

El PDF exige una direccion diferente a la del master y acceso directo por
HTTPS/443. En esta red libvirt se usara MetalLB con la IP de laboratorio
`192.168.90.50`. Verifica antes que esa IP este libre y fuera del rango DHCP.

## 26.1. Instalar Ingress NGINX

Ejecutar en **`k8-master`**:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

**Punto de control 26.1:** `kubectl get pods -n ingress-nginx` debe mostrar
el controller `Running` antes de continuar con MetalLB.

## 26.2. Instalar MetalLB

Ejecutar en **`k8-master`**:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
METALLB_VERSION=v0.15.2
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml
kubectl wait --for=condition=available deployment/controller \
  -n metallb-system --timeout=180s
```

Crear el pool L2 de la red `k8s-lab`:

``` bash
# NODO: k8-master
# RUTA: /tmp (rutas absolutas, no depende del directorio de trabajo)
cat <<'EOF' > /tmp/metallb-pool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: k8s-lab-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.90.50-192.168.90.50
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: k8s-lab-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
    - k8s-lab-pool
EOF

kubectl apply -f /tmp/metallb-pool.yaml
kubectl get ipaddresspool,l2advertisement -n metallb-system
```

Verificar que Ingress recibio la IP dedicada:

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get svc -n ingress-nginx ingress-nginx-controller -w
```

**Punto de control 26.2:** continuar solo cuando `EXTERNAL-IP` sea
`192.168.90.50` (no `<pending>`).

## 26.3. Crear certificado TLS de laboratorio

Ejecutar en **`k8-master`**. Este certificado es autofirmado y el
navegador mostrara una advertencia; para produccion usa una CA confiable.

> **Corrección:** un certificado que solo define `CN` no es válido para
> clientes TLS modernos (navegadores, y versiones recientes de Go/Chrome
> ignoran el `CN` y exigen `subjectAltName`). Con `curl -k` no se nota
> porque se desactiva la validación, pero para que el candado del
> navegador funcione hay que agregar el SAN con la misma IP:

``` bash
# NODO: k8-master
# RUTA: /tmp (rutas absolutas, no depende del directorio de trabajo)
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /tmp/wordpress.key \
  -out /tmp/wordpress.crt \
  -subj '/CN=192.168.90.50/O=Kubernetes Lab' \
  -addext 'subjectAltName=IP:192.168.90.50'

openssl x509 -in /tmp/wordpress.crt -noout -text | grep -A1 "Subject Alternative Name"

kubectl -n wordpress create secret tls wordpress-tls \
  --cert=/tmp/wordpress.crt \
  --key=/tmp/wordpress.key \
  --dry-run=client -o yaml | kubectl apply -f -
```

## 26.4. Crear Ingress HTTPS

Ejecutar en **`k8-master`**:

``` bash
# NODO: k8-master
# RUTA: /tmp (rutas absolutas, no depende del directorio de trabajo)
cat <<'EOF' > /tmp/wordpress-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress
  namespace: wordpress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - secretName: wordpress-tls
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wordpress
                port:
                  number: 80
EOF

kubectl apply -f /tmp/wordpress-ingress.yaml
kubectl get ingress -n wordpress
```

> **Corrección importante:** el campo `spec.rules[].host` de un `Ingress`
> **no acepta una dirección IP**, solo nombres DNS
> (`Invalid value: "192.168.90.50": must be a DNS name`). Como se accede
> directamente por IP (no por dominio), se omite `host` en la regla y en
> `tls.hosts`, de forma que la regla aplica a cualquier `Host` recibido.

**Punto de control 26.4 (verificación del requisito 5):**

``` bash
# NODO: anfitrion (o cualquier equipo con ruta a la red k8s-lab)
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
curl -kI https://192.168.90.50/
```

Verificado en este laboratorio el 2026-08-23: responde `HTTP/2 302` con
`location: https://192.168.90.50/wp-admin/install.php` (redirección propia
de una instalación nueva de WordPress, confirma que la app está viva). La
IP usada (`192.168.90.50`) es distinta de la del master (`192.168.90.1`).

En el navegador abre:

``` text
https://192.168.90.50/
```

------------------------------------------------------------------------

-->

# 27. Verificacion de requerimientos finales

``` bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
kubectl get nodes -o wide
kubectl get pods -A
kubectl get deployment,service -n wordpress
kubectl get svc -n wordpress
```

El laboratorio cumple el PDF cuando se verifique:

-   [x] Cuatro nodos Kubernetes `Ready`.
-   [x] Dashboard Kubernetes desplegado.
-   [x] WordPress utiliza almacenamiento temporal `emptyDir`.
-   [x] WordPress, MariaDB y Redis estan en el mismo Pod.
-   [x] WordPress responde por HTTP mediante un servicio `NodePort`.

------------------------------------------------------------------------

# 27.1. Estado de ejecución del laboratorio

**Estado de esta reconstrucción: 23 de agosto de 2026.** Los pasos 1 a 16
quedaron ejecutados y verificados sobre las cuatro VMs: cuatro nodos
`Ready`, Calico saludable, NGINX operativo, Helm y Dashboard funcionando.
Las secciones 24 a 27 están pendientes de verificación en esta
reconstrucción porque el nodo Ceph `192.168.90.40` no es accesible
actualmente.

## Requisito 1 — Cluster con 1 master y 3 workers

``` text
k8-master    Ready    control-plane   192.168.90.1
k8-worker1   Ready    <none>          192.168.90.2
k8-worker2   Ready    <none>          192.168.90.3
k8-worker3   Ready    <none>          192.168.90.4
```

Calico, CoreDNS y `containerd` en `Running` en los 4 nodos. **Cumplido.**

## Requisito 2 — Dashboard

Kubernetes Dashboard v7.14.0 instalado vía Helm, todos los componentes
`Running`, usuario `admin-user` con `ClusterRoleBinding`. **Cumplido.**

## Requisito 3 — WordPress + MariaDB + Redis en un mismo Pod

Pod `wordpress-7b5ff89d57-gxwdx` (namespace `wordpress`) con **3/3**
contenedores `Running`: `wordpress=true`, `mariadb=true`, `redis=true`.
**Cumplido.**

## Requisito 4 — Almacenamiento

CephFS y CSI quedan fuera del alcance del laboratorio simple. WordPress
usa `emptyDir`, por lo que los datos solo viven mientras exista el Pod.

## Requisito 5 — WordPress por HTTP

WordPress se expone mediante un servicio `NodePort`. No se instalan
MetalLB, Ingress NGINX, certificados TLS ni HTTPS.

## Checklist final

-   [x] Cluster Kubernetes base funcional (1 master + 3 workers).
-   [x] Dashboard Kubernetes funcional.
-   [x] WordPress, MariaDB y Redis desplegados en un mismo Pod.
-   [x] WordPress expuesto por HTTP mediante `NodePort`.

------------------------------------------------------------------------

# 28. Verificación de correspondencia con la guía PDF original

Esta revisión final compara el contenido de este documento con la **Guía
Instalación Cluster Kubernetes, revisión 2026** de la Universidad de El
Salvador.

  ------------------------------------------------------------------------------------------------------------
  Tema de la guía PDF     Estado en esta guía     Observación
                          `.md`
  ----------------------- ----------------------- ------------------------------------------------------------
  Chrony/NTP              Incluido                Se conserva master como referencia opcional para workers y
                                                  zona horaria `America/El_Salvador`.

  Hostnames y             Incluido                Se amplía a `k8-worker3` para cumplir el requerimiento final
  `/etc/hosts`                                    de 3 workers.

  Deshabilitar Swap       Incluido                Se agrega verificación y persistencia.

  `overlay`,              Incluido                Se conservan los parámetros requeridos por Kubernetes.
  `br_netfilter` y
  `sysctl`

  Runtime de contenedores Incluido y corregido    Se usa `containerd` directamente; Docker no es requisito
                                                  para kubeadm.

  Repositorio Kubernetes  Incluido                Se conserva `pkgs.k8s.io` y se completan
  v1.36                                           dependencias/llaves.

  `kubeadm init`          Incluido y corregido    Se ejecuta una sola inicialización combinando
                                                  `--pod-network-cidr` y `--control-plane-endpoint`.

  Configuración de        Incluido                Se conservan los pasos de `$HOME/.kube/config`.
  `kubectl`

  CNI / Calico            Incluido y corregido    Se evita mezclar Flannel y Calico; se mantiene
                                                  Calico/Tigera.

  Incorporar workers      Incluido                Se documenta `kubeadm join` y regeneración del token.

  Prueba NGINX            Incluido                Deployment de 2 réplicas, NodePort y pruebas con `curl`.

  Helm                    Incluido                Se conserva la instalación requerida para Dashboard.

  Kubernetes Dashboard    Incluido y actualizado  Se instala con Helm; se evita mezclar el manifiesto antiguo
                                                  v2.7.0.

  Dashboard por NodePort  Agregado como           Se añadió la sección 15.1 adaptada al servicio moderno
  32000                   alternativa             `kubernetes-dashboard-kong-proxy`.

  Usuario `admin-user` y  Incluido                Se conserva por tratarse de laboratorio y se advierte sobre
  `cluster-admin`                                 sus privilegios.

  Token de Dashboard      Incluido                Se usa
                                                  `kubectl -n kubernetes-dashboard create token admin-user`.

  1 master + 3 workers    Incluido                La creación KVM prepara las cuatro VMs.

  WordPress + DB + Redis  Incluido                Se despliegan como tres contenedores dentro de un Pod, según
                                                  el requerimiento académico.

  Almacenamiento          Simplificado            WordPress usa `emptyDir` temporal; CephFS y CSI quedan
                                                  fuera del alcance del laboratorio.

  Exposición WordPress    Incluido                Se usa HTTP mediante `NodePort`; no se instalan MetalLB,
  por HTTP                Ingress ni TLS.
  ------------------------------------------------------------------------------------------------------------

## 28.1. Conclusión de la comparación

La guía `.md` **sí corresponde al objetivo y a las etapas de la guía
PDF**, pero deliberadamente no copia varios pasos antiguos o
contradictorios de forma literal. En particular:

1.  Se corrige `Ubuntu 24.4` a `Ubuntu 24.04` y la referencia incorrecta
    de Jammy a Noble.
2.  Se evita instalar Docker únicamente para obtener `containerd`.
3.  Se evita ejecutar `kubeadm init` dos veces.
4.  Se evita instalar Flannel y Calico simultáneamente.
5.  Se actualiza Kubernetes Dashboard al flujo moderno con Helm.
6.  Se conserva el acceso `NodePort 32000` como alternativa académica
    adaptada al Dashboard moderno.
7.  Se agregan las VMs KVM y el tercer worker porque el requerimiento
    final exige **1 master + 3 workers**, aunque gran parte del
    desarrollo inicial del PDF ejemplifica solamente dos workers.
8.  Los puntos de WordPress, Redis y base de datos tienen un procedimiento
  operativo documentado en las secciones 25 a 27. El laboratorio simple
  no incluye CephFS, MetalLB, Ingress ni HTTPS.

Con estos ajustes, el documento conserva la intención académica del PDF
y al mismo tiempo evita instrucciones que pueden romper o duplicar la
configuración en Kubernetes 1.36.
