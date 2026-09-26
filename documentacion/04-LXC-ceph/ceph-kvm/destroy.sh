#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/common.sh"

log_title "Destroying Ceph KVM lab"

for vm in "${CEPH_VMS[@]}"; do
    if vm_exists "${vm}"; then
        virsh destroy "${vm}" >/dev/null 2>&1 || true
        virsh undefine "${vm}" --remove-all-storage --nvram >/dev/null 2>&1 || virsh undefine "${vm}" --remove-all-storage >/dev/null 2>&1 || true
        log_info "Removed VM ${vm}"
    else
        log_info "VM ${vm} does not exist"
    fi
done

for net in "${CEPH_NETWORKS[@]}"; do
    if network_exists "${net}"; then
        virsh net-destroy "${net}" >/dev/null 2>&1 || true
        virsh net-undefine "${net}" >/dev/null 2>&1 || true
        log_info "Removed network ${net}"
    fi
done

log_info "Deleting local workdir ${WORKDIR}"
rm -rf "${WORKDIR}"

log_info "Cleanup completed"
