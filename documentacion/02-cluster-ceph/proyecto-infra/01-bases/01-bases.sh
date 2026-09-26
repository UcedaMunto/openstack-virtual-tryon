#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-plan}"
KVM_DIR="/home/uceda/Documents/cluster-ceph/kvm-generic"
OUT_DIR="/home/uceda/Documents/cluster-ceph/proyecto-infraestructura/01-bases/generated"
CREATE_VM="$KVM_DIR/create-kvm-vm.sh"

NET_NAME="${NET_NAME:-net-192-168-3}"
ADMIN_IP_CIDR="${ADMIN_IP_CIDR:-192.168.3.10/24}"
ADMIN_GW="${ADMIN_GW:-192.168.3.1}"
ADMIN_DNS1="${ADMIN_DNS1:-8.8.8.8}"
ADMIN_DNS2="${ADMIN_DNS2:-8.8.4.4}"

mkdir -p "$OUT_DIR"
COMMANDS_FILE="$OUT_DIR/01-bases-comandos.sh"

if [[ ! -x "$CREATE_VM" ]]; then
  echo "[ERROR] No existe o no es ejecutable: $CREATE_VM"
  exit 1
fi

run_plan() {
  bash "$CREATE_VM" \
    --name ceph-admin \
    --hostname ceph-admin \
    --user admin \
    --password admin123 \
    --ram 2048 \
    --vcpus 2 \
    --system-disk 20 \
    --data-disk 0 \
    --libvirt-nets "$NET_NAME" \
    --ifaces "enp1s0,$ADMIN_IP_CIDR,$ADMIN_GW,$ADMIN_DNS1,$ADMIN_DNS2" \
    --extra-hosts "192.168.3.10 ceph-admin;192.168.3.11 ceph-mon;192.168.3.12 ceph-osd1;192.168.3.13 ceph-osd2;192.168.3.14 ceph-osd3" \
    --primary-mac "52:54:00:cc:dd:10" \
    --comandos \
    --comandos-file "$COMMANDS_FILE"

  echo "[OK] Comandos base generados en: $COMMANDS_FILE"
}

run_apply() {
  if ! bash "$CREATE_VM" \
    --name ceph-admin \
    --hostname ceph-admin \
    --user admin \
    --password admin123 \
    --ram 2048 \
    --vcpus 2 \
    --system-disk 20 \
    --data-disk 0 \
    --libvirt-nets "$NET_NAME" \
    --ifaces "enp1s0,$ADMIN_IP_CIDR,$ADMIN_GW,$ADMIN_DNS1,$ADMIN_DNS2" \
    --extra-hosts "192.168.3.10 ceph-admin;192.168.3.11 ceph-mon;192.168.3.12 ceph-osd1;192.168.3.13 ceph-osd2;192.168.3.14 ceph-osd3" \
    --primary-mac "52:54:00:cc:dd:10"; then
    if sudo virsh dominfo ceph-admin >/dev/null 2>&1; then
      echo "[WARN] create-kvm-vm.sh devolvio error, pero la VM ceph-admin existe. Se continua."
    else
      echo "[ERROR] Fallo real creando ceph-admin"
      exit 1
    fi
  fi
}

case "$MODE" in
  plan)
    run_plan
    ;;
  apply)
    run_plan
    run_apply
    ;;
  *)
    echo "Uso: bash 01-bases.sh [plan|apply]"
    exit 1
    ;;
esac
