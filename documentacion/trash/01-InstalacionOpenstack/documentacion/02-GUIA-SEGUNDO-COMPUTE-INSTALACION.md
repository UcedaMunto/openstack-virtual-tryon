# Guía: Añadir compute2 — Instalación

> **Fecha:** 2026-07-05  
> **Objetivo:** Agregar compute2 al cluster OpenStack existente.  
> **Comprobaciones:** Ver `GUIA-SEGUNDO-COMPUTE-COMPROBACIONES.md`

**Convención de nodos:**
- `[LAPTOP]` → ThinkPad local (donde corren las VMs KVM)
- `[CONTROLLER]` → `ssh uceda@203.0.113.239`
- `[COMPUTE1]` → `ssh uceda@203.0.113.240`
- `[COMPUTE2]` → `ssh uceda@203.0.113.241` (una vez creada)

---

## Estado del cluster antes de empezar

| Nodo | IP Mgmt | IP Pública | Estado |
|------|---------|-----------|--------|
| serverocontroller | 10.0.0.11 | 203.0.113.239 | ✅ running |
| compute1 | 10.0.0.10 | 203.0.113.240 | ✅ running |
| **compute2** (nuevo) | **10.0.0.12** | **203.0.113.241** | ⬜ por crear |

### Redes KVM disponibles en el host

| Red KVM | Interfaz | Subred | Uso |
|---------|---------|--------|-----|
| openstack-public | virbr113 | 203.0.113.0/24 | SSH + VNC externo |
| openstack-admin | virbr10 | 10.0.0.0/24 | Gestión OpenStack |
| openstack-provider | virbr30 | — | Red provider (sin IP) |

---

## Resumen de pasos

| # | Paso | Nodo |
|---|------|------|
| 1.1 | Clonar disco de compute1 | LAPTOP |
| 1.2 | Pre-configurar disco con virt-customize **⚠️ antes de definir la VM** | LAPTOP |
| 1.3 | Definir VM desde XML de compute1 (misma topología PCI) y arrancar | LAPTOP |
| 2 | Primera conexión y remedición si es necesario | COMPUTE2 |
| 3 | Completar nova.conf (virt_type, VNC) | COMPUTE2 |
| 4 | Ajustar neutron OVS agent (local_ip) | COMPUTE2 |
| 5 | Reinicializar OVS y crear bridges | COMPUTE2 |
| 6 | Actualizar /etc/hosts en todos los nodos | CONTROLLER + COMPUTE1 + COMPUTE2 |
| 7 | Descubrir compute2 desde el controller | CONTROLLER |

---

## Paso 1 — Crear disco y VM compute2

> **Nodo:** `[LAPTOP]`

### 1.1 Clonar el disco de compute1

> **Archivo a clonar:** `/var/lib/libvirt/images/compute.qcow2` — es el disco de la VM `compute` (compute1).  
> Las variantes `compute-resp-*.qcow2` son snapshots anteriores, **no usar esas**.

> **⚠️ Si usaste `virsh undefine --remove-all-storage` en un intento previo**, ese flag elimina también `compute2.qcow2`. Debes re-clonarlo.

```bash
# [LAPTOP]
sudo cp /var/lib/libvirt/images/compute.qcow2 /var/lib/libvirt/images/compute2.qcow2
sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/compute2.qcow2
```

### 1.2 Pre-configurar el disco ANTES de crear la VM

> **⚠️ Hacer este paso antes de definir y arrancar la VM.**  
> Si arrancas sin pre-configurar, compute2 hereda IPs, hostname y UUIDs de compute1 → compute1 pierde SSH y Nova/Neutron se confunden.

> Requiere `libguestfs-tools`: `sudo apt install -y libguestfs-tools`

> **Nota:** El paso 1.3 define la VM desde el XML de compute1 garantizando **misma topología PCI** (`pci.1`→enp1s0, `pci.7`→enp7s0, `pci.8`→enp8s0). Por eso el `sed` sobre `50-cloud-init.yaml` es suficiente — no hace falta crear el archivo desde cero.

