# Limpiar KVM Ceph

Este archivo sirve para borrar el laboratorio Ceph anterior y dejar el entorno limpio.

No borra estas VMs:

- ubuntu-guest-1
- ubuntu-guest
- ubuntu-guest-2

## 1. Definir ruta de discos

```bash
export IMG_DIR=/var/lib/libvirt/images
```

## 2. Ver las VMs actuales

```bash
sudo virsh list --all
```

## 3. Apagar VMs Ceph si siguen activas

```bash
sudo virsh destroy ceph-1 2>/dev/null || true
```

```bash
sudo virsh destroy ceph-2 2>/dev/null || true
```

```bash
sudo virsh destroy ceph-3 2>/dev/null || true
```

```bash
sudo virsh destroy ceph-admin 2>/dev/null || true
```

```bash
sudo virsh destroy ceph-mon 2>/dev/null || true
```

```bash
sudo virsh destroy ceph-osd1 2>/dev/null || true
```

```bash
sudo virsh destroy ceph-osd2 2>/dev/null || true
```

```bash
sudo virsh destroy ceph-osd3 2>/dev/null || true
```

## 4. Eliminar definiciones de VMs Ceph

```bash
sudo virsh undefine ceph-1 2>/dev/null || true
```

```bash
sudo virsh undefine ceph-2 2>/dev/null || true
```

```bash
sudo virsh undefine ceph-3 2>/dev/null || true
```

```bash
sudo virsh undefine ceph-admin 2>/dev/null || true
```

```bash
sudo virsh undefine ceph-mon 2>/dev/null || true
```

```bash
sudo virsh undefine ceph-osd1 2>/dev/null || true
```

```bash
sudo virsh undefine ceph-osd2 2>/dev/null || true
```

```bash
sudo virsh undefine ceph-osd3 2>/dev/null || true
```

## 5. Borrar discos qcow2 del laboratorio Ceph

```bash
sudo rm -f $IMG_DIR/ceph-admin.qcow2
```

```bash
sudo rm -f $IMG_DIR/ceph-mon.qcow2
```

```bash
sudo rm -f $IMG_DIR/ceph-osd1.qcow2
```

```bash
sudo rm -f $IMG_DIR/ceph-osd1-data.qcow2
```

```bash
sudo rm -f $IMG_DIR/ceph-osd2.qcow2
```

```bash
sudo rm -f $IMG_DIR/ceph-osd2-data.qcow2
```

```bash
sudo rm -f $IMG_DIR/ceph-osd3.qcow2
```

```bash
sudo rm -f $IMG_DIR/ceph-osd3-data.qcow2
```

## 6. Borrar archivos temporales cloud-init

```bash
rm -f /tmp/user-data-ceph-admin.yaml
```

```bash
rm -f /tmp/user-data-ceph-mon.yaml
```

```bash
rm -f /tmp/user-data-ceph-osd1.yaml
```

```bash
rm -f /tmp/user-data-ceph-osd2.yaml
```

```bash
rm -f /tmp/user-data-ceph-osd3.yaml
```

## 7. Borrar red de laboratorio Ceph si quieres empezar completamente desde cero

Si quieres conservar la red `ceph-net`, salta esta seccion.

```bash
sudo virsh net-destroy ceph-net 2>/dev/null || true
```

```bash
sudo virsh net-undefine ceph-net 2>/dev/null || true
```

```bash
rm -f /tmp/ceph-net.xml
```

## 8. Verificar que Ceph fue eliminado

```bash
sudo virsh list --all
```

Despues de eso, ya no deberian aparecer estas VMs:

- ceph-1
- ceph-2
- ceph-3
- ceph-admin
- ceph-mon
- ceph-osd1
- ceph-osd2
- ceph-osd3

## 9. Verificar que no quedaron discos Ceph

```bash
sudo ls -lh $IMG_DIR | grep ceph || true
```

## 10. Estado final esperado

Debe seguir apareciendo solo lo que no es parte del laboratorio Ceph, por ejemplo:

```text
 Id   Name             State
---------------------------------
 1    ubuntu-guest-1   running
 -    ubuntu-guest     shut off
 -    ubuntu-guest-2   shut off
```

## 11. Recomendacion para reinstalar limpio

Cuando termines esta limpieza:

1. Revisa que `ceph-net` exista o recreala.
2. Crea primero solo `ceph-admin`.
3. Verifica con `sudo virsh list --all`.
4. Luego crea `ceph-mon`.
5. Despues crea los nodos OSD uno por uno.

No pegues varios bloques mezclados en una sola ejecucion.
