# Guía 3: Arquitectura de la infraestructura montada — presentación, diagramas UML y demostración

> **Propósito:** esta guía es la **presentación ejecutiva del laboratorio
> ya desplegado**. No instala nada nuevo; documenta **cómo se compone** la
> infraestructura, los servicios, los Pods y el almacenamiento, e incluye
> los **comandos de demostración** para recorrerla pieza por pieza desde el
> navegador o la terminal.
>
> **Estado real del laboratorio** (verificado el 2026-08-28):
> Kubernetes `v1.36.4` sobre **1 control-plane + 3 workers** (4 VMs KVM),
> red privada `k8s-lab` `192.168.90.0/24`, CNI **Calico**, LoadBalancer
> **MetalLB**, almacenamiento **Rook-Ceph (`CephFS`)**, y la aplicación
> **WordPress + MariaDB + Redis** en un solo Pod con tres volúmenes
> persistentes `CephFS`.
>
> El plan de **capacidad de repuesto N+1** (agregar `k8-worker4`) está
> documentado pero **aún no ejecutado**; se describe al final como
> proyección de crecimiento.

---

## Índice

- [Guía 3: Arquitectura de la infraestructura montada — presentación, diagramas UML y demostración](#guía-3-arquitectura-de-la-infraestructura-montada--presentación-diagramas-uml-y-demostración)
  - [Índice](#índice)
- [1. Resumen ejecutivo](#1-resumen-ejecutivo)
- [2. Vista de alto nivel](#2-vista-de-alto-nivel)
- [3. Inventario de IPs, credenciales y accesos](#3-inventario-de-ips-credenciales-y-accesos)
  - [3.1. IPs](#31-ips)
  - [3.2. Accesos web desde el anfitrión](#32-accesos-web-desde-el-anfitrión)
  - [3.3. Accesos SSH](#33-accesos-ssh)
- [4. Arquitectura capa a capa](#4-arquitectura-capa-a-capa)
  - [4.1. Capa de virtualización (anfitrión)](#41-capa-de-virtualización-anfitrión)
  - [4.2. Capa de orquestación (Kubernetes)](#42-capa-de-orquestación-kubernetes)
  - [4.3. Capa de red de servicios (MetalLB)](#43-capa-de-red-de-servicios-metallb)
  - [4.4. Capa de almacenamiento (Rook-Ceph)](#44-capa-de-almacenamiento-rook-ceph)
  - [4.5. Capa de aplicación (WordPress)](#45-capa-de-aplicación-wordpress)
  - [4.6. Capa de exposición](#46-capa-de-exposición)
- [5. Diagramas UML](#5-diagramas-uml)
- [6. Demo 1 — Infraestructura y nodos](#6-demo-1--infraestructura-y-nodos)
  - [6.1. VMs y red desde el anfitrión](#61-vms-y-red-desde-el-anfitrión)
  - [6.2. Nodos del clúster](#62-nodos-del-clúster)
  - [6.3. Namespaces](#63-namespaces)
- [7. Demo 2 — Services, Endpoints y LoadBalancer](#7-demo-2--services-endpoints-y-loadbalancer)
- [8. Demo 3 — Pods y contenedores](#8-demo-3--pods-y-contenedores)
  - [8.1. Ver el Pod de WordPress y sus 3 contenedores](#81-ver-el-pod-de-wordpress-y-sus-3-contenedores)
  - [8.2. Conectarse a cada contenedor](#82-conectarse-a-cada-contenedor)
  - [8.3. Probar cada contenedor](#83-probar-cada-contenedor)
  - [8.4. Pods del sistema (namespaces de infraestructura)](#84-pods-del-sistema-namespaces-de-infraestructura)
- [9. Demo 4 — Almacenamiento CephFS](#9-demo-4--almacenamiento-cephfs)
  - [9.1. Confirmar que los datos están montados en el Pod](#91-confirmar-que-los-datos-están-montados-en-el-pod)
  - [9.2. Prueba de persistencia (rápida)](#92-prueba-de-persistencia-rápida)
- [10. Demo 5 — Estado de Ceph y Rook](#10-demo-5--estado-de-ceph-y-rook)
- [11. Demo 6 — Verificación web de punta a punta](#11-demo-6--verificación-web-de-punta-a-punta)
- [12. Comandos rápidos de una línea](#12-comandos-rápidos-de-una-línea)
- [13. Proyección: capacidad de repuesto N+1](#13-proyección-capacidad-de-repuesto-n1)
  - [Nota final](#nota-final)

---

# 1. Resumen ejecutivo

El laboratorio despliega una **aplicación web WordPress con estado**
(WordPress + MariaDB + Redis conviviendo en un mismo Pod) sobre un
**clúster Kubernetes auto-gestionado en VMs KVM**, con **almacenamiento
persistente distribuido (CephFS)** y **exposición mediante IP flotante
(MetalLB)**, todo dentro de una red privada de laboratorio.

| Dimensión | Tecnología / valor | Descripción |
|---|---|---|
| Virtualización | KVM + libvirt (`virbr90`, red NAT `k8s-lab`) | Hipervisor KVM gestionado con `libvirt`; las 4 VMs comparten la red NAT `k8s-lab` a través del puente `virbr90` del anfitrión. |
| Sistema operativo | Ubuntu Server `24.04.4 LTS` en cada VM | Cada nodo corre el mismo SO para tener un entorno homogéneo y reproducible en todo el clúster. |
| Orquestador | Kubernetes `v1.36.4` (`kubeadm`, `containerd`) | Plataforma que orquesta los contenedores; `kubeadm` inicializó el clúster y `containerd` es el motor de contenedores. |
| Topología | 1 control-plane (`k8-master`) + 3 workers (`k8-worker1/2/3`) | Un nodo maestro con el plano de control y tres nodos de cómputo donde corren las cargas de trabajo y los componentes de Ceph. |
| Red de Pods | Calico `v3.32.1` (VXLAN, `172.16.0.0/16`) | CNI que da direccionamiento y conectividad a los Pods mediante VXLAN en la red `172.16.0.0/16`. |
| LoadBalancer | MetalLB `v0.16.1` (VIP `192.168.90.50`, L2) | Expone los servicios tipo `LoadBalancer` dentro de la red del laboratorio usando la IP virtual `192.168.90.50` en modo L2. |
| Almacenamiento | Rook `v1.20.6` → Ceph `v20.2.4` → `CephFS myfs` → `StorageClass cephfs-storage` | Almacenamiento distribuido y persistente: Rook despliega Ceph, que provee el sistema de archivos `myfs` expuesto como `StorageClass` a Kubernetes. |
| Aplicación | `Deployment wordpress` con 3 contenedores (`wordpress`, `mariadb`, `redis`) | La aplicación WordPress convive con su base de datos MariaDB y su caché Redis en un único Pod. |
| Volúmenes | 3 PVC `CephFS`: `wordpress-content` (5Gi RWX), `wordpress-db` (5Gi RWO), `wordpress-redis` (1Gi RWO) | Tres volúmenes persistentes sobre CephFS para el contenido web, la base de datos y la caché, garantizando la persistencia de los datos. |
| Interfaces | WordPress `https://192.168.90.50/`, Dashboard `https://192.168.90.1:32000`, Ceph `http://192.168.90.1:32174/`, NGINX `http://192.168.90.1:30885` | URLs de acceso a la aplicación y a los paneles de administración desde el anfitrión. |

### Tabla de definiciones

Términos técnicos clave del laboratorio:

| Término | Definición |
|---|---|
| **KVM** | Hypervisor de máquinas virtuales del kernel Linux; virtualiza las 4 VMs del clúster sobre el anfitrión. |
| **libvirt** | Herramienta que gestiona KVM: define VMs, discos y redes virtuales (aquí, la red `k8s-lab` y el bridge `virbr90`). |
| **Pod** | Unidad mínima de despliegue en Kubernetes; aquí un solo Pod aloja los 3 contenedores (`wordpress`, `mariadb`, `redis`). |
| **Namespace** | Espacio lógico aislado dentro de Kubernetes para agrupar recursos (por ejemplo: `wordpress`, `kube-system`, `rook-ceph`). |
| **Control plane** | Conjunto de componentes que gobiernan el clúster (apiserver, etcd, scheduler, controller-manager), corriendo en `k8-master`. |
| **kube-apiserver** | API central del control plane; expone y valida todas las operaciones de Kubernetes (es la puerta de entrada de `kubectl`). |
| **kubelet** | Agente que corre en cada nodo y asegura que los contenedores definidos en los Pods estén ejecutándose y sanos. |
| **containerd** | Runtime de contenedores usado por Kubernetes para crear y ejecutar los contenedores de los Pods. |
| **Tigera** | Distribuidor/operador de Calico; su operador (`tigera-operator`) despliega y gestiona el CNI Calico en el clúster. |
| **Calico** | CNI que provee red y políticas de red a los Pods; aquí usa VXLAN sobre la red `172.16.0.0/16`. |
| **MetalLB** | Controlador que asigna IPs externas (`LoadBalancer`) dentro de la red privada; anuncia la VIP `192.168.90.50` en modo L2. |
| **Interfaces** | Puntos de acceso (URLs/IPs+puertos) por los que se entra a WordPress y a los paneles de Kubernetes, Ceph y NGINX desde el anfitrión. |
| **Rook** | Operador que empaqueta Ceph para Kubernetes: despliega, configura y gestiona el clúster Ceph de forma declarativa. |
| **CephFS** | Sistema de archivos distribuido de Ceph (`myfs`) expuesto como `StorageClass`; da almacenamiento persistente a los PVC de WordPress. |
| **MON** | Monitor de Ceph (`mon`): mantiene el mapa del clúster y decide dónde se replican los datos; aquí hay 3 (`mon-a`, `mon-b`, `mon-c`). |

---



# 2. Vista de alto nivel

```text
usuario (navegador)
      |
      | https://192.168.90.50/  https://192.168.90.1:32000  http://192.168.90.1:32174/
      v
[ anfitrion 192.168.90.254 : virbr90 / red k8s-lab 192.168.90.0/24 ]
      |
      +-----------------+-----------------+-----------------+
      |                 |                 |                 |
[k8-master .1]   [k8-worker1 .2]   [k8-worker2 .3]   [k8-worker3 .4]
 Control Plane      Worker            Worker            Worker
 (apiserver/etcd)   (mon-a/osd-0)     (mon-b/osd-1)     (mon-c/osd-2/mgr)
      |                 |                 |                 |
      +-----------------+-----------------+-----------------+
                        Calico CNI (172.16.0.0/16)

  MetalLB (VIP 192.168.90.50)
      |
      v
  Service wordpress-lb (LoadBalancer :80)
      |
      v
  Pod wordpress  (wordpress + mariadb + redis)
      |
      +--> PVC wordpress-content   (CephFS, /var/www/html)
      +--> PVC wordpress-db        (CephFS, /var/lib/mysql)
      +--> PVC wordpress-redis     (CephFS, /data)
```

La **pieza clave** del diseño es que WordPress, su base de datos y su
cache comparten **un mismo Pod** (requisito del PDF) y que todos sus datos
viven en **CephFS** (requisito 4 del PDF: disco persistente asociado al
cluster CephFS). La tolerancia a fallos se logra replicando cada dato de
Ceph `size: 3` (una copia por worker).

---

# 3. Inventario de IPs, credenciales y accesos

## 3.1. IPs

| Equipo / servicio | IP | Rol / uso |
|---|---:|---|
| `anfitrion` | `192.168.90.254` | Host físico KVM/libvirt |
| `k8-master` | `192.168.90.1` | Control Plane, `kubectl` |
| `k8-worker1` | `192.168.90.2` | Worker (mon-a, osd-0) |
| `k8-worker2` | `192.168.90.3` | Worker (mon-b, osd-1) |
| `k8-worker3` | `192.168.90.4` | Worker (mon-c, osd-2, mgr-a) |
| `wordpress-lb` | `192.168.90.50` | VIP MetalLB para WordPress |

## 3.2. Accesos web desde el anfitrión

| Interfaz | URL | Usuario | Credencial |
|---|---|---|---|
| WordPress (público) | `https://192.168.90.50/` | — | — |
| WordPress (admin) | `https://192.168.90.50/wp-admin/` | `uceda` (o `admin`) | `WordPressK8sLab2026!` |
| Kubernetes Dashboard | `https://192.168.90.1:32000` | `admin-user` | Token temporal |
| Ceph Dashboard | `http://192.168.90.1:32174/` | `admin` | `13tAxYZaHbq0ujaxTkmU` |
| NGINX de prueba | `http://192.168.90.1:30885` | — | — |

> Token del Dashboard de Kubernetes:
> `kubectl -n kubernetes-dashboard create token admin-user`

## 3.3. Accesos SSH

```bash
# Desde el anfitrión
ssh uceda@192.168.90.1   # k8-master  (aquí se ejecuta kubectl)
ssh uceda@192.168.90.2   # k8-worker1
ssh uceda@192.168.90.3   # k8-worker2
ssh uceda@192.168.90.4   # k8-worker3
```

---

# 4. Arquitectura capa a capa

## 4.1. Capa de virtualización (anfitrión)

- Hipervisor **KVM** gestionado con **libvirt**.
- Red virtual **`k8s-lab`** (`192.168.90.0/24`, NAT/aislada) definida en
  `kubernetes/net/k8s-lab-network.xml`, montada sobre el bridge `virbr90`.
- 4 VMs Ubuntu 24.04 creadas con `cloud-init` + `virt-install`
  (script `kubernetes/scripts/create-k8s-lab-vms.sh`).
- Cada worker tiene un **segundo disco crudo `vdb` (20G)** usado
  exclusivamente como OSD de Ceph.

## 4.2. Capa de orquestación (Kubernetes)

- Control plane en `k8-master`: `kube-apiserver`, `etcd`,
  `kube-controller-manager`, `kube-scheduler`.
- Agente `kubelet` + runtime `containerd` en los 4 nodos.
- CNI **Calico** (operador Tigera `v1.42.3`, Calico `v3.32.1`).
- `kube-proxy` en cada nodo para la red de Services.

## 4.3. Capa de red de servicios (MetalLB)

- `IPAddressPool k8s-lab-pool` = `192.168.90.50-192.168.90.50`.
- `L2Advertisement k8s-lab-advertisement` anuncia la VIP por ARP.
- El `Service wordpress-lb` (tipo `LoadBalancer`) recibe la VIP y enruta
  al Pod de WordPress.

## 4.4. Capa de almacenamiento (Rook-Ceph)

- **Rook Operator** `v1.20.6` despliega y gestiona **Ceph `v20.2.4`**.
- `CephCluster`: `3 mon` (uno por worker), `1 mgr`, `3 osd` (sobre `vdb`).
- `CephFilesystem myfs` con pools `replicated.size = 3`
  (`failureDomain: host`).
- `StorageClass cephfs-storage` (provisioner CSI
  `rook-ceph.cephfs.csi.ceph.com`) para aprovisionar PVC dinámicos.

## 4.5. Capa de aplicación (WordPress)

- `Deployment wordpress` (namespace `wordpress`), `replicas: 1`,
  estrategia `Recreate`.
- **Un solo Pod con 3 contenedores**:
  - `wordpress` (`wordpress:6.8-apache`, puerto 80)
  - `mariadb` (`mariadb:11.4`, puerto 3306)
  - `redis` (`redis:7.4`, puerto 6379)
- Conexión interna por `localhost`: `WORDPRESS_DB_HOST=127.0.0.1:3306` y
  `WP_REDIS_HOST=127.0.0.1`.
- 3 PVC CephFS montados en el Pod.

## 4.6. Capa de exposición

| Recurso | Tipo | Puerto / VIP |
|---|---|---|
| `Service wordpress` | ClusterIP | `:80` interno |
| `Service wordpress-lb` | LoadBalancer | `192.168.90.50:80` (NodePort 32731) |
| Dashboard K8s | NodePort | `32000` (HTTPS) |
| NGINX prueba | NodePort | `30885` (HTTP) |
| Dashboard Ceph | NodePort propio | `32174` (HTTP) |

---

# 5. Diagramas UML

Los diagramas fuente (PlantUML) están en `kubernetes/puml/`:

| Archivo | Contenido |
|---|---|
| `01-red-y-bridges.puml` | Red `k8s-lab`, bridge `virbr90` e IPs de servicios |
| `02-workers.puml` | Componentes por nodo (control-plane, workers, mon/osd/mds) |
| `03-pods-y-conexion.puml` | Pods por namespace y comandos de conexión |
| `04-infraestructura-sistema.puml` | Infraestructura completa del sistema |
| `05-arquitectura-servicios-pods.puml` | Arquitectura de servicios y Pods (esta guía) |

> Para renderizarlos a imagen/SVG:
>
> ```bash
> # NODO: anfitrion
> # RUTA: kubernetes/puml
> # Requiere plantuml.jar (https://plantuml.com/download) o el plugin PlantUML de VS Code.
> java -jar plantuml.jar -tsvg *.puml
> ```

---

# 6. Demo 1 — Infraestructura y nodos

> Todo `kubectl` se ejecuta en `k8-master`. Requisito previo en cada
> terminal:
> `export KUBECONFIG="/home/uceda/.kube/config"`

## 6.1. VMs y red desde el anfitrión

```bash
# NODO: anfitrion
virsh list --all
virsh net-list --all
virsh net-dhcp-leases k8s-lab
ip addr show virbr90
```

## 6.2. Nodos del clúster

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"
kubectl get nodes -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.'node-role\.kubernetes\.io/control-plane',IP:.status.addresses[0].address,OS:.status.nodeInfo.osImage,VERSION:.status.nodeInfo.kubeletVersion
```

Salida esperada (resumen):

```text
NAME         STATUS   ROLES           INTERNAL-IP    OS-IMAGE             VERSION
k8-master    Ready    control-plane   192.168.90.1   Ubuntu 24.04.4 LTS   v1.36.4
k8-worker1   Ready    <none>          192.168.90.2   Ubuntu 24.04.4 LTS   v1.36.4
k8-worker2   Ready    <none>          192.168.90.3   Ubuntu 24.04.4 LTS   v1.36.4
k8-worker3   Ready    <none>          192.168.90.4   Ubuntu 24.04.4 LTS   v1.36.4
```

## 6.3. Namespaces

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"
kubectl get namespaces
```

---

# 7. Demo 2 — Services, Endpoints y LoadBalancer

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

# Todos los Services del namespace wordpress
kubectl -n wordpress get svc -o wide

# Endpoints (a qué Pods enruta cada Service)
kubectl -n wordpress get endpoints

# Detalle del LoadBalancer y su VIP asignada por MetalLB
kubectl -n wordpress describe svc wordpress-lb

# IPAddressPool y anuncio L2 de MetalLB
kubectl -n metallb-system get ipaddresspool,l2advertisement
```

Punto de control esperado:

```text
wordpress      ClusterIP      10.97.153.171  <none>  80/TCP
wordpress-lb   LoadBalancer   10.106.243.222 192.168.90.50  80:32731/TCP
```

---

# 8. Demo 3 — Pods y contenedores

## 8.1. Ver el Pod de WordPress y sus 3 contenedores

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

kubectl -n wordpress get pod -o wide
kubectl -n wordpress get pod -l app=wordpress \
  -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,PHASE:.status.phase,READY:.status.containerStatuses[*].ready

# Identificar el nombre real del Pod
POD="$(kubectl -n wordpress get pod -l app=wordpress -o jsonpath='{.items[0].metadata.name}')"
echo "POD=$POD"
```

## 8.2. Conectarse a cada contenedor

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"
POD="$(kubectl -n wordpress get pod -l app=wordpress -o jsonpath='{.items[0].metadata.name}')"

# Shell en el contenedor wordpress
kubectl -n wordpress exec -it "$POD" -c wordpress -- bash

# Shell en el contenedor mariadb
kubectl -n wordpress exec -it "$POD" -c mariadb -- bash

# Shell en el contenedor redis
kubectl -n wordpress exec -it "$POD" -c redis -- sh
```

## 8.3. Probar cada contenedor

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

# MariaDB: ping de BD (debe responder "mysqld is alive")
kubectl -n wordpress exec deploy/wordpress -c mariadb -- \
  mariadb-admin ping -h 127.0.0.1 -uroot -p'RootK8sLab2026!'

# Listar bases de datos
kubectl -n wordpress exec deploy/wordpress -c mariadb -- \
  mariadb -uroot -p'RootK8sLab2026!' -e "SHOW DATABASES;"

# Usuarios de WordPress
kubectl -n wordpress exec deploy/wordpress -c mariadb -- \
  mariadb -uroot -p'RootK8sLab2026!' -e "SELECT ID,user_login,user_email FROM wp_users;" wordpress

# Redis: ping (debe responder PONG)
kubectl -n wordpress exec deploy/wordpress -c redis -- redis-cli ping

# WordPress: versión por CLI
kubectl -n wordpress exec deploy/wordpress -c wordpress -- wp --info --allow-root 2>/dev/null \
  || kubectl -n wordpress exec deploy/wordpress -c wordpress -- php -r 'echo getenv("WORDPRESS_DB_HOST"),"\n";'
```

## 8.4. Pods del sistema (namespaces de infraestructura)

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

kubectl get pods -A
kubectl -n kube-system get pods
kubectl -n calico-system get pods
kubectl -n tigera-operator get pods
kubectl -n metallb-system get pods
kubectl -n kubernetes-dashboard get pods
kubectl -n rook-ceph get pods -o wide
```

Punto de control: en `rook-ceph` deben verse los daemons de Ceph
(`mon-a/b/c`, `mgr`, `osd-0/1/2`, `mds`) y el CSI (`ctrlplugin` /
`nodeplugin`).

---

# 9. Demo 4 — Almacenamiento CephFS

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

# StorageClass
kubectl get storageclass cephfs-storage -o wide

# PVCs de WordPress (deben estar Bound)
kubectl -n wordpress get pvc

# Ver qué volumen atiende cada PVC
kubectl -n wordpress get pvc -o custom-columns=NAME:.metadata.name,CAPACITY:.status.capacity.storage,ACCESS:.status.accessModes,PHASE:.status.phase,VOLUME:.spec.volumeName
```

Punto de control esperado:

```text
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES
wordpress-content   Bound    pvc-e7725828-...                           5Gi        RWX
wordpress-db        Bound    pvc-8abfd554-...                           5Gi        RWO
wordpress-redis     Bound    pvc-968e93e5-...                           1Gi        RWO
```

## 9.1. Confirmar que los datos están montados en el Pod

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"
POD="$(kubectl -n wordpress get pod -l app=wordpress -o jsonpath='{.items[0].metadata.name}')"

# Listar contenido del volumen de WordPress
kubectl -n wordpress exec "$POD" -c wordpress -- ls -la /var/www/html

# Ver que MariaDB usa su volumen en /var/lib/mysql
kubectl -n wordpress exec "$POD" -c mariadb -- ls -la /var/lib/mysql

# Ver que Redis escribe en /data
kubectl -n wordpress exec "$POD" -c redis -- ls -la /data
```

## 9.2. Prueba de persistencia (rápida)

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"
POD="$(kubectl -n wordpress get pod -l app=wordpress -o jsonpath='{.items[0].metadata.name}')"

# Crear un archivo de prueba
kubectl -n wordpress exec "$POD" -c wordpress -- \
  sh -c 'echo persistencia-cephfs > /var/www/html/demo-persistencia.txt && cat /var/www/html/demo-persistencia.txt'

# Reiniciar el Deployment y comprobar que el archivo sigue
kubectl -n wordpress rollout restart deployment/wordpress
kubectl -n wordpress rollout status deployment/wordpress --timeout=300s
POD="$(kubectl -n wordpress get pod -l app=wordpress -o jsonpath='{.items[0].metadata.name}')"
kubectl -n wordpress exec "$POD" -c wordpress -- cat /var/www/html/demo-persistencia.txt
```

---

# 10. Demo 5 — Estado de Ceph y Rook

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

# Fase del CephCluster
kubectl -n rook-ceph get cephcluster

# Estado de salud de Ceph (mon/mgr/osd)
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s

# Árbol de OSDs (3 OSDs, uno por worker, sobre vdb)
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree

# Estado del filesystem myfs
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph fs status myfs
kubectl -n rook-ceph get cephfilesystem myfs

# Logs del operador (por si hay que diagnosticar)
kubectl -n rook-ceph logs deploy/rook-ceph-operator --tail=100
```

Punto de control esperado:

```text
CephCluster PHASE: Ready
health: HEALTH_OK  (o HEALTH_WARN solo por keyType aes, aceptable)
osd: 3 osds: 3 up, 3 in
CephFilesystem myfs PHASE: Ready
```

---

# 11. Demo 6 — Verificación web de punta a punta

Desde el **anfitrión** (o con un navegador):

```bash
# NODO: anfitrion
# Cabeceras de WordPress
curl -kI https://192.168.90.50/

# HTML de WordPress (primeras líneas)
curl -kL https://192.168.90.50/ | head -n 20

# Dashboard de Kubernetes (verificar que responde)
curl -k -I https://192.168.90.1:32000

# Dashboard de Ceph (API de login)
curl -sk -X POST "http://192.168.90.1:32174/api/auth" \
  -H "Accept: application/vnd.ceph.api.v1.0+json" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"13tAxYZaHbq0ujaxTkmU"}'
```

Abrir en el navegador del anfitrión:

| URL | Qué demuestra |
|---|---|
| `https://192.168.90.50/` | WordPress público servido a través de MetalLB + Pod + CephFS |
| `https://192.168.90.50/wp-admin/` | WordPress admin (login con `uceda` / `WordPressK8sLab2026!`) |
| `https://192.168.90.1:32000` | Dashboard de Kubernetes (token `admin-user`) |
| `http://192.168.90.1:32174/` | Dashboard de Ceph (usuario `admin`) |

---

# 12. Comandos rápidos de una línea

```bash
# NODO: k8-master  (prefijar con: export KUBECONFIG="/home/uceda/.kube/config")

# Nodos y versiones
kubectl get nodes -o wide

# Todos los Pods del clúster
kubectl get pods -A -o wide

# Services de WordPress
kubectl -n wordpress get svc -o wide

# Pod de WordPress y su nodo
kubectl -n wordpress get pod -o wide

# PVCs de WordPress
kubectl -n wordpress get pvc

# StorageClass CephFS
kubectl get storageclass cephfs-storage

# Salud de Ceph
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s

# Árbol de OSDs
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree

# Pool MetalLB
kubectl -n metallb-system get ipaddresspool,l2advertisement
```

---

# 13. Proyección: capacidad de repuesto N+1

El clúster hoy es **1 master + 3 workers**, y Ceph reparte sus 3 mons y 3
OSDs **uno por worker**. Esto cumple el laboratorio, pero **no tolera la
pérdida permanente** de un worker sin quedar degradado: `mon` no tendría
dónde migrar y el `osd` de ese nodo quedaría fuera.

La **capacidad de repuesto N+1** consiste en agregar un **`k8-worker4`**
(`192.168.90.5`, MAC `52:54:00:90:00:05`) con su propio disco `vdb`,
manteniendo `mon.count=3`. Con 4 nodos:

- Rook deja **1 nodo libre** como candidato de *fail-over* de `mon`.
- Ceph suma un **4º OSD**, por lo que la pérdida de cualquier worker se
  puede re-replicar automáticamente.

Esto está **planificado en detalle** (fases 23.1 a 23.7) en la guía de
continuación `guia_continuacion_wordpress_cephfs_lab.md` (y su exportación
HTML), pero **aún no ejecutado**. No forma parte del despliegue actual.

---

## Nota final

Esta guía es **descriptiva y de demostración**: su objetivo es recorrer la
infraestructura montada (KVM → Kubernetes → CephFS → WordPress) con los
comandos y diagramas que evidencian **cómo se compone** cada capa y cómo
**confluyen los servicios, Pods y volúmenes** en el estado real del
laboratorio.