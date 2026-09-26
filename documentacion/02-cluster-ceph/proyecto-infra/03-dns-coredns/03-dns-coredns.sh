#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-plan}"
KVM_DIR="/home/uceda/Documents/cluster-ceph/kvm-generic"
OUT_DIR="/home/uceda/Documents/cluster-ceph/proyecto-infraestructura/03-dns-coredns/generated"
CREATE_VM="$KVM_DIR/create-kvm-vm.sh"

NET_NAME="${NET_NAME:-net-192-168-3}"
DNS_VM_IP="${DNS_VM_IP:-192.168.3.55/24}"
DNS_GW="${DNS_GW:-192.168.3.1}"
DNS1="${DNS1:-8.8.8.8}"
DNS2="${DNS2:-1.1.1.1}"

mkdir -p "$OUT_DIR"
COMMANDS_FILE="$OUT_DIR/03-dns-comandos.sh"

if [[ ! -x "$CREATE_VM" ]]; then
  echo "[ERROR] No existe o no es ejecutable: $CREATE_VM"
  exit 1
fi

generate() {
  bash "$CREATE_VM" \
    --name dns-1 \
    --hostname dns-1 \
    --user admin \
    --password admin123 \
    --ram 2048 \
    --vcpus 2 \
    --system-disk 20 \
    --data-disk 0 \
    --libvirt-nets "$NET_NAME" \
    --ifaces "enp1s0,$DNS_VM_IP,$DNS_GW,$DNS1,$DNS2" \
    --extra-hosts "192.168.3.50 lb1;192.168.3.51 lb2;192.168.3.52 app1;192.168.3.53 app2;192.168.3.54 app3;192.168.3.55 dns-1" \
    --primary-mac "52:54:00:cc:dd:55" \
    --comandos \
    --comandos-file "$COMMANDS_FILE"

  echo "[OK] Comandos DNS generados en: $COMMANDS_FILE"
}

apply_vm() {
  if ! bash "$CREATE_VM" \
    --name dns-1 \
    --hostname dns-1 \
    --user admin \
    --password admin123 \
    --ram 2048 \
    --vcpus 2 \
    --system-disk 20 \
    --data-disk 0 \
    --libvirt-nets "$NET_NAME" \
    --ifaces "enp1s0,$DNS_VM_IP,$DNS_GW,$DNS1,$DNS2" \
    --extra-hosts "192.168.3.50 lb1;192.168.3.51 lb2;192.168.3.52 app1;192.168.3.53 app2;192.168.3.54 app3;192.168.3.55 dns-1" \
    --primary-mac "52:54:00:cc:dd:55"; then
    if sudo virsh dominfo dns-1 >/dev/null 2>&1; then
      echo "[WARN] create-kvm-vm.sh devolvio error, pero la VM dns-1 existe. Se continua."
    else
      echo "[ERROR] Fallo real creando dns-1"
      exit 1
    fi
  fi
}

case "$MODE" in
  plan)
    generate
    ;;
  apply)
    generate
    apply_vm
    ;;
  *)
    echo "Uso: bash 03-dns-coredns.sh [plan|apply]"
    exit 1
    ;;
esac
