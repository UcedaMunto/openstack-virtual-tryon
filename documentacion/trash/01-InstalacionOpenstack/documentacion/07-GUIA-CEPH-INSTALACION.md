# Guía: Instalar Ceph e integrarlo con OpenStack

> **Fecha:** 2026-07-15  
> **Objetivo:** Desplegar un cluster Ceph mínimo (1 MON + 1 OSD) e integrarlo con OpenStack  
> para usar Ceph como backend de Glance (imágenes) y Cinder (volúmenes).  
> **Estado:** ⬜ Pendiente de ejecutar

**Convención de nodos:**
- `[LAPTOP]` → ThinkPad local (host KVM)
- `[CONTROLLER]` → `ssh uceda@203.0.113.239`
- `[COMPUTE1]` → `ssh uceda@203.0.113.240`
- `[CEPH1]` → `ssh uceda@203.0.113.234` (una vez arrancada)

---

## Estado del lab antes de empezar

| Nodo | IP Pública | IP Mgmt (br-mgmt) | Estado |
|------|-----------|-------------------|--------|
| serverocontroller | 203.0.113.239 | 10.0.0.11 | ✅ running |
| compute1 | 203.0.113.240 | 10.0.0.10 | ✅ running |
| compute2 | 203.0.113.241 | 10.0.0.12 | ✅ running |
| compute3 | 203.0.113.242 | 10.0.0.13 | ✅ running |
| compute4 | 203.0.113.243 | 10.0.0.14 | ✅ running |
| storage1 | 203.0.113.244 | 10.0.0.15 | ✅ running |
| **ceph1** | **203.0.113.234** | **10.0.0.20** | ⬜ shut off |

### Redes KVM disponibles para Ceph

| Red KVM | Bridge | Subred | Uso |
|---------|--------|--------|-----|
| openstack-public | virbr113 | 203.0.113.0/24 | SSH externo |
| openstack-admin | virbr10 | 10.0.0.0/24 | Gestión OpenStack |
| ceph-admin-net | vbrcadmin | 192.168.130.0/24 | Red admin Ceph |
| ceph-data-net | vbrcdata | 192.168.140.0/24 | Red de replicación Ceph (cluster network) |

### Disco disponible en la VM ceph1

| Disco | Tamaño | Uso |
|-------|--------|-----|
| ceph1.qcow2 | 16G | SO Ubuntu 24.04 |
| ceph1-data.qcow2 | 455M | OSD (disco de datos Ceph) |

---

## Arquitectura Ceph en este lab

```
LAPTOP (host KVM)
│
├── ceph1 (MON + MGR + OSD)
│   ├── enp1s0  → 203.0.113.234/24   (acceso SSH / openstack-public)
│   ├── enp2s0  → 192.168.130.x/24   (ceph-admin-net / public network)
│   ├── enp3s0  → 192.168.140.x/24   (ceph-data-net / cluster network)
│   └── /dev/vdb → OSD (ceph1-data.qcow2)
│
├── controller → usa Ceph vía librbd (Glance + Cinder)
└── computes   → usan Ceph vía librbd (Nova ephemeral, si se configura)
```

> **Nota laboratorio (1 nodo):** En producción se usan mínimo 3 nodos MON para quórum.  
> Para este lab, 1 nodo con `mon_allow_pool_delete = true` y `osd_pool_default_size = 1`  
> es suficiente para demostrar la integración con OpenStack.

---

## Resumen de pasos

| # | Paso | Nodo |
|---|------|------|
| 1 | Arrancar la VM ceph1 | LAPTOP |
| 2 | Verificar red y conectividad | CEPH1 |
| 3 | Instalar paquetes Ceph | CEPH1 |
| 4 | Inicializar el cluster (cephadm bootstrap) | CEPH1 |
| 5 | Añadir el OSD (/dev/vdb) | CEPH1 |
| 6 | Crear pools para OpenStack | CEPH1 |
| 7 | Crear usuarios Ceph para OpenStack | CEPH1 |
| 8 | Copiar keyrings al controller | CEPH1 + CONTROLLER |
| 9 | Configurar Glance para usar Ceph | CONTROLLER |
| 10 | Configurar Cinder para usar Ceph | CONTROLLER + STORAGE1 |
| 11 | Configurar Nova para usar Ceph (ephemeral) | COMPUTES |
| 12 | Verificación final | CONTROLLER |

