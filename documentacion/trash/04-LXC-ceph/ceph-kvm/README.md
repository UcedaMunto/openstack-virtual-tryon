# Ceph Cluster con KVM/libvirt - Setup Completo

Este proyecto replica la misma topologia del laboratorio Docker, pero usando maquinas virtuales KVM/libvirt.

## 📖 Documentación Disponible

| Documento | Descripción |
|-----------|-----------|
| **[QUICK_START.md](QUICK_START.md)** | Acceso rápido en 5 minutos |
| **[SECUENCIA_COMANDOS.md](SECUENCIA_COMANDOS.md)** | ⭐ **GUÍA COMPLETA** - Todos los comandos paso a paso con explicaciones detalladas |
| **[DETALLES_SCRIPTS_HOST.md](DETALLES_SCRIPTS_HOST.md)** | 🖥️ **SCRIPTS EN HOST** - Qué ejecuta cada script (virsh, cloud-init, SSH) |
| **[COMANDOS_EN_VMS.md](COMANDOS_EN_VMS.md)** | 🔧 **COMANDOS EN VMs** - Detalles de cada comando que corre dentro de las máquinas |
| [GUIA_CEPH_KVM.md](GUIA_CEPH_KVM.md) | Conceptos y arquitectura |
| [README.md](#resumen-rápido) | Esta página (resumen) |

---

## Resumen Rápido

Deploy de un cluster Ceph completo con 3 OSDs sobre KVM en 3 pasos:

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
./up.sh
./status.sh
```

Documentacion principal basada en la guia:

- [GUIA_CEPH_KVM.md](GUIA_CEPH_KVM.md)

## Topology

- ceph-admin (admin + mgr)
- ceph-mon (monitor)
- ceph-1, ceph-2, ceph-3 (OSDs)
- Admin network: 192.168.130.0/24
- Data network: 192.168.140.0/24

## Project layout

- config/cluster.env: all configurable variables (IPs, dashboard credentials, VM sizing)
- scripts/00-check-prereqs.sh: host checks + base image download
- scripts/10-create-networks.sh: libvirt network creation
- scripts/20-create-vms.sh: VM and cloud-init provisioning
- scripts/30-bootstrap-ceph.sh: Ceph package install and cluster bootstrap
- scripts/prepare-infra.sh: wrapper aligned with the guide, prepares prereqs + networks + VMs
- scripts/setup-cluster.sh: wrapper aligned with the guide, runs cluster bootstrap
- up.sh: full end-to-end bring-up
- start.sh: starts existing libvirt networks and VMs
- stop.sh: gracefully stops running VMs
- status.sh: prints networks and VM states
- reset.sh: destroys and recreates the full lab automatically
- destroy.sh: full teardown

## Host prerequisites

Install on host:

```bash
sudo apt-get update
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst cloud-image-utils qemu-utils openssh-client curl
```

Make sure your user can use libvirt:

```bash
sudo usermod -aG libvirt "$USER"
newgrp libvirt
```

## Bring up the KVM lab

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
chmod +x up.sh start.sh stop.sh status.sh reset.sh destroy.sh scripts/*.sh
./up.sh
```

Tambien puedes seguir el flujo paso a paso de la guia:

```bash
bash scripts/prepare-infra.sh
bash scripts/setup-cluster.sh
./status.sh
```

## Day-2 operations

```bash
# See VM/network status
./status.sh

# Stop the full lab without deleting it
./stop.sh

# Start the existing lab again
./start.sh

# Destroy and recreate everything from zero
./reset.sh

# Remove all VMs, disks, networks and local generated files
./destroy.sh
```

## Verify cluster

```bash
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.100 "sudo ceph -s"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.100 "sudo ceph osd tree"
```

Dashboard URL:

- https://192.168.130.100:8443
- user: admin
- pass: AdminCeph2026!

## Destroy everything

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
./destroy.sh
```

## Notes

- This project is isolated from the Docker setup in the parent folder.
- The default KVM CIDRs were moved to `192.168.130.0/24` and `192.168.140.0/24` to avoid conflicts with Docker or the libvirt default network.
- OSD nodes use an extra virtual disk (`/dev/vdb`) for Ceph data.
