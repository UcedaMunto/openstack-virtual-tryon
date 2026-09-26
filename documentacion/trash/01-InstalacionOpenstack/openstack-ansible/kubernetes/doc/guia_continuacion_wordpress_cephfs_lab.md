# Guia 2: Continuacion del laboratorio Kubernetes - WordPress con CephFS y acceso HTTP

> **Punto de partida:** esta guia continua despues de la guia principal, en el punto donde el laboratorio quedo detenido: **25.2 Preparar almacenamiento temporal**.  
> **No reemplaza** la guia principal. Esta guia es una continuacion operativa para cerrar los requerimientos restantes del PDF usando el entorno actual.

## 0. Objetivo de esta segunda guia

Completar la fase final del laboratorio con una ruta simple y adecuada para practica academica:

1. Validar que el cluster Kubernetes base sigue sano.
2. Instalar Ceph desde cero con Rook, directamente sobre los nodos del clúster Kubernetes (sin crear una VM adicional).
3. Crear el CephFilesystem y la StorageClass para que Kubernetes pueda pedir volúmenes CephFS.
4. Validar almacenamiento persistente con un PVC y un Pod de prueba.
5. Crear almacenamiento persistente para WordPress usando `StorageClass cephfs-storage`.
6. Desplegar WordPress, MariaDB y Redis en **un mismo Pod**, como pide el PDF.
7. Exponer WordPress desde el anfitrion usando una IP diferente a la del master.
8. Evitar SSL/HTTPS, certificados, Ingress y recursos extra innecesarios.

La exposicion final recomendada para este laboratorio sera:

```text
https://192.168.90.50/
```

La IP `192.168.90.50` sera entregada por MetalLB como IP flotante de laboratorio.

## 1. Fuentes revisadas y criterios usados

Fuentes principales:

| Tema | Fuente |
|---|---|
| PersistentVolumes y PersistentVolumeClaims | https://kubernetes.io/docs/concepts/storage/persistent-volumes/ |
| Stateful apps con volumen persistente | https://kubernetes.io/docs/tasks/run-application/run-single-instance-stateful-application/ |
| Services `ClusterIP`, `NodePort`, `LoadBalancer` | https://kubernetes.io/docs/concepts/services-networking/service/ |
| Secrets en Kubernetes | https://kubernetes.io/docs/concepts/configuration/secret/ |
| MetalLB IPAddressPool y L2Advertisement | https://metallb.io/configuration/ |
| Rook Ceph - Quickstart | https://rook.io/docs/rook/latest-release/Getting-Started/quickstart/ |
| Rook Ceph - Example configurations | https://rook.io/docs/rook/latest-release/Getting-Started/example-configurations/ |
| Rook Ceph - CephFilesystem CRD | https://rook.io/docs/rook/latest-release/CRDs/Shared-Filesystem/ceph-filesystem-crd/ |
| Guia PDF del laboratorio | Requerimientos de la guia UES, revision 2026 |

Criterios de diseno para esta practica:

| Decision | Motivo |
|---|---|
| Usar CephFS antes de WordPress | Evita migrar datos despues y cumple el requisito de disco persistente. |
| Instalar Ceph con Rook dentro del mismo clúster Kubernetes | Evita crear y mantener una VM Ceph aparte; sigue la documentación oficial de Kubernetes/Rook y reutiliza los 4 nodos que ya existen. |
| Usar PVCs dinamicos | Kubernetes recomienda que las aplicaciones consuman almacenamiento mediante PVC. |
| Usar WordPress, MariaDB y Redis en un solo Pod | Cumple literalmente el requerimiento del PDF. |
| Usar `replicas: 1` y estrategia `Recreate` | MariaDB y Redis son stateful; no queremos dos Pods escribiendo al mismo tiempo durante updates. |
| Usar MetalLB `LoadBalancer` | Permite IP flotante diferente al master sin Ingress ni TLS. |
| Usar HTTP puerto 80 | El usuario indico que no se requiere SSL/HTTPS para esta practica. |
| Mantener recursos bajos | Es laboratorio local con VMs; no se requieren replicas ni alta disponibilidad. |

> **Nota sobre la base de datos:** el PDF pide WordPress con una base de
> datos y Redis. En esta guia se usa **MariaDB**, que es compatible con
> WordPress de forma nativa. **PostgreSQL no se usa** en este flujo porque
> WordPress no lo soporta oficialmente sin capas/plugins adicionales, lo
> cual agregaria complejidad innecesaria para la practica.

## 2. Estado actual esperado del entorno

Segun la validacion actual del laboratorio:

| Componente | Estado esperado |
|---|---|
| `k8-master` | `Ready` |
| `k8-worker1` | `Ready` |
| `k8-worker2` | `Ready` |
| `k8-worker3` | `Ready` |
| Kubernetes | `v1.36.4` |
| CNI | Calico `v3.32.1`, Pods `Running` |
| Dashboard | Instalado por Helm, expuesto por NodePort `32000` |
| NGINX prueba | Funcionando por NodePort `30885` |
| WordPress | Aun no desplegado en esta ejecucion actual |
| Ceph / CephFS | No instalado todavia; se despliega desde cero con Rook en esta guia (sin VM adicional) |

> No existe ningun cluster Ceph previo en esta ejecucion: se instala Ceph con Rook directamente sobre los 3 nodos worker de este mismo cluster Kubernetes. Por eso esta guia **no asume** nada de Ceph: lo instala y luego lo valida antes de usarlo con WordPress.

## 3. Tabla de IPs, credenciales y servicios para esta fase

### 3.1. IPs

| Equipo / servicio | IP | Uso |
|---|---:|---|
| `anfitrion` | `192.168.90.254` | Host fisico con navegador y KVM/libvirt |
| `k8-master` | `192.168.90.1` | Control Plane y ejecucion de `kubectl` |
| `k8-worker1` | `192.168.90.2` | Worker |
| `k8-worker2` | `192.168.90.3` | Worker |
| `k8-worker3` | `192.168.90.4` | Worker (aporta un OSD Ceph via Rook) |
| `wordpress-lb` | `192.168.90.50` | IP flotante MetalLB para WordPress |

### 3.2. Credenciales de laboratorio

| Recurso | Usuario | Credencial / password | Uso |
|---|---|---|---|
| SSH VMs | `uceda` | Llave `~/.ssh/id_ed25519` | Acceso SSH a `k8-master` y workers |
| Kubernetes | `uceda` | `/home/uceda/.kube/config` | Administracion con `kubectl` en `k8-master` |
| MariaDB root | `root` | `RootK8sLab2026!` | Administracion local de MariaDB |
| MariaDB WordPress | `wordpress` | `MariaDbK8sLab2026!` | Conexion de WordPress a la BD |
| WordPress admin | `uceda` (recomendado `admin`, ver nota) | `WordPressK8sLab2026!` | Usar en el asistente web inicial de WordPress |
| Dashboard | `admin-user` | Token temporal | Se genera con `kubectl -n kubernetes-dashboard create token admin-user` |
| Ceph Dashboard | `admin` | `13tAxYZaHbq0ujaxTkmU` | `http://192.168.90.1:32174/` (seccion 18.1) |

> **Nota (2026-08-26):** el password autogenerado por Rook traia caracteres especiales (backtick) que se perdian al copiar desde el chat. Se reemplazo por uno solo con letras y numeros usando `ceph dashboard ac-user-set-password admin -i <archivo>` desde el toolbox, para evitar ese problema. Ver seccion 18.2.

> **Nota (2026-08-26):** el Secret `wordpress-admin-password` solo guarda el password sugerido; el **usuario** real lo define quien completa el asistente web. En esta ejecucion del laboratorio se instalo con usuario `uceda` en vez de `admin`. Verificar siempre el usuario real con `kubectl -n wordpress exec deploy/wordpress -c mariadb -- mariadb -uroot -p'RootK8sLab2026!' -e "SELECT user_login FROM wp_users;" wordpress`.

> Estas credenciales son de laboratorio. No usarlas en produccion ni subirlas a repositorios publicos. Las credenciales CSI de Ceph (`rook-csi-cephfs-provisioner`/`rook-csi-cephfs-node`) las genera y gestiona Rook automaticamente en el namespace `rook-ceph`; no hay que crearlas a mano.

### 3.3. Servicios finales esperados

| Servicio | Namespace | Tipo | Puerto | Acceso desde anfitrion |
|---|---|---|---:|---|
| Dashboard | `kubernetes-dashboard` | `NodePort` | `32000` | `https://192.168.90.1:32000` |
| NGINX prueba | `default` | `NodePort` | `30885` en esta ejecucion | `http://192.168.90.1:30885` o cualquier nodo |
| Ceph (Rook) | `rook-ceph` | CSI interno + `NodePort` (seccion 18.1) | `32174` | `http://192.168.90.1:32174/` (dashboard web); tambien con toolbox `ceph -s` |
| WordPress | `wordpress` | `Ingress` (nginx) | `443` (HTTPS) | `https://192.168.90.50/` |
| MariaDB | Dentro del Pod WordPress | Interno | `3306` | `127.0.0.1:3306` dentro del Pod |
| Redis | Dentro del Pod WordPress | Interno | `6379` | `127.0.0.1:6379` dentro del Pod |

## 4. Plan de ejecucion

| Fase | Resultado esperado | Se continua si... |
|---|---|---|
| 4.1 Validar cluster | Nodos y Pods base sanos | Todos los nodos estan `Ready` |
| 4.2 Instalar Ceph con Rook | Operador Rook, mons/mgr/osd `Running`, `ceph -s` sano | `kubectl -n rook-ceph get cephcluster` en `Ready` |
| 4.3 Crear CephFilesystem y StorageClass | MDS activo y `cephfs-storage` creada | `cephfs-storage` existe |
| 4.4 Probar PVC CephFS | `cephfs-test` queda `Bound` | Un Pod escribe y lee un archivo |
| 4.5 Crear WordPress | Pod `wordpress` `3/3 Running` | WordPress, MariaDB y Redis estan listos |
| 4.6 Exponer WordPress | MetalLB asigna `192.168.90.50` | `curl https://192.168.90.50/` responde |

Si una fase falla, no continuar a la siguiente.

---

# 5. Validacion inicial del cluster Kubernetes