---

## Paso 1 — Arrancar la VM ceph1

> **Nodo:** `[LAPTOP]`

```bash
# [LAPTOP]
virsh --connect qemu:///system start ceph1

# Activar las redes Ceph si están inactivas
virsh --connect qemu:///system net-start ceph-admin-net
virsh --connect qemu:///system net-start ceph-data-net

# Esperar arranque
sleep 30
ssh uceda@203.0.113.234
```

> Si SSH falla con "Connection reset", regenerar claves SSH host:
> ```bash
> virsh --connect qemu:///system console ceph1
> # login: uceda / asdfghjkl
> echo asdfghjkl | sudo -S dpkg-reconfigure openssh-server
> echo asdfghjkl | sudo -S systemctl restart ssh
> # Ctrl+]
> ```

---

## Paso 2 — Verificar red en ceph1

> **Nodo:** `[CEPH1]` — `ssh uceda@203.0.113.234`

```bash
# [CEPH1]
ip -br addr
ping -c3 controller    # debe responder (10.0.0.11 vía openstack-admin)
ping -c3 8.8.8.8       # internet
cat /etc/hosts         # debe tener controller, compute1, storage1
```

Añadir entradas al `/etc/hosts` si faltan:

```bash
echo asdfghjkl | sudo -S tee -a /etc/hosts << 'EOF'
10.0.0.11  controller  serverocontroller
10.0.0.10  compute1
10.0.0.12  compute2
10.0.0.13  compute3
10.0.0.14  compute4
10.0.0.15  storage1
10.0.0.20  ceph1
EOF
```

---

## Paso 3 — Instalar paquetes Ceph

> **Nodo:** `[CEPH1]`

```bash
# [CEPH1]
echo asdfghjkl | sudo -S apt update
echo asdfghjkl | sudo -S apt install -y cephadm ceph-common

# Verificar versión
cephadm version
```

> **Por qué cephadm:** Es el instalador oficial de Ceph desde Octopus (16+).  
> Despliega los servicios Ceph en contenedores y simplifica la gestión del cluster.

---

## Paso 4 — Inicializar el cluster Ceph

> **Nodo:** `[CEPH1]`

```bash
# [CEPH1]
# IP que usará el MON — usar la red ceph-admin-net o openstack-admin
# Usar 10.0.0.20 (openstack-admin) para que controller pueda alcanzarlo directamente
echo asdfghjkl | sudo -S cephadm bootstrap \
  --mon-ip 10.0.0.20 \
  --cluster-network 192.168.140.0/24 \
  --initial-dashboard-user admin \
  --initial-dashboard-password icc115 \
  --allow-overwrite

# Instalar herramientas en el host (no solo en contenedor)
echo asdfghjkl | sudo -S cephadm install ceph-common

# Verificar cluster
sudo ceph status
# Debe mostrar: health: HEALTH_OK (o HEALTH_WARN por 1 solo OSD — normal en lab)
```

> **`--mon-ip 10.0.0.20`:** IP del primer monitor. Se usa la red `openstack-admin`  
> porque controller y computes ya tienen conectividad a `10.0.0.0/24` vía `br-mgmt`.

> **`--cluster-network`:** Red interna de replicación entre OSDs. En lab con 1 nodo  
> no hay replicación real, pero se declara para seguir el modelo correcto.

---

## Paso 5 — Añadir el OSD

> **Nodo:** `[CEPH1]`

```bash
# [CEPH1]
# Verificar que /dev/vdb existe y está libre
sudo lsblk /dev/vdb

# Añadir como OSD
sudo ceph orch daemon add osd ceph1:/dev/vdb

# Verificar OSD activo
sudo ceph osd tree
sudo ceph status
# Debe mostrar: 1 osds: 1 up, 1 in
```

