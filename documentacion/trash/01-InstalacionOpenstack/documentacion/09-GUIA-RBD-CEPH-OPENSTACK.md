# Guía: Integrar Ceph RBD con OpenStack actual

> **Fecha:** 2026-07-19  
> **Estado:** Cinder RBD, Glance RBD y Nova ephemeral RBD ejecutados y validados  
> **Objetivo:** Añadir Ceph/RBD al despliegue OpenStack manual actual para usar volúmenes Cinder sobre RBD.  
> **Alcance recomendado:** Cinder RBD primero. Glance RBD y Nova ephemeral RBD quedan como fases opcionales.  
> **Basado en documentación oficial:** Cinder RBD driver, Ceph + OpenStack RBD, Glance RBD backend y Nova/KVM RBD backing storage.

---

## Documentación oficial usada

- Cinder RBD driver:  
  <https://docs.openstack.org/cinder/latest/configuration/block-storage/drivers/ceph-rbd-volume-driver.html>

- Ceph + OpenStack RBD:  
  <https://docs.ceph.com/en/latest/rbd/rbd-openstack/>

- Glance storage backends, incluido RBD:  
  <https://docs.openstack.org/glance/latest/configuration/configuring.html#configuring-the-rbd-storage-backend>

- Nova/KVM backing storage, incluido RBD:  
  <https://docs.openstack.org/nova/latest/admin/configuration/hypervisor-kvm.html#configure-compute-backing-storage>

---

## Estado actual del laboratorio

Según las comprobaciones realizadas antes de ejecutar esta guía:

| Servicio | Estado actual | Backend actual |
|----------|---------------|----------------|
| Cinder | activo | LVM thin + iSCSI en `storage1@lvm` |
| Glance | activo | filesystem local (`fs:file`) |
| Nova | activo | discos locales/default libvirt en computes |
| Swift | activo | object nodes `object1`, `object2`, `object3` |

El backend Cinder actual es:

```text
cinder-volume    storage1@lvm    enabled/up
pool             storage1@lvm#LVM
driver           cinder.volume.drivers.lvm.LVMVolumeDriver
protocol         iSCSI
VG               cinder-volumes sobre /dev/vdb en storage1
```

Esta guía asume que los volúmenes Cinder actuales **no importan** y se pueden borrar. Aun así, se evita tocar Swift salvo que se elija explícitamente usar sus discos como OSD.

### Estado después de ejecutar la fase recomendada

Actualizado tras la ejecución del 2026-07-19:

| Componente | Estado validado |
|------------|-----------------|
| Ceph | cluster creado en `storage1`, FSID `e6d0c1bf-8386-11f1-a069-525400a2b3c4`, MON/MGR/OSD activos |
| OSD | `osd.0` sobre `/dev/vdb`, `up/in` |
| Pools | `volumes`, `images`, `backups`, `vms` creados e inicializados para RBD, `size=1`, `min_size=1` |
| Cinder | backend `storage1@ceph` `enabled/up`, pool `storage1@ceph#ceph`, protocolo `ceph` |
| Tipo de volumen | `ceph` creado con `volume_backend_name=ceph` |
| Volumen de prueba | `test-rbd-vol` creado en Cinder y visible como RBD `volume-23ef3eda-7d5b-4b9d-a756-38fc1c22d380` en pool `volumes` |
| Attach RBD | `test-rbd-vol` adjuntado correctamente a `test-vm1` activa en `compute1` como `/dev/vdb`; estado Cinder `in-use` |
| Nova computes | `compute1` a `compute4` con `rbd_user=cinder`, `rbd_secret_uuid=457eb676-33da-42ec-9a8c-9293d545c337` y `nova-compute` activo |
| Libvirt secret | secreto RBD creado en computes con UUID `457eb676-33da-42ec-9a8c-9293d545c337` |
| Glance | sin cambios, sigue usando filesystem local |
| Glance RBD | multistore configurado con `fs:file,rbd:rbd`, backend por defecto `rbd`, imagen `cirros-rbd` activa en pool `images` |
| Nova ephemeral | configurado en `compute1` a `compute4` con `images_type=rbd`, `images_rbd_pool=vms`, `images_rbd_ceph_conf=/etc/ceph/ceph.conf`, `rbd_user=cinder` y secreto libvirt común; validado con VM nueva `test-rbd-ephemeral` `ACTIVE` en `compute2` y disco RBD en pool `vms` |

Avisos actuales:

- `storage1@lvm` queda como servicio Cinder antiguo `enabled/down`; el backend activo real es `storage1@ceph`.
- Ceph quedó `HEALTH_OK` tras limpiar caché/journal en `storage1` y ajustar para este lab el umbral `mon_data_avail_warn` a `20`; los PGs están `active+clean`.
- El primer attach a `test-vm1` no se consideró validado porque la instancia estaba `SHUTOFF`; se limpió el attachment incompleto, se arrancó la VM y el attach posterior con la instancia `ACTIVE` quedó correcto.
- Para Glance RBD fue necesario dejar `/etc/ceph/ceph.conf` legible por servicios (`chmod 644`); con `600 root:root`, `glance-api` fallaba con `RADOS object not found (error calling conf_read_file)`.
- Nova ephemeral RBD quedó aplicado en los cuatro computes y validado creando `test-rbd-ephemeral` desde `cirros-rbd`; el disco `5715b01e-7e73-4958-9d9f-90c026c0c439_disk` apareció en el pool Ceph `vms`.
- Durante la validación final el lab KVM estaba apagado; fue necesario arrancar `controller`, `storage1`, `compute`, `compute2`, `compute3` y `compute4` desde el host antes de continuar. El error inicial fue de conectividad local (`No route to host`), no de Ceph.

---

## Decisión recomendada para este lab

### Opción recomendada: Ceph mínimo en `storage1`

Usar `storage1` como nodo Ceph inicial:

| Rol | Nodo | IP pública | IP mgmt | Disco Ceph |
|-----|------|------------|---------|------------|
| MON/MGR/OSD | storage1 | 203.0.113.244 | 10.0.0.15 | `/dev/vdb` |

