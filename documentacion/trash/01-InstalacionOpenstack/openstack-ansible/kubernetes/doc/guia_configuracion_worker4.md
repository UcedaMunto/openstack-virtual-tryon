# Guía: Configuración de `k8-worker4` (capacidad de repuesto N+1)

> **Estado:** implementado y verificado (2026-08-27 / 2026-08-29).
> `k8-worker4` (`192.168.90.5`) se agregó al clúster como **worker de repuesto**
> para tolerar la pérdida permanente de un worker sin quedar en `HEALTH_WARN`
> indefinido. Aporta un 4º disco OSD a Ceph y deja un nodo libre como candidato
> de fail-over de `mon`.

## Resumen de decisiones de diseño

| Parámetro | Valor | Motivo |
|---|---:|---|
| Nombre | `k8-worker4` | Sigue el patrón `k8-worker1/2/3` |
| IP | `192.168.90.5` | Siguiente libre en `192.168.90.0/24` |
| MAC | `52:54:00:90:00:05` | Siguiente en la secuencia `...:01` a `...:04` |
| RAM / vCPU | `5120` MB / `2` | Igual a los otros workers |
| Disco raíz | `40G` (overlay qcow2) | Igual a los otros workers |
| Disco OSD (`vdb`) | `20G` qcow2 crudo | Igual a la sección 6.1 |
| Rol Kubernetes | Worker normal (`kubeadm join`), sin taints | Recibe Pods normales + el OSD |
| Rol Ceph | Solo `storage.nodes`; **sin `mon` extra** | Con 4 nodos y `mon.count: 3`, queda 1 libre para fail-over |

> La reserva DHCP de `k8-worker4` ya está en `net/k8s-lab-network.xml`
> (`<host mac='52:54:00:90:00:05' name='k8-worker4' ip='192.168.90.5'/>`).

---

## Fase 1 — Crear la VM `k8-worker4` (anfitrión)

Mismo patrón que el resto de VMs: imagen base + overlay qcow2 + cloud-init + `virt-install`.

```bash
# NODO: anfitrion
VM_DIR="/var/lib/libvirt/images/k8s-lab"
CLOUD_INIT_DIR="/home/uceda/Documents/InstalacionOpenstack/openstack-ansible/kubernetes/cloud-init"
BASE_IMG="${VM_DIR}/noble-server-cloudimg-amd64.img"

# 1. Disco raíz (overlay 40G sobre la imagen base)
BASE_FMT="$(sudo qemu-img info "$BASE_IMG" | awk -F': ' '/file format/ {print $2; exit}')"
sudo qemu-img create -f qcow2 -F "$BASE_FMT" -b "$BASE_IMG" "${VM_DIR}/k8-worker4.qcow2" 40G

# 2. Cloud-init: user-data (mismo usuario/llave SSH que k8-worker1/2/3)
#    (hoy se genera con: scripts/gen-cloud-init.sh ~/.ssh/id_ed25519.pub k8-worker4)
# 3. Cloud-init: meta-data
cat > "${CLOUD_INIT_DIR}/k8-worker4-meta-data" <<'EOF'
instance-id: k8-worker4
local-hostname: k8-worker4
EOF

# 4. Generar el seed.iso
cloud-localds \
  "${CLOUD_INIT_DIR}/k8-worker4-seed.iso" \
  "${CLOUD_INIT_DIR}/k8-worker4-user-data" \
  "${CLOUD_INIT_DIR}/k8-worker4-meta-data"

# 5. Crear la VM
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
```

> **Automatizado hoy:** `scripts/gen-cloud-init.sh` (incluye `k8-worker4` por
> defecto) y `scripts/create-k8s-lab-vms.sh` (bloque `k8-worker4`) hacen este
> paso. Ver `deployment-set/`.

**Punto de control:** `virsh net-dhcp-leases k8s-lab` debe mostrar `k8-worker4`
con IP `192.168.90.5`, y el SSH debe responder:
```bash
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 uceda@192.168.90.5 'hostname; cloud-init status'
```

---

## Fase 2 — Preparar el sistema operativo de `k8-worker4`

Mismos pasos de la guía principal (swap, módulos kernel/sysctl, containerd,
kubeadm/kubelet/kubectl), aplicados solo al nodo nuevo. Desde `k8-master`:

