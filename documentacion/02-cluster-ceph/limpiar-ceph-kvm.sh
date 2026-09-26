#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# LIMPIEZA TOTAL DEL LAB CEPH EN KVM
# ==========================================================
# Elimina recursos creados por el flujo de "comandos ejecutados.txt":
# - VMs ceph-admin, ceph-mon, ceph-osd1, ceph-osd2, ceph-osd3
# - Discos qcow2 asociados
# - Red libvirt ceph-net
# - Archivos cloud-init temporales
# ==========================================================

IMG_DIR="${IMG_DIR:-/var/lib/libvirt/images}"
CEPH_NET="ceph-net"

VM_NAMES=(ceph-admin ceph-mon ceph-osd1 ceph-osd2 ceph-osd3)
DISKS=(
  "$IMG_DIR/ceph-admin.qcow2"
  "$IMG_DIR/ceph-mon.qcow2"
  "$IMG_DIR/ceph-osd1.qcow2"
  "$IMG_DIR/ceph-osd1-data.qcow2"
  "$IMG_DIR/ceph-osd2.qcow2"
  "$IMG_DIR/ceph-osd2-data.qcow2"
  "$IMG_DIR/ceph-osd3.qcow2"
  "$IMG_DIR/ceph-osd3-data.qcow2"
)
CLOUD_FILES=(
  /tmp/ceph-net.xml
  /tmp/user-data-ceph-admin.yaml
  /tmp/user-data-ceph-mon.yaml
  /tmp/user-data-ceph-osd1.yaml
  /tmp/user-data-ceph-osd2.yaml
  /tmp/user-data-ceph-osd3.yaml
)

destroy_vms() {
  echo "[INFO] Apagando VMs Ceph si estan activas..."
  for vm in "${VM_NAMES[@]}"; do
    sudo virsh destroy "$vm" >/dev/null 2>&1 || true
  done
}

undefine_vms() {
  echo "[INFO] Eliminando definiciones de VMs Ceph..."
  for vm in "${VM_NAMES[@]}"; do
    sudo virsh undefine "$vm" --nvram >/dev/null 2>&1 || sudo virsh undefine "$vm" >/dev/null 2>&1 || true
  done
}

remove_disks() {
  echo "[INFO] Borrando discos qcow2 de Ceph..."
  for disk in "${DISKS[@]}"; do
    sudo rm -f "$disk"
  done
}

remove_network() {
  echo "[INFO] Eliminando red $CEPH_NET..."
  sudo virsh net-destroy "$CEPH_NET" >/dev/null 2>&1 || true
  sudo virsh net-undefine "$CEPH_NET" >/dev/null 2>&1 || true
}

remove_temp_files() {
  echo "[INFO] Borrando temporales cloud-init y XML..."
  rm -f "${CLOUD_FILES[@]}"
}

show_status() {
  echo "[INFO] VMs actuales:"
  sudo virsh list --all || true

  echo
  echo "[INFO] Redes actuales:"
  sudo virsh net-list --all || true

  echo
  echo "[INFO] Discos restantes de Ceph en $IMG_DIR:"
  sudo ls -1 "$IMG_DIR" | grep -E '^ceph-.*\.qcow2$' || true
}


echo "[INFO] Iniciando limpieza total del laboratorio Ceph..."
destroy_vms
undefine_vms
remove_disks
remove_network
remove_temp_files
show_status

echo
echo "[OK] Limpieza finalizada."