Ventajas:

- No destruye Swift.
- Reutiliza el disco que hoy usa Cinder LVM.
- Permite probar RBD con Cinder de forma directa.
- Es suficiente para laboratorio.

Limitaciones:

- Un solo OSD no da alta disponibilidad.
- `size = 1` significa que si `storage1` cae, no hay réplica.
- En producción se recomienda mínimo 3 nodos Ceph con 3 MON y varios OSD.

### Opción alternativa: Ceph con `object1-3`

También podrías usar `object1`, `object2`, `object3` como OSDs, pero eso implica **destruir o desmontar Swift** en esos discos. No se recomienda si quieres conservar Swift funcionando.

Esta guía desarrolla la opción recomendada: **Ceph mínimo en `storage1`**, integrando primero Cinder RBD.

---

## Inventario usado por la guía

| Etiqueta | Nodo | SSH |
|----------|------|-----|
| `[CONTROLLER]` | serverocontroller | `ssh uceda@203.0.113.239` |
| `[STORAGE1]` | storage1 | `ssh uceda@203.0.113.244` |
| `[COMPUTE1]` | compute1 | `ssh uceda@203.0.113.240` |
| `[COMPUTE2]` | compute2 | `ssh uceda@203.0.113.241` |
| `[COMPUTE3]` | compute3 | `ssh uceda@203.0.113.242` |
| `[COMPUTE4]` | compute4 | `ssh uceda@203.0.113.243` |

Contraseñas usadas en el lab:

```text
sudo/SSH usuario uceda: asdfghjkl
OpenStack services: icc115
```

---

## Resumen de fases

| Fase | Acción | Destructiva | Recomendación |
|------|--------|-------------|---------------|
| 0 | Backup y estado inicial | No | Obligatoria |
| 1 | Borrar volúmenes Cinder de prueba | Sí, Cinder | Ejecutada |
| 2 | Preparar `storage1` y limpiar `/dev/vdb` | Sí, disco `/dev/vdb` | Ejecutada |
| 3 | Instalar y bootstrap Ceph | Sí, crea cluster | Ejecutada |
| 4 | Crear pools RBD | No destructiva | Ejecutada |
| 5 | Crear usuarios/keyrings Ceph | No destructiva | Ejecutada |
| 6 | Distribuir `ceph.conf` y keyrings | No destructiva | Ejecutada |
| 7 | Crear secreto libvirt para RBD | Cambia libvirt | Ejecutada |
| 8 | Configurar Cinder RBD | Cambia backend Cinder | Ejecutada |
| 9 | Configurar Nova para adjuntar RBD | Cambia Nova/libvirt auth | Ejecutada |
| 10 | Verificar Cinder RBD | No | Ejecutada: volumen y attach OK |
| 11 | Migrar Glance a RBD | Cambia backend Glance | Ejecutada: imagen `cirros-rbd` OK |
| 12 | Nova ephemeral en RBD | Cambia discos de instancias nuevas | Ejecutada: VM nueva OK |

### Bitácora de ejecución rápida

| Fase | Estado real | Evidencia |
|------|-------------|-----------|
| 0 | Hecha | Respaldos globales en `/root/openstack-config-backups/pre-rbd-ceph-20260719-092304/` en los nodos |
| 1 | Hecha | Volumen Cinder antiguo de prueba eliminado antes de reemplazar LVM |
| 2 | Hecha | `/dev/vdb` de `storage1` liberado de LVM y reutilizado como OSD Ceph |
| 3 | Hecha | Ceph FSID `e6d0c1bf-8386-11f1-a069-525400a2b3c4`, MON/MGR/OSD activos en `storage1` |
| 4 | Hecha | Pools `.mgr`, `volumes`, `images`, `backups`, `vms`; PGs `active+clean` |
| 5 | Hecha | Usuarios `client.glance`, `client.cinder`, `client.cinder-backup` creados |
| 6 | Hecha | `ceph.conf` y keyrings copiados a controller/storage/computes; permisos corregidos |
| 7 | Hecha | Secreto libvirt UUID `457eb676-33da-42ec-9a8c-9293d545c337` presente en computes |
| 8 | Hecha | Cinder activo con `storage1@ceph#ceph`, `storage_protocol='ceph'` |
| 9 | Hecha | `nova-compute` activo en `compute1` a `compute4` con auth RBD para volúmenes |
| 10 | Hecha | `test-rbd-vol` `in-use`, adjunto a `test-vm1` en `compute1` como `/dev/vdb` |
| 11 | Hecha | `cirros-rbd` creada en Glance con `stores='rbd'`; RBD existe en pool `images` |
| 12 | Hecha | `test-rbd-ephemeral` `ACTIVE` en `compute2`; RBD `5715b01e-7e73-4958-9d9f-90c026c0c439_disk` creado en pool `vms` |
| 13 | Hecha | Verificación general final OK: Cinder Ceph `up`, Nova/Neutron `up`, pools RBD con objetos esperados; Ceph `HEALTH_OK`; respaldo post-cambio creado |

---

## Fase 0 — Backup y foto inicial

> **Nodo:** `[CONTROLLER]`

```bash
ssh uceda@203.0.113.239
```

Guardar estado de OpenStack:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  mkdir -p /root/pre-ceph-rbd
  openstack volume service list > /root/pre-ceph-rbd/volume-services.txt
  openstack volume list --all-projects > /root/pre-ceph-rbd/volumes.txt
  openstack volume type list --long > /root/pre-ceph-rbd/volume-types.txt
  openstack server list --all-projects > /root/pre-ceph-rbd/servers.txt
  openstack image list > /root/pre-ceph-rbd/images.txt
  openstack compute service list > /root/pre-ceph-rbd/compute-services.txt
  openstack network agent list > /root/pre-ceph-rbd/network-agents.txt
  cp -a /etc/cinder /root/pre-ceph-rbd/etc-cinder
  cp -a /etc/nova /root/pre-ceph-rbd/etc-nova-controller
  cp -a /etc/glance /root/pre-ceph-rbd/etc-glance
  tar czf /root/pre-ceph-rbd.tar.gz -C /root pre-ceph-rbd
  ls -lh /root/pre-ceph-rbd.tar.gz