```bash
# NODO: k8-master (tiene SSH sin password a los workers)
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
W4=192.168.90.5

# Deshabilitar swap
ssh "${SSH_OPTS[@]}" uceda@$W4 'sudo swapoff -a && sudo sed -ri "/^([^#].*\sswap\s.*)$/s/^/#/" /etc/fstab'

# Módulos kernel y sysctl
ssh "${SSH_OPTS[@]}" uceda@$W4 'printf "%s\n" overlay br_netfilter | sudo tee /etc/modules-load.d/k8s.conf && sudo modprobe overlay && sudo modprobe br_netfilter'
ssh "${SSH_OPTS[@]}" uceda@$W4 "printf '%s\n' 'net.bridge.bridge-nf-call-iptables  = 1' 'net.bridge.bridge-nf-call-ip6tables = 1' 'net.ipv4.ip_forward                 = 1' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null && sudo sysctl --system"

# containerd
ssh "${SSH_OPTS[@]}" uceda@$W4 'sudo apt-get update && sudo apt-get install -y containerd'
ssh "${SSH_OPTS[@]}" uceda@$W4 'sudo mkdir -p /etc/containerd && containerd config default | sudo tee /etc/containerd/config.toml >/dev/null && sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/" /etc/containerd/config.toml && sudo systemctl restart containerd && sudo systemctl enable containerd'

# kubeadm/kubelet/kubectl v1.36
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
'
```

**Punto de control:** `kubeadm version -o short` debe dar `v1.36.x` (igual que el master).

---

## Fase 3 — Unir `k8-worker4` al clúster (`kubeadm join`)

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

# Genera un token nuevo (los anteriores expiran)
JOIN_COMMAND="$(kubeadm token create --print-join-command)"
echo "$JOIN_COMMAND"

# Ejecutar el join en k8-worker4
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 uceda@192.168.90.5 "sudo $JOIN_COMMAND"

# Verificar
kubectl get nodes -o wide
```

**Punto de control:** `k8-worker4` aparece `NotReady` (sin CNI) y pasa a `Ready`
en 1-2 min cuando Calico despliega su Pod (`kubectl -n calico-system get pods -o wide | grep k8-worker4`).

---

## Fase 4 — Agregar el disco OSD (`vdb`) y el módulo `ceph`

```bash
# NODO: anfitrion
VM_DIR="/var/lib/libvirt/images/k8s-lab"

# Disco OSD 20G + adjuntar como vdb
sudo qemu-img create -f qcow2 "${VM_DIR}/k8-worker4-ceph-osd.qcow2" 20G
sudo virsh attach-disk k8-worker4 \
  --source "${VM_DIR}/k8-worker4-ceph-osd.qcow2" \
  --target vdb --subdriver qcow2 --targetbus virtio \
  --live --config --persistent

sudo virsh domblklist k8-worker4
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 uceda@192.168.90.5 \
  'hostname; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/vdb'

# Módulo de kernel ceph (requisito del cliente CephFS del CSI)
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 uceda@192.168.90.5 '
  sudo modprobe ceph
  echo "ceph" | sudo tee /etc/modules-load.d/ceph.conf
  lsmod | grep -q "^ceph " && echo "OK: modulo ceph cargado" || echo "ERROR"
'
```

**Punto de control:** `FSTYPE` vacío para `vdb` (disco crudo, sin particiones).

---

## Fase 5 — Agregar `k8-worker4` al `CephCluster` de Rook

```bash
# NODO: k8-master
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

> **No se toca `mon.count`** (queda en `3`): con 4 nodos y 3 mons, Rook tiene
> 1 worker libre como candidato natural de fail-over de `mon`.

**Punto de control:** aparece `rook-ceph-osd-3-...` en `Running` sobre
`k8-worker4` (y un `rook-ceph-osd-prepare-k8-worker4-*` en `Completed`).

> También hay que actualizar `tmp/03-rook-cluster.yaml` (agregar `k8-worker4` a
> `storage.nodes`) para que el respaldo en git refleje el estado real.

---

## Fase 6 — Verificar la capacidad de repuesto

```bash
# NODO: k8-master
export KUBECONFIG="/home/uceda/.kube/config"

kubectl get nodes -o wide
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree
kubectl -n rook-ceph get pods -o wide
```

**Esperado:**

| Verificación | Resultado |
|---|---|
| `kubectl get nodes` | `k8-master` + `k8-worker1/2/3/4` en `Ready` |
| `ceph -s` → `osd` | `4 osds: 4 up, 4 in` |
| `ceph osd tree` | 4 hojas (una por worker), todas `up` |
| Sin `mon`/`mgr` en `k8-worker4` | Correcto: es solo el destino de fail-over |

---

## Fase 7 (opcional) — Simular pérdida de un worker

Valida que el N+1 funciona; **no es parte del despliegue normal**:

```bash
# NODO: anfitrion
# Apagar (no destruir) un worker original, ej. k8-worker2
sudo virsh shutdown k8-worker2

# Esperar varios minutos y revisar desde k8-master:
#   kubectl get nodes
#   kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
#   kubectl -n rook-ceph get pods -o wide
# Esperado: un nuevo osd se crea en k8-worker4 y Ceph re-replica los datos
# perdidos automáticamente, sin intervención manual.

# Revertir:
sudo virsh start k8-worker2
```

> ⚠️ Prueba **disruptiva**: `k8-worker2` aloja `mon-b`/`osd-1`. El clúster
> debería tolerarlo, pero conviene avisar antes de ejecutarla.

