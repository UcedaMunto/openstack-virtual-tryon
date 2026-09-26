#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-plan}"
KVM_DIR="/home/uceda/Documents/cluster-ceph/kvm-generic"
OUT_DIR="/home/uceda/Documents/cluster-ceph/proyecto-infraestructura/04-balanceadores-nginx/generated"
CREATE_VM="$KVM_DIR/create-kvm-vm.sh"

NET_NAME="${NET_NAME:-net-192-168-3}"
GW="${GW:-192.168.3.1}"
DNS1="${DNS1:-192.168.3.55}"
DNS2="${DNS2:-8.8.8.8}"

mkdir -p "$OUT_DIR"
COMMANDS_FILE="$OUT_DIR/04-balanceadores-comandos.sh"

if [[ ! -x "$CREATE_VM" ]]; then
  echo "[ERROR] No existe o no es ejecutable: $CREATE_VM"
  exit 1
fi

add_vm() {
  local name="$1"
  local ipcidr="$2"
  local mac="$3"

  bash "$CREATE_VM" \
    --name "$name" \
    --hostname "$name" \
    --user admin \
    --password admin123 \
    --ram 2048 \
    --vcpus 2 \
    --system-disk 20 \
    --data-disk 0 \
    --libvirt-nets "$NET_NAME" \
    --ifaces "enp1s0,$ipcidr,$GW,$DNS1,$DNS2" \
    --extra-hosts "192.168.3.50 lb1;192.168.3.51 lb2;192.168.3.52 app1;192.168.3.53 app2;192.168.3.54 app3;192.168.3.55 dns-1" \
    --primary-mac "$mac" \
    --comandos \
    --comandos-file "$COMMANDS_FILE"
}

add_vm_apply() {
  local name="$1"
  local ipcidr="$2"
  local mac="$3"

  if ! bash "$CREATE_VM" \
    --name "$name" \
    --hostname "$name" \
    --user admin \
    --password admin123 \
    --ram 2048 \
    --vcpus 2 \
    --system-disk 20 \
    --data-disk 0 \
    --libvirt-nets "$NET_NAME" \
    --ifaces "enp1s0,$ipcidr,$GW,$DNS1,$DNS2" \
    --extra-hosts "192.168.3.50 lb1;192.168.3.51 lb2;192.168.3.52 app1;192.168.3.53 app2;192.168.3.54 app3;192.168.3.55 dns-1" \
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
  add_vm lb1 192.168.3.50/24 52:54:00:cc:dd:50
  add_vm lb2 192.168.3.51/24 52:54:00:cc:dd:51
  echo "[OK] Comandos de balanceadores generados en: $COMMANDS_FILE"
}

case "$MODE" in
  plan)
    generate
    ;;
  apply)
    generate
    add_vm_apply lb1 192.168.3.50/24 52:54:00:cc:dd:50
    add_vm_apply lb2 192.168.3.51/24 52:54:00:cc:dd:51
    ;;
  *)
    echo "Uso: bash 04-balanceadores-nginx.sh [plan|apply]"
    exit 1
    ;;
esac