Ejecutar desde `k8-master`:

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
if [[ ! -s "/home/uceda/.kube/config" ]]; then
  echo "ERROR: falta /home/uceda/.kube/config"
  echo "Regresa a la guia principal y completa la configuracion de kubectl."
  exit 1
fi

export KUBECONFIG="/home/uceda/.kube/config"
kubectl get nodes -o wide
kubectl get pods -A
kubectl get svc -A
```

Punto de control:

| Comando | Resultado esperado |
|---|---|
| `kubectl get nodes` | `k8-master`, `k8-worker1`, `k8-worker2`, `k8-worker3` en `Ready` |
| `kubectl get pods -A` | Sin `CrashLoopBackOff`, `ImagePullBackOff` ni `Pending` persistente |
| `kubectl get svc -A` | Dashboard `NodePort 443:32000/TCP` y NGINX `NodePort` |

---

# 6. Instalar Ceph con Rook directamente en el clúster Kubernetes (sin VM adicional)

A diferencia de un intento anterior de este laboratorio, aquí **no se crea
ninguna VM `ceph-admin` aparte**. Partimos de cero: no hay ningún Ceph
instalado todavía, solo el clúster Kubernetes ya desplegado. Ceph se
instala **dentro** del propio clúster (`k8-master` + `k8-worker1/2/3`)
usando [Rook](https://rook.io/docs/rook/latest-release/Getting-Started/intro/),
el operador oficial de Ceph para Kubernetes recomendado por la
documentación de Kubernetes para exponer almacenamiento persistente. Esto
cumple el requerimiento 4 del PDF ("Desplegar un disco persistente
asociado al Cluster de Cephfs") reutilizando la infraestructura que ya
existe, sin levantar servidores adicionales.

Requisito de Rook (documentación oficial de la [Quickstart](https://rook.io/docs/rook/latest-release/Getting-Started/quickstart/)):
cada nodo que aporte almacenamiento necesita al menos un **dispositivo de
bloques crudo** (sin particiones ni sistema de archivos). Como las VMs
`k8-worker1/2/3` solo tienen el disco de sistema, se le agrega un segundo
disco pequeño a cada una para usarlo exclusivamente como OSD.

> Versión usada en esta guía: Rook `v1.20.6` (release estable más
> reciente al momento de escribir esta guía, soporta Kubernetes
> v1.31–v1.36, que cubre la `v1.36.4` de este laboratorio).

## 6.1. Agregar un disco crudo dedicado a cada worker (OSD)

Ejecutar desde el anfitrion (host KVM). Se crea un disco qcow2 pequeño
por worker y se conecta en caliente como `vdb`, sin apagar las VMs.

```bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
VM_DIR="/var/lib/libvirt/images/k8s-lab"

for w in k8-worker1 k8-worker2 k8-worker3; do
  sudo qemu-img create -f qcow2 "${VM_DIR}/${w}-ceph-osd.qcow2" 20G
  sudo virsh attach-disk "${w}" \
    --source "${VM_DIR}/${w}-ceph-osd.qcow2" \
    --target vdb --subdriver qcow2 --targetbus virtio \
    --live --config --persistent
done

sudo virsh domblklist k8-worker1
sudo virsh domblklist k8-worker2
sudo virsh domblklist k8-worker3
```

Punto de control: cada `domblklist` debe mostrar `vdb` apuntando al
archivo `-ceph-osd.qcow2` recien creado.

Verificar desde dentro de cada worker que `vdb` aparece como disco crudo,
sin particiones ni sistema de archivos:

```bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in 192.168.90.2 192.168.90.3 192.168.90.4; do
  ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 uceda@"${ip}" 'hostname; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/vdb'
done
```

Punto de control: `FSTYPE` debe salir vacío para `vdb` en los 3 workers.
Si `vdb` no aparece, revisa `virsh domblklist` y confirma que el disco se
creó con `qemu-img create` antes del `attach-disk`.

> Si `vdb` ya tuviera datos de un intento anterior (por ejemplo restos de
> un OSD viejo), Rook rechazará el disco. Límpialo con `wipefs -a /dev/vdb`
> **solo si estás seguro de que no tiene datos que quieras conservar**.

## 6.2. Cargar el módulo de kernel `ceph` en los 4 nodos Kubernetes

El cliente kernel de CephFS (usado por el nodeplugin del CSI) requiere el
módulo `ceph` cargado en el sistema operativo de cada nodo, no solo dentro
de los contenedores.

```bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
for ip in 192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4; do
  ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 uceda@"${ip}" '
    sudo modprobe ceph
    echo "ceph" | sudo tee /etc/modules-load.d/ceph.conf
    lsmod | grep -q "^ceph " && echo "OK: modulo ceph cargado" || echo "ERROR: modulo ceph no cargado"
  '
done
```

Punto de control: los 4 nodos deben responder `OK: modulo ceph cargado`.

## 6.3. Instalar los CRDs, recursos comunes y el operador de Rook

Ejecutar desde `k8-master`, usando directamente los manifiestos oficiales
de la release fijada (sin clonar el repositorio completo), siguiendo el
[Quickstart oficial de Rook](https://rook.io/docs/rook/latest-release/Getting-Started/quickstart/):

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
ROOK_VERSION="v1.20.6"
BASE_URL="https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples"

kubectl create -f "${BASE_URL}/crds.yaml" \
  -f "${BASE_URL}/common.yaml" \
  -f "${BASE_URL}/csi-operator.yaml"

kubectl create -f "${BASE_URL}/operator.yaml"

kubectl -n rook-ceph get pod
```

Punto de control: `rook-ceph-operator-...` debe llegar a `1/1 Running`
antes de continuar (puede tardar uno o dos minutos mientras descarga la
imagen).

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n rook-ceph rollout status deployment/rook-ceph-operator --timeout=180s
```

## 6.4. Crear el CephCluster usando los discos `vdb` de los 3 workers

Este `CephCluster` está adaptado al mínimo de recursos de este
laboratorio: 3 monitores (uno por worker, uno menos que el default no
tendría sentido con solo 3 nodos disponibles), 1 solo mgr (en vez de 2),
sin dashboard de Ceph (el requerimiento 2 del PDF ya lo cumple el
Dashboard de Kubernetes), sin recolector de crashes ni de logs, y usando
explícitamente solo el disco `vdb` de cada worker (nunca el disco del
sistema operativo).

```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

cat <<'EOF' > /tmp/rook-cluster.yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v20.2.4
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  mon:
    count: 3
    allowMultiplePerNode: false
  mgr:
    count: 1
    allowMultiplePerNode: false
  dashboard:
    enabled: false
  monitoring:
    enabled: false
  crashCollector:
    disable: true
  logCollector:
    enabled: false
  security:
    cephx:
      csi:
        keyType: aes
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: "k8-worker1"
        devices:
          - name: "vdb"
      - name: "k8-worker2"
        devices:
          - name: "vdb"
      - name: "k8-worker3"
        devices:
          - name: "vdb"
EOF

kubectl apply -f /tmp/rook-cluster.yaml
kubectl -n rook-ceph get cephcluster
```

> `security.cephx.csi.keyType: aes` es el valor por defecto que trae el
> `cluster.yaml` oficial para kernels de Linux menores a 7.0 (es el caso de
> Ubuntu 24.04, kernel `6.8`); evita el problema histórico de llaves CephX
> de 32 bytes (`aes256k`) que ningún cliente puede decodificar.

Punto de control inicial: el `CephCluster` debe pasar de `Progressing` a
`Ready` en unos minutos. Sigue el progreso con:

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n rook-ceph get pods -o wide -w
```

Presiona `Ctrl+C` cuando veas 3 pods `rook-ceph-mon-*`, 1 `rook-ceph-mgr-*`
y 3 `rook-ceph-osd-*` en estado `Running` (más los `rook-ceph-osd-prepare-*`
en `Completed`).

> Si algún `rook-ceph-osd-prepare-*` no llega a `Completed`, revisa sus
> logs con `kubectl -n rook-ceph logs job/rook-ceph-osd-prepare-<nodo>` y
> confirma en 6.1 que el disco `vdb` de ese nodo está realmente vacío.

## 6.5. Instalar el toolbox y verificar la salud de Ceph

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
ROOK_VERSION="v1.20.6"

kubectl create -f "https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples/toolbox.yaml"
kubectl -n rook-ceph rollout status deployment/rook-ceph-tools --timeout=120s

kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree
```

Punto de control:

| Elemento | Esperado |
|---|---|
| `health` | `HEALTH_OK` (o `HEALTH_WARN` aceptable en laboratorio, ej. por pocos OSD) |
| `mon` | `3 daemons, quorum ...` |
| `mgr` | `... active` |
| `osd` | `3 osds: 3 up, 3 in` |

## 6.6. Resumen: todos los comandos de la seccion 6, listos para copiar y pegar

Este bloque no agrega nada nuevo: es el mismo contenido de 6.1 a 6.5, sin
la explicacion, en el orden exacto en que hay que ejecutarlo. Usalo solo
si ya leiste las secciones anteriores; si algo falla, vuelve al numeral
correspondiente (6.1-6.5) para ver el punto de control y el detalle.

Primero, todo lo que se ejecuta desde el **anfitrion** (6.1 y 6.2):


```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

# ===== 6.3 - CRDs, recursos comunes y operador de Rook =====

# Version estable de Rook fijada para esta guia (soporta Kubernetes v1.31-v1.36)
ROOK_VERSION="v1.20.6"
# URL base de los manifiestos oficiales de esa release, sin clonar el repo completo
BASE_URL="https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples"

# Crea los CRDs de Ceph, los recursos comunes (namespace/RBAC) y el operador CSI
kubectl create -f "${BASE_URL}/crds.yaml" \
  -f "${BASE_URL}/common.yaml" \
  -f "${BASE_URL}/csi-operator.yaml"

# Despliega el operador de Rook, que es quien gestiona todo el ciclo de vida de Ceph
kubectl create -f "${BASE_URL}/operator.yaml"

# Espera a que el operador quede en Running antes de continuar
kubectl -n rook-ceph rollout status deployment/rook-ceph-operator --timeout=180s

# ===== 6.4 - CephCluster usando el disco vdb de cada worker =====

