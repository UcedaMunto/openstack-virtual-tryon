#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/common.sh"

log_title "Starting Ceph KVM lab"

for net in "${CEPH_NETWORKS[@]}"; do
    if network_exists "${net}"; then
        if [[ "$(virsh net-info "${net}" | awk -F': +' '/Active/ {print $2}')" != "yes" ]]; then
            virsh net-start "${net}"
            log_info "Started network ${net}"
        else
            log_info "Network ${net} already active"
        fi
    else
        log_warn "Network ${net} does not exist. Run ./up.sh or ./reset.sh"
    fi
done

for vm in "${CEPH_VMS[@]}"; do
    if vm_exists "${vm}"; then
        if [[ "$(vm_state "${vm}")" == "running" ]]; then
            log_info "VM ${vm} already running"
        else
            virsh start "${vm}" >/dev/null
            log_info "Started VM ${vm}"
        fi
    else
        log_warn "VM ${vm} does not exist. Run ./up.sh or ./reset.sh"
    fi
done

log_info "Start sequence finished"