```bash
# [LAPTOP]

# Escribir el netplan completo (más seguro que sed sobre el archivo clonado)
sudo virt-customize -a /var/lib/libvirt/images/compute2.qcow2 \
  --no-network \
  --write '/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [203.0.113.241/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp7s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.12/24]
    enp8s0:
      dhcp4: false
      dhcp6: false
      link-local: []
' \
  --hostname compute2 \
  --run-command "touch /etc/cloud/cloud-init.disabled" \
  --run-command "sed -i 's/^GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8\"/' /etc/default/grub" \
  --run-command "update-grub" \
  --run-command "systemctl enable serial-getty@ttyS0.service" \
  --run-command "sed -i 's/^my_ip = 10\.0\.0\.10/my_ip = 10.0.0.12/' /etc/nova/nova.conf" \
  --run-command "sed -i 's/^local_ip = 10\.0\.0\.10/local_ip = 10.0.0.12/' /etc/neutron/plugins/ml2/openvswitch_agent.ini" \
  --run-command "rm -f /etc/openvswitch/conf.db" \
  --run-command "rm -f /var/lib/nova/compute_id" \
  --run-command "rm -rf /var/lib/nova/instances/[0-9a-f][0-9a-f][0-9a-f][0-9a-f]*" \
  --run-command "rm -f /etc/machine-id /var/lib/dbus/machine-id" \
  --run-command "rm -f /etc/ssh/ssh_host_*" \
  --run-command "sed -i 's/127\.0\.1\.1 .*/127.0.1.1 compute2/' /etc/hosts"
```

> **Por qué escribir el netplan completo en lugar de usar sed:** El disco clonado puede tener secciones extra (`bridges:`, `vlans:`, `addresses` de redes anteriores) que `sed` deja como residuo. Escribir el archivo completo garantiza un netplan limpio.

> **Por qué `dhcp6: false` y `link-local: []`:** Ubuntu 24.04 tiene un bug en systemd-networkd que falla con "Failed to configure DHCPv6 client: No such file or directory" incluso con solo `dhcp4: false`. Esto impide que las IPs estáticas se apliquen al arrancar. Añadir estas dos líneas por interfaz lo evita.

> **Por qué `--no-network`:** libguestfs >= 1.50 en Ubuntu 24.04 intenta usar passt para red interna y falla con "passt PID file: Permission denied" al ejecutar con sudo.

> **Por qué borrar el netplan con sed o con archivo completo:** El disco clonado hereda todas las interfaces del nodo original. Si se usa sed, secciones residuales pueden causar conflictos con OVS o dejar IPs incorrectas.

> **Por qué borrar `compute_id`:** Si no se borra, Nova arranca y detecta que el UUID en disco pertenece a compute1, falla con "Possible rename detected".

> **Por qué borrar `instances/UUID*/`:** Nova detecta directorios de instancias heredados de compute1 como "instancias existentes en un servicio nuevo" y se niega a arrancar.

> **Por qué quitar `bridges:`:** El netplan de compute1 tiene una sección `bridges:` que crea `br-provider` como Linux bridge. OVS necesita ese mismo nombre para su bridge — si ya existe como Linux bridge, OVS falla con "File exists".

Verificar que el netplan y el grub quedaron correctos **antes de arrancar**:
```bash
# [LAPTOP]
sudo virt-cat -a /var/lib/libvirt/images/compute2.qcow2 /etc/netplan/50-cloud-init.yaml
# Debe mostrar ethernets: enp1s0 (203.0.113.241), enp7s0 (10.0.0.12), enp8s0 (sin IP)
# NO debe tener sección "bridges:"

sudo virt-cat -a /var/lib/libvirt/images/compute2.qcow2 /etc/default/grub | grep CMDLINE
# Debe mostrar: GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"
```

### 1.3 Definir la VM usando el XML de compute1 como plantilla

> **⚠️ NO usar `virt-install` directamente.**  
> `virt-install` asigna buses PCI diferentes y las interfaces quedan `enp2s0`/`enp3s0` en lugar de `enp7s0`/`enp8s0` → el netplan clonado no coincide → compute2 arranca sin red.