> Si el disco tiene particiones residuales, limpiar antes:
> ```bash
> sudo wipefs -a /dev/vdb
> sudo sgdisk --zap-all /dev/vdb
> ```

---

## Paso 6 — Crear pools para OpenStack

> **Nodo:** `[CEPH1]`

```bash
# [CEPH1]
# Ajustar para 1 OSD (lab) — replicación = 1
sudo ceph config set global osd_pool_default_size 1
sudo ceph config set global osd_pool_default_min_size 1

# Crear pools
sudo ceph osd pool create volumes 32        # para Cinder
sudo ceph osd pool create images 32         # para Glance
sudo ceph osd pool create vms 32            # para Nova ephemeral

# Inicializar los pools como RBD
sudo rbd pool init volumes
sudo rbd pool init images
sudo rbd pool init vms

# Verificar
sudo ceph osd lspools
```

> **Por qué pg_num=32:** En un lab con 1 OSD, usar 32 PGs por pool es suficiente.  
> En producción se calcula según número de OSDs (fórmula: `target_pgs_per_osd × num_osds / num_pools`).

---

## Paso 7 — Crear usuarios Ceph para OpenStack

> **Nodo:** `[CEPH1]`

```bash
# [CEPH1]
# Usuario para Cinder
sudo ceph auth get-or-create client.cinder \
  mon 'profile rbd' \
  osd 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd-read-only pool=images' \
  mgr 'profile rbd pool=volumes, profile rbd pool=vms'

# Usuario para Glance
sudo ceph auth get-or-create client.glance \
  mon 'profile rbd' \
  osd 'profile rbd pool=images' \
  mgr 'profile rbd pool=images'

# Usuario para Nova
sudo ceph auth get-or-create client.nova \
  mon 'profile rbd' \
  osd 'profile rbd pool=vms, profile rbd-read-only pool=images' \
  mgr 'profile rbd pool=vms'

# Verificar usuarios creados
sudo ceph auth ls | grep -E 'client.cinder|client.glance|client.nova'
```

---

## Paso 8 — Exportar keyrings y ceph.conf al controller

> **Nodo:** `[CEPH1]` y `[CONTROLLER]`

```bash
# [CEPH1] — exportar keyrings y configuración
sudo ceph auth get-or-create client.cinder -o /tmp/ceph.client.cinder.keyring
sudo ceph auth get-or-create client.glance -o /tmp/ceph.client.glance.keyring
sudo ceph auth get-or-create client.nova   -o /tmp/ceph.client.nova.keyring
sudo cp /etc/ceph/ceph.conf /tmp/ceph.conf

# Copiar al controller
scp /tmp/ceph.conf /tmp/ceph.client.*.keyring uceda@controller:/tmp/

# [CONTROLLER] — instalar ceph-common y colocar los ficheros
echo asdfghjkl | sudo -S apt install -y ceph-common

sudo cp /tmp/ceph.conf /etc/ceph/
sudo cp /tmp/ceph.client.cinder.keyring /etc/ceph/
sudo cp /tmp/ceph.client.glance.keyring /etc/ceph/
sudo cp /tmp/ceph.client.nova.keyring   /etc/ceph/
sudo chmod 640 /etc/ceph/ceph.client.*.keyring
sudo chown root:ceph /etc/ceph/ceph.client.*.keyring 2>/dev/null || true

# Verificar conectividad desde el controller
sudo ceph --id glance status
# Debe mostrar el estado del cluster Ceph
```

> Copiar también a **cada compute** si se va a configurar Nova ephemeral en Ceph:
> ```bash
> for node in compute1 compute2 compute3 compute4; do
>   scp /tmp/ceph.conf /tmp/ceph.client.nova.keyring uceda@$node:/tmp/
>   ssh uceda@$node 'echo asdfghjkl | sudo -S apt install -y ceph-common && \
>     sudo cp /tmp/ceph.conf /etc/ceph/ && \
>     sudo cp /tmp/ceph.client.nova.keyring /etc/ceph/'
> done
> ```

