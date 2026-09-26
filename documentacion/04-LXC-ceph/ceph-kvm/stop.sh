#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/common.sh"

log_title "Stopping Ceph KVM lab"

for vm in "${CEPH_VMS[@]}"; do
    if vm_exists "${vm}"; then
        if [[ "$(vm_state "${vm}")" == "running" ]]; then
            virsh shutdown "${vm}" >/dev/null || true
            log_info "Sent shutdown to ${vm}"
        else
            log_info "VM ${vm} already stopped"
        fi
    else
        log_info "VM ${vm} does not exist"
    fi
done

log_warn "If a VM does not stop cleanly, use: virsh destroy <vm-name>"
