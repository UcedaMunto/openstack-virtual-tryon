#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-plan}"
KVM_DIR="/home/uceda/Documents/cluster-ceph/kvm-generic"
OUT_DIR="/home/uceda/Documents/cluster-ceph/proyecto-infraestructura/06-datos/generated"
CREATE_VM="$KVM_DIR/create-kvm-vm.sh"

NET_NAME="${NET_NAME:-net-192-168-3}"
GW="${GW:-192.168.3.1}"
DNS1="${DNS1:-192.168.3.55}"
DNS2="${DNS2:-8.8.8.8}"

mkdir -p "$OUT_DIR"
COMMANDS_FILE="$OUT_DIR/06-datos-comandos.sh"

if [[ ! -x "$CREATE_VM" ]]; then
  echo "[ERROR] No existe o no es ejecutable: $CREATE_VM"
  exit 1
fi

add_vm() {
  local name="$1"
  local ipcidr="$2"
  local ram="$3"
  local disk_data="$4"
  local mac="$5"

  bash "$CREATE_VM" \
    --name "$name" \
    --hostname "$name" \
    --user admin \
    --password admin123 \
    --ram "$ram" \
    --vcpus 2 \
    --system-disk 30 \
    --data-disk "$disk_data" \
    --libvirt-nets "$NET_NAME" \
    --ifaces "enp1s0,$ipcidr,$GW,$DNS1,$DNS2" \
    --extra-hosts "192.168.3.56 redis-1;192.168.3.60 maxscale-1;192.168.3.61 mariadb-1;192.168.3.62 mariadb-2;192.168.3.63 mariadb-3;192.168.3.64 cephfs-1" \
    --primary-mac "$mac" \
    --comandos \
    --comandos-file "$COMMANDS_FILE"
}

add_vm_apply() {
  local name="$1"
  local ipcidr="$2"
  local ram="$3"
  local disk_data="$4"
  local mac="$5"

  if ! bash "$CREATE_VM" \
    --name "$name" \
    --hostname "$name" \
    --user admin \
    --password admin123 \
    --ram "$ram" \
    --vcpus 2 \
    --system-disk 30 \
    --data-disk "$disk_data" \
    --libvirt-nets "$NET_NAME" \
    --ifaces "enp1s0,$ipcidr,$GW,$DNS1,$DNS2" \
    --extra-hosts "192.168.3.56 redis-1;192.168.3.60 maxscale-1;192.168.3.61 mariadb-1;192.168.3.62 mariadb-2;192.168.3.63 mariadb-3;192.168.3.64 cephfs-1" \
    --primary-mac "$mac"; then
    if sudo virsh dominfo "$name" >/dev/null 2>&1; then
      echo "[WARN] create-kvm-vm.sh devolvio error, pero la VM $name existe. Se continua."
    else
      echo "[ERROR] Fallo real creando $name"
      exit 1
    fi
  fi
}

generate() {
  add_vm redis-1 192.168.3.56/24 2048 0 52:54:00:cc:dd:56
  add_vm maxscale-1 192.168.3.60/24 2048 0 52:54:00:cc:dd:60
  add_vm mariadb-1 192.168.3.61/24 4096 40 52:54:00:cc:dd:61
  add_vm mariadb-2 192.168.3.62/24 4096 40 52:54:00:cc:dd:62
  add_vm mariadb-3 192.168.3.63/24 4096 40 52:54:00:cc:dd:63
  add_vm cephfs-1 192.168.3.64/24 4096 80 52:54:00:cc:dd:64
  echo "[OK] Comandos de datos generados en: $COMMANDS_FILE"
}

case "$MODE" in
  plan)
    generate
    ;;
  apply)
    generate
    add_vm_apply redis-1 192.168.3.56/24 2048 0 52:54:00:cc:dd:56
    add_vm_apply maxscale-1 192.168.3.60/24 2048 0 52:54:00:cc:dd:60
    add_vm_apply mariadb-1 192.168.3.61/24 4096 40 52:54:00:cc:dd:61
    add_vm_apply mariadb-2 192.168.3.62/24 4096 40 52:54:00:cc:dd:62
    add_vm_apply mariadb-3 192.168.3.63/24 4096 40 52:54:00:cc:dd:63
    add_vm_apply cephfs-1 192.168.3.64/24 4096 80 52:54:00:cc:dd:64
    ;;
  *)
    echo "Uso: bash 06-datos.sh [plan|apply]"
    exit 1
    ;;
esac