# Escribe el manifiesto del CephCluster minimo (3 mon, 1 mgr, sin dashboard/monitoring)
cat <<'EOF' > /tmp/rook-cluster.yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v20.2.4
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  mon:
    count: 3
    allowMultiplePerNode: false
  mgr:
    count: 1
    allowMultiplePerNode: false
  dashboard:
    enabled: false
  monitoring:
    enabled: false
  crashCollector:
    disable: true
  logCollector:
    enabled: false
  security:
    cephx:
      csi:
        keyType: aes
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: "k8-worker1"
        devices:
          - name: "vdb"
      - name: "k8-worker2"
        devices:
          - name: "vdb"
      - name: "k8-worker3"
        devices:
          - name: "vdb"
EOF

# Aplica el CephCluster; a partir de aqui el operador crea mons, mgr y OSDs
kubectl apply -f /tmp/rook-cluster.yaml
# Consulta el estado general del CephCluster (debe llegar a Ready)
kubectl -n rook-ceph get cephcluster

# Sigue el progreso en vivo: espera 3 mon + 1 mgr + 3 osd en Running (Ctrl+C para salir)
kubectl -n rook-ceph get pods -o wide -w
```

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
ROOK_VERSION="v1.20.6"

# ===== 6.5 - toolbox y verificacion de salud =====

# Despliega el pod toolbox (cliente ceph -s/-w listo para usar dentro del cluster)
kubectl create -f "https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples/toolbox.yaml"
# Espera a que el toolbox quede Running
kubectl -n rook-ceph rollout status deployment/rook-ceph-tools --timeout=120s

# Estado general de salud del cluster Ceph (mon/mgr/osd, health OK o WARN)
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
# Arbol de OSDs: confirma que los 3 discos vdb quedaron up/in
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree
```

---

# 7. Crear el CephFilesystem y la StorageClass para Kubernetes

A diferencia del flujo manual con `cephadm` + Ceph CSI upstream que se
usó en un intento anterior de este laboratorio, aquí Rook ya instaló y
configuró el driver CSI de CephFS como parte del operador (sección 6.3).
Aquí solo falta crear el filesystem y la `StorageClass`; Rook genera
automáticamente los Secrets que el CSI necesita
(`rook-csi-cephfs-provisioner` y `rook-csi-cephfs-node`, en el namespace
`rook-ceph`), por lo que no hay que manipular llaves CephX a mano ni
crear ConfigMaps de `ceph.conf`/`keyring` como antes.

## 7.1. Crear el CephFilesystem `myfs`

```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

cat <<'EOF' > /tmp/rook-filesystem.yaml
apiVersion: ceph.rook.io/v1
kind: CephFilesystem
metadata:
  name: myfs
  namespace: rook-ceph
spec:
  metadataPool:
    replicated:
      size: 3
  dataPools:
    - name: replicated
      failureDomain: host
      replicated:
        size: 3
  preserveFilesystemOnDelete: true
  metadataServer:
    activeCount: 1
    activeStandby: false
---
apiVersion: ceph.rook.io/v1
kind: CephFilesystemSubVolumeGroup
metadata:
  name: myfs-csi
  namespace: rook-ceph
spec:
  name: csi
  filesystemName: myfs
EOF

kubectl apply -f /tmp/rook-filesystem.yaml
kubectl -n rook-ceph get cephfilesystem myfs
kubectl -n rook-ceph get pod -l app=rook-ceph-mds
```

Punto de control: al menos un pod `rook-ceph-mds-myfs-...` en `Running`.
Con `activeStandby: false` solo se crea 1 MDS (sin standby-replay), para
mantener el mínimo de recursos del laboratorio; con 3 OSDs en 3 hosts
distintos, `replicated.size: 3` da redundancia real sin necesidad de
bajar el tamaño de réplica como en el intento anterior con un solo OSD.

## 7.2. Crear la StorageClass `cephfs-storage`

```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

cat <<'EOF' > /tmp/cephfs-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cephfs-storage
provisioner: rook-ceph.cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  fsName: myfs
  pool: myfs-replicated
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF

kubectl apply -f /tmp/cephfs-storageclass.yaml
kubectl get storageclass cephfs-storage
```

> El nombre de la `StorageClass` (`cephfs-storage`) se mantiene igual al
> resto de esta guía para no tener que cambiar los PVC de las secciones
> siguientes; lo que cambia es el `provisioner` (ahora es el CSI que
> instala Rook: `rook-ceph.cephfs.csi.ceph.com`) y el namespace de los
> Secrets (`rook-ceph` en vez de `default`).

## 7.3. Verificar los pods CSI que instaló Rook

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n rook-ceph get pods
```

Punto de control: deben aparecer, además de `rook-ceph-mon/mgr/osd/mds`,
pods del driver CSI de CephFS (nombres típicos en Rook `v1.20`:
`rook-ceph.cephfs.csi.ceph.com-ctrlplugin-...` y
`rook-ceph.cephfs.csi.ceph.com-nodeplugin-...`), todos en `Running`.

Si alguno falla, revisa primero el operador (más estable entre versiones
que los nombres internos del CSI):

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n rook-ceph logs deploy/rook-ceph-operator --tail=200
```

---

# 8. Prueba obligatoria de CephFS antes de WordPress

## 8.1. Crear PVC de prueba

```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

kubectl delete pod cephfs-test-pod --ignore-not-found
kubectl delete pvc cephfs-test --ignore-not-found

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
      storage: 1Gi
EOF

kubectl apply -f /tmp/cephfs-test-pvc.yaml
kubectl get pvc cephfs-test
```

Esperado:

```text
cephfs-test   Bound
```

Si queda `Pending`, no continues a WordPress. Ejecuta:

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl describe pvc cephfs-test
kubectl get events --sort-by=.lastTimestamp | tail -n 80
kubectl -n rook-ceph get pods
kubectl -n rook-ceph logs deploy/rook-ceph-operator --tail=200
```

## 8.2. Crear Pod que escriba y lea en CephFS

```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

cat <<'EOF' > /tmp/cephfs-test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cephfs-test-pod
spec:
  restartPolicy: Never
  containers:
    - name: tester
      image: busybox:1.36
      command:
        - sh
        - -c
        - "echo hola-cephfs-$(date +%s) > /mnt/test.txt && cat /mnt/test.txt && sleep 30"
      volumeMounts:
        - name: data
          mountPath: /mnt
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: cephfs-test
EOF

kubectl apply -f /tmp/cephfs-test-pod.yaml
kubectl wait --for=condition=Ready pod/cephfs-test-pod --timeout=120s
kubectl logs cephfs-test-pod
```

Punto de control: la salida debe contener `hola-cephfs-...`.

Limpiar la prueba:

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl delete pod cephfs-test-pod --ignore-not-found
kubectl delete pvc cephfs-test --ignore-not-found
```

---

# 9. Crear namespace y credenciales de WordPress

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

kubectl create namespace wordpress --dry-run=client -o yaml | kubectl apply -f -

kubectl -n wordpress create secret generic wordpress-secrets \
  --from-literal=mariadb-root-password='RootK8sLab2026!' \
  --from-literal=mariadb-password='MariaDbK8sLab2026!' \
  --from-literal=wordpress-admin-password='WordPressK8sLab2026!' \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n wordpress get secret wordpress-secrets
```

Punto de control:

```text
wordpress-secrets   Opaque   3
```

---

# 10. Crear PVCs CephFS para WordPress

Se usaran tres PVCs pequenos para laboratorio:

| PVC | Tamano | AccessMode | Montaje | Motivo |
|---|---:|---|---|---|
| `wordpress-content` | `5Gi` | `ReadWriteMany` | `/var/www/html` | Archivos, plugins, temas y uploads |
| `wordpress-db` | `5Gi` | `ReadWriteOnce` | `/var/lib/mysql` | Datos de MariaDB |
| `wordpress-redis` | `1Gi` | `ReadWriteOnce` | `/data` | AOF de Redis |

```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

cat <<'EOF' > /tmp/wordpress-pvcs.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-content
  namespace: wordpress
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: cephfs-storage
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-db
  namespace: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: cephfs-storage
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-redis
  namespace: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: cephfs-storage
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply -f /tmp/wordpress-pvcs.yaml
kubectl -n wordpress get pvc
```

Punto de control: los tres PVCs deben quedar `Bound`.

Si alguno queda `Pending`, detenerse y revisar:

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n wordpress describe pvc wordpress-content
kubectl -n wordpress describe pvc wordpress-db
kubectl -n wordpress describe pvc wordpress-redis
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
```

## 10.1. Comprobación de progreso y configuración antes de continuar

Antes de desplegar WordPress (seccion 11), verifica en un solo paso que
todo lo anterior (cluster, Ceph/Rook, CephFilesystem, StorageClass y los
PVCs) sigue sano. Si algo de esto falla, no continues a la seccion 11.

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

echo "== 5. Nodos del cluster =="
kubectl get nodes

echo "== 6. Pods de Rook/Ceph =="
kubectl -n rook-ceph get pods

echo "== 6. Estado del CephCluster =="
kubectl -n rook-ceph get cephcluster

echo "== 6. Salud de Ceph (mon/mgr/osd) =="
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s

echo "== 7. CephFilesystem y MDS =="
kubectl -n rook-ceph get cephfilesystem myfs
kubectl -n rook-ceph get pod -l app=rook-ceph-mds

echo "== 7. StorageClass =="
kubectl get storageclass cephfs-storage

echo "== 9. Namespace y Secret de WordPress =="
kubectl get namespace wordpress
kubectl -n wordpress get secret wordpress-secrets

echo "== 10. PVCs de WordPress =="
kubectl -n wordpress get pvc
```

Punto de control (todo debe cumplirse antes de pasar a la seccion 11):

| Verificacion | Esperado |
|---|---|
| Nodos | `k8-master`, `k8-worker1/2/3` en `Ready` |
| Pods `rook-ceph` | `mon-a/b/c`, `mgr-a`, `osd-0/1/2`, `mds-myfs-a`, CSI ctrlplugin/nodeplugin, `rook-ceph-tools` en `Running` |
| `CephCluster` | `PHASE Ready` |
| `ceph -s` | `health: HEALTH_OK` (o `HEALTH_WARN` por `keyType: aes`, aceptable) y `mon: 3`, `mgr: ... active`, `osd: 3 up, 3 in` |
| `CephFilesystem myfs` | `PHASE Ready` (o `Progressing` justo tras crearlo), MDS `Running` |
| `StorageClass cephfs-storage` | Existe, `PROVISIONER rook-ceph.cephfs.csi.ceph.com` |
| `Secret wordpress-secrets` | `Opaque` con `3` claves |
| PVCs `wordpress-content/db/redis` | Los 3 en `Bound` |

Si algun PVC de WordPress sigue en `Pending` a pesar de que `myfs` y la
`StorageClass` ya existen, repite el PVC de prueba de la seccion 8 antes
de seguir, para descartar un problema mas general del CSI:

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl get pvc cephfs-test
```

