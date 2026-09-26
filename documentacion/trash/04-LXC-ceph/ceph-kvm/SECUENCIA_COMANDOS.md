# Secuencia Completa de Comandos - Ceph KVM

Esta guía detalla todos los comandos necesarios para levantar el cluster Ceph en KVM, **en el orden exacto de ejecución**, con explicaciones de cada paso.

---

## Tabla de Contenidos

1. [Requisitos previos del host](#requisitos-previos-del-host)
2. [Modo Rápido (3 comandos)](#modo-rápido-3-comandos)
3. [Modo Paso a Paso (con explicaciones detalladas)](#modo-paso-a-paso-con-explicaciones-detalladas)
4. [Operaciones Diarias](#operaciones-diarias)
5. [Verificación del Cluster](#verificación-del-cluster)
6. [Desmontaje y Limpieza](#desmontaje-y-limpieza)

---

## Requisitos previos del host

Antes de ejecutar nada, asegúrate de que tu host tiene instalados todos los paquetes necesarios:

### Paso 1: Actualizar sistema e instalar dependencias

```bash
# Actualizar repositorios
sudo apt-get update

# Instalar paquetes requeridos para KVM y Ceph
sudo apt-get install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  virtinst \
  cloud-image-utils \
  qemu-utils \
  openssh-client \
  curl \
  gnupg \
  lsb-release \
  ubuntu-keyring
```

**Explicación:**
- `qemu-kvm`: emulador/hipervisor KVM
- `libvirt-*`: herramientas de gestión de máquinas virtuales
- `virtinst`: herramienta para crear VMs
- `cloud-image-utils`: utilidades para procesar imágenes cloud-init
- `qemu-utils`: herramientas de manipulación de discos QEMU

### Paso 2: Configurar permisos de usuario para libvirt

```bash
# Agregar tu usuario al grupo libvirt
sudo usermod -aG libvirt "$USER"

# Aplicar cambios de grupo en la sesión actual
newgrp libvirt

# Verificar que funciona (sin sudo)
virsh list --all
```

**Explicación:**
- Sin esto, necesitarías `sudo` para cada comando libvirt
- El grupo `libvirt` permite acceso sin elevar privilegios

---

## Modo Rápido (3 comandos)

Si confías en los defaults y tienes prisa, este es el flujo más rápido:

```bash
# 1. Navegar a la carpeta del proyecto
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm

# 2. Hacer scripts ejecutables (primera vez)
chmod +x up.sh start.sh stop.sh status.sh reset.sh destroy.sh scripts/*.sh

# 3. Levantar todo (infrastructure + bootstrap)
./up.sh

# 4. Esperar 3-5 minutos y verificar estado
./status.sh

# 5. Acceder al dashboard
# URL: https://192.168.130.100:8443
# Usuario: admin
# Contraseña: AdminCeph2026!
```

**Tiempo estimado:** 5-7 minutos en primera ejecución

---

## Modo Paso a Paso (con explicaciones detalladas)

Este modo permite ejecutar cada fase por separado y entender qué ocurre en cada etapa.

### **FASE 1: Verificar Prerequisitos del Host**

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm

# Ejecutar verificación de prerequisites
bash scripts/00-check-prereqs.sh
```

**Qué hace:**
- ✓ Descarga la imagen base de Ubuntu 22.04 (si no existe)
- ✓ Verifica disponibilidad de KVM/libvirt
- ✓ Normaliza permisos de archivos
- ✓ Crea directorios de trabajo

**Salida esperada:**
```
[INFO] Base image already present: /var/tmp/ceph-kvm/images/jammy-server-cloudimg-amd64.img
[INFO] All prerequisites are ready
```

---

### **FASE 2: Crear Redes Virtuales Libvirt**

```bash
# Crear redes admin y data en libvirt
bash scripts/10-create-networks.sh
```

**Qué hace:**
- ✓ Crea red `ceph-admin-net` (192.168.130.0/24)
- ✓ Crea red `ceph-data-net` (192.168.140.0/24)
- ✓ Configura puentes (bridges) vbrcadmin y vbrcdata
- ✓ Activa autostart de las redes

**Salida esperada:**
```
[INFO] Created network ceph-admin-net (192.168.130.0/24)
[INFO] Created network ceph-data-net (192.168.140.0/24)
[INFO] Network setup completed
```

**Verificación:**
```bash
virsh net-list --all
# Deberías ver:
#  Name              State      Autostart  Persistent
#  ceph-admin-net    active     yes        yes
#  ceph-data-net     active     yes        yes
```

---

### **FASE 3: Crear Máquinas Virtuales con Cloud-Init**

```bash
# Crear las 5 VMs (admin, mon, osd-1, osd-2, osd-3)
bash scripts/20-create-vms.sh
```

**Qué hace:**
- ✓ Genera ISOs cloud-init para cada VM con configuración de red estática
- ✓ Crea discos QCOW2 personalizados para cada VM (40GB)
- ✓ Define 5 máquinas virtuales en libvirt
- ✓ Arranca todas las VMs

**VMs creadas:**
| VM | Red Admin | Red Data | Rol |
|---|---|---|---|
| ceph-admin | 192.168.130.100 | - | Admin + MGR |
| ceph-mon | 192.168.130.10 | - | Monitor |
| ceph-1 | 192.168.130.11 | 192.168.140.11 | OSD 0 |
| ceph-2 | 192.168.130.12 | 192.168.140.12 | OSD 1 |
| ceph-3 | 192.168.130.13 | 192.168.140.13 | OSD 2 |

**Salida esperada:**
```
[INFO] VM ceph-admin created
[INFO] VM ceph-mon created
[INFO] VM ceph-1 created
[INFO] VM ceph-2 created
[INFO] VM ceph-3 created
[INFO] VM creation finished
```

**Verificación:**
```bash
virsh list --all
# Todas las VMs deben estar en estado "running"
```

---

### **FASE 4: Esperar Inicialización Cloud-Init**

```bash
# Las VMs necesitan 2-3 minutos para inicializar cloud-init
# Espera y verifica conectividad SSH

echo "Esperando inicialización de VMs..."
sleep 120

# Probar SSH a nodo admin
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_rsa ubuntu@192.168.130.100 "echo OK"
```

**Qué ocurre internamente:**
- Cloud-init ejecuta on boot
- Instala openssh-server
- Configura netplan con IPs estáticas
- Configura usuario ubuntu con acceso sudo sin password

**Verificación:**
```bash
for ip in 192.168.130.100 192.168.130.10 192.168.130.11 192.168.130.12 192.168.130.13; do
  echo "Probando $ip..."
  ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@$ip "uptime" && echo "✓ OK" || echo "✗ FAIL"
done
```

---

### **FASE 5: Bootstrap del Cluster Ceph**

```bash
# Instalar paquetes y configurar Ceph en todas las VMs
bash scripts/30-bootstrap-ceph.sh
```

**Qué hace (en orden):**
1. **Espera SSH en todos los nodos** (hasta 200 intentos = ~17 min)
2. **Instala repositorio y paquetes Ceph Quincy:**
   - ceph, ceph-mon, ceph-osd, ceph-mgr en admin
   - ceph, ceph-osd en nodos OSD
3. **Configura red de datos OSD** (segundo NIC con IP 192.168.140.x)
4. **Crea keyrings de autenticación:**
   - Admin keyring (acceso total)
   - Monitor keyring
   - Bootstrap OSD keyring
5. **Genera monmap** con topología del monitor
6. **Inicializa monitor** Ceph en ceph-mon
7. **Activa manager** en ceph-admin
8. **Provisiona OSDs** usando ceph-volume lvm:
   - Crea volumen group en /dev/vdb
   - Crea logical volumes para datos
   - Inicializa BlueStore
   - Activa daemons OSD
9. **Crea pools:** rbd (para volúmenes)
10. **Configura dashboard web** con certificado autofirmado

**Salida esperada (final):**
```
cluster:
  id:     ac1d91d2-3b3a-424c-8016-e474baeba918
  health: HEALTH_WARN (expected initially)

services:
  mon: 1 daemons, quorum ceph-mon
  mgr: ceph-admin(active, since 4s)
  osd: 3 osds: 3 up, 3 in

data:
  pools:   2 pools, 129 pgs
  objects: 4 objects, 449 KiB
  usage:   873 MiB used, 59 GiB / 60 GiB avail
  pgs:     129 active+clean

[INFO] Dashboard URL: https://192.168.130.100:8443
[INFO] Dashboard user: admin
[INFO] Dashboard pass: AdminCeph2026!
```

---

### **FASE 6: Verificar Estado Final**

```bash
# Ver status del cluster
bash scripts/status.sh

# Conectarse por SSH y ejecutar comandos Ceph
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph -s'

# Ver árbol de OSDs
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph osd tree'

# Ver pools
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph osd pool ls'

# Ver servicios del manager
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph mgr services'
```

---

## Operaciones Diarias

### Ver Estado del Lab

```bash
# Status de redes y VMs
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
./status.sh
```

---

### Detener el Lab (sin borrar)

```bash
# Apaga todas las VMs gracefully
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
./stop.sh

# Verificar que quedaron apagadas
virsh list --all
```

---

### Iniciar el Lab Nuevamente

```bash
# Levanta las VMs y redes que ya existen
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
./start.sh

# Esperar a que cloud-init y Ceph se reinicialicen (2-3 min)
sleep 180

# Verificar estado
./status.sh
```

---

### Reconstruir Completamente (Destroy + Up)

```bash
# Destruye TODO y levanta nuevamente
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
./reset.sh

# Esperar completion (~7 min)
# Resultado: cluster nuevo y limpio
```

---

### Ejecutar Fase por Fase Manualmente

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm

# 1. Check prerequisites
bash scripts/00-check-prereqs.sh

# 2. Create networks  
bash scripts/10-create-networks.sh

# 3. Create VMs
bash scripts/20-create-vms.sh

# 4. Bootstrap Ceph
bash scripts/30-bootstrap-ceph.sh

# 5. Verify
./status.sh
```

---

## Verificación del Cluster

### Dashboard Web

```bash
# Abre navegador:
# URL: https://192.168.130.100:8443
# Usuario: admin
# Contraseña: AdminCeph2026!

# Aceptar certificado autofirmado
# Ver métricas, OSDs, pools, health
```

### Comandos CLI (SSH)

```bash
# Status general
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph -s'

# Tree de OSDs
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph osd tree'

# Listar pools
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph osd pool ls'

# Ver health en detalle
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph health detail'

# Ver servicios del manager (incluye dashboard URL)
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph mgr services'
```

### Probar Almacenamiento RBD

```bash
# Crear imagen RBD de 1GB
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd create test-image --pool rbd --size 1024'

# Listar imágenes
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd ls --pool rbd'

# Mapear imagen a kernel
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd map rbd/test-image'

# Formatear y montar (dentro del VM)
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo mkfs.ext4 /dev/rbd0 && sudo mount /dev/rbd0 /mnt && df -h /mnt'
```

---

## Desmontaje y Limpieza

### Opción 1: Apagar sin Borrar

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
./stop.sh
# Las VMs/discos/redes permanecen para reactivar después
```

### Opción 2: Destruir TODO

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
./destroy.sh

# Elimina:
# ✓ Todas las VMs (libvirt domains)
# ✓ Todos los discos QCOW2
# ✓ Todos los ISOs cloud-init
# ✓ Todas las redes virtuales
# ✓ Directorios locales generados (/var/tmp/ceph-kvm)
```

---

## Notas Importantes

### Configuración Personalizable

Todos los parámetros están en `config/cluster.env`:

```bash
cat config/cluster.env | grep -E "^[A-Z_]+="

# Ejemplos editables:
# - IPs de los nodos
# - Credenciales del dashboard
# - Tamaño de RAM/CPU de VMs
# - Tamaño del disco OSD
# - Redes (CIDR)
```

**Para cambiar valores:**
```bash
# Editar antes de ejecutar scripts
nano config/cluster.env

# Luego es recomendado hacer reset para aplicar cambios
./reset.sh
```

### Troubleshooting

**Las VMs no obtienen IP:**
```bash
# Esperar más (cloud-init toma tiempo)
sleep 120
virsh domifaddr ceph-admin

# Si sigue sin IP, revisar logs
sudo tail -f /var/log/libvirt/qemu/ceph-admin.log
```

**SSH timeout:**
```bash
# Las primeras ejecuciones tardan (package_update)
# Esperar hasta 200 intentos (17 minutos)
# O aumentar timeout en scripts/common.sh -> wait_for_ssh()
```

**HEALTH_WARN en Ceph:**
```bash
# Es normal en instalaciones nuevas
# Para llevar a HEALTH_OK:
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph config set mon mon_warn_on_insecure_global_id_reclaim_allowed false'
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph mon enable-msgr2'
```

---

## Flujo Completo en un Solo Copypaste

```bash
# Setup completo (primero asegúrate de tener requisitos del host)
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm

# Permisos
chmod +x up.sh start.sh stop.sh status.sh reset.sh destroy.sh scripts/*.sh

# Levantar
./up.sh

# Esperar
sleep 30
./status.sh

# Verificar
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.100 'sudo ceph -s'

# Dashboard
echo "Dashboard: https://192.168.130.100:8443"
echo "Usuario: admin"
echo "Contraseña: AdminCeph2026!"
```

---

**Última actualización:** April 24, 2026  
**Versión Ceph:** Quincy (17.2.9)  
**Base imagen:** Ubuntu 22.04 LTS (Jammy)
