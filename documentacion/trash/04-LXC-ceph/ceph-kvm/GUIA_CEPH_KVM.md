# Guia Simplificada: Cluster Ceph con KVM/libvirt

## Descripcion General
Ceph es un sistema de almacenamiento distribuido que proporciona escalabilidad, confiabilidad y alto rendimiento.  
En esta variante, la infraestructura corre sobre maquinas virtuales KVM/libvirt, separada del laboratorio Docker.

---

## Componentes Principales

### 1. Ceph-mon (Monitor)
- Funcion: mantiene el mapa del cluster y el quorum.
- Responsabilidades:
  - Monitoreo de salud del cluster.
  - Distribucion de configuracion y mapas.

### 2. Ceph-osds (Object Storage Daemons)
- Funcion: proporcionan el almacenamiento real del cluster.
- Responsabilidades:
  - Gestion de discos virtuales dedicados.
  - Replicacion y persistencia de datos.

### 3. Ceph-admin (Administrador)
- Funcion: nodo de administracion central.
- Responsabilidades:
  - Bootstrap del cluster.
  - Gestion de usuarios, dashboard y troubleshooting.

---

## INICIO RAPIDO - 3 COMANDOS

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
./up.sh
./status.sh
```

Con eso se crean redes, VMs y se ejecuta el bootstrap completo de Ceph.

---

## Estructura de Archivos Necesarios

```bash
ceph-kvm/
├── config/
│   └── cluster.env
├── scripts/
│   ├── 00-check-prereqs.sh
│   ├── 10-create-networks.sh
│   ├── 20-create-vms.sh
│   ├── 30-bootstrap-ceph.sh
│   ├── prepare-infra.sh
│   └── setup-cluster.sh
├── up.sh
├── start.sh
├── stop.sh
├── status.sh
├── reset.sh
├── destroy.sh
└── README.md
```

---

## Deploy Completo - Paso a Paso

### Paso 1: Preparar Host

```bash
sudo apt-get update
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst cloud-image-utils qemu-utils openssh-client curl
sudo usermod -aG libvirt "$USER"
newgrp libvirt
```

Esto instala KVM/libvirt y las herramientas necesarias para crear VMs, redes y discos cloud-init.

### Paso 2: Preparar Infraestructura

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
chmod +x up.sh start.sh stop.sh status.sh reset.sh destroy.sh scripts/*.sh
bash scripts/prepare-infra.sh
```

Este bloque hace automaticamente:
- Verificacion de prerequisitos.
- Descarga de imagen base Ubuntu Cloud.
- Creacion de redes libvirt.
- Creacion de las VMs `ceph-admin`, `ceph-mon`, `ceph-1`, `ceph-2`, `ceph-3`.

### Paso 3: Ejecutar Bootstrap del Cluster

```bash
bash scripts/setup-cluster.sh
```

Este script automaticamente:
- Espera conectividad SSH a las VMs.
- Instala paquetes Ceph.
- Genera `FSID`, `ceph.conf`, keyrings y monmap.
- Inicializa monitor, manager y 3 OSDs.
- Crea pool `rbd`.
- Habilita dashboard web.

### Paso 4: Verificar Cluster

```bash
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.100 "sudo ceph status"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.100 "sudo ceph osd tree"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.100 "sudo ceph osd lspools"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.100 "sudo ceph df"
```

Estado esperado:
- `health: HEALTH_OK` o `HEALTH_WARN` transitorio durante bootstrap.
- 3 OSDs `up/in`.
- pool `rbd` creado.

---

## Redes Virtuales

### Red de Administracion
- Nombre: `ceph-admin-net`
- Subred: `192.168.130.0/24`
- Uso: trafico de administracion y CLI.

### Red de Datos
- Nombre: `ceph-data-net`
- Subred: `192.168.140.0/24`
- Uso: trafico de cluster y replicacion de OSDs.

---

## Operaciones Equivalentes a Docker

```bash
# Levantar todo desde cero
./up.sh

# Ver estado
./status.sh

# Detener sin borrar
./stop.sh

# Volver a arrancar
./start.sh

# Borrar y recrear todo
./reset.sh

# Borrar por completo VMs, redes y discos
./destroy.sh
```

---

## Dashboard Web

URL esperada:

```bash
https://192.168.130.100:8443
```

Credenciales por defecto:

```bash
usuario: admin
password: AdminCeph2026!
```

Puedes cambiarlas en `config/cluster.env` antes de ejecutar `./up.sh`.

---

## Troubleshooting Rapido

### Las VMs no arrancan
```bash
./status.sh
virsh list --all
```

### No responde SSH
```bash
virsh net-list --all
virsh console ceph-admin
```

### El cluster no levanta
```bash
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.100 "sudo ceph -s"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.10 "sudo systemctl status ceph-mon@ceph-mon"
```

### Quiero reiniciar limpio
```bash
./reset.sh
```