---

# 11. Desplegar WordPress, MariaDB y Redis en un mismo Pod

Este manifiesto cumple el requerimiento del PDF: tres contenedores agrupados en un Pod.

```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

cat <<'EOF' > /tmp/wordpress-cephfs.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress
spec:
  replicas: 1
  strategy:
    type: Recreate
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
            - name: http
              containerPort: 80
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
            - name: WORDPRESS_CONFIG_EXTRA
              value: |
                define('WP_REDIS_HOST', '127.0.0.1');
                define('WP_REDIS_PORT', 6379);
                define('WP_CACHE', true);
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
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
          ports:
            - name: mysql
              containerPort: 3306
          resources:
            requests:
              cpu: 100m
              memory: 512Mi
            limits:
              cpu: 700m
              memory: 1Gi
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
            - name: redis
              containerPort: 6379
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          volumeMounts:
            - name: wordpress-redis
              mountPath: /data
      volumes:
        - name: wordpress-content
          persistentVolumeClaim:
            claimName: wordpress-content
        - name: wordpress-db
          persistentVolumeClaim:
            claimName: wordpress-db
        - name: wordpress-redis
          persistentVolumeClaim:
            claimName: wordpress-redis
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
      targetPort: http
      protocol: TCP
  type: ClusterIP
EOF

kubectl apply -f /tmp/wordpress-cephfs.yaml
kubectl rollout status deployment/wordpress -n wordpress --timeout=300s
kubectl -n wordpress get pods -o wide
kubectl -n wordpress get svc wordpress
```

## 11.1. Validar los tres contenedores

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

kubectl -n wordpress get pod -l app=wordpress \
  -o jsonpath='{range .items[0].status.containerStatuses[*]}{.name}{"="}{.ready}{"\n"}{end}'
```

Esperado:

```text
wordpress=true
mariadb=true
redis=true
```

## 11.2. Validar MariaDB y Redis dentro del Pod

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

POD="$(kubectl -n wordpress get pod -l app=wordpress -o jsonpath='{.items[0].metadata.name}')"

kubectl -n wordpress exec "${POD}" -c mariadb -- \
  mariadb-admin ping -h 127.0.0.1 -uroot -p'RootK8sLab2026!'

kubectl -n wordpress exec "${POD}" -c redis -- redis-cli ping
```

Esperado:

```text
mysqld is alive
PONG
```

---

# 12. Instalar o validar MetalLB para IP flotante HTTP

> Si MetalLB ya esta instalado, estos comandos solo verifican y re-aplican configuracion.  
> Para este laboratorio se usa una sola IP: `192.168.90.50`.

## 12.1. Instalar MetalLB

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
METALLB_VERSION="v0.16.1"

kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl wait --namespace metallb-system \
  --for=condition=Available deployment/controller \
  --timeout=180s
kubectl -n metallb-system get pods -o wide
```

## 12.2. Configurar IPAddressPool y L2Advertisement

```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

cat <<'EOF' > /tmp/metallb-k8s-lab-pool.yaml
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

kubectl apply -f /tmp/metallb-k8s-lab-pool.yaml
kubectl -n metallb-system get ipaddresspool,l2advertisement
```

Punto de control: deben existir `k8s-lab-pool` y `k8s-lab-advertisement`.

---

# 13. Exponer WordPress por IP flotante HTTP

No se usa Ingress, SSL ni HTTPS. El Service sera `LoadBalancer` y MetalLB asignara `192.168.90.50`.

```bash
# NODO: k8-master
# RUTA: /tmp
export KUBECONFIG="/home/uceda/.kube/config"

cat <<'EOF' > /tmp/wordpress-lb-http.yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress-lb
  namespace: wordpress
  annotations:
    metallb.io/loadBalancerIPs: 192.168.90.50
spec:
  type: LoadBalancer
  selector:
    app: wordpress
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: http
EOF

kubectl apply -f /tmp/wordpress-lb-http.yaml
kubectl -n wordpress get svc wordpress wordpress-lb -o wide
```

Punto de control:

```text
wordpress-lb   LoadBalancer   ...   192.168.90.50   80:xxxxx/TCP
```

Si `EXTERNAL-IP` queda en `pending`, revisar:

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n metallb-system get pods -o wide
kubectl -n metallb-system describe ipaddresspool k8s-lab-pool
kubectl -n metallb-system logs deployment/controller --tail=100
kubectl -n wordpress describe svc wordpress-lb
```

---

# 14. Probar acceso desde el anfitrion

Ejecutar desde el anfitrion:

```bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
curl -kI https://192.168.90.50/
curl -kL https://192.168.90.50/ | head -n 20
```

Abrir en el navegador del anfitrion:

```text
https://192.168.90.50/
```

En el asistente web de WordPress usar:

| Campo | Valor recomendado |
|---|---|
| Site Title | `Kubernetes Lab` |
| Username | `admin` |
| Password | `WordPressK8sLab2026!` |
| Email | `admin@k8s.lab` |
| Search engine visibility | Indiferente para laboratorio |

> El password del admin web no lo crea automaticamente Kubernetes. Se define en el asistente inicial de WordPress. El Secret `wordpress-admin-password` queda como referencia de laboratorio. En esta ejecucion del lab el usuario real quedo como `uceda` (ver nota en seccion 3.2) — comprobar siempre el usuario real antes de intentar iniciar sesion.

## 14.1. [Troubleshooting] Resetear el password del admin si el login falla

Solo aplica si el login en `/wp-login.php` falla con "The password you entered ... is incorrect" pese a usar la password de la seccion 3.2. Causas mas comunes: el usuario real no es `admin` (ver nota 3.2), o el hash quedo desincronizado.

**Importante:** WordPress >= 6.8 no aplica bcrypt directo sobre el password. Primero calcula `base64_encode(hash_hmac('sha384', trim($password), 'wp-sha384', true))` y luego `'$wp' . password_hash(ese_valor, PASSWORD_BCRYPT)`. Generar el hash con `password_hash($password, PASSWORD_BCRYPT)` a secas produce un hash valido mal formado que **nunca** valida contra el password real.

```bash
# NODO: k8-master
# 1. Verificar el usuario real
kubectl -n wordpress exec deploy/wordpress -c mariadb -- \
  mariadb -uroot -p'RootK8sLab2026!' -e "SELECT ID,user_login FROM wp_users;" wordpress

# 2. Generar el hash correcto (evitar escribir el password con "!" literal en la
#    terminal: puede corromperse por expansion de historial de bash). Mejor
#    escribirlo a un archivo y verificar sus bytes con xxd antes de usarlo.
printf '%s' 'WordPressK8sLab2026!' > /tmp/pwdfile
xxd /tmp/pwdfile | tail -1   # confirmar que termina en ...21 (0x21 = '!')

PODNAME=$(kubectl get pod -n wordpress -l app=wordpress -o jsonpath='{.items[0].metadata.name}')
kubectl cp /tmp/pwdfile wordpress/$PODNAME:/tmp/pwdfile -c wordpress
kubectl exec -i -n wordpress deploy/wordpress -c wordpress -- php <<'PHP'
<?php
$password = file_get_contents('/tmp/pwdfile');
$password_to_hash = base64_encode( hash_hmac( 'sha384', trim( $password ), 'wp-sha384', true ) );
$hash = '$wp' . password_hash( $password_to_hash, PASSWORD_BCRYPT );
file_put_contents('/tmp/newhash.txt', $hash);
echo "HASH=$hash\n";
PHP
kubectl cp wordpress/$PODNAME:/tmp/newhash.txt /tmp/newhash.txt -c wordpress

# 3. Actualizar la BD con el hash generado (reemplazar USUARIO por el user_login real)
NEWHASH=$(cat /tmp/newhash.txt)
kubectl exec -i -n wordpress deploy/wordpress -c mariadb -- mariadb -uroot -p'RootK8sLab2026!' wordpress <<SQL
UPDATE wp_users SET user_pass='$NEWHASH' WHERE user_login='USUARIO';
SQL

# 4. Vaciar cache de Redis (si no, el login sigue fallando con datos cacheados)
kubectl exec -n wordpress deploy/wordpress -c redis -- redis-cli FLUSHALL
```

**Punto de control:** iniciar sesion en `https://192.168.90.50/wp-login.php` con el `user_login` real y el password usado en el paso 2; debe redirigir a `/wp-admin/`.

---

# 15. Validar persistencia real

## 15.1. Crear un archivo dentro del volumen de WordPress

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
POD="$(kubectl -n wordpress get pod -l app=wordpress -o jsonpath='{.items[0].metadata.name}')"

kubectl -n wordpress exec "${POD}" -c wordpress -- \
  sh -c 'echo persistencia-cephfs > /var/www/html/cephfs-check.txt && cat /var/www/html/cephfs-check.txt'
```

## 15.2. Reiniciar el Deployment y comprobar que el archivo sigue

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

kubectl -n wordpress rollout restart deployment/wordpress
kubectl -n wordpress rollout status deployment/wordpress --timeout=300s

POD="$(kubectl -n wordpress get pod -l app=wordpress -o jsonpath='{.items[0].metadata.name}')"
kubectl -n wordpress exec "${POD}" -c wordpress -- cat /var/www/html/cephfs-check.txt
```

Esperado:

```text
persistencia-cephfs
```

## 15.3. Validar PVCs despues del reinicio

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n wordpress get pvc
kubectl -n wordpress get pods -o wide
kubectl -n wordpress get svc wordpress-lb
```

---

# 16. Checklist final de esta guia

| Requisito PDF | Estado esperado con esta guia |
|---|---|
| 1 master + 3 workers | Ya cumplido en la guia principal |
| Dashboard web | Ya cumplido por Dashboard NodePort `32000` |
| WordPress + BD + Redis en un Pod | Cumplido por Deployment `wordpress` con 3 contenedores |
| Disco persistente CephFS | Cumplido por PVCs `wordpress-content`, `wordpress-db`, `wordpress-redis` |
| IP diferente a la del master | Cumplido por MetalLB `192.168.90.50` |
| Acceso web | Para esta practica: `https://192.168.90.50/` con SSL/HTTPS (puerto 443, cert autofirmado) |