'
```

> Si el lab está en VMs KVM, también es recomendable hacer snapshots desde el host antes de tocar discos.

---

## Fase 1 — Borrar volúmenes Cinder actuales

> **Nodo:** `[CONTROLLER]`  
> **Destructivo:** borra volúmenes Cinder actuales.

Listar volúmenes:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  openstack volume list --all-projects
'
```

Borrar los volúmenes de prueba. Si solo existe `test-vol`:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  openstack volume delete test-vol || true
  openstack volume list --all-projects
'
```

Si hay más volúmenes y quieres borrar todos:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  for id in $(openstack volume list --all-projects -f value -c ID); do
    openstack volume delete "$id" || true
  done
  openstack volume list --all-projects
'
```

---

## Fase 2 — Preparar `storage1` y liberar `/dev/vdb`

> **Nodo:** `[STORAGE1]`  
> **Destructivo:** elimina el backend LVM actual `cinder-volumes` en `/dev/vdb`.

Entrar al nodo:

```bash
ssh uceda@203.0.113.244
```

Comprobar disco y servicios:

```bash
echo asdfghjkl | sudo -S bash -lc '
  hostname
  lsblk -f
  systemctl is-active cinder-volume || true
  vgs || true
  lvs -a || true
'
```

Parar Cinder Volume y target iSCSI:

```bash
echo asdfghjkl | sudo -S bash -lc '
  systemctl stop cinder-volume || true
  systemctl stop tgt || true
  systemctl stop target || true
'
```

Eliminar volúmenes lógicos y VG actual:

```bash
echo asdfghjkl | sudo -S bash -lc '
  lvremove -y /dev/cinder-volumes/* || true
  vgremove -y cinder-volumes || true
  pvremove -y /dev/vdb || true
  wipefs -a /dev/vdb
  sgdisk --zap-all /dev/vdb || true
  lsblk -f /dev/vdb
'
```

> Si `sgdisk` no existe:

```bash
echo asdfghjkl | sudo -S apt install -y gdisk
```

---

## Fase 3 — Instalar y crear cluster Ceph mínimo

> **Nodo:** `[STORAGE1]`

Instalar paquetes:

```bash
echo asdfghjkl | sudo -S bash -lc '
  apt update
  apt install -y cephadm ceph-common lvm2 gdisk crudini
  cephadm version || true
'
```

> En este lab `cephadm version` puede devolver `UNKNOWN` y salir con código no cero aunque `cephadm bootstrap` funcione. Por eso se deja con `|| true`.

Inicializar Ceph usando la IP de gestión `10.0.0.15`:

```bash
echo asdfghjkl | sudo -S cephadm bootstrap \
  --mon-ip 10.0.0.15 \
  --initial-dashboard-user admin \
  --initial-dashboard-password icc115 \
  --allow-overwrite
```

Instalar `ceph-common` en el host y verificar:

```bash
echo asdfghjkl | sudo -S bash -lc '
  cephadm install ceph-common
  ceph -s
'
```

Permitir modo laboratorio con un solo OSD:

```bash
echo asdfghjkl | sudo -S bash -lc '
  ceph config set mon mon_allow_pool_size_one true
  ceph config set global osd_pool_default_size 1
  ceph config set global osd_pool_default_min_size 1
  ceph config set mon mon_warn_on_pool_no_redundancy false
'
```

Añadir `/dev/vdb` como OSD:

```bash
echo asdfghjkl | sudo -S bash -lc '
  ceph orch device ls
  ceph orch daemon add osd storage1:/dev/vdb
  sleep 15
  ceph osd tree
  ceph -s
'
```

> Si Ceph rechaza pools con `size = 1`, confirma que `mon_allow_pool_size_one` está activo antes de crear los pools.

Resultado esperado:

```text
1 osds: 1 up, 1 in
mon: 1 daemons, quorum storage1
mgr: active
```

---

## Fase 4 — Crear pools RBD para OpenStack

> **Nodo:** `[STORAGE1]`

Crear pools:

```bash
echo asdfghjkl | sudo -S bash -lc '
  ceph osd pool create volumes 32
  ceph osd pool create images 32
  ceph osd pool create backups 32
  ceph osd pool create vms 32

  rbd pool init volumes
  rbd pool init images
  rbd pool init backups
  rbd pool init vms

  ceph osd lspools
  ceph df
'
```

Uso de cada pool:

| Pool | Servicio |
|------|----------|
| `volumes` | Cinder RBD |
| `images` | Glance RBD opcional |
| `backups` | Cinder Backup opcional |
| `vms` | Nova ephemeral RBD opcional |

---

## Fase 5 — Crear usuarios Ceph para OpenStack

> **Nodo:** `[STORAGE1]`

Crear usuarios con capacidades recomendadas por Ceph/OpenStack:

```bash
echo asdfghjkl | sudo -S bash -lc '
  ceph auth get-or-create client.glance \
    mon "profile rbd" \
    osd "profile rbd pool=images" \
    mgr "profile rbd pool=images"

  ceph auth get-or-create client.cinder \
    mon "profile rbd" \
    osd "profile rbd pool=volumes, profile rbd pool=vms, profile rbd-read-only pool=images" \
    mgr "profile rbd pool=volumes, profile rbd pool=vms"

  ceph auth get-or-create client.cinder-backup \
    mon "profile rbd" \
    osd "profile rbd pool=backups" \
    mgr "profile rbd pool=backups"

  ceph auth ls | grep -E "client.glance|client.cinder|client.cinder-backup"
'
```

Exportar archivos para OpenStack:

