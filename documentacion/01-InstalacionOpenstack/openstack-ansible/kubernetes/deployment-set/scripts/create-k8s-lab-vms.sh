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

if sudo virsh dominfo k8-worker4 >/dev/null 2>&1; then
  echo "La VM k8-worker4 ya existe en libvirt; se omite"
else
  sudo virt-install \
    --name k8-worker4 \
    --memory 5120 \
    --vcpus 2 \
    --cpu host-passthrough \
    --import \
    --disk path="$VM_DIR/k8-worker4.qcow2",format=qcow2,bus=virtio \
    --disk path="$VM_DIR/k8-worker4-seed.iso",device=cdrom \
    --network network=k8s-lab,model=virtio,mac=52:54:00:90:00:05 \
    --os-variant ubuntu24.04 \
    --graphics none \
    --noautoconsole
fi

# Nodo Ceph opcional/historico (cephadm todo-en-uno, IP 192.168.90.40).
# En el flujo actual el almacenamiento lo provee Rook-Ceph DENTRO de Kubernetes,
# por lo que este nodo solo se crea si se quiere reproducir la seccion historica.
if sudo virsh dominfo ceph-admin >/dev/null 2>&1; then
  echo "La VM ceph-admin ya existe en libvirt; se omite"
else
  sudo virt-install \
    --name ceph-admin \
    --memory 4096 \
    --vcpus 2 \
    --cpu host-passthrough \
    --import \
    --disk path="$VM_DIR/ceph-admin.qcow2",format=qcow2,bus=virtio \
    --disk path="$VM_DIR/ceph-admin-seed.iso",device=cdrom \
    --network network=k8s-lab,model=virtio \
    --os-variant ubuntu24.04 \
    --graphics none \
    --noautoconsole
fi

# =============================================================================
# Discos crudos vdb (OSD de Ceph) para los workers de Rook.
# Se crea un qcow2 de 20G por worker y se adjunta en caliente como vdb.
# =============================================================================
OSD_SIZE_G="20"
for w in k8-worker1 k8-worker2 k8-worker3 k8-worker4; do
  DISK="$VM_DIR/${w}-ceph-osd.qcow2"

  if [[ ! -f "$DISK" ]]; then
    echo "Creando disco OSD: $DISK (${OSD_SIZE_G}G)"
    sudo qemu-img create -f qcow2 "$DISK" "${OSD_SIZE_G}G"
  else
    echo "El disco OSD ya existe: $DISK; se omite"
  fi

  # Adjuntar como vdb solo si no esta ya adjunto.
  if sudo virsh domblklist "$w" 2>/dev/null | grep -qw vdb; then
    echo "vdb ya esta adjunto en $w; se omite"
    continue
  fi

  echo "Adjuntando vdb a $w"
  if sudo virsh domstate "$w" 2>/dev/null | grep -q running; then
    sudo virsh attach-disk "$w" --source "$DISK" --target vdb \
      --subdriver qcow2 --targetbus virtio --live --config --persistent
  else
    sudo virsh attach-disk "$w" --source "$DISK" --target vdb \
      --subdriver qcow2 --targetbus virtio --config --persistent
  fi
done
