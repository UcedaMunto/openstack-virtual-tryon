#!/usr/bin/env bash
# deploy-all.sh — despliegue completo del laboratorio desde el anfitrión.
# Ejecuta en orden las fases que corren en el host (imágenes, cloud-init, VMs)
# y al final indica los pasos que se ejecutan en k8-master.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VM_DIR="/var/lib/libvirt/images/k8s-lab"
PUBKEY="${PUBKEY:-$HOME/.ssh/id_ed25519.pub}"

step() {
  echo
  echo "=============================================================="
  echo "$1"
  echo "=============================================================="
}

step "1) Preparar imágenes (descargar base + overlays qcow2)"
"$SCRIPT_DIR/prepare-images.sh"

step "2) Generar cloud-init (user-data + meta-data + seed.iso)"
"$SCRIPT_DIR/gen-cloud-init.sh" "$PUBKEY"

step "3) Crear red libvirt + VMs (y adjuntar discos vdb)"
sudo virsh net-define "$PROJECT_DIR/net/k8s-lab-network.xml" 2>/dev/null || true
sudo virsh net-start k8s-lab 2>/dev/null || true
sudo virsh net-autostart k8s-lab 2>/dev/null || true
sudo mkdir -p "$VM_DIR"
sudo cp -f "$PROJECT_DIR/cloud-init/"*-seed.iso "$VM_DIR/" 2>/dev/null || true
"$SCRIPT_DIR/create-k8s-lab-vms.sh"

cat <<EOF

==============================================================
Fases que se ejecutan en k8-master (una vez arrancadas las VMs)
==============================================================
1) Copia este proyecto a k8-master:
   scp -r "$PROJECT_DIR" uceda@192.168.90.1:/home/uceda/

2) Entra a k8-master y ejecuta:
   ssh uceda@192.168.90.1
   cd deployment-set
   scripts/bootstrap-cluster.sh
   scripts/deploy-manifests.sh
==============================================================
EOF
