#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/common.sh"

create_seed() {
    local name="$1"
    local admin_ip="$2"
  local admin_mac="$3"

    local user_data="${WORKDIR}/seed/${name}-user-data.yaml"
    local meta_data="${WORKDIR}/seed/${name}-meta-data.yaml"
    local net_cfg="${WORKDIR}/seed/${name}-network.yaml"
    local seed_iso="${WORKDIR}/seed/${name}-seed.iso"

    cat > "${user_data}" <<EOF
#cloud-config
users:
  - name: ${SSH_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "${SSH_PUBLIC_KEY}")
runcmd:
  - apt-get install -y qemu-guest-agent openssh-server >/dev/null 2>&1 || true
  - systemctl enable --now qemu-guest-agent || true
  - systemctl enable --now ssh || true
EOF

    cat > "${meta_data}" <<EOF
instance-id: ${name}
local-hostname: ${name}
EOF

    cat > "${net_cfg}" <<EOF
version: 2
ethernets:
  admin0:
    dhcp4: false
    match:
      macaddress: "${admin_mac}"
    set-name: admin0
    addresses: [${admin_ip}/24]
    gateway4: ${CEPH_ADMIN_IP%.*}.1
    nameservers:
      addresses: [${CEPH_ADMIN_IP%.*}.1, 1.1.1.1, 8.8.8.8]
EOF

    cloud-localds --network-config "${net_cfg}" "${seed_iso}" "${user_data}" "${meta_data}"
    chmod 644 "${user_data}" "${meta_data}" "${net_cfg}" "${seed_iso}"
    echo "${seed_iso}"
}

admin_mac_for_vm() {
  case "$1" in
    ceph-admin) echo "52:54:00:13:00:64" ;;
    ceph-mon) echo "52:54:00:13:00:0a" ;;
    ceph-1) echo "52:54:00:13:00:11" ;;
    ceph-2) echo "52:54:00:13:00:12" ;;
    ceph-3) echo "52:54:00:13:00:13" ;;
    *) echo "52:54:00:13:00:fe" ;;
  esac
}

data_mac_for_vm() {
  case "$1" in
    ceph-1) echo "52:54:00:14:00:11" ;;
    ceph-2) echo "52:54:00:14:00:12" ;;
    ceph-3) echo "52:54:00:14:00:13" ;;
    *) echo "" ;;
  esac
}

create_vm() {
    local name="$1"
    local admin_ip="$2"
    local data_ip="${3:-}"
  local admin_mac
  local data_mac

  admin_mac="$(admin_mac_for_vm "${name}")"
  data_mac="$(data_mac_for_vm "${name}")"

    if vm_exists "${name}"; then
        log_info "VM ${name} already exists"
        return 0
    fi

    local vm_disk="${WORKDIR}/vms/${name}.qcow2"
    qemu-img create -f qcow2 -F qcow2 -b "${BASE_IMAGE}" "${vm_disk}" 40G >/dev/null
  chmod 666 "${vm_disk}"

    local seed_iso
  seed_iso="$(create_seed "${name}" "${admin_ip}" "${admin_mac}")"

    local args=(
        --name "${name}"
        --memory "${VM_MEMORY_MB}"
        --vcpus "${VM_CPUS}"
        --cpu host-passthrough
        --disk "path=${vm_disk},format=qcow2,bus=virtio"
        --disk "path=${seed_iso},device=cdrom"
        --network "network=${ADMIN_NET_NAME},model=virtio,mac=${admin_mac}"
        --graphics none
        --console pty,target_type=serial
        --import
        --noautoconsole
        --osinfo detect=on,require=off
    )

    if [[ -n "${data_ip}" ]]; then
        local osd_disk="${WORKDIR}/vms/${name}-osd.qcow2"
        qemu-img create -f qcow2 "${osd_disk}" "${OSD_DATA_DISK_GB}G" >/dev/null
      chmod 666 "${osd_disk}"
      args+=(--network "network=${DATA_NET_NAME},model=virtio,mac=${data_mac}")
        args+=(--disk "path=${osd_disk},format=qcow2,bus=virtio")
    fi

    virt-install "${args[@]}"
    log_info "VM ${name} created"
}

log_title "Creating Ceph VMs"
ensure_workdirs

create_vm "ceph-admin" "${CEPH_ADMIN_IP}"
create_vm "ceph-mon" "${CEPH_MON_IP}"
create_vm "ceph-1" "${CEPH_1_ADMIN_IP}" "${CEPH_1_DATA_IP}" "0"
create_vm "ceph-2" "${CEPH_2_ADMIN_IP}" "${CEPH_2_DATA_IP}" "1"
create_vm "ceph-3" "${CEPH_3_ADMIN_IP}" "${CEPH_3_DATA_IP}" "2"

log_info "VM creation finished"