```bash
# [LAPTOP]

# 1. Exportar XML de compute1
virsh --connect qemu:///system dumpxml compute > /tmp/compute1.xml

# 2. Generar XML de compute2 (mismo PCI, diferente nombre/UUID/MACs/disco)
python3 << 'PYEOF'
import xml.etree.ElementTree as ET, uuid

tree = ET.parse('/tmp/compute1.xml')
root = tree.getroot()

root.find('name').text = 'compute2'
root.find('uuid').text = str(uuid.uuid4())

for disk in root.iter('disk'):
    src = disk.find('source')
    if src is not None and 'compute.qcow2' in src.get('file', ''):
        src.set('file', '/var/lib/libvirt/images/compute2.qcow2')
        if 'index' in src.attrib:
            del src.attrib['index']

new_macs = ['52:54:00:a1:b2:c3', '52:54:00:d4:e5:f6', '52:54:00:11:22:33']
ifaces = [e for e in root.iter('interface') if e.get('type') == 'network']
for iface, mac in zip(ifaces, new_macs):
    mac_el = iface.find('mac')
    if mac_el is not None:
        mac_el.set('address', mac)
    src = iface.find('source')
    if src is not None and 'portid' in src.attrib:
        del src.attrib['portid']

ET.indent(tree, space='  ')
tree.write('/tmp/compute2.xml', encoding='unicode', xml_declaration=False)
print("XML generado en /tmp/compute2.xml")
PYEOF

# 3. Desregistrar intento anterior si existe, y definir compute2
virsh --connect qemu:///system destroy compute2 2>/dev/null || true
virsh --connect qemu:///system undefine compute2 2>/dev/null || true
virsh --connect qemu:///system define /tmp/compute2.xml

# 4. Arrancar compute2
virsh --connect qemu:///system start compute2
```

---

## Paso 2 — Primera conexión a compute2

> **Nodo:** `[COMPUTE2]`  
> Credenciales: usuario `uceda`, contraseña `asdfghjkl`

Esperar ~40s y probar SSH:
```bash
# [LAPTOP]
sleep 40
ssh uceda@203.0.113.241
```

> **⚠️ Si SSH da "Connection reset by peer":** `virt-customize` borró las claves SSH del host y `sshd` no puede arrancar sin ellas. Conectar por consola serie y regenerarlas:
> ```bash
> # [LAPTOP]
> virsh --connect qemu:///system console compute2
> # login: uceda / asdfghjkl
> echo asdfghjkl | sudo -S dpkg-reconfigure openssh-server
> echo asdfghjkl | sudo -S systemctl restart ssh
> # Salir: exit → Ctrl+]
> ```

> **⚠️ Si `ip -br addr` no muestra IPv4 en enp1s0/enp7s0:** netplan no se aplicó al arrancar:
> ```bash
> # [COMPUTE2]
> echo asdfghjkl | sudo -S netplan apply
> ```

---

## Paso 3 — Completar nova.conf en compute2

> **Nodo:** `[COMPUTE2]` — `ssh uceda@203.0.113.241`

`virt-customize` ya corrigió `my_ip = 10.0.0.12`. Solo falta añadir `virt_type` y la sección VNC.

### 3.1 Configurar [libvirt] para nested KVM

```bash
# [COMPUTE2]
# IMPORTANTE: usar grep con ^ para no hacer match en líneas comentadas (#virt_type = kvm)
echo asdfghjkl | sudo -S bash -c "
  grep -q '^virt_type' /etc/nova/nova.conf || \\
    sed -i '/^\[libvirt\]/a virt_type = kvm\ncpu_mode = host-passthrough' /etc/nova/nova.conf
"
```

> **⚠️ No usar `grep -q 'virt_type'` sin `^`:** El disco clonado puede tener `#virt_type = kvm` (comentado). El grep sin `^` detecta esa línea como configurada y no añade la configuración activa, dejando nova-compute sin nested KVM.

### 3.2 Configurar VNC proxy

```bash
# [COMPUTE2]
echo asdfghjkl | sudo -S bash -c "
  grep -q '^\[vnc\]' /etc/nova/nova.conf || cat >> /etc/nova/nova.conf << 'EOF'

[vnc]
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = 10.0.0.12
novncproxy_base_url = http://203.0.113.239:6080/vnc_auto.html
EOF"

# El disco clonado puede tener 'server_proxyclient_address = \$my_ip' literal (sin expandir)
# en la sección [vnc] heredada. Corregir:
echo asdfghjkl | sudo -S sed -i \
  's/^server_proxyclient_address = \$my_ip/server_proxyclient_address = 10.0.0.12/' \
  /etc/nova/nova.conf
```

> **⚠️ Por qué corregir `$my_ip` literal:** El nova.conf del disco clonado tiene `server_proxyclient_address = $my_ip` sin expandir en la sección [vnc]. Si no se corrige, Nova no puede anunciar su IP a novncproxy y la consola VNC de las instancias no funciona.

---

## Paso 4 — Configurar neutron-openvswitch-agent

> **Nodo:** `[COMPUTE2]` — `ssh uceda@203.0.113.241`

