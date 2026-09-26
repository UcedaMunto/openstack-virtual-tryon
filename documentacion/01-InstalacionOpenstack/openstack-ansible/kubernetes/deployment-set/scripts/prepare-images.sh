#!/usr/bin/env bash
# prepare-images.sh: descarga la imagen cloud base de Ubuntu 24.04 y crea los
# discos qcow2 derivados (overlays) de cada VM del laboratorio.
# Ejecutar en el anfitrion (host KVM/libvirt).
set -euo pipefail

VM_DIR="/var/lib/libvirt/images/k8s-lab"
BASE_IMG_NAME="noble-server-cloudimg-amd64.img"
BASE_IMG_URL="https://cloud-images.ubuntu.com/noble/current/${BASE_IMG_NAME}"
BASE_IMG="${VM_DIR}/${BASE_IMG_NAME}"

sudo mkdir -p "$VM_DIR"

# 1) Descargar la imagen base (si no existe).
if [[ -f "$BASE_IMG" ]]; then
  echo "Imagen base ya existe: $BASE_IMG"
else
  echo "Descargando imagen base: $BASE_IMG_URL"
  sudo curl -fL -o "$BASE_IMG" "$BASE_IMG_URL"
fi

# 2) Detectar el formato real de la imagen base (qcow2/raw) para -F.
BASE_FMT="$(sudo qemu-img info "$BASE_IMG" | awk -F': ' '/file format/ {print $2; exit}')"
echo "Formato de la imagen base: $BASE_FMT"
test -n "$BASE_FMT" || { echo "No se pudo detectar el formato de la imagen base"; exit 1; }

# 3) Crear overlays por VM (idempotente).
create_overlay() {
  local name="$1" size="$2"
  local disk="$VM_DIR/${name}.qcow2"
  if [[ -f "$disk" ]]; then
    echo "Ya existe: $disk; se omite"
  else
    echo "Creando overlay: $disk ($size)"
    sudo qemu-img create -f qcow2 -F "$BASE_FMT" -b "$BASE_IMG" "$disk" "$size"
  fi
}

create_overlay k8-master  30G
create_overlay k8-worker1 40G
create_overlay k8-worker2 40G
create_overlay k8-worker3 40G
create_overlay k8-worker4 40G
create_overlay ceph-admin 30G

echo "Imágenes listas en $VM_DIR"
