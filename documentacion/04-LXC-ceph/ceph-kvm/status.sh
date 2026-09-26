#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/scripts/common.sh"

log_title "Ceph KVM lab status"

echo "Networks:"
for net in "${CEPH_NETWORKS[@]}"; do
    if network_exists "${net}"; then
        virsh net-info "${net}" | sed 's/^/  /'
    else
        echo "  ${net}: not defined"
    fi
done

echo ""
echo "VMs:"
for vm in "${CEPH_VMS[@]}"; do
    if vm_exists "${vm}"; then
        echo "  ${vm}: $(vm_state "${vm}")"
    else
        echo "  ${vm}: not defined"
    fi
done
