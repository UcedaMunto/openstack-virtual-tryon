# Detalles de Scripts: Qué Se Ejecuta en HOST vs VMs

Este documento clarifica dónde se ejecutan los comandos.

---

## 🔴 IMPORTANTE: Dónde Se Ejecutan los Scripts

```
┌─────────────────────────────────────┐
│ TU HOST (Linux)                     │
├─────────────────────────────────────┤
│                                     │
│  ├─ 00-check-prereqs.sh  ← EN HOST │
│  ├─ 10-create-networks.sh ← EN HOST│
│  ├─ 20-create-vms.sh      ← EN HOST│
│  └─ 30-bootstrap-ceph.sh  ← MIXTO  │
│                                     │
│  └─ Cloud-init (genera ISOs)        │
│                                     │
└─────────────────────────────────────┘
              ↓ CREA ↓
┌─────────────────────────────────────┐
│ MÁQUINAS VIRTUALES (5 VMs)          │
├─────────────────────────────────────┤
│  ├─ ceph-admin (192.168.130.100)    │
│  ├─ ceph-mon   (192.168.130.10)     │
│  ├─ ceph-1     (192.168.130.11)     │
│  ├─ ceph-2     (192.168.130.12)     │
│  └─ ceph-3     (192.168.130.13)     │
│                                     │
│  Dentro: cloud-init → bash → ceph   │
└─────────────────────────────────────┘
```

---

## Script 1: `scripts/00-check-prereqs.sh`

**Ubicación:** HOST  
**Comando para ejecutar:** `bash scripts/00-check-prereqs.sh`

### Qué Ejecuta en el HOST:

```bash
# Verificar si qemu-img existe
which qemu-img

# Verificar si virsh (libvirt) funciona
virsh list --all

# Descargar imagen base (si no existe)
cd /var/tmp/ceph-kvm/images/
curl -fsSL -o jammy-server-cloudimg-amd64.img \
    https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Normalizar permisos
chmod 644 /var/tmp/ceph-kvm/images/jammy-server-cloudimg-amd64.img

# Crear directorios de trabajo
mkdir -p /var/tmp/ceph-kvm/{vms,seed,tmp}
chmod 755 /var/tmp/ceph-kvm/{vms,seed,tmp}
```

**NO ejecuta nada en las VMs** (todavía no existen)

---

## Script 2: `scripts/10-create-networks.sh`

**Ubicación:** HOST  
**Comando para ejecutar:** `bash scripts/10-create-networks.sh`

### Qué Ejecuta en el HOST:

Este script crea redes virtuales **libvirt** en el host. Los comandos son:

```bash
# 1. Crear archivo XML de red admin
cat > /var/tmp/ceph-kvm/tmp/ceph-admin-net.xml <<EOF
<network>
  <name>ceph-admin-net</name>
  <bridge name='vbrcadmin' stp='on' delay='0'/>
  <forward mode='nat'/>
  <ip address='192.168.130.1' netmask='255.255.255.0'/>
</network>
EOF

# 2. Definir red en libvirt
virsh net-define /var/tmp/ceph-kvm/tmp/ceph-admin-net.xml

# 3. Activar autostart
virsh net-autostart ceph-admin-net

# 4. Iniciar red
virsh net-start ceph-admin-net

# 5. Crear archivo XML de red data
cat > /var/tmp/ceph-kvm/tmp/ceph-data-net.xml <<EOF
<network>
  <name>ceph-data-net</name>
  <bridge name='vbrcdata' stp='on' delay='0'/>
  <forward mode='nat'/>
  <ip address='192.168.140.1' netmask='255.255.255.0'/>
</network>
EOF

# 6. Definir red data en libvirt
virsh net-define /var/tmp/ceph-kvm/tmp/ceph-data-net.xml

# 7. Activar autostart
virsh net-autostart ceph-data-net

# 8. Iniciar red data
virsh net-start ceph-data-net
```

### Resultado en HOST:

```bash
# Verificar que funcionó:
virsh net-list --all

# Output:
#  Name              State      Autostart  Persistent
#  ceph-admin-net    active     yes        yes
#  ceph-data-net     active     yes        yes
```

**NO ejecuta nada en las VMs** (las redes ya están listas para que las VMs las usen)

---

## Script 3: `scripts/20-create-vms.sh`

**Ubicación:** HOST (con cloud-init embebido)  
**Comando para ejecutar:** `bash scripts/20-create-vms.sh`

### Qué Ejecuta en el HOST:

```bash
# ========== FASE 1: Generar Cloud-Init ISOs ==========

# Para CADA VM (ceph-admin, ceph-mon, ceph-1, ceph-2, ceph-3):

# 1.1. Crear archivo cloud-init user-data
cat > /var/tmp/ceph-kvm/seed/ceph-admin-user-data.yaml <<EOF
#cloud-config
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAA... (tu clave pública)
runcmd:
  - apt-get install -y qemu-guest-agent openssh-server >/dev/null 2>&1 || true
  - systemctl enable --now qemu-guest-agent || true
  - systemctl enable --now ssh || true
EOF

# 1.2. Crear archivo cloud-init meta-data
cat > /var/tmp/ceph-kvm/seed/ceph-admin-meta-data.yaml <<EOF
instance-id: ceph-admin
local-hostname: ceph-admin
EOF

# 1.3. Crear archivo cloud-init network config
cat > /var/tmp/ceph-kvm/seed/ceph-admin-network.yaml <<EOF
version: 2
ethernets:
  admin0:
    dhcp4: false
    match:
      macaddress: "52:54:00:13:00:64"  # MAC del admin
    set-name: admin0
    addresses: [192.168.130.100/24]
    gateway4: 192.168.130.1
    nameservers:
      addresses: [192.168.130.1, 1.1.1.1, 8.8.8.8]
EOF

# 1.4. Crear ISO cloud-init
cloud-localds --network-config /var/tmp/ceph-kvm/seed/ceph-admin-network.yaml \
    /var/tmp/ceph-kvm/seed/ceph-admin-seed.iso \
    /var/tmp/ceph-kvm/seed/ceph-admin-user-data.yaml \
    /var/tmp/ceph-kvm/seed/ceph-admin-meta-data.yaml

# ========== FASE 2: Crear Discos QCOW2 ==========

# 2.1. Crear disco principal de 40GB (copy-on-write sobre imagen base)
qemu-img create -f qcow2 -F qcow2 -b /var/tmp/ceph-kvm/images/jammy-server-cloudimg-amd64.img \
    /var/tmp/ceph-kvm/vms/ceph-admin.qcow2 40G

# 2.2. Cambiar permisos para que libvirt pueda leerlo
chmod 666 /var/tmp/ceph-kvm/vms/ceph-admin.qcow2

# (Repetir pasos 1.1-2.2 para cada VM: ceph-mon, ceph-1, ceph-2, ceph-3)

# Para OSDs adicionales (ceph-1, ceph-2, ceph-3), crear disco OSD de 100GB:
qemu-img create -f qcow2 /var/tmp/ceph-kvm/vms/ceph-1-osd.qcow2 100G
chmod 666 /var/tmp/ceph-kvm/vms/ceph-1-osd.qcow2

# ========== FASE 3: Definir VMs en Libvirt ==========

# 3.1. Crear VM ceph-admin
virt-install \
    --name ceph-admin \
    --memory 2048 \
    --vcpus 2 \
    --cpu host-passthrough \
    --disk path=/var/tmp/ceph-kvm/vms/ceph-admin.qcow2,format=qcow2,bus=virtio \
    --disk path=/var/tmp/ceph-kvm/seed/ceph-admin-seed.iso,device=cdrom \
    --network network=ceph-admin-net,model=virtio,mac=52:54:00:13:00:64 \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --noautoconsole \
    --osinfo detect=on,require=off

# 3.2. Crear VM ceph-mon
virt-install \
    --name ceph-mon \
    --memory 2048 \
    --vcpus 2 \
    --cpu host-passthrough \
    --disk path=/var/tmp/ceph-kvm/vms/ceph-mon.qcow2,format=qcow2,bus=virtio \
    --disk path=/var/tmp/ceph-kvm/seed/ceph-mon-seed.iso,device=cdrom \
    --network network=ceph-admin-net,model=virtio,mac=52:54:00:13:00:0a \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --noautoconsole \
    --osinfo detect=on,require=off

# 3.3. Crear VMs OSD (ceph-1, ceph-2, ceph-3) con DOS interfaces
virt-install \
    --name ceph-1 \
    --memory 2048 \
    --vcpus 2 \
    --cpu host-passthrough \
    --disk path=/var/tmp/ceph-kvm/vms/ceph-1.qcow2,format=qcow2,bus=virtio \
    --disk path=/var/tmp/ceph-kvm/seed/ceph-1-seed.iso,device=cdrom \
    --disk path=/var/tmp/ceph-kvm/vms/ceph-1-osd.qcow2,format=qcow2,bus=virtio \
    --network network=ceph-admin-net,model=virtio,mac=52:54:00:13:00:11 \
    --network network=ceph-data-net,model=virtio,mac=52:54:00:14:00:11 \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --noautoconsole \
    --osinfo detect=on,require=off

# (Repetir para ceph-2 y ceph-3 con MACs y directorios diferentes)
```

### Resultado en HOST:

```bash
# Verificar que VMs se crearon:
virsh list --all

# Output:
#  Id   Name         State
#  -    ceph-admin   running
#  -    ceph-mon     running
#  -    ceph-1       running
#  -    ceph-2       running
#  -    ceph-3       running
```

### Lo que Cloud-Init Ejecuta DENTRO de las VMs (on boot):

Cloud-init se ejecuta automáticamente cuando cada VM inicia:

