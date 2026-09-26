#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Estado de VMs"
sudo virsh list --all

echo
echo "[INFO] Estado de redes"
sudo virsh net-list --all

echo
echo "[INFO] IPs detectadas (si hay guest-agent)"
for vm in ceph-admin dns-1 lb1 lb2 app1 app2 app3 redis-1 maxscale-1 mariadb-1 mariadb-2 mariadb-3 cephfs-1; do
  if sudo virsh dominfo "$vm" >/dev/null 2>&1; then
    echo "--- $vm ---"
    if ! sudo virsh domifaddr "$vm" --source agent 2>/dev/null; then
      if ! sudo virsh domifaddr "$vm" --source lease 2>/dev/null; then
        echo "[WARN] Sin IP aun (guest-agent/dhcp lease no disponible)"
      fi
    fi
  fi
done