Validacion resumida:

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

kubectl get nodes
kubectl -n wordpress get pods
kubectl -n wordpress get pvc
kubectl -n wordpress get svc wordpress-lb
kubectl -n metallb-system get ipaddresspool,l2advertisement
```

Validacion desde anfitrion:

```bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
curl -kI https://192.168.90.50/
```

---

# 17. Troubleshooting rapido

## 17.1. PVC queda en `Pending`

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl describe pvc cephfs-test
kubectl -n wordpress describe pvc wordpress-content
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
kubectl -n rook-ceph get pods
kubectl -n rook-ceph logs deploy/rook-ceph-operator --tail=200
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
```

Causas probables:

| Sintoma | Causa probable | Accion |
|---|---|---|
| `rook-ceph-osd-prepare-*` no llega a `Completed` | El disco `vdb` no esta vacio o no llego a la VM | Revisar 6.1 (`virsh domblklist`, `lsblk`), limpiar con `wipefs -a /dev/vdb` si no tiene datos utiles |
| `no mds is up` | CephFilesystem/MDS no sano | Validar `kubectl -n rook-ceph get pod -l app=rook-ceph-mds` y `ceph fs status myfs` desde el toolbox |
| PVC sigue en `Pending` tras corregir el CephCluster | El operador de Rook o el CSI mantienen estado viejo | `kubectl -n rook-ceph rollout restart deployment/rook-ceph-operator` y reintentar |
| `CephCluster` no llega a `Ready` | Falta el modulo de kernel `ceph` en algun nodo | Repetir 6.2 en los 4 nodos y revisar `kubectl -n rook-ceph get pods -o wide` |

## 17.2. WordPress queda en `ContainerCreating`

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n wordpress describe pod -l app=wordpress
kubectl -n wordpress get pvc
```

Revisar primero montajes de PVC.

## 17.3. WordPress queda en `CrashLoopBackOff`

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
POD="$(kubectl -n wordpress get pod -l app=wordpress -o jsonpath='{.items[0].metadata.name}')"
kubectl -n wordpress logs "${POD}" -c wordpress --tail=100
kubectl -n wordpress logs "${POD}" -c mariadb --tail=100
kubectl -n wordpress logs "${POD}" -c redis --tail=100
```

## 17.4. `192.168.90.50` no responde

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n wordpress get svc wordpress-lb -o wide
kubectl -n wordpress get endpoints wordpress-lb
kubectl -n metallb-system get pods -o wide
kubectl -n metallb-system logs deployment/controller --tail=100
```

Desde anfitrion:

```bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ping -c 3 192.168.90.50
curl -kv https://192.168.90.50/
```

---

# 18. Limpieza opcional de esta fase

> Ejecutar solo si quieres desmontar WordPress y MetalLB. No borres CephFS si quieres conservar datos.

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

kubectl -n wordpress delete svc wordpress-lb --ignore-not-found
kubectl -n wordpress delete deployment wordpress --ignore-not-found
kubectl -n wordpress delete svc wordpress --ignore-not-found
```

Para borrar tambien datos persistentes de WordPress:

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

kubectl -n wordpress delete pvc wordpress-content wordpress-db wordpress-redis --ignore-not-found
kubectl delete namespace wordpress --ignore-not-found
```

> Si borras los PVCs, Ceph CSI eliminara los subvolumenes dinamicos porque el `StorageClass` usa `reclaimPolicy: Delete`.

---

# 18.1. [Opcional] Habilitar el dashboard de Ceph sin SSL

No es un requisito del PDF (el requerimiento 2 ya lo cubre el Dashboard
de Kubernetes), pero es de muy bajo costo: el dashboard de Ceph no crea
ningun Pod nuevo, solo activa un modulo dentro del Pod `rook-ceph-mgr-a`
que ya esta `Running`. Se sigue la [documentacion oficial de Rook](https://rook.io/docs/rook/latest-release/Storage-Configuration/Monitoring/ceph-dashboard/),
usando `ssl: false` para no tener que lidiar con el certificado
autofirmado, igual que el resto de esta guia evita TLS.

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

# Habilita el modulo dashboard del mgr, sin SSL, en el puerto 7000
kubectl -n rook-ceph patch cephcluster rook-ceph --type merge \
  -p '{"spec":{"dashboard":{"enabled":true,"ssl":false,"port":7000}}}'

# Espera a que Rook cree el Service del dashboard con el puerto 7000/TCP
kubectl -n rook-ceph get svc rook-ceph-mgr-dashboard -w
```

Presiona `Ctrl+C` en cuanto `rook-ceph-mgr-dashboard` aparezca con
`PORT(S)` en `7000/TCP` (puede tardar uno o dos minutos en reconciliar).

> **Importante:** NO uses `kubectl patch svc rook-ceph-mgr-dashboard -p
> '{"spec":{"type":"NodePort"}}'` para exponerlo. El Service
> `rook-ceph-mgr-dashboard` lo posee y reconcilia el operador de Rook, que
> lo resetea a `ClusterIP` en su siguiente ciclo de reconciliacion (pocos
> minutos despues). El sintoma es: funciona un rato, luego "Connection
> refused" desde el anfitrion aunque `kubectl get svc` mostraba `NodePort`
> momentos antes. La forma persistente es crear un Service **adicional**,
> no gestionado por Rook, con el mismo selector de Pods.

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

# Crea un Service NodePort propio (no tocado por el operador de Rook)
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: rook-ceph-mgr-dashboard-external
  namespace: rook-ceph
spec:
  type: NodePort
  selector:
    app: rook-ceph-mgr
    mgr_role: active
    rook_cluster: rook-ceph
  ports:
    - name: dashboard
      port: 7000
      targetPort: 7000
      nodePort: 32174
YAML
kubectl -n rook-ceph get svc rook-ceph-mgr-dashboard-external

# Contrasena autogenerada por Rook para el usuario admin
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode; echo
```

Punto de control: `get svc rook-ceph-mgr-dashboard-external` debe mostrar
`TYPE NodePort` con `7000:32174/TCP` de forma estable (repetir el `get`
varias veces con minutos de diferencia para confirmar que no vuelve a
`ClusterIP`). Con ese `NodePort` y la contrasena impresa, accede desde el
anfitrion:

```text
http://192.168.90.1:32174/
```

| Campo | Valor |
|---|---|
| Usuario | `admin` |
| Password | La impresa por el comando anterior (`rook-ceph-dashboard-password`) |

## 18.2. [Opcional/Recomendado] Cambiar el password del dashboard a solo letras y numeros

El password autogenerado por Rook trae simbolos (incluye backtick), faciles
de perder al copiar desde una terminal o un chat. Se puede reemplazar por
uno con solo letras/numeros directamente en Ceph (no toca el Secret de
Kubernetes, solo la base de datos interna del modulo dashboard):

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

# Genera un password alfanumerico y lo copia al Pod del toolbox como archivo
NEWPASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)
echo "Nuevo password: $NEWPASS"
printf '%s' "$NEWPASS" > /tmp/cephpass.txt
PODNAME=$(kubectl get pod -n rook-ceph -l app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}')
kubectl cp /tmp/cephpass.txt rook-ceph/$PODNAME:/tmp/cephpass.txt
kubectl -n rook-ceph exec "$PODNAME" -- ceph dashboard ac-user-set-password admin -i /tmp/cephpass.txt
```

Punto de control: probar login por API antes de usar el navegador:

```bash
curl -sk -X POST "http://192.168.90.1:32174/api/auth" \
  -H "Accept: application/vnd.ceph.api.v1.0+json" -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"$NEWPASS\"}"
```

Debe devolver un JSON con un campo `"token"` (JWT). Si devuelve
`"Invalid credentials"`, revisar que `$NEWPASS` no se corrompio en la
terminal (verificar con `od -c` o `xxd` sobre el archivo antes de usarlo).

---

# 19. Accesos rapidos a todas las interfaces desde el anfitrion

Tabla resumen de rutas y credenciales para entrar a cada interfaz del laboratorio, todas alcanzables desde el **anfitrion** (host KVM) sin pasos adicionales.

| Interfaz | Ruta desde el anfitrion | Usuario | Password / credencial | Notas |
|---|---|---|---|---|
| WordPress (sitio publico) | `https://192.168.90.50/` | — | — | IP flotante MetalLB, sin login |
| WordPress (wp-admin) | `https://192.168.90.50/wp-admin/` | `uceda` (verificar, ver seccion 3.2) | `WordPressK8sLab2026!` | Definido en el asistente inicial de WordPress (seccion 14); si falla el login ver seccion 14.1 |
| Kubernetes Dashboard | `https://192.168.90.1:32000` | `admin-user` | Token temporal | Generar con `kubectl -n kubernetes-dashboard create token admin-user` desde `k8-master` |
| NGINX de prueba | `http://192.168.90.1:30885` (o cualquier nodo) | — | — | NodePort de prueba de la guia principal |
| SSH `k8-master` | `ssh uceda@192.168.90.1` | `uceda` | Llave `~/.ssh/id_ed25519` | Nodo donde se ejecuta `kubectl` |
| SSH `k8-worker1/2/3` | `ssh uceda@192.168.90.2` / `.3` / `.4` | `uceda` | Llave `~/.ssh/id_ed25519` | Workers del cluster |
| Ceph (Rook toolbox) | `http://192.168.90.1:32174/` | `admin` | `13tAxYZaHbq0ujaxTkmU` | Habilitado con la seccion 18.1 mediante Service propio `rook-ceph-mgr-dashboard-external` (NodePort fijo 32174); password cambiado a solo letras/numeros en la seccion 18.2; tambien disponible por CLI con `kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s` |
| MariaDB / Redis | Sin exposicion externa | — | Ver seccion 3.2 | Solo accesibles dentro del Pod `wordpress` (`127.0.0.1:3306` / `127.0.0.1:6379`) |

> Todas las contrasenas de esta tabla son de laboratorio (ver seccion 3.2). No las reutilices en entornos reales.

---

# 20. Inventario de archivos de configuracion criticos

Lista de los archivos/recursos mas criticos de todo lo levantado en esta
guia, verificados directamente sobre el laboratorio el 2026-08-26.

