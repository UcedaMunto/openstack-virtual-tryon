#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/common.sh"

log_title "Bootstrap Ceph on KVM"

configure_osd_data_nic() {
    local ip="$1"
    local data_ip="$2"
    local data_mac="$3"

    ssh_run "${ip}" "cat <<'EOF' | sudo tee /etc/netplan/60-ceph-data.yaml >/dev/null
network:
    version: 2
    ethernets:
        data0:
            dhcp4: false
            match:
                macaddress: \"${data_mac}\"
            set-name: data0
            addresses:
                - ${data_ip}/24
EOF"
    ssh_run "${ip}" "sudo chmod 600 /etc/netplan/60-ceph-data.yaml && sudo netplan generate && sudo netplan apply"
}

wait_for_apt_locks() {
    local ip="$1"
    ssh_run "${ip}" "sudo bash -lc 'for _ in {1..60}; do if ! fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; then exit 0; fi; sleep 5; done; exit 1'"
}

for ip in "${CEPH_ADMIN_IP}" "${CEPH_MON_IP}" "${CEPH_1_ADMIN_IP}" "${CEPH_2_ADMIN_IP}" "${CEPH_3_ADMIN_IP}"; do
    log_info "Waiting for SSH on ${ip}..."
    if ! wait_for_ssh "${ip}" 200; then
        log_error "SSH did not become ready on ${ip}"
        exit 1
    fi
done

install_repo_and_packages() {
    local ip="$1"
    local role="$2"

    local pkg_set="ceph ceph-common"
    if [[ "${role}" == "admin" ]]; then
        pkg_set="ceph ceph-common ceph-mon ceph-osd ceph-mgr"
    elif [[ "${role}" == "mon" ]]; then
        pkg_set="ceph ceph-common ceph-mon"
    elif [[ "${role}" == "osd" ]]; then
        pkg_set="ceph ceph-common ceph-osd ceph-volume lvm2"
    fi

    wait_for_apt_locks "${ip}"
    ssh_run "${ip}" "sudo apt-get -o DPkg::Lock::Timeout=300 update -qq"
    ssh_run "${ip}" "sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y -qq curl gnupg ca-certificates lsb-release ubuntu-keyring"
    ssh_run "${ip}" "curl -fsSL https://download.ceph.com/keys/release.asc -o /tmp/ceph-release.asc && sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/ceph-archive-keyring.gpg /tmp/ceph-release.asc && rm -f /tmp/ceph-release.asc"
    ssh_run "${ip}" "echo 'deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-quincy jammy main' | sudo tee /etc/apt/sources.list.d/ceph.list >/dev/null"
    ssh_run "${ip}" "sudo apt-get -o DPkg::Lock::Timeout=300 update -qq"
    ssh_run "${ip}" "if ! command -v ceph >/dev/null 2>&1; then sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y -qq ${pkg_set}; fi"
}

get_existing_fsid() {
    local ip="$1"
    ssh_run "${ip}" "if [[ -f /etc/ceph/ceph.conf ]]; then awk -F'=' '/^fsid/{gsub(/ /,\"\",\$2); print \$2; exit}' /etc/ceph/ceph.conf; fi" || true
}

log_title "Installing Ceph packages"
install_repo_and_packages "${CEPH_ADMIN_IP}" "admin"
install_repo_and_packages "${CEPH_MON_IP}" "mon"
install_repo_and_packages "${CEPH_1_ADMIN_IP}" "osd"
install_repo_and_packages "${CEPH_2_ADMIN_IP}" "osd"
install_repo_and_packages "${CEPH_3_ADMIN_IP}" "osd"

log_title "Configuring OSD data network"
configure_osd_data_nic "${CEPH_1_ADMIN_IP}" "${CEPH_1_DATA_IP}" "52:54:00:14:00:11"
configure_osd_data_nic "${CEPH_2_ADMIN_IP}" "${CEPH_2_DATA_IP}" "52:54:00:14:00:12"
configure_osd_data_nic "${CEPH_3_ADMIN_IP}" "${CEPH_3_DATA_IP}" "52:54:00:14:00:13"

existing_fsid="$(get_existing_fsid "${CEPH_MON_IP}")"
if [[ -z "${existing_fsid}" ]]; then
    existing_fsid="$(get_existing_fsid "${CEPH_ADMIN_IP}")"
fi

if [[ -n "${existing_fsid}" ]]; then
    FSID="${existing_fsid}"
    log_info "Reusing existing Cluster FSID: ${FSID}"
else
    FSID="$(uuidgen)"
    log_info "Cluster FSID: ${FSID}"
fi

