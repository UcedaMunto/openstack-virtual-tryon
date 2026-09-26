#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-plan}"
NET_NAME="${NET_NAME:-net-192-168-3}"
NET_MODE="${NET_MODE:-nat}"
NET_GW="${NET_GW:-192.168.3.1}"
NET_MASK="${NET_MASK:-255.255.255.0}"
DHCP_START="${DHCP_START:-192.168.3.200}"
DHCP_END="${DHCP_END:-192.168.3.254}"

if ! command -v virsh >/dev/null 2>&1; then
  echo "[ERROR] Falta virsh"
  exit 1
fi

if [[ "$MODE" == "plan" ]]; then
  cat <<EOF
[PLAN] Ejecuta estos comandos para crear la red:

cat > /tmp/${NET_NAME}.xml <<XML
<network>
  <name>${NET_NAME}</name>
  <forward mode='${NET_MODE}'/>
  <ip address='${NET_GW}' netmask='${NET_MASK}'>
    <dhcp>
      <range start='${DHCP_START}' end='${DHCP_END}'/>
    </dhcp>
  </ip>
</network>
XML

sudo virsh net-define /tmp/${NET_NAME}.xml
sudo virsh net-autostart ${NET_NAME}
sudo virsh net-start ${NET_NAME}
sudo virsh net-info ${NET_NAME}
EOF
  exit 0
fi

if [[ "$MODE" == "apply" ]]; then
  TMP_XML="/tmp/${NET_NAME}.xml"
  cat > "$TMP_XML" <<XML
<network>
  <name>${NET_NAME}</name>
  <forward mode='${NET_MODE}'/>
  <ip address='${NET_GW}' netmask='${NET_MASK}'>
    <dhcp>
      <range start='${DHCP_START}' end='${DHCP_END}'/>
    </dhcp>
  </ip>
</network>
XML

  if sudo virsh net-info "$NET_NAME" >/dev/null 2>&1; then
    echo "[WARN] La red $NET_NAME ya existe, no se vuelve a definir"
  else
    sudo virsh net-define "$TMP_XML"
  fi

  sudo virsh net-autostart "$NET_NAME" || true
  if sudo virsh net-info "$NET_NAME" | awk -F': +' '/Active:/ {print $2}' | grep -qi '^yes$'; then
    echo "[INFO] La red $NET_NAME ya estaba activa"
  else
    sudo virsh net-start "$NET_NAME"
  fi
  sudo virsh net-info "$NET_NAME"
  exit 0
fi

echo "Uso: bash 02-redes.sh [plan|apply]"
exit 1