> **Hallazgo importante:** los manifiestos YAML aplicados con `kubectl
> apply -f /tmp/*.yaml` a lo largo de esta guia (CephCluster,
> CephFilesystem, StorageClass, PVCs y Deployment de WordPress, pool de
> MetalLB) **ya no existen** en `/tmp` de `k8-master` (se limpian solos,
> es normal en Linux). Hoy la unica fuente de verdad de esos recursos es
> `etcd` (el cluster vivo) y el texto de esta misma guia. Si `k8-master`
> se corrompiera sin haber hecho un backup real de `etcd`, la unica forma
> de reconstruir esos recursos seria copiar el YAML desde las secciones
> 6, 7, 9-13 y 18 de este documento.

## 20.1. Host (anfitrion) — libvirt/KVM

| Archivo | Ruta | Que es | Por que es critico |
|---|---|---|---|
| Red virtual `k8s-lab` | `kubernetes/net/k8s-lab-network.xml` | XML de definicion de red libvirt (`virsh net-define`): bridge, rango DHCP y modo NAT/aislado de la subred del laboratorio | Define la subred `192.168.90.0/24`; si se pierde, las VMs pierden DHCP/bridge |
| cloud-init de cada VM | `kubernetes/cloud-init/` (`k8-master/worker1/2/3-user-data`, `-meta-data`, `-seed.iso`) | `user-data`/`meta-data` en formato cloud-init (YAML): usuario inicial, llave SSH publica, hostname; `-seed.iso` es la imagen ISO ya empaquetada que se monta como CD-ROM en la VM al primer arranque | Usuario `uceda`, SSH keys, hostname; necesarios para recrear una VM desde cero |
| Discos qcow2 | `/var/lib/libvirt/images/k8s-lab/*.qcow2` (incluye `*-ceph-osd.qcow2` de la seccion 6.1) | Imagenes de disco virtual formato QEMU COW2: el disco raiz de cada VM (SO + todo lo instalado) y el disco crudo `vdb` dedicado a cada OSD de Ceph | Estado completo de cada VM y de los OSDs de Ceph |

## 20.2. `k8-master` — control plane Kubernetes

| Archivo | Ruta | Que es | Por que es critico |
|---|---|---|---|
| kubeconfig admin | `/home/uceda/.kube/config` (copia de `/etc/kubernetes/admin.conf`) | YAML con la URL del API server, la CA del cluster y el certificado/llave del usuario `kubernetes-admin`; es lo que usa `kubectl` para autenticarse | Sin esto no hay `kubectl`; usado en cada comando de la guia |
| Certificados/config kubeadm | `/etc/kubernetes/` (`admin.conf`, `pki/`) | Carpeta con la Autoridad Certificadora (CA) del cluster y todos los certificados/llaves TLS generados por `kubeadm init` (API server, etcd, kubelet, front-proxy) | Identidad del cluster (CA, certs de API server/etcd) |
| containerd | `/etc/containerd/config.toml` | Archivo TOML de configuracion del runtime de contenedores: registries, `sandbox_image`, plugins CRI | Runtime de contenedores de los 4 nodos |
| kubelet | `/var/lib/kubelet/config.yaml` | YAML generado por kubeadm con los parametros del kubelet de ese nodo (cgroup driver, puertos, autenticacion al API server) | Config del kubelet por nodo |
| Datos de etcd | `/var/lib/etcd/` (en `k8-master`) | Base de datos clave-valor (BoltDB) donde Kubernetes guarda literalmente todos sus objetos (Pods, Secrets, ConfigMaps, CRDs como `CephCluster`, etc.) | **El mas critico de todos**: todo el estado del cluster (todos los objetos, Secrets, CephCluster, Deployments) vive aqui. Si se pierde sin backup, se pierde el cluster completo |

## 20.3. Rook-Ceph

| Recurso | Ubicacion | Que es | Por que es critico |
|---|---|---|---|
| `CephCluster` CR | Solo en etcd (namespace `rook-ceph`) — YAML fuente en `tmp/03-rook-cluster.yaml` y seccion 6.4 | Custom Resource de Rook que declara cuantos mon/mgr quiere el cluster, que imagen de Ceph usar y en que discos (`vdb`) crear los OSD; el operador de Rook lo lee y crea/mantiene todo lo demas | Define mons/mgr/OSDs; sin backup del YAML, hay que reconstruirlo a mano |
| Datos de monitores Ceph | `/var/lib/rook` en cada nodo mon (`dataDirHostPath`) | Directorio en disco de cada nodo con el `monmap`, el keyring del cluster y el estado interno del monitor Ceph de ese nodo | Mapa de OSDs, quorum; perder los 3 a la vez = perder el cluster Ceph |
| `CephFilesystem`/`StorageClass` | Solo en etcd — YAML fuente en `tmp/04-rook-filesystem.yaml`, `tmp/05-cephfs-storageclass.yaml` y seccion 7 | El primero declara el filesystem CephFS `myfs` (pools de datos/metadatos, MDS); el segundo es el objeto Kubernetes que le dice al CSI de Rook como aprovisionar PVCs sobre ese filesystem | Necesarios para que los PVC sigan aprovisionando |
| Secrets CSI (`rook-csi-cephfs-provisioner/node`) | Namespace `rook-ceph`, autogenerados por Rook | `Secret` de Kubernetes con las llaves CephX (`aes`, 28 bytes) que usa el driver CSI para autenticarse contra el cluster Ceph al crear/montar volumenes | Credenciales que usa el CSI para montar CephFS |

## 20.4. WordPress

| Archivo | Ubicacion | Que es | Por que es critico |
|---|---|---|---|
| `wp-config.php` | Dentro del Pod (`/var/www/html/wp-config.php`), generado por variables de entorno del Deployment | Archivo PHP estandar de WordPress con los datos de conexion a la BD (host/usuario/password), las `AUTH_KEY`/`SALT` y el prefijo de tablas; en esta imagen Docker se genera solo, leyendo las variables `WORDPRESS_DB_*`/`WORDPRESS_CONFIG_EXTRA` del Deployment | Conexion a BD, claves; si cambia el Secret sin actualizar esto, WordPress deja de arrancar |
| `Secret wordpress-secrets` | Namespace `wordpress` (YAML fuente en `tmp/02-wordpress-secrets.yaml`, no versionado, ver seccion 21) | `Secret` de Kubernetes tipo `Opaque` con 3 claves: `mariadb-root-password`, `mariadb-password`, `wordpress-admin-password` | Passwords de MariaDB root/wordpress y el sugerido de WP admin |
| Datos en PVCs CephFS | `wordpress-content`, `wordpress-db`, `wordpress-redis` | Volumenes CephFS montados en `/var/www/html` (plugins/temas/uploads), `/var/lib/mysql` (datos de MariaDB) y `/data` (AOF de Redis) respectivamente | Todo el contenido real del sitio, la base de datos y el cache persistente |

## 20.5. Este mismo repositorio

| Archivo | Que es | Por que es critico |
|---|---|---|
| Este documento (`kubernetes/guia_continuacion_wordpress_cephfs_lab.md`) | Runbook Markdown con explicacion, comandos y el YAML completo de cada paso ejecutado en el laboratorio | Unica copia versionada de **todos** los manifiestos YAML aplicados (Rook, StorageClass, WordPress, MetalLB) — es el respaldo de facto mientras no se exporte el estado vivo del cluster a archivos separados |

---

# 21. Respaldo de los manifiestos YAML en `tmp/`

Los YAML de las secciones 6 a 18 se escribieron originalmente en `/tmp`
de `k8-master` y se perdieron de ahi (comportamiento normal de Linux,
ver seccion 20). Se recrearon con contenido identico y quedaron
versionados en este repositorio, en la carpeta `tmp/` (raiz del
repositorio, junto a `ansible/`, `kubernetes/`, etc.), para poder
reaplicarlos sin tener que copiarlos a mano desde esta guia.

Para reaplicar cualquiera de estos archivos desde `k8-master`:

```bash
export KUBECONFIG="/home/uceda/.kube/config"
kubectl apply -f <archivo>.yaml
```

| Archivo | Seccion de esta guia | Que es |
|---|---|---|
| `tmp/01-wordpress-namespace.yaml` | 9 | `Namespace wordpress` |
| `tmp/02-wordpress-secrets.yaml` | 9 | `Secret wordpress-secrets` (passwords de MariaDB/WordPress). **No versionado en git** (bloqueado por `.gitignore: **/*secret*`); solo existe en disco local |
| `tmp/03-rook-cluster.yaml` | 6.4 | `CephCluster` (3 mon, 1 mgr, 3 OSD sobre el disco `vdb` de cada worker) |
| `tmp/04-rook-filesystem.yaml` | 7.1 | `CephFilesystem myfs` + `CephFilesystemSubVolumeGroup csi` |
| `tmp/05-cephfs-storageclass.yaml` | 7.2 | `StorageClass cephfs-storage` (provisioner CSI de Rook) |
| `tmp/06-wordpress-pvcs.yaml` | 10 | PVCs `wordpress-content` (5Gi RWX), `wordpress-db` (5Gi RWO), `wordpress-redis` (1Gi RWO) |
| `tmp/07-wordpress-cephfs.yaml` | 11 | `Deployment wordpress` (contenedores `wordpress`/`mariadb`/`redis`) + `Service wordpress` (ClusterIP) |
| `tmp/08-metallb-k8s-lab-pool.yaml` | 12.2 | `IPAddressPool k8s-lab-pool` + `L2Advertisement k8s-lab-advertisement` (IP `192.168.90.50`) |
| `tmp/09-wordpress-lb-http.yaml` | 13 | `Service wordpress-lb` tipo `LoadBalancer`, IP fija `192.168.90.50` |
| `tmp/10-rook-ceph-mgr-dashboard-external.yaml` | 18.1 | `Service` `NodePort` propio del dashboard de Ceph (puerto `32174`), **no gestionado por Rook** (ver advertencia de la seccion 18.1 sobre por que no usar `kubectl patch svc` directo) |
| `tmp/test-cephfs-pvc.yaml` | 8.1 | PVC de prueba `cephfs-test` — solo para validar el CSI, no es parte del despliegue final |
| `tmp/test-cephfs-pod.yaml` | 8.2 | Pod de prueba `cephfs-test-pod` — solo para validar el CSI, no es parte del despliegue final |