ceph_conf="${WORKDIR}/tmp/ceph.conf"
cat > "${ceph_conf}" <<EOF
[global]
fsid = ${FSID}
mon_initial_members = ceph-mon
mon_host = ${CEPH_MON_IP}
public_network = ${ADMIN_NET_CIDR}
cluster_network = ${DATA_NET_CIDR}
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
osd_pool_default_size = 3
osd_pool_default_min_size = 2
osd_crush_chooseleaf_type = 1

[mon.ceph-mon]
host = ceph-mon
addr = ${CEPH_MON_IP}

[osd.0]
host = ceph-1
public_addr = ${CEPH_1_ADMIN_IP}
cluster_addr = ${CEPH_1_DATA_IP}

[osd.1]
host = ceph-2
public_addr = ${CEPH_2_ADMIN_IP}
cluster_addr = ${CEPH_2_DATA_IP}

[osd.2]
host = ceph-3
public_addr = ${CEPH_3_ADMIN_IP}
cluster_addr = ${CEPH_3_DATA_IP}
EOF

for ip in "${CEPH_ADMIN_IP}" "${CEPH_MON_IP}" "${CEPH_1_ADMIN_IP}" "${CEPH_2_ADMIN_IP}" "${CEPH_3_ADMIN_IP}"; do
    scp_to "${ceph_conf}" "${ip}" "/tmp/ceph.conf"
    ssh_run "${ip}" "sudo mkdir -p /etc/ceph && sudo mv /tmp/ceph.conf /etc/ceph/ceph.conf"
done

log_title "Creating keyrings and monmap"
ssh_run "${CEPH_ADMIN_IP}" "if [[ ! -f /etc/ceph/ceph.client.admin.keyring ]]; then sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mgr 'allow *' --cap mds 'allow *'; fi"
ssh_run "${CEPH_ADMIN_IP}" "if [[ ! -f /tmp/ceph.mon.keyring ]]; then sudo ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'; sudo ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring; fi"
ssh_run "${CEPH_ADMIN_IP}" "sudo monmaptool --clobber --create --add ceph-mon ${CEPH_MON_IP} --fsid ${FSID} /tmp/monmap"

admin_keyring_local="${WORKDIR}/tmp/ceph.client.admin.keyring"
mon_keyring_local="${WORKDIR}/tmp/ceph.mon.keyring"
monmap_local="${WORKDIR}/tmp/monmap"

ssh_run "${CEPH_ADMIN_IP}" "sudo cat /etc/ceph/ceph.client.admin.keyring" > "${admin_keyring_local}"
ssh_run "${CEPH_ADMIN_IP}" "sudo cat /tmp/ceph.mon.keyring" > "${mon_keyring_local}"
ssh_run "${CEPH_ADMIN_IP}" "sudo cat /tmp/monmap" > "${monmap_local}"

scp_to "${mon_keyring_local}" "${CEPH_MON_IP}" "/tmp/ceph.mon.keyring"
scp_to "${monmap_local}" "${CEPH_MON_IP}" "/tmp/monmap"
ssh_run "${CEPH_MON_IP}" "sudo mkdir -p /var/lib/ceph/mon/ceph-ceph-mon"
ssh_run "${CEPH_MON_IP}" "if [[ -z \"\$(sudo ls -A /var/lib/ceph/mon/ceph-ceph-mon 2>/dev/null)\" ]]; then sudo ceph-mon --mkfs -i ceph-mon --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring; else echo 'monitor data already exists, skipping mkfs'; fi"
ssh_run "${CEPH_MON_IP}" "sudo chown -R ceph:ceph /var/lib/ceph/mon/ceph-ceph-mon"
ssh_run "${CEPH_MON_IP}" "sudo systemctl enable --now ceph-mon@ceph-mon"

for ip in "${CEPH_MON_IP}" "${CEPH_1_ADMIN_IP}" "${CEPH_2_ADMIN_IP}" "${CEPH_3_ADMIN_IP}"; do
    scp_to "${admin_keyring_local}" "${ip}" "/tmp/ceph.client.admin.keyring"
    ssh_run "${ip}" "sudo mv /tmp/ceph.client.admin.keyring /etc/ceph/ceph.client.admin.keyring"
done

log_title "Starting manager"
ssh_run "${CEPH_ADMIN_IP}" "sudo mkdir -p /var/lib/ceph/mgr/ceph-ceph-admin"
ssh_run "${CEPH_ADMIN_IP}" "sudo ceph auth get-or-create mgr.ceph-admin mon 'allow profile mgr' osd 'allow *' mds 'allow *' -o /var/lib/ceph/mgr/ceph-ceph-admin/keyring"
ssh_run "${CEPH_ADMIN_IP}" "sudo chown -R ceph:ceph /var/lib/ceph/mgr/ceph-ceph-admin"
ssh_run "${CEPH_ADMIN_IP}" "sudo systemctl enable --now ceph-mgr@ceph-admin"

