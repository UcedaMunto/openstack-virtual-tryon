#!/usr/bin/env bash
set -euo pipefail

TMP_XML=""

cleanup() {
  if [[ -n "$TMP_XML" && -f "$TMP_XML" ]]; then
    rm -f "$TMP_XML"
  fi
}

trap cleanup EXIT

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] No se encontro comando requerido: $cmd"
    exit 1
  fi
}

prompt_default() {
  local prompt_text="$1"
  local default_value="$2"
  local user_value=""

  read -r -p "$prompt_text [$default_value]: " user_value
  if [[ -z "$user_value" ]]; then
    user_value="$default_value"
  fi

  printf '%s\n' "$user_value"
}

prompt_required() {
  local prompt_text="$1"
  local user_value=""

  while true; do
    read -r -p "$prompt_text: " user_value
    if [[ -n "${user_value// }" ]]; then
      printf '%s\n' "$user_value"
      return
    fi
    echo "[WARN] Este valor es obligatorio."
  done
}

prompt_yes_no() {
  local prompt_text="$1"
  local default_value="$2"
  local user_value=""
  local normalized_default="${default_value,,}"

  while true; do
    read -r -p "$prompt_text [$default_value]: " user_value
    if [[ -z "$user_value" ]]; then
      user_value="$normalized_default"
    fi
    user_value="${user_value,,}"
    case "$user_value" in
      y|yes|s|si)
        printf 'yes\n'
        return
        ;;
      n|no)
        printf 'no\n'
        return
        ;;
      *)
        echo "[WARN] Responde si/no."
        ;;
    esac
  done
}

print_existing_networks() {
  local networks
  networks="$(sudo virsh net-list --all --name | sed '/^$/d')"

  echo "[INFO] Redes libvirt actuales:"
  if [[ -z "${networks// }" ]]; then
    echo "  - No hay redes definidas."
    return
  fi

  while IFS= read -r network_name; do
    [[ -z "${network_name// }" ]] && continue

    local active_state
    local autostart_state
    local xml
    local gateway_ip
    local netmask
    local dhcp_start
    local dhcp_end

    active_state="$(sudo virsh net-info "$network_name" 2>/dev/null | awk -F': +' '/Active:/ {print $2}')"
    autostart_state="$(sudo virsh net-info "$network_name" 2>/dev/null | awk -F': +' '/Autostart:/ {print $2}')"
    xml="$(sudo virsh net-dumpxml "$network_name")"
    gateway_ip="$(printf '%s\n' "$xml" | awk -F"'" '/<ip address=/{print $2; exit}')"
    netmask="$(printf '%s\n' "$xml" | awk -F"'" '/<ip address=/{print $4; exit}')"
    dhcp_start="$(printf '%s\n' "$xml" | awk -F"'" '/<range start=/{print $2; exit}')"
    dhcp_end="$(printf '%s\n' "$xml" | awk -F"'" '/<range start=/{print $4; exit}')"

    echo "  - $network_name"
    echo "    activa: ${active_state:-desconocido} | autostart: ${autostart_state:-desconocido}"
    if [[ -n "$gateway_ip" && -n "$netmask" ]]; then
      echo "    rango base: $gateway_ip / $netmask"
    else
      echo "    rango base: no definido en XML"
    fi
    if [[ -n "$dhcp_start" && -n "$dhcp_end" ]]; then
      echo "    dhcp: $dhcp_start - $dhcp_end"
    else
      echo "    dhcp: no definido"
    fi
  done <<< "$networks"
}

build_network_xml() {
  local network_name="$1"
  local mode="$2"
  local gateway_ip="$3"
  local netmask="$4"
  local dhcp_enabled="$5"
  local dhcp_start="$6"
  local dhcp_end="$7"

  cat <<EOF
<network>
  <name>${network_name}</name>
EOF

  if [[ "$mode" == "nat" ]]; then
    echo "  <forward mode='nat'/>"
  fi

  cat <<EOF
  <ip address='${gateway_ip}' netmask='${netmask}'>
EOF

  if [[ "$dhcp_enabled" == "yes" ]]; then
    cat <<EOF
    <dhcp>
      <range start='${dhcp_start}' end='${dhcp_end}'/>
    </dhcp>
EOF
  fi

  cat <<EOF
  </ip>
</network>
EOF
}

main() {
  require_command virsh
  require_command sudo

  print_existing_networks
  echo
  echo "[INFO] Creacion paso a paso de red libvirt"

  local network_name
  local mode
  local gateway_ip
  local netmask
  local dhcp_enabled
  local dhcp_start=""
  local dhcp_end=""
  local autostart_enabled
  local start_now

  network_name="$(prompt_required 'Nombre de la nueva red')"
  if sudo virsh net-info "$network_name" >/dev/null 2>&1; then
    echo "[ERROR] Ya existe una red con ese nombre: $network_name"
    exit 1
  fi

  while true; do
    mode="$(prompt_default 'Modo de red (nat o isolated)' 'nat')"
    mode="${mode,,}"
    case "$mode" in
      nat|isolated)
        break
        ;;
      *)
        echo "[WARN] Solo se acepta nat o isolated."
        ;;
    esac
  done

  gateway_ip="$(prompt_required 'IP gateway de la red (ej. 192.168.50.1)')"
  netmask="$(prompt_default 'Mascara de red' '255.255.255.0')"
  dhcp_enabled="$(prompt_yes_no 'Deseas habilitar DHCP?' 'si')"

  if [[ "$dhcp_enabled" == "yes" ]]; then
    dhcp_start="$(prompt_required 'IP inicial del rango DHCP')"
    dhcp_end="$(prompt_required 'IP final del rango DHCP')"
  fi

  autostart_enabled="$(prompt_yes_no 'Deseas autostart para esta red?' 'si')"
  start_now="$(prompt_yes_no 'Deseas iniciar la red al terminar?' 'si')"

  echo
  echo "[INFO] Resumen de la red a crear"
  echo "  nombre: $network_name"
  echo "  modo: $mode"
  echo "  gateway: $gateway_ip"
  echo "  netmask: $netmask"
  if [[ "$dhcp_enabled" == "yes" ]]; then
    echo "  dhcp: $dhcp_start - $dhcp_end"
  else
    echo "  dhcp: deshabilitado"
  fi
  echo "  autostart: $autostart_enabled"
  echo "  iniciar ahora: $start_now"

  if [[ "$(prompt_yes_no 'Confirmas la creacion?' 'si')" != "yes" ]]; then
    echo "[INFO] Operacion cancelada."
    exit 0
  fi

  TMP_XML="$(mktemp /tmp/libvirt-net-XXXXXX.xml)"
  build_network_xml "$network_name" "$mode" "$gateway_ip" "$netmask" "$dhcp_enabled" "$dhcp_start" "$dhcp_end" > "$TMP_XML"

  echo "[INFO] Definiendo red libvirt..."
  sudo virsh net-define "$TMP_XML"

  if [[ "$autostart_enabled" == "yes" ]]; then
    sudo virsh net-autostart "$network_name"
  fi

  if [[ "$start_now" == "yes" ]]; then
    sudo virsh net-start "$network_name"
  fi

  echo "[OK] Red creada: $network_name"
  echo
  print_existing_networks
}

main "$@"