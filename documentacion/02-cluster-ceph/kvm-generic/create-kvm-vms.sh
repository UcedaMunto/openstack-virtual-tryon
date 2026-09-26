#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREATE_ONE_VM_SH="$SCRIPT_DIR/create-kvm-vm.sh"
INVENTORY_FILE="${INVENTORY_FILE:-$SCRIPT_DIR/vm-inventory.conf}"
GENERATE_COMMANDS_ONLY="false"
COMMANDS_FILE=""
LOGS_DIR="${LOGS_DIR:-$SCRIPT_DIR/logs}"

resolve_commands_output_file() {
  local bucket_min
  bucket_min=$(( (10#$(date +%M) / 10) * 10 ))
  printf '%s/%s-%02d.txt' "$LOGS_DIR" "$(date +%m-%d-%H)" "$bucket_min"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --comandos)
      GENERATE_COMMANDS_ONLY="true"
      shift
      ;;
    --comandos-file)
      COMMANDS_FILE="$2"
      shift 2
      ;;
    --logs-dir)
      LOGS_DIR="$2"
      shift 2
      ;;
    --inventory-file)
      INVENTORY_FILE="$2"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Uso:
  bash create-kvm-vms.sh [--inventory-file /ruta/inventario] [--comandos] [--comandos-file /ruta/archivo] [--logs-dir /ruta/logs]

Opciones:
- --inventory-file: ruta del inventario a usar.
- --comandos: no crea VMs; genera comandos paso a paso comentados.
- --comandos-file: archivo destino para comandos generados.
- --logs-dir: directorio base para comandos si no envias --comandos-file.
EOF
      exit 0
      ;;
    *)
      echo "[ERROR] Opcion no valida: $1"
      exit 1
      ;;
  esac
done

if [[ ! -x "$CREATE_ONE_VM_SH" ]]; then
  echo "[ERROR] No se puede ejecutar: $CREATE_ONE_VM_SH"
  echo "Asegura permisos con: chmod +x $CREATE_ONE_VM_SH"
  exit 1
fi

if [[ ! -f "$INVENTORY_FILE" ]]; then
  echo "[ERROR] No existe inventario: $INVENTORY_FILE"
  exit 1
fi

echo "[INFO] Leyendo inventario: $INVENTORY_FILE"

if [[ "$GENERATE_COMMANDS_ONLY" == "true" && -z "$COMMANDS_FILE" ]]; then
  COMMANDS_FILE="$(resolve_commands_output_file)"
fi

DEFAULT_VM_USER="${VM_USER:-ceph}"
DEFAULT_VM_PASSWORD="${VM_PASSWORD:-ceph1234}"

while IFS='|' read -r vm_name vm_hostname ram_mb vcpus system_disk_gb data_disk_gb libvirt_nets ifaces_spec extra_hosts vm_user vm_password first_boot_script primary_mac; do
  [[ -z "${vm_name// }" ]] && continue
  [[ "$vm_name" =~ ^# ]] && continue

  vm_hostname="${vm_hostname:-$vm_name}"
  ram_mb="${ram_mb:-2048}"
  vcpus="${vcpus:-2}"
  system_disk_gb="${system_disk_gb:-20}"
  data_disk_gb="${data_disk_gb:-0}"
  libvirt_nets="${libvirt_nets:-ceph-net}"
  vm_user="${vm_user:-$DEFAULT_VM_USER}"
  vm_password="${vm_password:-$DEFAULT_VM_PASSWORD}"

  if [[ "$GENERATE_COMMANDS_ONLY" == "true" ]]; then
    echo "[INFO] Generando comandos para VM: $vm_name"
  else
    echo "[INFO] Creando/validando VM: $vm_name"
  fi

  cmd=(bash "$CREATE_ONE_VM_SH" \
    --name "$vm_name" \
    --hostname "$vm_hostname" \
    --user "$vm_user" \
    --password "$vm_password" \
    --ram "$ram_mb" \
    --vcpus "$vcpus" \
    --system-disk "$system_disk_gb" \
    --data-disk "$data_disk_gb" \
    --libvirt-nets "$libvirt_nets" \
    --ifaces "$ifaces_spec" \
    --extra-hosts "$extra_hosts" \
    --first-boot-script "$first_boot_script" \
    --primary-mac "$primary_mac")

  if [[ "$GENERATE_COMMANDS_ONLY" == "true" ]]; then
    cmd+=(--comandos)
    cmd+=(--comandos-file "$COMMANDS_FILE")
    cmd+=(--logs-dir "$LOGS_DIR")
  fi

  "${cmd[@]}"
done < "$INVENTORY_FILE"

if [[ "$GENERATE_COMMANDS_ONLY" == "true" ]]; then
  echo "[OK] Comandos de todas las VMs generados."
  echo "[INFO] Archivo: $COMMANDS_FILE"
else
  echo "[OK] Proceso de VMs en lote finalizado."
fi