bootstrap_local="${WORKDIR}/tmp/bootstrap-osd.keyring"
ssh_run "${CEPH_ADMIN_IP}" "sudo mkdir -p /var/lib/ceph/bootstrap-osd && if sudo ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring >/dev/null 2>&1; then true; else sudo ceph auth get-or-create client.bootstrap-osd mon 'allow profile bootstrap-osd' -o /var/lib/ceph/bootstrap-osd/ceph.keyring; fi"
ssh_run "${CEPH_ADMIN_IP}" "sudo cat /var/lib/ceph/bootstrap-osd/ceph.keyring" > "${bootstrap_local}"

for ip in "${CEPH_1_ADMIN_IP}" "${CEPH_2_ADMIN_IP}" "${CEPH_3_ADMIN_IP}"; do
    scp_to "${bootstrap_local}" "${ip}" "/tmp/bootstrap-osd.keyring"
    ssh_run "${ip}" "sudo mkdir -p /var/lib/ceph/bootstrap-osd"
    ssh_run "${ip}" "sudo cp /tmp/bootstrap-osd.keyring /var/lib/ceph/bootstrap-osd/ceph.keyring"
    ssh_run "${ip}" "sudo cp /tmp/bootstrap-osd.keyring /etc/ceph/ceph.client.bootstrap-osd.keyring"
done

log_title "Preparing OSDs"
prepare_osd() {
    local ip="$1"
    ssh_run "${ip}" "if sudo ceph-volume lvm list | grep -q 'osd id'; then echo already; else sudo wipefs -a /dev/vdb || true; sudo ceph-volume lvm create --bluestore --data /dev/vdb; fi"
}

prepare_osd "${CEPH_1_ADMIN_IP}"
prepare_osd "${CEPH_2_ADMIN_IP}"
prepare_osd "${CEPH_3_ADMIN_IP}"

log_title "Waiting for healthy OSD state"
for _ in $(seq 1 30); do
    osd_stat="$(ssh_run "${CEPH_ADMIN_IP}" "sudo ceph osd stat" || true)"
    if echo "${osd_stat}" | grep -q '3 osds: 3 up' && echo "${osd_stat}" | grep -q '3 in'; then
        log_info "All 3 OSDs are up/in"
        break
    fi
    sleep 5
done

ssh_run "${CEPH_ADMIN_IP}" "sudo ceph osd pool ls | grep -qx rbd || sudo ceph osd pool create rbd 128 128 replicated"
ssh_run "${CEPH_ADMIN_IP}" "sudo rbd pool init rbd || true"

log_title "Configuring dashboard"
ssh_run "${CEPH_ADMIN_IP}" "sudo ceph mgr module enable dashboard"
ssh_run "${CEPH_ADMIN_IP}" "sudo ceph dashboard create-self-signed-cert"
ssh_run "${CEPH_ADMIN_IP}" "sudo ceph config set mgr mgr/dashboard/server_addr ${CEPH_ADMIN_IP}"
ssh_run "${CEPH_ADMIN_IP}" "sudo ceph config set mgr mgr/dashboard/server_port ${DASHBOARD_PORT}"
ssh_run "${CEPH_ADMIN_IP}" "printf '%s' '${DASHBOARD_PASSWORD}' | sudo tee /tmp/dashboard_password.txt >/dev/null"
ssh_run "${CEPH_ADMIN_IP}" "if sudo ceph dashboard ac-user-show ${DASHBOARD_USER} >/dev/null 2>&1; then sudo ceph dashboard ac-user-set-password ${DASHBOARD_USER} -i /tmp/dashboard_password.txt; else sudo ceph dashboard ac-user-create ${DASHBOARD_USER} -i /tmp/dashboard_password.txt administrator; fi"
ssh_run "${CEPH_ADMIN_IP}" "sudo rm -f /tmp/dashboard_password.txt"

log_title "Ceph KVM cluster ready"
ssh_run "${CEPH_ADMIN_IP}" "sudo ceph -s"

echo ""
log_info "Dashboard URL: https://${CEPH_ADMIN_IP}:${DASHBOARD_PORT}"
log_info "Dashboard user: ${DASHBOARD_USER}"
log_info "Dashboard pass: ${DASHBOARD_PASSWORD}"
log_info "FSID: ${FSID}"
