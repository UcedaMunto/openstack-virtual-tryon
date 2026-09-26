#!/usr/bin/env bash
set -euo pipefail

IMG_DIR="${IMG_DIR:-/var/lib/libvirt/images}"

VM_NAME=""
REMOVE_KNOWN_HOSTS="false"

usage() {
  cat <<'EOF'
Uso:
  bash delete-kvm-vm.sh --name n-admin

Opciones:
- --name: nombre de la VM en libvirt.
- --remove-known-hosts: elimina entradas SSH del host para las IPs actuales de la VM.

Que limpia:
- dominio libvirt
- discos adjuntos a la VM
- archivos temporales /tmp/user-data-<vm>.yaml
- archivos temporales /tmp/network-config-<vm>.yaml
- imagenes seed/cloud-init comunes si existen en el pool de imagenes
EOF
}

collect_vm_ips() {
  local vm_name="$1"
  sudo virsh domifaddr "$vm_name" 2>/dev/null | awk '/ipv4/ {split($4, a, "/"); print a[1]}' || true
}

collect_vm_disks() {
  local vm_name="$1"
  sudo virsh domblklist "$vm_name" --details 2>/dev/null | awk '$1 == "file" && $2 == "disk" {print $4}' || true
}

remove_known_hosts_entries() {
  local vm_name="$1"
  local vm_ips
  vm_ips="$(collect_vm_ips "$vm_name")"

  if [[ -z "${vm_ips// }" ]]; then
    echo "[INFO] No se detectaron IPs para limpiar known_hosts."
    return
  fi

  while IFS= read -r vm_ip; do
    [[ -z "${vm_ip// }" ]] && continue
    ssh-keygen -R "$vm_ip" >/dev/null 2>&1 || true
    echo "[INFO] known_hosts limpiado para $vm_ip"
  done <<< "$vm_ips"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      VM_NAME="$2"
      shift 2
      ;;
    --remove-known-hosts)
      REMOVE_KNOWN_HOSTS="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Opcion no valida: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$VM_NAME" ]]; then
  echo "[ERROR] --name es obligatorio"
  usage
  exit 1
fi

echo "[INFO] Preparando eliminacion de VM: $VM_NAME"

VM_DISKS="$(collect_vm_disks "$VM_NAME")"

if sudo virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "[INFO] Apagando VM si esta encendida..."
  sudo virsh destroy "$VM_NAME" >/dev/null 2>&1 || true

  echo "[INFO] Eliminando definicion libvirt..."
  sudo virsh undefine "$VM_NAME" --nvram --managed-save --snapshots-metadata >/dev/null 2>&1 \
    || sudo virsh undefine "$VM_NAME" --managed-save --snapshots-metadata >/dev/null 2>&1 \
    || sudo virsh undefine "$VM_NAME" >/dev/null 2>&1
else
  echo "[WARN] La VM $VM_NAME no existe en libvirt. Continuando con limpieza de archivos."
fi

if [[ -n "${VM_DISKS// }" ]]; then
  echo "[INFO] Eliminando discos adjuntos..."
  while IFS= read -r disk_path; do
    [[ -z "${disk_path// }" ]] && continue
    if [[ -f "$disk_path" ]]; then
      sudo rm -f "$disk_path"
      echo "[INFO] Eliminado: $disk_path"
    fi
  done <<< "$VM_DISKS"
fi

EXTRA_FILES=(
  "/tmp/user-data-${VM_NAME}.yaml"
  "/tmp/network-config-${VM_NAME}.yaml"
  "$IMG_DIR/${VM_NAME}-seed.iso"
  "$IMG_DIR/${VM_NAME}-cidata.iso"
  "$IMG_DIR/${VM_NAME}-cloudinit.iso"
  "$IMG_DIR/${VM_NAME}-seed.img"
)

echo "[INFO] Limpiando archivos auxiliares..."
for extra_file in "${EXTRA_FILES[@]}"; do
  if [[ -f "$extra_file" ]]; then
    sudo rm -f "$extra_file"
    echo "[INFO] Eliminado: $extra_file"
  fi
done

if [[ "$REMOVE_KNOWN_HOSTS" == "true" ]]; then
  remove_known_hosts_entries "$VM_NAME"
fi

echo "[OK] Limpieza finalizada para $VM_NAME"