---

## Paso 9 — Configurar Glance para usar Ceph

> **Nodo:** `[CONTROLLER]`

```bash
# [CONTROLLER]
# Editar /etc/glance/glance-api.conf
echo asdfghjkl | sudo -S bash -c "cat >> /etc/glance/glance-api.conf << 'EOF'

[glance_store]
stores = rbd
default_store = rbd
rbd_store_pool = images
rbd_store_user = glance
rbd_store_ceph_conf = /etc/ceph/ceph.conf
rbd_store_chunk_size = 8
EOF"

# Reiniciar Glance
echo asdfghjkl | sudo -S systemctl restart glance-api
echo asdfghjkl | sudo -S systemctl status glance-api | grep Active

# Verificar — subir imagen de prueba y que vaya al pool de Ceph
. admin-openrc
openstack image create --disk-format raw --container-format bare \
  --file /dev/null --public test-ceph-image
openstack image list
# Luego en ceph1: sudo rbd ls images  → debe aparecer el UUID de la imagen
```

> **Por qué `raw` en lugar de `qcow2`:** Ceph RBD funciona mejor con imágenes en formato  
> `raw`. Glance convierte automáticamente al subir si se configura `image_conversion`.

---

## Paso 10 — Configurar Cinder para usar Ceph

> **Nodo:** `[CONTROLLER]` (cinder.conf) y `[STORAGE1]` (cinder-volume backend)

```bash
# [STORAGE1] — instalar ceph-common y copiar keyrings
echo asdfghjkl | sudo -S apt install -y ceph-common
scp uceda@controller:/tmp/ceph.conf /tmp/
scp uceda@controller:/tmp/ceph.client.cinder.keyring /tmp/
echo asdfghjkl | sudo -S cp /tmp/ceph.conf /etc/ceph/
echo asdfghjkl | sudo -S cp /tmp/ceph.client.cinder.keyring /etc/ceph/

# [STORAGE1] — añadir backend Ceph en cinder.conf
echo asdfghjkl | sudo -S bash -c "cat >> /etc/cinder/cinder.conf << 'EOF'

[ceph]
volume_driver = cinder.volume.drivers.rbd.RBDDriver
volume_backend_name = ceph
rbd_pool = volumes
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_flatten_volume_from_snapshot = false
rbd_max_clone_depth = 5
rbd_store_chunk_size = 4
rados_connect_timeout = -1
rbd_user = cinder
rbd_secret_uuid = 457eb676-33da-42ec-9a8c-9293d545c337
EOF"

# Añadir el backend en la sección [DEFAULT]
echo asdfghjkl | sudo -S sed -i \
  's/^enabled_backends = lvm/enabled_backends = lvm,ceph/' \
  /etc/cinder/cinder.conf

echo asdfghjkl | sudo -S systemctl restart cinder-volume

# [CONTROLLER] — registrar el tipo de volumen Ceph
. admin-openrc
openstack volume type create ceph
openstack volume type set ceph --property volume_backend_name=ceph
openstack volume type list
```

> **`rbd_secret_uuid`:** UUID arbitrario que se usará también en Nova (libvirt secret).  
> Debe ser el mismo en cinder.conf y en el secret XML de libvirt en cada compute.

---

## Paso 11 — Configurar Nova para usar Ceph (ephemeral)

> **Nodo:** cada `[COMPUTE]` — compute1, compute2, compute3, compute4

