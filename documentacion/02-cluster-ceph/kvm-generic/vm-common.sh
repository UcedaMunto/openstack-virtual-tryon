#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_KEYS_DIR="${SSH_KEYS_DIR:-$SCRIPT_DIR/ssh-keys}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-$SSH_KEYS_DIR/id_rsa}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-$SSH_KEYS_DIR/id_rsa.pub}"
HOST_PUBLIC_KEY="${HOST_PUBLIC_KEY:-}"

resolve_host_public_key() {
  if [[ -n "$HOST_PUBLIC_KEY" && -f "$HOST_PUBLIC_KEY" ]]; then
    return
  fi

  if [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
    HOST_PUBLIC_KEY="$HOME/.ssh/id_rsa.pub"
    return
  fi

  if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
    HOST_PUBLIC_KEY="$HOME/.ssh/id_ed25519.pub"
    return
  fi

  HOST_PUBLIC_KEY=""
}

ensure_shared_ssh_keys() {
  mkdir -p "$SSH_KEYS_DIR"

  if [[ ! -f "$SSH_PRIVATE_KEY" || ! -f "$SSH_PUBLIC_KEY" ]]; then
    ssh-keygen -t rsa -b 4096 -N "" -f "$SSH_PRIVATE_KEY" >/dev/null
  fi

  chmod 700 "$SSH_KEYS_DIR"
  chmod 600 "$SSH_PRIVATE_KEY"
  chmod 644 "$SSH_PUBLIC_KEY"
  resolve_host_public_key
}

build_authorized_keys_content() {
  local content
  content="$(<"$SSH_PUBLIC_KEY")"

  if [[ -n "$HOST_PUBLIC_KEY" && -f "$HOST_PUBLIC_KEY" ]]; then
    local host_key
    host_key="$(<"$HOST_PUBLIC_KEY")"
    if [[ "$host_key" != "$content" ]]; then
      content+=$'\n'"$host_key"
    fi
  fi

  printf '%s\n' "$content"
}

build_authorized_keys_yaml_list() {
  local multiline_keys="$1"
  while IFS= read -r key_line; do
    [[ -z "${key_line// }" ]] && continue
    printf '      - %s\n' "$key_line"
  done <<< "$multiline_keys"
}

build_first_boot_script_write_file() {
  local first_boot_script="$1"

  if [[ -z "${first_boot_script// }" ]]; then
    return
  fi

  if [[ ! -f "$first_boot_script" ]]; then
    echo "[ERROR] No existe first boot script: $first_boot_script"
    exit 1
  fi

  cat <<EOF
  - path: /usr/local/sbin/custom-first-boot.sh
    owner: root:root
    permissions: '0700'
    content: |
$(yaml_indented_file 6 "$first_boot_script")
EOF
}

build_first_boot_script_runcmd() {
  local first_boot_script="$1"

  if [[ -z "${first_boot_script// }" ]]; then
    return
  fi

  cat <<'EOF'
  - sed -i 's/\r$//' /usr/local/sbin/custom-first-boot.sh
  - /usr/local/sbin/custom-first-boot.sh
EOF
}

yaml_indented_file() {
  local spaces="$1"
  local file_path="$2"
  local indent
  indent="$(printf '%*s' "$spaces" '')"
  sed "s/^/${indent}/" "$file_path"
}

yaml_indented_text() {
  local spaces="$1"
  local text="$2"
  local indent
  indent="$(printf '%*s' "$spaces" '')"
  while IFS= read -r line; do
    printf '%s%s\n' "$indent" "$line"
  done <<< "$text"
}

build_hosts_content() {
  local hostname="$1"
  local extra_hosts="$2"

  local content="127.0.0.1 localhost
127.0.1.1 ${hostname}"

  if [[ -n "$extra_hosts" ]]; then
    IFS=';' read -r -a hosts_array <<< "$extra_hosts"
    for host_entry in "${hosts_array[@]}"; do
      [[ -z "${host_entry// }" ]] && continue
      content+=$'\n'"$host_entry"
    done
  fi

  printf '%s\n' "$content"
}

build_network_yaml() {
  local ifaces_spec="$1"
  local primary_mac="${2:-}"

  if [[ -z "${ifaces_spec// }" ]]; then
    cat <<'EOF'
    enp1s0:
      dhcp4: true
EOF
    return
  fi

  IFS=';' read -r -a iface_array <<< "$ifaces_spec"
  local iface_index=0
  for iface_def in "${iface_array[@]}"; do
    [[ -z "${iface_def// }" ]] && continue

    local iface_name=""
    local iface_addr=""
    local iface_gateway=""
    local iface_dns=""

    IFS=',' read -r iface_name iface_addr iface_gateway iface_dns <<< "$iface_def"

    [[ -z "$iface_name" ]] && continue

    echo "    ${iface_name}:"

    if [[ $iface_index -eq 0 && -n "$primary_mac" ]]; then
      cat <<EOF
      match:
        macaddress: ${primary_mac}
      set-name: ${iface_name}
EOF
    fi

    if [[ -n "$iface_addr" ]]; then
      echo "      dhcp4: false"
      echo "      addresses: [${iface_addr}]"
    else
      echo "      dhcp4: true"
    fi

    if [[ -n "$iface_gateway" ]]; then
      cat <<EOF
      routes:
        - to: default
          via: ${iface_gateway}
EOF
    fi

    if [[ -n "$iface_dns" ]]; then
      local dns_list="${iface_dns//|/, }"
      cat <<EOF
      nameservers:
        addresses: [${dns_list}]
EOF
    fi

    iface_index=$((iface_index + 1))
  done
}

write_network_config() {
  local output_file="$1"
  local ifaces_spec="$2"
  local primary_mac="${3:-}"

  cat > "$output_file" <<EOF
version: 2
ethernets:
$(build_network_yaml "$ifaces_spec" "$primary_mac" | sed 's/^    /  /')
EOF
}

build_user_cloud_init_yaml() {
  local vm_user="$1"
  local password_hash="$2"
  local authorized_keys_content="$3"

  cat <<EOF
  - name: ${vm_user}
$(if [[ "$vm_user" == "admin" ]]; then cat <<'INNER'
    primary_group: admin
INNER
fi)
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${password_hash}
    ssh_authorized_keys:
$(build_authorized_keys_yaml_list "$authorized_keys_content")
EOF
}

write_cloud_init() {
  local output_file="$1"
  local vm_hostname="$2"
  local vm_user="$3"
  local vm_password="$4"
  local ifaces_spec="$5"
  local extra_hosts="$6"
  local first_boot_script="$7"
  local primary_mac="${8:-}"

  local hosts_content
  hosts_content="$(build_hosts_content "$vm_hostname" "$extra_hosts")"

  local password_hash=""
  if command -v openssl >/dev/null 2>&1; then
    password_hash="$(openssl passwd -6 "$vm_password")"
  else
    echo "[ERROR] openssl no esta instalado. Instala openssl para generar hash de password."
    exit 1
  fi

  local authorized_keys_content
  authorized_keys_content="$(build_authorized_keys_content)"

  cat > "$output_file" <<EOF
#cloud-config
hostname: ${vm_hostname}
manage_etc_hosts: false
timezone: America/El_Salvador
users:
$(build_user_cloud_init_yaml "$vm_user" "$password_hash" "$authorized_keys_content")
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
$(yaml_indented_text 6 "$hosts_content")
  - path: /home/${vm_user}/.ssh/id_rsa
    owner: ${vm_user}:${vm_user}
    permissions: '0600'
    content: |
$(yaml_indented_file 6 "$SSH_PRIVATE_KEY")
  - path: /home/${vm_user}/.ssh/id_rsa.pub
    owner: ${vm_user}:${vm_user}
    permissions: '0644'
    content: |
$(yaml_indented_file 6 "$SSH_PUBLIC_KEY")
  - path: /home/${vm_user}/.ssh/authorized_keys
    owner: ${vm_user}:${vm_user}
    permissions: '0600'
    content: |
$(yaml_indented_text 6 "$authorized_keys_content")
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
$(yaml_indented_file 6 "$SSH_PRIVATE_KEY")
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
$(yaml_indented_file 6 "$SSH_PUBLIC_KEY")
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
$(yaml_indented_text 6 "$authorized_keys_content")
$(build_first_boot_script_write_file "$first_boot_script")
package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/${vm_user}/.ssh
  - chmod 600 /home/${vm_user}/.ssh/id_rsa /home/${vm_user}/.ssh/authorized_keys
  - chmod 644 /home/${vm_user}/.ssh/id_rsa.pub
  - chown -R ${vm_user}:${vm_user} /home/${vm_user}/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub
$(build_first_boot_script_runcmd "$first_boot_script")
EOF
}