```bash
echo asdfghjkl | sudo -S bash -lc '
  mkdir -p /root/openstack-ceph
  ceph auth get-or-create client.glance -o /root/openstack-ceph/ceph.client.glance.keyring
  ceph auth get-or-create client.cinder -o /root/openstack-ceph/ceph.client.cinder.keyring
  ceph auth get-or-create client.cinder-backup -o /root/openstack-ceph/ceph.client.cinder-backup.keyring
  cp /etc/ceph/ceph.conf /root/openstack-ceph/ceph.conf
  chmod 600 /root/openstack-ceph/*
  mkdir -p /tmp/openstack-ceph
  cp /root/openstack-ceph/ceph.conf /tmp/openstack-ceph/
  cp /root/openstack-ceph/ceph.client.*.keyring /tmp/openstack-ceph/
  chown -R uceda:uceda /tmp/openstack-ceph
  ls -l /root/openstack-ceph
'
```

---

## Fase 6 — Distribuir `ceph.conf` y keyrings

### 6.1 Copiar a controller

> **Nodo:** `[STORAGE1]`

```bash
scp /tmp/openstack-ceph/ceph.conf uceda@203.0.113.239:/tmp/
scp /tmp/openstack-ceph/ceph.client.glance.keyring uceda@203.0.113.239:/tmp/
scp /tmp/openstack-ceph/ceph.client.cinder.keyring uceda@203.0.113.239:/tmp/
```

> **Nodo:** `[CONTROLLER]`

```bash
ssh uceda@203.0.113.239
```

```bash
echo asdfghjkl | sudo -S bash -lc '
  apt update
  apt install -y ceph-common python3-rbd crudini
  mkdir -p /etc/ceph
  cp /tmp/ceph.conf /etc/ceph/ceph.conf
  cp /tmp/ceph.client.glance.keyring /etc/ceph/ceph.client.glance.keyring
  cp /tmp/ceph.client.cinder.keyring /etc/ceph/ceph.client.cinder.keyring
  chown glance:glance /etc/ceph/ceph.client.glance.keyring
  chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring
  chmod 644 /etc/ceph/ceph.conf
  chmod 640 /etc/ceph/ceph.client.*.keyring
  ceph --id glance -s
  ceph --id cinder -s
'
```

### 6.2 Copiar a `storage1` para Cinder

> **Nodo:** `[STORAGE1]`

Como Ceph y Cinder están en el mismo nodo, solo hay que dejar los permisos correctos:

```bash
echo asdfghjkl | sudo -S bash -lc '
  cp /root/openstack-ceph/ceph.client.cinder.keyring /etc/ceph/ceph.client.cinder.keyring
  chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring
  chmod 640 /etc/ceph/ceph.client.cinder.keyring
  ceph --id cinder -s
'
```

### 6.3 Copiar a computes para adjuntar volúmenes RBD

> **Nodo:** `[STORAGE1]`

```bash
for node in 203.0.113.240 203.0.113.241 203.0.113.242 203.0.113.243; do
  echo "=== copiando a $node ==="
  scp /tmp/openstack-ceph/ceph.conf uceda@$node:/tmp/
  scp /tmp/openstack-ceph/ceph.client.cinder.keyring uceda@$node:/tmp/
done
```

> **Nodo:** `[LAPTOP]` o cualquier nodo con SSH hacia computes

```bash
for node in 203.0.113.240 203.0.113.241 203.0.113.242 203.0.113.243; do
  echo "=== preparando compute $node ==="
  ssh uceda@$node "echo asdfghjkl | sudo -S bash -lc '
    apt update
    apt install -y ceph-common crudini
    mkdir -p /etc/ceph
    cp /tmp/ceph.conf /etc/ceph/ceph.conf
    cp /tmp/ceph.client.cinder.keyring /etc/ceph/ceph.client.cinder.keyring
    chown nova:nova /etc/ceph/ceph.client.cinder.keyring
    chmod 640 /etc/ceph/ceph.client.cinder.keyring
    ceph --id cinder -s
  '"
done
```

---

## Fase 7 — Crear secreto libvirt para RBD en computes

> **Nodo:** `[STORAGE1]`

Generar un UUID fijo para todos los computes:

```bash
uuidgen
```

Ejemplo usado en esta guía:

```text
457eb676-33da-42ec-9a8c-9293d545c337
```

Guardar la clave de `client.cinder` en un archivo temporal local:

```bash
echo asdfghjkl | sudo -S ceph auth get-key client.cinder > /tmp/client.cinder.key
```

Definir el secreto en cada compute:

```bash
RBD_SECRET_UUID="457eb676-33da-42ec-9a8c-9293d545c337"
for node in 203.0.113.240 203.0.113.241 203.0.113.242 203.0.113.243; do
  echo "=== libvirt secret en $node ==="
  scp /tmp/client.cinder.key uceda@$node:/tmp/client.cinder.key
  ssh uceda@$node "cat > /tmp/secret.xml << EOF
<secret ephemeral='no' private='no'>
  <uuid>${RBD_SECRET_UUID}</uuid>
  <usage type='ceph'>
    <name>client.cinder secret</name>
  </usage>
</secret>
EOF
echo asdfghjkl | sudo -S virsh secret-define --file /tmp/secret.xml
echo asdfghjkl | sudo -S virsh secret-set-value --secret ${RBD_SECRET_UUID} --file /tmp/client.cinder.key
rm -f /tmp/client.cinder.key /tmp/secret.xml
echo asdfghjkl | sudo -S virsh secret-list
"
done
rm -f /tmp/client.cinder.key
```

> `virsh secret-set-value --base64 $(cat ...)` fue rechazado por libvirt por exponer el secreto como argumento de línea de comandos. Usar `--file` es el método correcto en este lab.

---

## Fase 8 — Configurar Cinder para RBD

Hay dos caminos:

1. **Recomendado:** mantener `lvm` y añadir `ceph` como segundo backend.
2. **Destructivo/simple:** reemplazar `lvm` por `ceph` como único backend.

Como tus volúmenes actuales no importan, puedes usar el camino simple. Aun así, mantener ambos backends ayuda a comparar y revertir.