> Estos archivos reflejan el estado en el que se aplicaron durante esta
> guia. Si mas adelante se modifica algo directamente con `kubectl edit`
> o `kubectl patch` sin actualizar el archivo correspondiente, el YAML de
> `tmp/` queda desactualizado respecto al cluster real.

---

# 22. Los 20 comandos mas criticos de este entorno

Tabla de referencia rapida con los comandos de diagnostico y
configuracion mas usados en este laboratorio, con el nodo donde se
ejecutan y para que sirven. Todos son de solo lectura o de mantenimiento
puntual (ninguno borra datos por si solo).

| # | Nodo / Servicio | Comando | Para que sirve |
|---:|---|---|---|
| 1 | `anfitrion` | `virsh list --all` | Ver que VMs estan `running`/`shut off` |
| 2 | `anfitrion` | `virsh net-dhcp-leases k8s-lab` | Ver las IPs asignadas a cada VM en la red del laboratorio |
| 3 | `anfitrion` | `ssh uceda@192.168.90.1` | Conectarse a `k8-master` para ejecutar `kubectl` (el anfitrion no tiene kubeconfig propio) |
| 4 | `k8-master` | `export KUBECONFIG="/home/uceda/.kube/config"` | Requisito previo a cualquier comando `kubectl` en este laboratorio |
| 5 | `k8-master` | `kubectl get nodes -o wide` | Confirmar que los 4 nodos (`k8-master`/`worker1/2/3`) estan `Ready` |
| 6 | `k8-master` | `kubectl get pods -A` | Ver el estado de todos los Pods del cluster, detectar `CrashLoopBackOff`/`Pending` |
| 7 | `k8-master` | `kubectl -n wordpress get pod -l app=wordpress -o wide` | Ver si WordPress esta `Running` y en que nodo (`NODE`) esta programado |
| 8 | `k8-master` | `kubectl -n wordpress logs deploy/wordpress -c wordpress --tail=100` | Ver logs del contenedor WordPress si algo falla |
| 9 | `k8-master` | `kubectl -n wordpress logs deploy/wordpress -c mariadb --tail=100` | Ver logs de MariaDB dentro del mismo Pod |
| 10 | `k8-master` | `kubectl -n wordpress exec deploy/wordpress -c redis -- redis-cli FLUSHALL` | Vaciar cache de Redis (necesario tras cambiar algo directo en la BD, ej. un password) |
| 11 | `k8-master` | `kubectl -n wordpress rollout restart deployment/wordpress` | Reiniciar el Pod de WordPress de forma controlada (recreacion, no borra datos) |
| 12 | `k8-master` | `kubectl -n wordpress get pvc` | Confirmar que los 3 PVC (`content`/`db`/`redis`) siguen `Bound` |
| 13 | `k8-master` | `kubectl -n wordpress get svc wordpress-lb -o wide` | Ver la IP asignada por MetalLB y el puerto expuesto |
| 14 | `anfitrion` | `curl -kI https://192.168.90.50/` | Probar que WordPress responde desde fuera del cluster |
| 15 | `k8-master` | `kubectl -n rook-ceph get cephcluster` | Ver la fase del cluster Ceph (`Ready`/`Progressing`) |
| 16 | `k8-master` | `kubectl -n rook-ceph get pods -o wide` | Ver estado de mon/mgr/osd/mds/CSI de Ceph y en que worker corre cada uno |
| 17 | `k8-master` | `kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s` | Salud general de Ceph (`HEALTH_OK`/`WARN`, quorum de mons, OSDs up/in) |
| 18 | `k8-master` | `kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree` | Confirmar que los 3 OSD (`vdb` de cada worker) estan `up`/`in` |
| 19 | `k8-master` | `kubectl -n metallb-system get ipaddresspool,l2advertisement` | Confirmar que el pool `k8s-lab-pool` (IP `192.168.90.50`) sigue configurado |
| 20 | `k8-master` | `kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph dashboard ac-user-set-password admin -i <archivo>` | Resetear el password del dashboard de Ceph si se pierden las credenciales (ver seccion 18.2) |