`virt-customize` ya cambió `local_ip`. Este paso es verificación rápida + corrección manual si falló.

```bash
# [COMPUTE2]
# Si por alguna razón virt-customize no lo cambió:
echo asdfghjkl | sudo -S grep 'local_ip' /etc/neutron/plugins/ml2/openvswitch_agent.ini
# Si muestra 10.0.0.10, corregir:
# echo asdfghjkl | sudo -S sed -i 's/^local_ip = 10.0.0.10/local_ip = 10.0.0.12/' \
#   /etc/neutron/plugins/ml2/openvswitch_agent.ini
```

---

## Paso 5 — Reinicializar OVS y crear bridges

> **Nodo:** `[COMPUTE2]` — `ssh uceda@203.0.113.241`

El `conf.db` de OVS fue borrado por virt-customize. Hay que reinicializar OVS y recrear los bridges.

### 5.1 Reiniciar OVS limpio

```bash
# [COMPUTE2]
echo asdfghjkl | sudo -S bash -c '
  systemctl stop neutron-openvswitch-agent nova-compute 2>/dev/null || true
  systemctl stop openvswitch-switch
  rm -f /etc/openvswitch/conf.db
  systemctl start openvswitch-switch
  sleep 2
'
```

### 5.2 Crear bridges OVS

```bash
# [COMPUTE2]
echo asdfghjkl | sudo -S bash -c '
  # Usar ovs-vsctl br-exists para no fallar si el bridge ya existe en el conf.db clonado
  ovs-vsctl br-exists br-provider || ovs-vsctl add-br br-provider
  ovs-vsctl set bridge br-provider fail_mode=secure
  ovs-vsctl port-to-br enp8s0 2>/dev/null | grep -q br-provider || ovs-vsctl add-port br-provider enp8s0

  ovs-vsctl br-exists br-int || ovs-vsctl add-br br-int
  ovs-vsctl set bridge br-int fail_mode=secure

  ovs-vsctl br-exists br-tun || ovs-vsctl add-br br-tun
  ovs-vsctl set bridge br-tun fail_mode=secure

  ip link set br-int up
  ip link set br-tun up
  ip link set br-provider up
'
```

> **Nota:** El disco clonado puede tener `br-int` y `br-tun` ya definidos en el conf.db (porque virt-customize borra el conf.db pero al reiniciar OVS recupera el estado). El error "cannot create a bridge named br-int because a bridge named br-int already exists" es inofensivo — `ovs-vsctl br-exists` lo evita limpiamente.

### 5.3 Iniciar servicios

> **⚠️ Quitar `--timeout` de libvirtd:** Ubuntu 24.04 arranca libvirtd con `--timeout 120`. Si nova-compute no conecta en ese tiempo, libvirtd se para y nova-compute falla. El override siguiente lo elimina de forma permanente.

```bash
# [COMPUTE2]
echo asdfghjkl | sudo -S bash -c '
  # Quitar --timeout 120 de libvirtd
  mkdir -p /etc/systemd/system/libvirtd.service.d
  cat > /etc/systemd/system/libvirtd.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/libvirtd
EOF
  systemctl daemon-reload

  systemctl start libvirtd
  sleep 3
  systemctl start neutron-openvswitch-agent
  sleep 3
  systemctl start nova-compute
  sleep 10
  systemctl is-active libvirtd neutron-openvswitch-agent nova-compute
'
# Los tres deben mostrar: active
```

---

## Paso 6 — Actualizar /etc/hosts en todos los nodos

Cada nodo OpenStack debe poder resolver `compute2` por nombre.

### 6.1 En el controller

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
echo asdfghjkl | sudo -S bash -c "echo '10.0.0.12 compute2' >> /etc/hosts"
```

### 6.2 En compute1

```bash
# [COMPUTE1] ssh uceda@203.0.113.240
echo asdfghjkl | sudo -S bash -c "echo '10.0.0.12 compute2' >> /etc/hosts"
# Corregir alias incorrecto heredado del clon del controller:
echo asdfghjkl | sudo -S sed -i 's/127.0.1.1 serverocontroller/127.0.1.1 compute1/' /etc/hosts
```

### 6.3 En compute2

```bash
# [COMPUTE2] ssh uceda@203.0.113.241
echo asdfghjkl | sudo -S bash -c "
  sed -i 's/127.0.1.1 serverocontroller/127.0.1.1 compute2/' /etc/hosts
  grep -q '10.0.0.12 compute2' /etc/hosts || echo '10.0.0.12 compute2' >> /etc/hosts