### 8.1 Configurar `cinder.conf` en `storage1`

> **Nodo:** `[STORAGE1]`

Hacer backup:

```bash
echo asdfghjkl | sudo -S cp -a /etc/cinder/cinder.conf /etc/cinder/cinder.conf.pre-rbd
```

Configurar Ceph como backend adicional:

```bash
RBD_SECRET_UUID="457eb676-33da-42ec-9a8c-9293d545c337"
echo asdfghjkl | sudo -S bash -lc "
  apt install -y crudini
  crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends lvm,ceph
  crudini --set /etc/cinder/cinder.conf ceph volume_driver cinder.volume.drivers.rbd.RBDDriver
  crudini --set /etc/cinder/cinder.conf ceph volume_backend_name ceph
  crudini --set /etc/cinder/cinder.conf ceph rbd_pool volumes
  crudini --set /etc/cinder/cinder.conf ceph rbd_ceph_conf /etc/ceph/ceph.conf
  crudini --set /etc/cinder/cinder.conf ceph rbd_flatten_volume_from_snapshot false
  crudini --set /etc/cinder/cinder.conf ceph rbd_max_clone_depth 5
  crudini --set /etc/cinder/cinder.conf ceph rbd_store_chunk_size 4
  crudini --set /etc/cinder/cinder.conf ceph rados_connect_timeout -1
  crudini --set /etc/cinder/cinder.conf ceph rbd_user cinder
  crudini --set /etc/cinder/cinder.conf ceph rbd_secret_uuid ${RBD_SECRET_UUID}
"
```

Si quieres que **solo** quede Ceph y no LVM:

```bash
echo asdfghjkl | sudo -S sed -i 's/^enabled_backends *= *.*/enabled_backends = ceph/' /etc/cinder/cinder.conf
```

En la ejecución real se dejó **solo Ceph** como backend activo:

```ini
[DEFAULT]
enabled_backends = ceph

[ceph]
volume_driver = cinder.volume.drivers.rbd.RBDDriver
volume_backend_name = ceph
rbd_pool = volumes
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_user = cinder
rbd_secret_uuid = 457eb676-33da-42ec-9a8c-9293d545c337
```

La sección `[lvm]` puede seguir existiendo en `/etc/cinder/cinder.conf`, pero no se usa si `enabled_backends = ceph`.

Reiniciar Cinder Volume:

```bash
echo asdfghjkl | sudo -S systemctl restart cinder-volume
echo asdfghjkl | sudo -S systemctl status cinder-volume --no-pager
```

### 8.2 Crear tipo de volumen Ceph

> **Nodo:** `[CONTROLLER]`

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  openstack volume type create ceph || true
  openstack volume type set ceph --property volume_backend_name=ceph
  openstack volume type list --long
  openstack volume service list
  openstack volume backend pool list --long
'
```

Resultado esperado en pools:

```text
storage1@ceph#ceph ... volume_backend_name='ceph' storage_protocol='ceph'
```

---

## Fase 9 — Configurar Nova para adjuntar volúmenes RBD

> **Nodo:** cada compute (`compute1` a `compute4`)  
> Esto no cambia todavía el backend ephemeral de Nova. Solo permite que libvirt adjunte volúmenes Cinder RBD.

Ejecutar desde `[LAPTOP]` o desde cualquier nodo con SSH:

```bash
RBD_SECRET_UUID="457eb676-33da-42ec-9a8c-9293d545c337"
for node in 203.0.113.240 203.0.113.241 203.0.113.242 203.0.113.243; do
  echo "=== configurando nova-compute en $node ==="
  ssh uceda@$node "echo asdfghjkl | sudo -S bash -lc '
    cp -a /etc/nova/nova.conf /etc/nova/nova.conf.pre-rbd
    apt install -y crudini
    crudini --set /etc/nova/nova.conf libvirt rbd_user cinder
    crudini --set /etc/nova/nova.conf libvirt rbd_secret_uuid ${RBD_SECRET_UUID}
    systemctl restart nova-compute
    systemctl is-active nova-compute
  '"
done
```

Verificar desde controller:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  openstack compute service list
  openstack hypervisor list
'
```

---

## Fase 10 — Prueba de Cinder RBD

> **Nodo:** `[CONTROLLER]`

Estado ejecutado:

- `test-rbd-vol` se creó correctamente con tipo `ceph`.
- Cinder lo ubicó en `storage1@ceph#ceph`.
- En Ceph aparece como `volume-23ef3eda-7d5b-4b9d-a756-38fc1c22d380` dentro del pool `volumes`.
- El attach inicial contra `test-vm1` no queda validado porque la instancia estaba `SHUTOFF`; Cinder dejó un attachment incompleto en `attaching`, que se limpió y el volumen volvió a `available`.
- Después de arrancar `test-vm1`, el attach se repitió correctamente y el volumen quedó `in-use` en `compute1` como `/dev/vdb`.

Crear volumen RBD:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  openstack volume create --type ceph --size 1 test-rbd-vol
  sleep 10
  openstack volume show test-rbd-vol
  openstack volume list
'
```

Verificar en Ceph:

```bash
ssh uceda@203.0.113.244 "echo asdfghjkl | sudo -S rbd --id cinder ls -l volumes"
```

Adjuntar a una instancia existente si tienes una VM activa:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  openstack server list --all-projects
  openstack server add volume test-vm1 test-rbd-vol
  sleep 10
  openstack volume show test-rbd-vol
'
```

Si `test-vm1` está apagada (`SHUTOFF`), puedes probar creando una VM nueva o arrancándola primero:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  openstack server start test-vm1 || true
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    status=$(openstack server show test-vm1 -f value -c status 2>/dev/null || true)
    echo "status=$status"
    [ "$status" = ACTIVE ] && break
    sleep 5
  done
  openstack server show test-vm1 -c name -c status -c OS-EXT-SRV-ATTR:host
  openstack server add volume test-vm1 test-rbd-vol
  sleep 10
  openstack volume show test-rbd-vol -c name -c status -c attachments -c os-vol-host-attr:host
