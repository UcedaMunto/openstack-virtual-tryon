# Guía: Corrección y preparación de nodos Swift (object1 / object2)

## Estado inicial detectado

| Problema | object1 (203.0.113.245) | object2 (203.0.113.246) |
|---|---|---|
| SSH accesible | ✅ | ✅ |
| Red pública enp1s0 | ✅ 203.0.113.245/24 | ✅ 203.0.113.246/24 |
| Red mgmt enp2s0 | ❌ Sin IP (netplan usaba enp7s0) | ❌ Sin IP (netplan usaba enp7s0) |
| /etc/hosts | ❌ Entradas residuales de compute | ❌ Entradas residuales de compute |
| Disco datos Swift | ❌ No existe | ❌ No existe |
| Paquetes Swift | ❌ No instalados | ❌ No instalados |

---

## PASO 1 — Apagar los nodos

```bash
# Desde el laptop (host KVM)
virsh --connect qemu:///system shutdown swift1
virsh --connect qemu:///system shutdown swift2

# Esperar hasta shut off
watch -n2 'virsh --connect qemu:///system list --all | grep swift'
```

---

## PASO 2 — Corregir netplan y /etc/hosts en disco

El netplan fue escrito con `enp7s0`/`enp8s0` (nombres del compute clonado),
pero los swift VMs usan `enp2s0`/`enp3s0`.

### object1

```bash
sudo virt-customize -a /var/lib/libvirt/images/swift1.qcow2 \
  --no-network \
  --write '/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [203.0.113.245/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp2s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.16/24]
    enp3s0:
      dhcp4: false
      dhcp6: false
      link-local: []
' \
  --run-command "sed -i '/10\.0\.0\./d' /etc/hosts" \
  --run-command "echo '10.0.0.11 controller' >> /etc/hosts" \
  --run-command "echo '10.0.0.16 object1' >> /etc/hosts" \
  --run-command "echo '10.0.0.17 object2' >> /etc/hosts"
```

### object2

```bash
sudo virt-customize -a /var/lib/libvirt/images/swift2.qcow2 \
  --no-network \
  --write '/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [203.0.113.246/24]
      routes: [{to: default, via: 203.0.113.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
    enp2s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.17/24]
    enp3s0:
      dhcp4: false
      dhcp6: false
      link-local: []
' \
  --run-command "sed -i '/10\.0\.0\./d' /etc/hosts" \
  --run-command "echo '10.0.0.11 controller' >> /etc/hosts" \
  --run-command "echo '10.0.0.16 object1' >> /etc/hosts" \
  --run-command "echo '10.0.0.17 object2' >> /etc/hosts"
```

---

## PASO 3 — Añadir disco de datos para Swift (XFS)

Swift necesita una partición XFS dedicada para los rings de almacenamiento.

```bash
# Crear discos de datos (5GB cada uno, ajustar según espacio disponible)
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/swift1-data.qcow2 5G
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/swift2-data.qcow2 5G

# Adjuntar disco a swift1
virsh --connect qemu:///system attach-disk swift1 \
  /var/lib/libvirt/images/swift1-data.qcow2 vdb \
  --driver qemu --subdriver qcow2 \
  --targetbus virtio --persistent

# Adjuntar disco a swift2
virsh --connect qemu:///system attach-disk swift2 \
  /var/lib/libvirt/images/swift2-data.qcow2 vdb \
  --driver qemu --subdriver qcow2 \
  --targetbus virtio --persistent
```

> **Nota**: `--persistent` guarda el cambio en la definición XML permanentemente.

---

## PASO 4 — Arrancar y verificar red

```bash
virsh --connect qemu:///system start swift1
virsh --connect qemu:///system start swift2

# Esperar ~20s y verificar
ssh uceda@203.0.113.245 'hostname && ip -br addr | grep -v lo'
ssh uceda@203.0.113.246 'hostname && ip -br addr | grep -v lo'
```

Resultado esperado en cada nodo:
```
enp1s0  UP  203.0.113.245/24    # o .246
enp2s0  UP  10.0.0.16/24        # o .17
enp3s0  DOWN                    # provider, sin IP (OK)
```

Verificar ping al controller por red mgmt:
```bash
ssh uceda@203.0.113.245 'ping -c2 10.0.0.11'
ssh uceda@203.0.113.246 'ping -c2 10.0.0.11'
```

---

## PASO 5 — Formatear disco de datos como XFS

Desde cada nodo:

```bash
# En object1
ssh uceda@203.0.113.245 'sudo mkfs.xfs /dev/vdb'

# En object2
ssh uceda@203.0.113.246 'sudo mkfs.xfs /dev/vdb'
```

Crear punto de montaje y configurar fstab:

```bash
# En object1 y object2 (repetir en cada uno)
sudo mkdir -p /srv/node/vdb
echo '/dev/vdb /srv/node/vdb xfs noatime,nodiratime,nobarrier,logbufs=8 0 2' \
  | sudo tee -a /etc/fstab
sudo mount /srv/node/vdb
sudo chown -R swift:swift /srv/node
```

---

## PASO 6 — Instalar paquetes Swift en los nodos

```bash
sudo apt-get update
sudo apt-get install -y swift swift-account swift-container swift-object \
  xfsprogs rsync
```

---

## PASO 7 — Actualizar /etc/hosts en el controller

Asegurarse de que el controller resuelve los nodos object por nombre:

```bash
# En el controller (203.0.113.239)
sudo bash -c 'cat >> /etc/hosts <<EOF
10.0.0.16 object1
10.0.0.17 object2
EOF'
```

---

## Resumen de IPs finales

| Nodo | IP pública | IP mgmt | Disco datos |
|---|---|---|---|
| controller | 203.0.113.239 | 10.0.0.11 | — |
| object1 | 203.0.113.245 | 10.0.0.16 | /dev/vdb → /srv/node/vdb |
| object2 | 203.0.113.246 | 10.0.0.17 | /dev/vdb → /srv/node/vdb |