"
```

---

## Paso 7 — Descubrir compute2 desde el controller

> **Nodo:** `[CONTROLLER]` — `ssh uceda@203.0.113.239`

```bash
# [CONTROLLER]
echo asdfghjkl | sudo -S nova-manage cell_v2 discover_hosts --verbose
# Debe mostrar: Added host compute2 in cell cell1
```

---

## Resolución de problemas comunes

### SSH rechazado en el primer arranque ("Connection reset by peer")

**Causa:** `virt-customize` borró `/etc/ssh/ssh_host_*` y `sshd` no puede arrancar sin ellas.

```bash
# [LAPTOP] Conectar por consola serial:
virsh --connect qemu:///system console compute2
# Dentro de compute2 (login: uceda / asdfghjkl):
echo asdfghjkl | sudo -S dpkg-reconfigure openssh-server
echo asdfghjkl | sudo -S systemctl restart ssh
# Salir: exit → Ctrl+]
```

### nova-compute no arranca: "Possible rename detected" / UUID de compute1

**Causa:** `/var/lib/nova/compute_id` heredado del clon contiene el UUID de compute1.

```bash
# [COMPUTE2]
echo asdfghjkl | sudo -S rm -f /var/lib/nova/compute_id
echo asdfghjkl | sudo -S systemctl restart nova-compute
```

### nova-compute no arranca: "existing instances but new service"

**Causa:** Hay directorios UUID en `/var/lib/nova/instances/` heredados de compute1.

```bash
# [COMPUTE2]
echo asdfghjkl | sudo -S bash -c '
  cd /var/lib/nova/instances
  for d in */; do
    d="${d%/}"
    [[ "$d" == "_base" || "$d" == "locks" ]] && continue
    rm -rf "$d" && echo "Borrado: $d"
  done
'
echo asdfghjkl | sudo -S systemctl restart nova-compute
```

### br-provider conflicta con OVS ("could not add network device br-provider to ofproto: File exists")

**Causa:** El netplan clonado tiene `bridges:` que creó `br-provider` como Linux bridge.

```bash
# [COMPUTE2]
echo asdfghjkl | sudo -S bash -c '
  ip link set enp8s0 nomaster 2>/dev/null || true
  ip link delete br-provider type bridge 2>/dev/null || true