'
```

Si un intento de attach se queda en `attaching` sin attachment real, limpiar antes de repetir:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  for id in $(openstack volume attachment list --volume test-rbd-vol -f value -c ID); do
    openstack volume attachment delete "$id" || true
  done
  openstack volume set --state available test-rbd-vol || true
  openstack volume show test-rbd-vol -c name -c status -c attachments
'
```

Continuar solo cuando la instancia esté `ACTIVE` y el volumen esté `available`.

---

## Fase 11 — Opcional: mover Glance a RBD

> **Recomendación:** ejecutar esta fase solo cuando Cinder RBD ya esté probado.

Estado ejecutado:

- Backup creado: `/etc/glance/glance-api.conf.pre-rbd-live`.
- `enabled_backends = fs:file,rbd:rbd`.
- `default_backend = rbd`.
- `glance-api` reiniciado y escuchando en `0.0.0.0:9292`.
- Imagen `cirros-rbd` creada como `raw`, `active`, con propiedad `stores='rbd'`.
- En Ceph aparece la imagen RBD `0b5c228d-a6e3-416e-87b3-5421e1c8cc6e` en el pool `images`.

Corrección aplicada durante la ejecución:

```bash
echo asdfghjkl | sudo -S bash -lc '
  chmod 755 /etc/ceph
  chmod 644 /etc/ceph/ceph.conf
  sudo -u glance ceph --id glance -s
  systemctl restart glance-api
'
```

Sin ese permiso, `glance-api` arrancaba en bucle con:

```text
RADOS object not found (error calling conf_read_file)
```

Glance actualmente usa filesystem local. Mover Glance a RBD cambia dónde se guardan las imágenes nuevas. Las imágenes existentes en filesystem pueden quedar accesibles si se mantiene el backend `fs:file` como store adicional.

### 11.1 Configuración recomendada multistore

> **Nodo:** `[CONTROLLER]`

Backup:

```bash
echo asdfghjkl | sudo -S cp -a /etc/glance/glance-api.conf /etc/glance/glance-api.conf.pre-rbd
```

Configurar `fs` y `rbd` como backends, dejando RBD como default:

```bash
echo asdfghjkl | sudo -S bash -lc '
  apt install -y crudini
  crudini --set /etc/glance/glance-api.conf DEFAULT enabled_backends fs:file,rbd:rbd
  crudini --set /etc/glance/glance-api.conf glance_store default_backend rbd
  crudini --set /etc/glance/glance-api.conf rbd rbd_store_pool images
  crudini --set /etc/glance/glance-api.conf rbd rbd_store_user glance
  crudini --set /etc/glance/glance-api.conf rbd rbd_store_ceph_conf /etc/ceph/ceph.conf
  crudini --set /etc/glance/glance-api.conf rbd rbd_store_chunk_size 8
  crudini --set /etc/glance/glance-api.conf fs filesystem_store_datadir /var/lib/glance/images/
  systemctl restart glance-api
  systemctl is-active glance-api
'
```

> En OpenStack moderno se usa `enabled_backends = store_id:store_type` y `default_backend`. La forma antigua `stores = rbd` / `default_store = rbd` aparece en documentación Ceph histórica, pero para versiones recientes conviene usar multistore.

### 11.2 Subir imagen raw de prueba

> **Nodo:** `[CONTROLLER]`

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  IMAGE_ID=$(openstack image list --name cirros -f value -c ID | head -n1)
  openstack image save "$IMAGE_ID" --file /tmp/cirros-source.img
  qemu-img convert -O raw /tmp/cirros-source.img /tmp/cirros.raw
  openstack image create cirros-rbd \
    --disk-format raw \
    --container-format bare \
    --public \
    --file /tmp/cirros.raw
  openstack image list
'
```

Verificar en Ceph:

```bash
ssh uceda@203.0.113.244 "echo asdfghjkl | sudo -S rbd ls images"
```

---

## Fase 12 — Opcional: Nova ephemeral en RBD

> **Recomendación:** ejecutar al final, después de validar Cinder RBD y Glance RBD.  
> Afecta a instancias nuevas. Las instancias existentes con discos locales no se migran automáticamente.

Estado ejecutado hasta ahora:

- Backup creado en cada compute: `/etc/nova/nova.conf.pre-ephemeral-rbd-live`.
- Configuración aplicada en `compute1`, `compute2`, `compute3` y `compute4`:

```ini
[libvirt]
rbd_user = cinder
rbd_secret_uuid = 457eb676-33da-42ec-9a8c-9293d545c337
images_type = rbd
images_rbd_pool = vms
images_rbd_ceph_conf = /etc/ceph/ceph.conf
disk_cachemodes = network=writeback
```

- `nova-compute` quedó `active` en los 4 computes.
- `virsh secret-list` muestra el secreto Ceph `client.cinder secret` con UUID `457eb676-33da-42ec-9a8c-9293d545c337`.
- Validación final completada: `test-rbd-ephemeral` creada desde `cirros-rbd`, estado `ACTIVE`, host `compute2`, IP `10.10.10.144`.
- Ceph confirmó el disco ephemeral en RBD: `5715b01e-7e73-4958-9d9f-90c026c0c439_disk` en pool `vms`, tamaño `1 GiB`, lock exclusivo.
- Comprobación final: `nova-scheduler`, `nova-conductor` y `nova-compute` en `compute1`, `compute2`, `compute3` y `compute4` quedaron `enabled/up`; la funcionalidad RBD ephemeral quedó validada con una VM nueva real.

Nova puede usar RBD para discos ephemeral de instancias (`images_type = rbd`). Esto permite que los discos de las VMs estén en el pool `vms` y facilita evacuación/migración, pero requiere que todos los computes tengan acceso correcto a Ceph.

> **Nodo:** cada compute

```bash
RBD_SECRET_UUID="457eb676-33da-42ec-9a8c-9293d545c337"
for node in 203.0.113.240 203.0.113.241 203.0.113.242 203.0.113.243; do
  echo "=== nova ephemeral rbd en $node ==="
  ssh uceda@$node "echo asdfghjkl | sudo -S bash -lc '
    cp -a /etc/nova/nova.conf /etc/nova/nova.conf.pre-ephemeral-rbd
    apt install -y crudini
    crudini --set /etc/nova/nova.conf libvirt images_type rbd
    crudini --set /etc/nova/nova.conf libvirt images_rbd_pool vms
    crudini --set /etc/nova/nova.conf libvirt images_rbd_ceph_conf /etc/ceph/ceph.conf
    crudini --set /etc/nova/nova.conf libvirt rbd_user cinder
    crudini --set /etc/nova/nova.conf libvirt rbd_secret_uuid ${RBD_SECRET_UUID}
    crudini --set /etc/nova/nova.conf libvirt disk_cachemodes network=writeback
    systemctl restart nova-compute
    systemctl is-active nova-compute
  '"
