#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/common.sh"

log_title "Prerequisites"

for cmd in virsh virt-install qemu-img cloud-localds ssh scp; do
    require_cmd "${cmd}"
done

if [[ ! -f "${SSH_PUBLIC_KEY}" ]]; then
    log_warn "SSH key not found at ${SSH_PUBLIC_KEY}. Generating one..."
    mkdir -p "$(dirname "${SSH_PRIVATE_KEY}")"
    ssh-keygen -t rsa -b 4096 -N "" -f "${SSH_PRIVATE_KEY}"
fi

ensure_workdirs

if [[ ! -f "${BASE_IMAGE}" ]]; then
    log_info "Downloading Ubuntu cloud image..."
    curl -L "${BASE_IMAGE_URL}" -o "${BASE_IMAGE}"
else
    log_info "Base image already present: ${BASE_IMAGE}"
fi

chmod 644 "${BASE_IMAGE}"

log_info "All prerequisites are ready"