```bash
# DENTRO DE CADA VM (ejecutado por cloud-init):

# 1. Crear usuario ubuntu
useradd -m -s /bin/bash -G sudo ubuntu

# 2. Agregar clave SSH pública
mkdir -p /home/ubuntu/.ssh
cat >> /home/ubuntu/.ssh/authorized_keys <<EOF
ssh-rsa AAAA... (tu clave pública)
EOF
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# 3. Permitir sudo sin password
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-cloud-init-users

# 4. Instalar paquetes iniciales
apt-get install -y qemu-guest-agent openssh-server

# 5. Habilitar servicios
systemctl enable --now qemu-guest-agent
systemctl enable --now ssh

# 6. Aplicar configuración de red (netplan)
netplan generate
netplan apply

# RESULTADO: VM lista con SSH accesible en su IP estática
```

---

## Script 4: `scripts/30-bootstrap-ceph.sh`

**Ubicación:** HOST (ejecuta comandos VÍA SSH en las VMs)  
**Comando para ejecutar:** `bash scripts/30-bootstrap-ceph.sh`

### Qué Ejecuta en el HOST (como cliente SSH):

```bash
# El script HOST hace SSH a cada VM y ejecuta comandos remotos

# Ejemplo: HOST → VM ceph-admin
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 "comando_remoto"
```

### Qué Se Ejecuta DENTRO de las VMs:

Ver el documento `COMANDOS_EN_VMS.md` que creé anteriormente (cubre todo en detalle).

---

## Resumen por Script

| Script | Ubicación | Qué Hace | Dentro de VMs |
|--------|-----------|----------|---------------|
| `00-check-prereqs.sh` | 🟦 HOST | Verifica/descarga imagen, valida KVM/libvirt | ❌ Nada |
| `10-create-networks.sh` | 🟦 HOST | Crea redes libvirt con virsh | ❌ Nada |
| `20-create-vms.sh` | 🟦 HOST (cloud-init) | Genera ISOs cloud-init, crea discos, define VMs | ✅ Cloud-init user-data (SSH, paquetes bases) |
| `30-bootstrap-ceph.sh` | 🟦 HOST vía SSH | SSH a cada VM, ejecuta comandos remotos | ✅ Instalar Ceph, configurar keyrings, OSDs, dashboard |

---

## Flujo Visual Completo

```
┌─────────────────────────────────────────────────────┐
│ HOST (Tu máquina Linux)                             │
│                                                     │
│ $ cd ceph-kvm                                       │
│ $ bash scripts/00-check-prereqs.sh                  │
│   └─ Validar prerequisites, descargar imagen       │
│                                                     │
│ $ bash scripts/10-create-networks.sh                │
│   └─ Crear redes vbrcadmin, vbrcdata con virsh     │
│                                                     │
│ $ bash scripts/20-create-vms.sh                     │
│   ├─ Generar cloud-init ISOs                       │
│   ├─ Crear discos QCOW2                            │
│   └─ Definir + arrancar VMs con virt-install       │
│       │                                             │
│       └─→ DENTRO DE CADA VM ARRANCA CLOUD-INIT:    │
│           ├─ Instalar SSH                          │
│           ├─ Crear usuario ubuntu                  │
│           └─ Configurar netplan (IPs estáticas)    │
│                                                     │
│ (Esperar 2-3 min a cloud-init)                     │
│                                                     │
│ $ bash scripts/30-bootstrap-ceph.sh                 │
│   └─ HOST hace SSH a cada VM y ejecuta:            │
│       ├─ Instalar repo Ceph                        │
│       ├─ Instalar paquetes Ceph                    │
│       ├─ Configurar keyrings                       │
│       ├─ Iniciar monitor                           │
│       ├─ Iniciar manager                           │
│       ├─ Provisionar OSDs (ceph-volume lvm)        │
│       └─ Configurar dashboard                      │
│                                                     │
│ ✅ CLUSTER LISTO                                    │
└─────────────────────────────────────────────────────┘
```

---

## Para Ver en Tiempo Real

Mientras script está corriendo:

```bash
# Ver logs de VMs
sudo tail -f /var/log/libvirt/qemu/ceph-admin.log

# Ver que SSH está disponible
for ip in 192.168.130.{100,10,11,12,13}; do
  echo "Testing $ip..."
  ssh -o ConnectTimeout=2 -i ~/.ssh/id_rsa ubuntu@$ip "uptime" && echo "✓ OK" || echo "✗ FAIL"
done

# Conectarse a una VM manualmente
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100

# Ver comando que está ejecutando ceph-admin ahora
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 "ps aux | grep ceph | head -10"
```

---

## Conclusión

- **Fases 1-3 (00, 10, 20):** Todo ocurre en HOST, excepto cloud-init boot
- **Fase 4 (30):** HOST SSH → VMs, ejecuta DENTRO de cada VM
- **Documentación completa:** Ver `COMANDOS_EN_VMS.md` para cada comando específico que corre en las VMs
