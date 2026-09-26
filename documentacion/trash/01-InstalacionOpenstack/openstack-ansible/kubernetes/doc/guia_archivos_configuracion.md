# Guía: cómo visualizar los archivos de configuración más importantes

Referencia de los archivos de configuración clave del laboratorio y el comando
para verlos. Cada comando lleva un comentario `# NODO:` que indica dónde se
ejecuta:

- **anfitrion** → el host físico KVM (fuera de las VMs).
- **k8-master** → dentro de la VM `k8-master` (o vía `ssh uceda@192.168.90.1`).
- **workers** → dentro de cada VM worker (o vía `ssh uceda@192.168.90.X`).

---

## 1. Configuración de Ceph (Rook-Ceph)

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

# (a) CephCluster: topología del clúster (mon/mgr/osd, discos vdb, keyType)
kubectl -n rook-ceph get cephcluster rook-ceph -o yaml

# (b) ceph.conf real dentro de un monitor (ej. mon-a)
kubectl -n rook-ceph exec deploy/rook-ceph-mon-a -- cat /etc/ceph/ceph.conf

# (c) Configuración efectiva del clúster (todos los valores de config)
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph config dump

# (d) CephFilesystem (myfs) y StorageClass
kubectl -n rook-ceph get cephfilesystem myfs -o yaml
kubectl get storageclass cephfs-storage -o yaml
```

```bash
# NODO: anfitrion (el manifiesto fuente en el repo)
cat /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/tmp/03-rook-cluster.yaml
```

---

## 2. Configuración de WordPress

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

# (a) Deployment: imágenes, variables de entorno, volúmenes (3 contenedores)
kubectl -n wordpress get deploy wordpress -o yaml

# (b) wp-config.php DENTRO del contenedor wordpress (config de PHP/DB/Redis)
kubectl -n wordpress exec deploy/wordpress -c wordpress -- cat /var/www/html/wp-config.php

# (c) Variables de entorno (DB host, Redis, etc.)
kubectl -n wordpress exec deploy/wordpress -c wordpress -- env | grep -E 'WORDPRESS|WP_|MARIADB'

# (d) Secrets (contraseñas) y el Ingress (exposición HTTPS)
kubectl -n wordpress get secret wordpress-secrets -o yaml
kubectl -n wordpress get ingress wordpress -o yaml
```

```bash
# NODO: anfitrion (los manifiestos fuente en el repo)
cat /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/tmp/07-wordpress-cephfs.yaml
cat /home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/tmp/13-wordpress-ingress.yaml
```

---

## 3. Configuración de Kubernetes (control-plane + nodos)

```bash
# NODO: k8-master (manifiestos de los pods estáticos del control-plane)
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml
sudo cat /etc/kubernetes/manifests/etcd.yaml
sudo cat /etc/kubernetes/manifests/kube-controller-manager.yaml
sudo cat /etc/kubernetes/manifests/kube-scheduler.yaml

# NODO: k8-master (config de kubeadm y kubeconfig admin)
sudo cat /etc/kubernetes/kubeadm-config.yaml
sudo cat /etc/kubernetes/admin.conf
```

```bash
# NODO: cada VM (kubelet y containerd) — vía SSH desde el anfitrion
for ip in 192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4 192.168.90.5; do
  echo "========== $ip =========="
  ssh uceda@$ip 'echo "--- kubelet config ---"; sudo cat /var/lib/kubelet/config.yaml; echo "--- containerd config ---"; sudo cat /etc/containerd/config.toml'
done
```

```bash
# NODO: k8-master (vía kubectl: los pods estáticos del control-plane)
export KUBECONFIG="/home/uceda/.kube/config"
kubectl -n kube-system get pod kube-apiserver-k8-master -o yaml
```

---

## 5. Configuración de Nginx (ingress-nginx + nginx-app de prueba)

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

# (a) ConfigMap del controlador ingress-nginx (parámetros globales del proxy)
kubectl -n ingress-nginx get cm ingress-nginx-controller -o yaml

# (b) nginx.conf DENTRO del controlador ingress-nginx
kubectl -n ingress-nginx exec deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf

# (c) Ingress de WordPress (routing + TLS que usa nginx)
kubectl -n wordpress get ingress wordpress -o yaml

# (d) El NGINX de prueba (default namespace)
kubectl -n default get deploy nginx-app -o yaml
kubectl -n default exec deploy/nginx-app -- cat /etc/nginx/nginx.conf
```

---

## 6. Configuración de Chrony (NTP)

```bash
# NODO: cada VM (el archivo de configuración + estado de sincronización)
# Vía SSH desde el anfitrion:
for ip in 192.168.90.1 192.168.90.2 192.168.90.3 192.168.90.4 192.168.90.5; do
  echo "========== $ip =========="
  ssh uceda@$ip 'echo "--- /etc/chrony/chrony.conf ---"; cat /etc/chrony/chrony.conf; echo "--- chronyc tracking ---"; chronyc tracking; echo "--- chronyc sources ---"; chronyc sources'
done
```
