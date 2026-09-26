# Verificación de requisitos del laboratorio Kubernetes

**Fecha de la verificación:** 2026-08-23
**Ejecutado desde:** `anfitrion` (host físico), con comandos remotos vía SSH
hacia `k8-master` (192.168.90.1) y el nodo Ceph `os-storage01`
(gestión 192.168.60.40 / datos 192.168.90.40).

Este documento es un anexo de comprobación puntual. La guía completa,
paso a paso y con la convención `# NODO: <nodo>` + "Puntos de control",
está en
[guia_kubernetes_ubuntu_24_04_con_vms_kvm_REVISADA_PDF.md](guia_kubernetes_ubuntu_24_04_con_vms_kvm_REVISADA_PDF.md).

Cada sección siguiente corresponde a un requisito del PDF, con el
comando ejecutado, el nodo, y la salida real obtenida en esta corrida.

---

## Requisito 1 — Cluster con al menos 1 máster y 3 workers

``` bash
# NODO: k8-master
kubectl get nodes -o wide
```

```
NAME         STATUS   ROLES           AGE     VERSION   INTERNAL-IP    CONTAINER-RUNTIME
k8-master    Ready    control-plane   4d13h   v1.36.3   192.168.90.1   containerd://2.2.1
k8-worker1   Ready    <none>          12h     v1.36.3   192.168.90.2   containerd://2.2.1
k8-worker2   Ready    <none>          12h     v1.36.3   192.168.90.3   containerd://2.2.1
k8-worker3   Ready    <none>          12h     v1.36.3   192.168.90.4   containerd://2.2.1
```

Calico (`calico-system`) y CoreDNS (`kube-system`): todos los pods `Running`
(`calico-node` x4, `calico-typha` x2, `calico-kube-controllers`,
`calico-apiserver` x2, `csi-node-driver` x4, `goldmane`, `whisker`,
`coredns` x2).

`containerd`/`kubelet` en los 4 nodos (verificado con SSH directo desde
`anfitrion` a cada IP, **no** encadenado vía `k8-master`):

```
192.168.90.1  containerd=active  kubelet=active
192.168.90.2  containerd=active  kubelet=active
192.168.90.3  containerd=active  kubelet=active
192.168.90.4  containerd=active  kubelet=active
```

**Resultado: ✅ CUMPLE.**

---

## Requisito 2 — Dashboard de Kubernetes

``` bash
# NODO: k8-master
kubectl get pods -n kubernetes-dashboard
kubectl get svc -n kubernetes-dashboard
kubectl get sa admin-user -n kubernetes-dashboard
kubectl get clusterrolebinding admin-user
```

```
kubernetes-dashboard-api-...               1/1   Running
kubernetes-dashboard-auth-...              1/1   Running
kubernetes-dashboard-kong-...              1/1   Running
kubernetes-dashboard-metrics-scraper-...   1/1   Running
kubernetes-dashboard-web-...               1/1   Running

sa/admin-user                              existe
clusterrolebinding/admin-user  ROLE=ClusterRole/cluster-admin
```

**Resultado: ✅ CUMPLE.**

---

## Requisito 4 — Disco persistente respaldado por CephFS

> Se documenta antes que el requisito 3 porque WordPress depende de él.

### 4.1. Estado del clúster Ceph

``` bash
# NODO: ceph-admin (os-storage01, vía cephadm shell)
sudo cephadm shell -- ceph -s
sudo cephadm shell -- ceph fs status storage
```

```
health: HEALTH_WARN
        Monitors are configured to use emergency allowed ciphers
        1 auth client entities with insecure key types
        Degraded data redundancy: 3508/7016 objects degraded (50.000%), 78 pgs degraded, 81 pgs undersized
mon: 1 daemons, quorum os-storage01
mgr: os-storage01.nblchv(active)
mds: 1/1 daemons up, 1 standby
osd: 2 osds: 2 up, 2 in
volumes: 1/1 healthy

storage - 2 clients
RANK  STATE   MDS                          ACTIVITY
 0    active  storage.os-storage01.ychtkk  Reqs: 0/s
STANDBY MDS: storage.os-storage01.yvbtka
```

**Nota sobre el `HEALTH_WARN`:** es esperado y aceptado en este laboratorio.
Con solo 2 OSD físicos (discos de la VM reutilizada `os-storage01`) y
pools con `size=2`, el clúster queda en `undersized` permanente (no hay
un 3er OSD para replicar). El filesystem, el MDS y el aprovisionamiento
CSI funcionan correctamente a pesar de esta advertencia — se comprueba
en 4.2. Las otras dos advertencias (`emergency allowed ciphers`,
`insecure key types`) son el resultado intencional del workaround
documentado en la sección 24.2.1/24.2.2 de la guía principal (bug de
generación de llaves CephX de 32 bytes en este clúster Ceph Squid
19.2.6).

### 4.2. Prueba end-to-end fresca: PVC + Pod con escritura y lectura real

``` bash
# NODO: k8-master
kubectl apply -f verif-pvc.yaml   # StorageClass cephfs-storage, RWX, 1Gi
kubectl get pvc verif-cephfs
```

```
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
verif-cephfs   Bound    pvc-9cce0d10-b633-4e4a-87ff-2bb2e6fe313c   1Gi        RWX            cephfs-storage
```