```bash
# Ejecutar en cada compute (ejemplo compute1):
# [COMPUTE1]

# Crear el libvirt secret para que Nova pueda acceder al pool 'vms'
cat > /tmp/secret.xml << 'EOF'
<secret ephemeral="no" private="no">
  <uuid>457eb676-33da-42ec-9a8c-9293d545c337</uuid>
  <usage type="ceph">
    <name>client.cinder secret</name>
  </usage>
</secret>
EOF

echo asdfghjkl | sudo -S virsh secret-define --file /tmp/secret.xml
CINDER_KEY=$(ssh uceda@ceph1 'sudo ceph auth get-key client.cinder')
echo asdfghjkl | sudo -S virsh secret-set-value \
  --secret 457eb676-33da-42ec-9a8c-9293d545c337 \
  --base64 "$CINDER_KEY"

# Configurar nova.conf para Ceph ephemeral
echo asdfghjkl | sudo -S bash -c "cat >> /etc/nova/nova.conf << 'EOF'

[libvirt]
images_type = rbd
images_rbd_pool = vms
images_rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_user = cinder
rbd_secret_uuid = 457eb676-33da-42ec-9a8c-9293d545c337
disk_cachemodes = network=writeback
EOF"

echo asdfghjkl | sudo -S systemctl restart nova-compute
```

---

## Paso 12 — Verificación final

> **Nodo:** `[CONTROLLER]`

```bash
# [CONTROLLER]
. admin-openrc

echo "=== Ceph status ==="
ssh uceda@203.0.113.234 'sudo ceph status'

echo ""
echo "=== Pools y uso ==="
ssh uceda@203.0.113.234 'sudo ceph df'

echo ""
echo "=== Servicios Cinder ==="
openstack volume service list

echo ""
echo "=== Tipos de volumen ==="
openstack volume type list

echo ""
echo "=== Crear volumen en backend Ceph ==="
openstack volume create --size 1 --type ceph test-ceph-vol
sleep 5
openstack volume list
# Verificar en Ceph:
# ssh uceda@203.0.113.234 'sudo rbd ls volumes'

echo ""
echo "=== Crear volumen en backend LVM ==="
openstack volume create --size 1 --type __DEFAULT__ test-lvm-vol
sleep 5
openstack volume list
```

---

## Notas de integración

### Por qué Ceph como backend de OpenStack

| Ventaja | Descripción |
|---------|-------------|
| Copy-on-Write clones | Lanzar VMs desde snapshot Ceph es instantáneo (no copia el disco completo) |
| Live migration sin shared storage | Nova puede migrar VMs en vivo porque el disco está en Ceph, accesible desde todos los computes |
| Sin single point of failure | El cluster Ceph replica automáticamente (en lab: replicación=1, en prod: replicación=3) |
| Backend único | Glance, Cinder y Nova usan el mismo cluster, ahorrando espacio (los volúmenes son COW clones de las imágenes) |

### Diagrama de flujo al lanzar una VM con Ceph

```
openstack server create
       │
       ▼
Nova scheduler → elige hypervisor
       │
       ▼
Nova (en compute) → clona imagen Glance (pool images) → disco en pool vms
       │                                                  (COW, instantáneo)
       ▼
libvirt arranca la VM usando rbd://ceph1/vms/UUID
       │
       ▼
VM accede a disco directamente en Ceph (sin pasar por el disco local del compute)
```

---

## Troubleshooting

### Ceph en estado HEALTH_WARN con "too few PGs"
```bash
# [CEPH1]
sudo ceph osd pool set volumes pg_num 64
sudo ceph osd pool set images pg_num 64
sudo ceph osd pool set vms pg_num 64
```

### Error "rbd: cannot open image" en Cinder
```bash
# [STORAGE1] — verificar que el keyring tiene permisos correctos
sudo ceph --id cinder rbd ls volumes
# Si falla, el keyring está mal copiado o mal nombrado
ls -la /etc/ceph/ceph.client.cinder.keyring
```

### Nova no puede acceder a Ceph (Authentication error)
```bash
# [COMPUTE] — verificar el secret de libvirt
sudo virsh secret-list
sudo virsh secret-get-value 457eb676-33da-42ec-9a8c-9293d545c337
# Debe devolver la clave base64 del usuario client.cinder
```

### Imagen Glance no aparece en rbd ls images
```bash
# Verificar que glance-api usa el store correcto
sudo grep -A5 'glance_store' /etc/glance/glance-api.conf
# Verificar logs
sudo journalctl -u glance-api -n 50 --no-pager
```