done
```

Verificar desde controller:

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  openstack compute service list
  openstack server delete test-rbd-ephemeral || true
  openstack server create \
    --flavor m1.tiny \
    --image cirros-rbd \
    --network selfservice-net \
    test-rbd-ephemeral
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    openstack server show test-rbd-ephemeral \
      -c name -c status -c OS-EXT-STS:vm_state -c OS-EXT-SRV-ATTR:host
    status=$(openstack server show test-rbd-ephemeral -f value -c status 2>/dev/null || true)
    [ "$status" = ACTIVE ] && break
    [ "$status" = ERROR ] && break
    sleep 5
  done
  openstack server show test-rbd-ephemeral \
    -c name -c status -c OS-EXT-STS:vm_state -c OS-EXT-SRV-ATTR:host -c fault
'
```

Resultado validado el 2026-07-19:

```text
name                 test-rbd-ephemeral
status               ACTIVE
OS-EXT-STS:vm_state  active
OS-EXT-SRV-ATTR:host compute2
IP                   selfservice-net=10.10.10.144
```

Comando de verificación usado para los computes:

```bash
for node in 203.0.113.240 203.0.113.241 203.0.113.242 203.0.113.243; do
  echo "=== nova ephemeral rbd en $node ==="
  ssh uceda@$node "echo asdfghjkl | sudo -S bash -lc '
    grep -nE "^images_type|^images_rbd_pool|^images_rbd_ceph_conf|^rbd_user|^rbd_secret_uuid|^disk_cachemodes" /etc/nova/nova.conf
    systemctl is-active nova-compute
    virsh secret-list | grep 457eb676
  '"
done
```

Verificar en Ceph:

```bash
ssh uceda@203.0.113.244 "echo asdfghjkl | sudo -S rbd ls -l vms"
```

Resultado validado en `storage1`:

```text
NAME                                       SIZE   PARENT  FMT  PROT  LOCK
5715b01e-7e73-4958-9d9f-90c026c0c439_disk  1 GiB            2        excl
```

---

## Fase 13 — Verificación general final

Estado validado el 2026-07-19:

- Keystone, Glance, Cinder v3, Neutron, Nova, Placement y Swift aparecen registrados en el catálogo de servicios.
- `cinder-scheduler` está `enabled/up` y `cinder-volume storage1@ceph` está `enabled/up`; el backend antiguo `storage1@lvm` queda `disabled/down`.
- Pool Cinder activo: `storage1@ceph#ceph`, `storage_protocol='ceph'`, `volume_backend_name='ceph'`, `free_capacity_gb='18.84'`.
- Tipo de volumen `ceph` creado con `volume_backend_name='ceph'`.
- `nova-scheduler`, `nova-conductor` y `nova-compute` en `compute1`, `compute2`, `compute3` y `compute4` están `enabled/up`.
- Hipervisores `compute1`, `compute2`, `compute3` y `compute4` están `up`.
- Agentes Neutron L3, DHCP y Open vSwitch están vivos (`:-)`) y `UP`.
- Glance muestra `cirros-rbd` `active`.
- VM `test-rbd-ephemeral` está `ACTIVE` en `compute2` con IP `10.10.10.144`.
- Volumen `test-rbd-vol` está `in-use`, adjunto a `test-vm1` como `/dev/vdb`.
- Ceph mantiene MON/MGR/OSD activos, 5 pools y 129 PGs `active+clean`; estado final `HEALTH_OK`.
- Se corrigió el aviso previo `MON_DISK_LOW` limpiando caché apt y journal en `storage1`; como este lab usa una raíz pequeña de 12 GiB, se dejó `ceph config set mon mon_data_avail_warn 20`.
- Respaldo post-cambio creado en controller, storage1 y computes: `/root/openstack-config-backups/post-rbd-ceph-20260719-131730/` y `/root/openstack-config-backups/post-rbd-ceph-20260719-131730.tar.gz`.

Objetos RBD validados:

```text
pool volumes:
volume-23ef3eda-7d5b-4b9d-a756-38fc1c22d380  1 GiB

pool images:
0b5c228d-a6e3-416e-87b3-5421e1c8cc6e       44 MiB
0b5c228d-a6e3-416e-87b3-5421e1c8cc6e@snap  44 MiB  protected

pool vms:
5715b01e-7e73-4958-9d9f-90c026c0c439_disk  1 GiB  lock excl
```

> **Nodo:** `[CONTROLLER]`

```bash
echo asdfghjkl | sudo -S bash -lc '
  source /root/admin-openrc
  echo "=== OpenStack services ==="
  openstack service list

  echo "=== Cinder services ==="
  openstack volume service list

  echo "=== Cinder pools ==="
  openstack volume backend pool list --long

  echo "=== Volume types ==="
  openstack volume type list --long

  echo "=== Nova ==="
  openstack compute service list
  openstack hypervisor list

  echo "=== Neutron ==="
  openstack network agent list

  echo "=== Glance ==="
  openstack image list
'
```