'
# Corregir el netplan (quitar sección bridges: manualmente):
echo asdfghjkl | sudo -S bash -c "cat > /etc/netplan/50-cloud-init.yaml << 'EOF'
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      addresses: [203.0.113.241/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp7s0:
      dhcp4: false
      addresses: [10.0.0.12/24]
    enp8s0:
      dhcp4: false
EOF"
echo asdfghjkl | sudo -S netplan apply
# Luego repetir paso 5.2 (crear bridges OVS) y paso 5.3 (iniciar servicios)
```

### enp7s0/enp8s0 no existen, aparecen enp2s0/enp3s0

**Causa:** La VM fue definida con `virt-install` → buses PCI diferentes.

```bash
# [LAPTOP]
virsh --connect qemu:///system destroy compute2
virsh --connect qemu:///system undefine compute2
# Repetir paso 1.3 completo (generar XML desde compute1 y virsh define)
```

### virt-customize falla con "passt PID file: Permission denied"

**Causa:** libguestfs >= 1.50 usa passt y falla con sudo. **Solución:** `--no-network` ya incluido en el paso 1.2.

### virsh console no muestra nada

```bash
# [LAPTOP]
virsh --connect qemu:///system screenshot compute2 /tmp/c2screen.png
# Abrir /tmp/c2screen.png para ver el estado actual de la VM
```

### nova-compute falla con "libvirt connection refused"

```bash
# [COMPUTE2]
echo asdfghjkl | sudo -S systemctl start libvirtd
echo asdfghjkl | sudo -S systemctl restart nova-compute
```

### nova-compute falla con "could not initialize domain event timer"

**Causa:** El disco clonado tiene instancias libvirt heredadas del nodo original (aparecen como `instance-XXXXXXXX shut off` en `virsh list --all`). Nova no puede inicializar el event timer de libvirt cuando hay dominios en estado inconsistente.

```bash
# [COMPUTE2]
# 1. Ver qué dominios hay
echo asdfghjkl | sudo -S virsh list --all

# 2. Eliminar cualquier domain instance-* heredado
echo asdfghjkl | sudo -S bash -c '
  for dom in $(virsh list --all --name | grep ^instance-); do
    virsh destroy "$dom" 2>/dev/null || true
    virsh undefine "$dom" 2>/dev/null || true
    echo "Eliminado: $dom"
  done
'

# 3. Reiniciar libvirtd y nova-compute
echo asdfghjkl | sudo -S systemctl restart libvirtd
sleep 5
echo asdfghjkl | sudo -S systemctl start nova-compute
```

### libvirtd se para solo con "--timeout" antes de que nova-compute conecte

**Causa:** Ubuntu 24.04 configura libvirtd con `--timeout 120` en el systemd unit. Si nova-compute no conecta en ese tiempo, libvirtd se para y nova-compute no puede arrancar.

```bash
# [COMPUTE2] — Quitar --timeout del unit de libvirtd
echo asdfghjkl | sudo -S bash -c '
  mkdir -p /etc/systemd/system/libvirtd.service.d
  cat > /etc/systemd/system/libvirtd.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/libvirtd
EOF
  systemctl daemon-reload
  systemctl restart libvirtd
'
```

---

### compute2 no aparece en `openstack compute service list` ni en `openstack hypervisor list`

Diagnóstico en dos pasos: primero verificar que nova-compute está activo en compute2, luego forzar el descubrimiento desde el controller.

**Paso 1 — Verificar nova-compute en compute2:**

```bash
# [COMPUTE2] ssh uceda@203.0.113.241
echo asdfghjkl | sudo -S systemctl is-active libvirtd nova-compute neutron-openvswitch-agent
# Si alguno NO es "active", ver el error:
echo asdfghjkl | sudo -S journalctl -u nova-compute -n 30 --no-pager | grep -E 'ERROR|CRITICAL|Started'
```

Si nova-compute no está activo, buscar el mensaje de error en los logs y aplicar el troubleshooting correspondiente (secciones anteriores). Luego continuar.

**Paso 2 — Re-ejecutar discover_hosts en el controller:**

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
echo asdfghjkl | sudo -S nova-manage cell_v2 discover_hosts --verbose
# Esperado: "Added host compute2 in cell cell1"
# Si dice "No hosts discovered", nova-compute en compute2 no está registrado aún
```

**Paso 3 — Verificar conectividad entre compute2 y el controller:**

```bash
# [COMPUTE2] ssh uceda@203.0.113.241
# ¿Puede compute2 llegar a RabbitMQ y Keystone?
curl -s http://controller:5000/v3/ | python3 -c "import sys,json; d=json.load(sys.stdin); print('Keystone OK:', d['version']['status'])"
# Esperado: Keystone OK: stable

# Si falla, el problema es /etc/hosts:
cat /etc/hosts | grep controller
# Si no aparece "10.0.0.11 controller" → añadir:
# echo asdfghjkl | sudo -S bash -c "echo '10.0.0.11 controller' >> /etc/hosts"
```

**Paso 4 — Forzar reinicio completo de nova-compute y esperar registro:**

```bash
# [COMPUTE2] ssh uceda@203.0.113.241
echo asdfghjkl | sudo -S bash -c '
  systemctl restart libvirtd
  sleep 3
  systemctl restart nova-compute
  sleep 10
  systemctl is-active nova-compute
'

# [CONTROLLER] ssh uceda@203.0.113.239 (en otra terminal)
echo asdfghjkl | sudo -S nova-manage cell_v2 discover_hosts --verbose
source ~/admin-openrc.sh
openstack compute service list
# Ahora debe aparecer nova-compute de compute2
```

**Paso 5 — Si aún no aparece, verificar RabbitMQ:**

```bash
# [COMPUTE2] ssh uceda@203.0.113.241
# Ver si nova-compute logra conectar a RabbitMQ (el log mostrará "Connected" o errores AMQP):
echo asdfghjkl | sudo -S journalctl -u nova-compute --since "2 minutes ago" --no-pager | grep -Ei 'rabbit|amqp|connect|error'
# Errores comunes:
#   "Authentication Failure" → contraseña RabbitMQ en nova.conf incorrecta
#   "Connection refused" → controller no responde en puerto 5672

# Verificar el transporte configurado en nova.conf:
grep 'transport_url' /etc/nova/nova.conf
# Esperado: rabbit://openstack:<password>@controller:5672/
```