> Ninguno de estos comandos modifica el entorno por si solo, salvo el
> `rollout restart` (#11, recrea el Pod sin perder datos de los PVC) y el
> `ac-user-set-password` (#20, solo cambia un password si se ejecuta a
> proposito). El resto son de solo lectura/diagnostico.

## 22.1. Extra: ver, levantar y reiniciar Pods

Comandos puntuales de ciclo de vida de Pods, complementarios a la tabla
anterior. `<ns>` es el namespace (`wordpress`, `rook-ceph`, etc.) y
`<pod>`/`<deploy>` el nombre real obtenido con el comando de "Ver".

| Accion | Nodo | Comando | Nota |
|---|---|---|---|
| Ver Pods de un namespace | `k8-master` | `kubectl -n <ns> get pods -o wide` | Columna `NODE` indica donde corre cada uno; `READY`/`STATUS` indican salud |
| Ver detalle de un Pod (eventos, motivo de fallo) | `k8-master` | `kubectl -n <ns> describe pod <pod>` | Util cuando un Pod queda en `Pending`/`CrashLoopBackOff` |
| Levantar un Deployment si quedo en 0 replicas | `k8-master` | `kubectl -n <ns> scale deployment/<deploy> --replicas=1` | Ej. `kubectl -n wordpress scale deployment/wordpress --replicas=1` |
| Levantar/recrear desde el respaldo en git si el recurso ya no existe | `k8-master` | `kubectl apply -f tmp/<archivo>.yaml` | Usar el archivo correspondiente de la seccion 21 (ej. `tmp/07-wordpress-cephfs.yaml`) |
| Reiniciar un Deployment completo (sin perder datos de PVC) | `k8-master` | `kubectl -n <ns> rollout restart deployment/<deploy>` | Ej. `kubectl -n wordpress rollout restart deployment/wordpress` (igual al comando #11) |
| Reiniciar solo un Pod puntual | `k8-master` | `kubectl -n <ns> delete pod <pod>` | El controlador (Deployment) lo vuelve a crear automaticamente; no borra PVC ni datos |
| Ver el progreso de un reinicio/despliegue | `k8-master` | `kubectl -n <ns> rollout status deployment/<deploy> --timeout=300s` | Se queda esperando hasta que el nuevo Pod este `Ready` |

---

# 23. [Implementado 2026-08-27] Capacidad de repuesto N+1: `k8-worker4`

> **Estado: EJECUTADO Y VERIFICADO.** `k8-worker4` (`192.168.90.5`) fue
> creado, unido al cluster y agregado al `CephCluster`. Verificacion en
> vivo (2026-08-29):
> - `kubectl get nodes` -> 5 nodos, todos `Ready` (`k8-master` +
>   `k8-worker1/2/3/4`).
> - `ceph -s` -> `osd: 4 osds: 4 up, 4 in` (antes 3).
> - `ceph osd tree` -> 4 hosts, uno por worker, todos `up`.
> - `CephCluster.spec.storage.nodes` -> incluye `k8-worker1/2/3/4`.
> - `mon.count` se dejo en `3` a proposito: `k8-worker4` queda como
>   candidato libre de fail-over automatico de mon si se pierde uno de
>   los 3 monitores actuales.
> - Efecto colateral esperado (no es un problema): cada componente tipo
>   `DaemonSet` (`calico-node`, `csi-node-driver`, `kube-proxy`,
>   `metallb-speaker`, exporters/nodeplugins de Rook) sumo +1 Pod al
>   detectar el nuevo nodo (~10 Pods mas en el cluster en total).
> - Prueba de fail-over real (seccion 23.7, apagar un worker existente)
>   **no se ha ejecutado todavia** — sigue pendiente si se quiere validar
>   punta a punta.
>
> El resto de esta seccion documenta, en detalle y con la lista de
> comandos, exactamente como se hizo, para poder repetirlo o auditarlo.
> Esta guia agrega un 4o worker de repuesto para que el cluster tolere
> la perdida permanente de un worker sin quedar en `HEALTH_WARN`
> indefinido. Ver la discusion previa: antes de esto, solo
> `wordpress`/`mgr`/`mds` se reprogramaban solos; los `mon` no tenian a
> donde migrar (los 3 workers ya tenian 1 cada uno) y los `osd` no
> podian moverse (estan atados al disco fisico de su worker). El 4o
> worker con su propio disco resuelve ambos casos.

## 23.0. Decisiones de diseno

| Parametro | Valor elegido | Motivo |
|---|---:|---|
| Nombre | `k8-worker4` | Sigue el patron `k8-worker1/2/3` |
| IP | `192.168.90.5` | Siguiente libre en la subred `192.168.90.0/24` del lab |
| MAC | `52:54:00:90:00:05` | Siguiente libre en la secuencia usada por `create-k8s-lab-vms.sh` (`...:01` a `...:04`) |
| RAM / vCPU | `5120` MB / `2` | Igual a `k8-worker1/2/3` (`create-k8s-lab-vms.sh`) |
| Disco raiz | `40G`, overlay qcow2 sobre la misma imagen base | Igual a los otros workers (seccion 0.1.4 de la guia principal) |
| Disco OSD (`vdb`) | `20G`, qcow2 crudo | Igual a la seccion 6.1 de esta guia |
| Rol en Kubernetes | Worker normal (`kubeadm join`), sin taints especiales | Debe poder recibir Pods normales (WordPress, mgr) y el nuevo OSD |
| Rol en Ceph | Solo aporta un disco extra a `CephCluster.spec.storage.nodes`; no se le agrega `mon` a proposito | Con 4 nodos y `mon.count: 3`, Rook deja 1 worker libre como candidato natural de fail-over de mon |

## 23.1. Fase 1 — Crear la VM `k8-worker4` (anfitrion)

Mismo patron que el resto de VMs del lab (imagen base + overlay qcow2 +
cloud-init + `virt-install`), documentado en la guia principal secciones
0.1.4, 0.1.6 y 0.1.7.1.

```bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
VM_DIR="/var/lib/libvirt/images/k8s-lab"
CLOUD_INIT_DIR="/home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init"
BASE_IMG="${VM_DIR}/noble-server-cloudimg-amd64.img"

# 1. Crear el disco raiz de k8-worker4 (40G, igual a los otros workers)
BASE_FMT="$(sudo qemu-img info "$BASE_IMG" | awk -F': ' '/file format/ {print $2; exit}')"
sudo qemu-img create -f qcow2 -F "$BASE_FMT" -b "$BASE_IMG" "${VM_DIR}/k8-worker4.qcow2" 40G

# 2. Cloud-init: user-data (mismo patron que k8-worker1/2/3, mismo usuario/llave SSH)
cat <<'EOF' > "${CLOUD_INIT_DIR}/k8-worker4-user-data"
#cloud-config
hostname: k8-worker4
manage_etc_hosts: true

users:
  - default
  - name: uceda
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkgKn+STK1A8yTy62VfS5af/5D6q6HaZr6dVPyGA5qb uceda@uceda-ThinkPad-L15-Gen-2a

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

# 3. Cloud-init: meta-data
cat <<'EOF' > "${CLOUD_INIT_DIR}/k8-worker4-meta-data"
instance-id: k8-worker4
local-hostname: k8-worker4
EOF

# 4. Generar la ISO seed de cloud-init
cloud-localds \
  "${CLOUD_INIT_DIR}/k8-worker4-seed.iso" \
  "${CLOUD_INIT_DIR}/k8-worker4-user-data" \
  "${CLOUD_INIT_DIR}/k8-worker4-meta-data"

# 5. Crear la VM (mismo patron que create-k8s-lab-vms.sh)
sudo virt-install \
  --name k8-worker4 \
  --memory 5120 \
  --vcpus 2 \
  --cpu host-passthrough \
  --import \
  --disk path="${VM_DIR}/k8-worker4.qcow2",format=qcow2,bus=virtio \
  --disk path="${VM_DIR}/k8-worker4-seed.iso",device=cdrom \
  --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:05 \
  --os-variant ubuntu24.04 \
  --graphics none \
  --noautoconsole

# 6. Verificar que arranco y tomo IP por DHCP
sleep 60
virsh domifaddr k8-worker4 || true
virsh net-dhcp-leases k8s-lab | grep k8-worker4 || true
```

Punto de control: `virsh net-dhcp-leases k8s-lab` debe mostrar
`k8-worker4` con IP `192.168.90.5`. Confirmar SSH:

```bash
# NODO: anfitrion
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 uceda@192.168.90.5 'hostname; cloud-init status'
```

## 23.2. Fase 2 — Preparar el sistema operativo de `k8-worker4`

Mismos pasos que la guia principal secciones 4, 5, 6 y 7 (deshabilitar
swap, modulos de kernel/sysctl, containerd, kubeadm/kubelet/kubectl),
aplicados solo a este nodo nuevo. Ejecutar desde `k8-master` (ya tiene
acceso SSH sin password a todos los workers):

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
set -euo pipefail
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
W4=192.168.90.5

# 4. Deshabilitar swap (en caliente y permanente)
ssh "${SSH_OPTS[@]}" uceda@$W4 'sudo swapoff -a && swapon --show; free -h'
ssh "${SSH_OPTS[@]}" uceda@$W4 "sudo cp /etc/fstab /etc/fstab.bak && sudo sed -ri '/^([^#].*\\sswap\\s.*)\$/s/^/#/' /etc/fstab"

# 5. Modulos de kernel y sysctl
ssh "${SSH_OPTS[@]}" uceda@$W4 'cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
lsmod | grep -E "overlay|br_netfilter"'

ssh "${SSH_OPTS[@]}" uceda@$W4 "printf '%s\n' 'net.bridge.bridge-nf-call-iptables  = 1' 'net.bridge.bridge-nf-call-ip6tables = 1' 'net.ipv4.ip_forward                 = 1' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null && sudo sysctl --system"

# 6. containerd
ssh "${SSH_OPTS[@]}" uceda@$W4 'sudo apt-get update && sudo apt-get install -y containerd'
ssh "${SSH_OPTS[@]}" uceda@$W4 'sudo mkdir -p /etc/containerd && containerd config default | sudo tee /etc/containerd/config.toml > /dev/null'
ssh "${SSH_OPTS[@]}" uceda@$W4 "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml && grep -n SystemdCgroup /etc/containerd/config.toml"
ssh "${SSH_OPTS[@]}" uceda@$W4 'sudo systemctl restart containerd && sudo systemctl enable containerd && sudo systemctl status containerd --no-pager'

# 7. kubeadm/kubelet/kubectl (misma version v1.36 que el resto del cluster)
ssh "${SSH_OPTS[@]}" uceda@$W4 '
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
  sudo systemctl enable kubelet
  kubeadm version -o short
'
```

Punto de control: el ultimo comando debe imprimir una version `v1.36.x`,
igual a la de `k8-master` (`kubeadm version -o short` en el master).

## 23.3. Fase 3 — Unir `k8-worker4` al cluster (`kubeadm join`)

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

# Genera un token de join nuevo (los anteriores ya expiraron)
JOIN_COMMAND="$(kubeadm token create --print-join-command)"
echo "$JOIN_COMMAND"

# Ejecuta ese join en k8-worker4
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 uceda@192.168.90.5 "sudo $JOIN_COMMAND"

# Verificar que aparece en el cluster
kubectl get nodes -o wide
```

Punto de control: `k8-worker4` debe aparecer en `kubectl get nodes`,
inicialmente `NotReady` (falta el CNI) y pasar a `Ready` en 1-2 minutos
en cuanto Calico despliegue su Pod ahi (`kubectl -n calico-system get
pods -o wide | grep k8-worker4`).

## 23.4. Fase 4 — Agregar el disco OSD (`vdb`) y el modulo `ceph`

Identico a las secciones 6.1 y 6.2 de esta misma guia, aplicado solo a
`k8-worker4`:

```bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
VM_DIR="/var/lib/libvirt/images/k8s-lab"

sudo qemu-img create -f qcow2 "${VM_DIR}/k8-worker4-ceph-osd.qcow2" 20G
sudo virsh attach-disk k8-worker4 \
  --source "${VM_DIR}/k8-worker4-ceph-osd.qcow2" \
  --target vdb --subdriver qcow2 --targetbus virtio \
  --live --config --persistent

sudo virsh domblklist k8-worker4

ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 uceda@192.168.90.5 \
  'hostname; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/vdb'
```

Punto de control: `FSTYPE` vacio para `vdb` (disco crudo, sin
particiones), igual que se valido para los otros 3 workers en 6.1.

```bash
# NODO: anfitrion
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 uceda@192.168.90.5 '
  sudo modprobe ceph
  echo "ceph" | sudo tee /etc/modules-load.d/ceph.conf
  lsmod | grep -q "^ceph " && echo "OK: modulo ceph cargado" || echo "ERROR: modulo ceph no cargado"
'
```

## 23.5. Fase 5 — Agregar `k8-worker4` al `CephCluster` de Rook

Se edita el mismo YAML de la seccion 6.4 / `tmp/03-rook-cluster.yaml`,
agregando una 4a entrada a `storage.nodes`. **No se toca `mon.count`**
(se deja en `3`): con 4 nodos y 3 mons, Rook ya tiene un candidato de
sobra para el fail-over automatico de mon si se pierde uno de los 3
actuales.

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

kubectl -n rook-ceph patch cephcluster rook-ceph --type merge -p '
{
  "spec": {
    "storage": {
      "nodes": [
        {"name": "k8-worker1", "devices": [{"name": "vdb"}]},
        {"name": "k8-worker2", "devices": [{"name": "vdb"}]},
        {"name": "k8-worker3", "devices": [{"name": "vdb"}]},
        {"name": "k8-worker4", "devices": [{"name": "vdb"}]}
      ]
    }
  }
}'

kubectl -n rook-ceph get cephcluster
kubectl -n rook-ceph get pods -o wide -w
```

Presiona `Ctrl+C` cuando aparezca un nuevo `rook-ceph-osd-3-...` en
`Running` sobre `k8-worker4` (más un `rook-ceph-osd-prepare-k8-worker4-*`
en `Completed`).

También actualizar el respaldo versionado en git para que quede
consistente (ver sección 21):

```bash
# NODO: anfitrion o k8-master (segun donde este el checkout del repo)
# RUTA: /home/uceda/Documents/InstalacionOpenstack/openstack-ansible
# Editar tmp/03-rook-cluster.yaml agregando el bloque de k8-worker4 a storage.nodes,
# igual al que se aplico arriba con kubectl patch, para que el archivo en git
# refleje el estado real del CephCluster.
```

## 23.6. Fase 6 — Verificar la capacidad de repuesto

```bash
# NODO: k8-master
# RUTA: cualquiera (no depende del directorio de trabajo; usa rutas absolutas o ninguna ruta de archivo)
export KUBECONFIG="/home/uceda/.kube/config"

echo "== Nodos =="
kubectl get nodes -o wide

echo "== Salud de Ceph =="
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s

echo "== Arbol de OSD (deben ser 4, uno por worker) =="
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree

echo "== Pods de rook-ceph por nodo =="
kubectl -n rook-ceph get pods -o wide
```

Punto de control esperado:

| Verificacion | Esperado |
|---|---|
| `kubectl get nodes` | `k8-master`, `k8-worker1/2/3/4` en `Ready` |
| `ceph -s` → `osd` | `4 osds: 4 up, 4 in` |
| `ceph osd tree` | 4 hojas, una por worker, todas `up` |
| Ningun `mon`/`mgr` corriendo en `k8-worker4` (todavia) | Correcto: Rook solo lo usara como destino de fail-over si se pierde otro worker |

## 23.7. Fase 7 (opcional) — Simular la perdida de un worker y confirmar la recuperacion automatica

Solo para validar que el N+1 realmente funciona, **no forma parte del
despliegue normal**:

```bash
# NODO: anfitrion
# Apagar (no destruir) uno de los workers ORIGINALES, ej. k8-worker2
sudo virsh shutdown k8-worker2

# Esperar varios minutos (node-monitor-grace-period + tolerationSeconds +
# mon_osd_down_out_interval de Ceph) y luego revisar desde k8-master:
#   kubectl get nodes
#   kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
#   kubectl -n rook-ceph get pods -o wide
# Esperado: un nuevo osd se crea en k8-worker4 y Ceph re-replica los datos
# perdidos de k8-worker2 automaticamente, sin intervencion manual.

# Para revertir la simulacion:
sudo virsh start k8-worker2
```

> **No ejecutar esta fase sin avisar primero**: apaga intencionalmente
> un worker en uso (`k8-worker2` aloja hoy `mon-b`/`osd-1`); aunque el
> resto del cluster deberia tolerarlo, es una prueba disruptiva.
