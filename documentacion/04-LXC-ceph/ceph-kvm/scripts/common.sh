#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/config/cluster.env"

CEPH_VMS=(ceph-admin ceph-mon ceph-1 ceph-2 ceph-3)
CEPH_NETWORKS=("${ADMIN_NET_NAME}" "${DATA_NET_NAME}")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_title() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}================================================${NC}"
}

require_cmd() {
    local cmd="$1"
    command -v "${cmd}" >/dev/null 2>&1 || {
        log_error "Missing command: ${cmd}"
        exit 1
    }
}

ensure_workdirs() {
    mkdir -p "${WORKDIR}/images" "${WORKDIR}/vms" "${WORKDIR}/seed" "${WORKDIR}/tmp"
    chmod 755 "${WORKDIR}" "${WORKDIR}/images" "${WORKDIR}/vms" "${WORKDIR}/seed" "${WORKDIR}/tmp"
}

ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

ssh_run() {
    local ip="$1"
    shift
    ssh "${ssh_opts[@]}" -i "${SSH_PRIVATE_KEY}" "${SSH_USER}@${ip}" "$@"
}

scp_to() {
    local src="$1"
    local ip="$2"
    local dst="$3"
    scp "${ssh_opts[@]}" -i "${SSH_PRIVATE_KEY}" "${src}" "${SSH_USER}@${ip}:${dst}"
}

wait_for_ssh() {
    local ip="$1"
    local attempts="${2:-60}"

    for _ in $(seq 1 "${attempts}"); do
        if ssh "${ssh_opts[@]}" -i "${SSH_PRIVATE_KEY}" "${SSH_USER}@${ip}" "echo ok" >/dev/null 2>&1; then
            return 0
        fi
        sleep 5
    done

    return 1
}

vm_exists() {
    local vm_name="$1"
    virsh dominfo "${vm_name}" >/dev/null 2>&1
}

vm_state() {
    local vm_name="$1"
    virsh domstate "${vm_name}" 2>/dev/null | tr -d '\r'
}

network_exists() {
    local network_name="$1"
    virsh net-info "${network_name}" >/dev/null 2>&1
}
