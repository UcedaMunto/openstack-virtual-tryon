#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/common.sh"

gateway_from_cidr() {
    local cidr="$1"
    local network_ip="${cidr%%/*}"
    echo "${network_ip%.*}.1"
}

admin_gateway="$(gateway_from_cidr "${ADMIN_NET_CIDR}")"
data_gateway="$(gateway_from_cidr "${DATA_NET_CIDR}")"

create_network() {
    local name="$1"
    local bridge="$2"
    local cidr="$3"
    local gateway="$4"

    if virsh net-info "${name}" >/dev/null 2>&1; then
        log_info "Network ${name} already exists"
        return 0
    fi

    local xml_file="${WORKDIR}/tmp/${name}.xml"

    cat > "${xml_file}" <<EOF
<network>
  <name>${name}</name>
  <bridge name='${bridge}' stp='on' delay='0'/>
  <forward mode='nat'/>
  <ip address='${gateway}' netmask='255.255.255.0'/>
</network>
EOF

    virsh net-define "${xml_file}"
    virsh net-autostart "${name}"
    virsh net-start "${name}"

    log_info "Created network ${name} (${cidr})"
}

log_title "Creating libvirt networks"
ensure_workdirs

create_network "${ADMIN_NET_NAME}" "vbrcadmin" "${ADMIN_NET_CIDR}" "${admin_gateway}"
create_network "${DATA_NET_NAME}" "vbrcdata" "${DATA_NET_CIDR}" "${data_gateway}"

log_info "Network setup completed"