`Bound` en **10 segundos** desde la creación del PVC.

``` bash
# NODO: k8-master
kubectl apply -f verif-pod.yaml   # monta el PVC y escribe/lee un archivo
kubectl get pod verif-cephfs-pod
kubectl logs verif-cephfs-pod
```

```
NAME               READY   STATUS    RESTARTS   AGE
verif-cephfs-pod   1/1     Running   0          20s

verificacion-1787503063
```

El Pod montó el volumen CephFS, escribió el archivo y lo leyó de vuelta
con éxito. Recursos de prueba eliminados después de la verificación.

**Resultado: ✅ CUMPLE** (verificado dos veces en esta sesión: en la
implementación inicial y en esta corrida de verificación independiente).

---

## Requisito 3 — WordPress + MariaDB + Redis en un mismo Pod

``` bash
# NODO: k8-master
kubectl get pods -n wordpress -o wide
kubectl get pod -n wordpress -l app=wordpress \
  -o jsonpath='{range .items[0].status.containerStatuses[*]}{.name}{"="}{.ready}{"  restarts="}{.restartCount}{"\n"}{end}'
kubectl get pvc -n wordpress
```

```
NAME                         READY   STATUS    RESTARTS   AGE   NODE
wordpress-7b5ff89d57-gxwdx   3/3     Running   0          10m   k8-worker3

mariadb=true    restarts=0
redis=true      restarts=0
wordpress=true  restarts=0

NAME                STATUS   CAPACITY   ACCESS MODES   STORAGECLASS
wordpress-content   Bound    10Gi       RWX            cephfs-storage
wordpress-db        Bound    10Gi       RWO            cephfs-storage
```

Los tres contenedores (`wordpress`, `mariadb`, `redis`) corren dentro del
**mismo Pod**, sin reinicios, con almacenamiento persistente CephFS.

**Resultado: ✅ CUMPLE.**

---

## Requisito 5 — WordPress expuesto por HTTPS/443 en IP distinta al máster

``` bash
# NODO: k8-master
kubectl get svc -n ingress-nginx ingress-nginx-controller
kubectl get ingress -n wordpress
kubectl get ipaddresspool -n metallb-system
```

```
NAME                       TYPE           EXTERNAL-IP     PORT(S)
ingress-nginx-controller   LoadBalancer   192.168.90.50   80:30721/TCP,443:32025/TCP

NAME        CLASS   ADDRESS         PORTS
wordpress   nginx   192.168.90.50   80, 443

NAME           ADDRESSES
k8s-lab-pool   ["192.168.90.50-192.168.90.50"]
```

``` bash
# NODO: anfitrion
curl -kI https://192.168.90.50/
```

```
HTTP/2 302
location: https://192.168.90.50/wp-admin/install.php
x-powered-by: PHP/8.3.28
x-redirect-by: WordPress
strict-transport-security: max-age=31536000; includeSubDomains
```

Confirmado:

-   IP flotante `192.168.90.50` ≠ IP del máster `192.168.90.1`.
-   Acceso directo por el puerto **443** (HTTPS), sin necesidad de
    `port-forward` ni túneles.
-   La aplicación WordPress responde de verdad (redirección propia de
    una instalación nueva hacia `wp-admin/install.php`).

**Hallazgo menor (no bloqueante):** `curl -I http://192.168.90.50/`
(puerto 80, sin `-k`/TLS) devuelve `302` redirigiendo a
`http://192.168.90.50/...` en lugar de forzar `https://`. La anotación
`nginx.ingress.kubernetes.io/ssl-redirect: "true"` no está forzando el
redirect de HTTP→HTTPS en este Ingress (posible interacción con
`ingress-nginx` y ausencia de cabecera `X-Forwarded-Proto` en L2 puro de
MetalLB). **No afecta el cumplimiento del requisito**, ya que este exige
"exponer... directamente en el puerto 443", lo cual funciona
correctamente; queda como mejora opcional para producción.

**Resultado: ✅ CUMPLE.**

---

## Resumen final

| # | Requisito | Estado | Evidencia |
|---|-----------|--------|-----------|
| 1 | Cluster 1 máster + 3 workers | ✅ | 4 nodos `Ready`, Calico/CoreDNS/containerd `Running`/`active` |
| 2 | Dashboard | ✅ | 5/5 componentes `Running`, `admin-user` + `cluster-admin` |
| 3 | WordPress + MariaDB + Redis en un Pod | ✅ | Pod `3/3 Running`, 0 reinicios |
| 4 | Disco persistente CephFS | ✅ | PVC `Bound` en 10s + escritura/lectura real verificada dos veces |
| 5 | WordPress HTTPS/443 en IP distinta al máster | ✅ | `192.168.90.50` vía MetalLB+Ingress, `curl -kI` → `HTTP/2 302` real |

**Los 5 requisitos del PDF están cumplidos y verificados con evidencia
real de ejecución (no solo manifiestos aplicados) en esta corrida de
comprobación independiente del 2026-08-23.**

Estado del clúster tras la verificación: se eliminaron todos los
recursos de prueba (`verif-cephfs`, `verif-cephfs-pod`); un barrido con
`kubectl get pods -A` confirma que no queda ningún Pod fuera de
`Running`/`Completed` en ningún namespace.