> **Nodo:** `[STORAGE1]`

```bash
echo asdfghjkl | sudo -S bash -lc '
  ceph -s
  ceph df
  rbd ls volumes
  rbd ls images || true
  rbd ls vms || true
'
```

---

## Comandos de rollback rápido

### Volver Cinder a LVM

> **Nodo:** `[STORAGE1]`

Solo sirve si no destruiste definitivamente el VG LVM o si lo recreas. Si seguiste esta guía y usaste `/dev/vdb` como OSD, LVM ya no existe.

```bash
echo asdfghjkl | sudo -S bash -lc '
  cp -a /etc/cinder/cinder.conf.pre-rbd /etc/cinder/cinder.conf
  systemctl restart cinder-volume
  systemctl status cinder-volume --no-pager
'
```

### Volver Glance a filesystem

> **Nodo:** `[CONTROLLER]`

```bash
echo asdfghjkl | sudo -S bash -lc '
  cp -a /etc/glance/glance-api.conf.pre-rbd /etc/glance/glance-api.conf
  systemctl restart glance-api
  systemctl status glance-api --no-pager
'
```

### Quitar Nova ephemeral RBD

> **Nodo:** cada compute

```bash
for node in 203.0.113.240 203.0.113.241 203.0.113.242 203.0.113.243; do
  ssh uceda@$node "echo asdfghjkl | sudo -S bash -lc '
    cp -a /etc/nova/nova.conf.pre-ephemeral-rbd /etc/nova/nova.conf
    systemctl restart nova-compute
    systemctl is-active nova-compute
  '"
done
```

---

## Troubleshooting

### `cinder-volume` no arranca con RBD

> **Nodo:** `[STORAGE1]`

```bash
echo asdfghjkl | sudo -S bash -lc '
  journalctl -u cinder-volume -n 100 --no-pager
  grep -nE "enabled_backends|\[ceph\]|volume_driver|rbd_" /etc/cinder/cinder.conf
  ceph --id cinder -s
  rbd --id cinder ls volumes
'
```

Problemas comunes:

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `Permission denied` | keyring mal copiado o permisos incorrectos | `chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring` |
| `No such file or directory ceph.conf` | falta `/etc/ceph/ceph.conf` | copiar desde `storage1` |
| `pool volumes does not exist` | pool no creado o no inicializado | crear pool y `rbd pool init volumes` |
| backend no aparece | `enabled_backends` no incluye `ceph` | corregir `[DEFAULT] enabled_backends` |

### Nova no adjunta volumen RBD

> **Nodo:** compute donde cae la VM

```bash
echo asdfghjkl | sudo -S bash -lc '
  journalctl -u nova-compute -n 100 --no-pager
  virsh secret-list
  virsh secret-get-value 457eb676-33da-42ec-9a8c-9293d545c337
  ceph --id cinder -s
'
```

Problemas comunes:

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `secret not found` | falta secret libvirt en ese compute | repetir Fase 7 |
| `auth failed` | clave de `client.cinder` incorrecta | repetir `virsh secret-set-value` |
| `rbd image not found` | volumen no se creó o pool equivocado | revisar Cinder pool y `rbd ls volumes` |

### Ceph queda en `HEALTH_WARN`

Con un solo OSD es normal ver avisos de falta de redundancia. Para laboratorio se puede aceptar si el cluster permite crear RBDs.

```bash
echo asdfghjkl | sudo -S ceph health detail
```

Si el aviso es por pools sin `size = 1`:

```bash
echo asdfghjkl | sudo -S bash -lc '
  for pool in volumes images backups vms; do
    ceph osd pool set "$pool" size 1
    ceph osd pool set "$pool" min_size 1
  done
  ceph -s
'
```

### Glance RBD falla al subir imagen

> **Nodo:** `[CONTROLLER]`

```bash
echo asdfghjkl | sudo -S bash -lc '
  journalctl -u glance-api -n 100 --no-pager
  ceph --id glance -s
  rbd --id glance ls images
  grep -nE "enabled_backends|default_backend|\[rbd\]|rbd_store" /etc/glance/glance-api.conf
'
```

---

## Notas importantes

### No mezclar pools

La documentación oficial de Cinder advierte que el pool RBD de Cinder debería ser exclusivo. No uses el mismo pool para Glance, Cinder y Nova.

Usar pools separados:

```text
volumes -> Cinder
images  -> Glance
vms     -> Nova ephemeral
backups -> Cinder Backup
```

### Imágenes raw para RBD

Ceph recomienda usar imágenes `raw` cuando Glance/Nova trabajan con RBD. `qcow2` funciona como formato de imagen Glance, pero para clones COW eficientes con RBD es mejor `raw`.

### Cinder RBD primero

El orden seguro es:

```text
1. Ceph cluster OK
2. Cinder RBD OK
3. Adjuntar volumen RBD a VM OK
4. Glance RBD opcional
5. Nova ephemeral RBD opcional
```

No conviene mover Glance y Nova al mismo tiempo que Cinder, porque si algo falla es más difícil aislar el problema.

### Swift no es Ceph

Swift y Ceph/RBD son sistemas distintos. Swift puede seguir funcionando en paralelo. No hace falta borrar Swift para usar RBD en Cinder.

---

## Estado esperado al final de la fase recomendada

Tras completar hasta Fase 10:

```text
Ceph:
  storage1 MON/MGR/OSD activo
  pool volumes inicializado para RBD

Cinder:
  cinder-volume storage1@ceph enabled/up
  volume type ceph -> volume_backend_name=ceph
  volumen test-rbd-vol creado en pool volumes
  test-rbd-vol adjuntado a test-vm1 como /dev/vdb

Nova:
  computes tienen ceph-common, ceph.conf, keyring client.cinder
  libvirt secret creado con UUID común
  instancias pueden adjuntar volúmenes RBD

Glance:
  sin cambios, sigue usando filesystem local salvo que ejecutes Fase 11

Swift:
  sin cambios
```
