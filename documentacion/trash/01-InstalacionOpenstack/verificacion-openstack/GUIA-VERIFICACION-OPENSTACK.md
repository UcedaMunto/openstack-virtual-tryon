# Guía de verificación del estado OpenStack

> **Fecha:** 2026-07-19  
> **Objetivo:** verificar paso a paso si los nodos, APIs, servicios, redes, Cinder/RBD, Glance, Nova, Neutron, Swift y Ceph están funcionales.  
> **Nodo principal de ejecución:** `controller` (`203.0.113.239`) salvo que se indique otro nodo.

---

## 0. Inventario esperado

| Rol | Hostname | IP pública | IP gestión |
|-----|----------|------------|------------|
| Controller | `serverocontroller` / `controller` | `203.0.113.239` | `10.0.0.11` |
| Compute1 | `compute1` | `203.0.113.240` | `10.0.0.10` |
| Compute2 | `compute2` | `203.0.113.241` | `10.0.0.12` |
| Compute3 | `compute3` | `203.0.113.242` | `10.0.0.13` |
| Compute4 | `compute4` | `203.0.113.243` | `10.0.0.14` |
| Storage1 | `storage1` | `203.0.113.244` | `10.0.0.15` |
| Object1 | `object1` | `203.0.113.245` | `10.0.0.51` |
| Object2 | `object2` | `203.0.113.246` | `10.0.0.52` |
| Object3 | `object3` | `object3` | `10.0.0.53` |

Resultado esperado: todos los nodos deben resolver por nombre y responder por IP de gestión.

---

## 1. Entrar al controller

Desde el host físico:

```bash
ssh uceda@203.0.113.239
```

Cargar credenciales de OpenStack:

```bash
echo asdfghjkl | sudo -S bash
source /root/admin-openrc
```

Validar identidad:

```bash
openstack token issue
```

Resultado esperado:

- Debe devolver un token.
- Si falla, revisar Keystone, Apache y `/root/admin-openrc`.

---

## 2. Verificar resolución de nombres

En `[CONTROLLER]`:

```bash
getent hosts controller compute1 compute2 compute3 compute4 storage1 object1 object2 object3
```

Resultado esperado:

```text
10.0.0.11 controller serverocontroller
10.0.0.10 compute1
10.0.0.12 compute2
10.0.0.13 compute3
10.0.0.14 compute4
10.0.0.15 storage1
10.0.0.51 object1
10.0.0.52 object2
10.0.0.53 object3
```

Si algún nombre apunta a otra IP, corregir `/etc/hosts` en el nodo afectado.

---

## 3. Verificar pings por red de gestión

En `[CONTROLLER]`:

```bash
for host in controller compute1 compute2 compute3 compute4 storage1 object1 object2 object3; do
  printf "%-12s " "$host"
  ping -c1 -W1 "$host" >/dev/null && echo OK || echo FAIL
done
```

Resultado esperado: todos `OK`.

Si falla un nodo:

```bash
ip -br addr
ip route
systemctl status systemd-networkd --no-pager
```

---

## 4. Verificar catálogo de servicios OpenStack

En `[CONTROLLER]`:

```bash
openstack service list
```

Servicios esperados:

| Servicio | Tipo |
|----------|------|
| Keystone | `identity` |
| Glance | `image` |
| Nova | `compute` |
| Placement | `placement` |
| Neutron | `network` |
| Cinder v3 | `volumev3` |
| Swift | `object-store` |

Si falta un servicio, revisar Keystone catalog y endpoints.

---

## 5. Verificar endpoints/API publicados

En `[CONTROLLER]`:

```bash
openstack endpoint list
```

Debe haber endpoints `public`, `internal` y `admin` para los servicios principales.

Verificación HTTP rápida:

```bash
for url in \
  http://controller:5000/v3/ \
  http://controller:8774/v2.1 \
  http://controller:8776/v3/ \
  http://controller:8778 \
  http://controller:9292 \
  http://controller:9696 \
  http://controller:8080; do
  printf "%-35s " "$url"
  curl -sS -o /dev/null -w "%{http_code}\n" --max-time 5 "$url" || echo FAIL
done
```

Resultados aceptables:

| API | Código esperado |
|-----|-----------------|
| Keystone `:5000/v3` | `200` |
| Nova `:8774/v2.1` | `200` |
| Cinder `:8776/v3` | `401` si no se pasa token |
| Placement `:8778` | `200` |
| Glance `:9292` | `300` o `200` |
| Neutron `:9696` | `200` |
| Swift `:8080` | `404` en raíz, normal sin ruta de cuenta |

---

## 6. Verificar servicios base del controller

En `[CONTROLLER]`:

```bash
for s in \
  apache2 mariadb rabbitmq-server memcached etcd \
  glance-api nova-api nova-scheduler nova-conductor \
  neutron-server neutron-openvswitch-agent neutron-l3-agent \
  neutron-dhcp-agent neutron-metadata-agent \
  cinder-scheduler swift-proxy; do
  printf "%-35s " "$s"
  systemctl is-active "$s" 2>/dev/null || true
done
```

Resultado esperado: todos `active`.

Nota: si `neutron-linuxbridge-agent` aparece `inactive`, no es problema si el despliegue usa OVS y `neutron-openvswitch-agent` está activo.

---

## 7. Verificar Nova y computes

En `[CONTROLLER]`:

```bash
openstack compute service list
openstack hypervisor list
```

Resultado esperado:

- `nova-scheduler`: `enabled/up`.
- `nova-conductor`: `enabled/up`.
- `nova-compute` en `compute1`, `compute2`, `compute3`, `compute4`: `enabled/up`.
- Hipervisores `compute1` a `compute4`: `up`.

En cada compute:

```bash
for node in 203.0.113.240 203.0.113.241 203.0.113.242 203.0.113.243; do
  echo "=== $node ==="
  ssh uceda@$node "echo asdfghjkl | sudo -S bash -lc '
    hostname
    for s in nova-compute neutron-openvswitch-agent libvirtd virtlogd openvswitch-switch; do
      printf \"%-30s \" \"$s\"
      systemctl is-active \"$s\" 2>/dev/null || true
    done
  '"
done
```

Resultado esperado: servicios activos.

---

## 8. Verificar Neutron

En `[CONTROLLER]`:

```bash
openstack network agent list
openstack network list
openstack subnet list
openstack router list
```

Resultado esperado:

- Agente L3 en controller vivo `:-)` y `UP`.
- Agente DHCP en controller vivo `:-)` y `UP`.
- Agentes OVS en controller y computes vivos `:-)` y `UP`.
- Router `router1` `ACTIVE/UP`.
- Redes esperadas:
  - `selfservice-net` con `10.10.10.0/24`.
  - `provider-net` con `192.168.122.0/24`.

---

## 9. Verificar Glance

En `[CONTROLLER]`:

```bash
openstack image list
openstack image show cirros-rbd
```

Resultado esperado:

- `cirros-rbd` en estado `active`.
- Si se usa RBD, debe existir también el objeto en el pool `images`.

Desde `[STORAGE1]`:

```bash
ssh uceda@203.0.113.244 "echo asdfghjkl | sudo -S rbd ls -l images"
```

Resultado esperado: imagen RBD y snapshot protegido.

---

## 10. Verificar Cinder y RBD

En `[CONTROLLER]`:

```bash
openstack volume service list
openstack volume backend pool list --long
openstack volume type list --long
openstack volume list --all-projects
```

Resultado esperado:

- `cinder-scheduler`: `enabled/up`.
- `storage1@ceph`: `enabled/up`.
- `storage1@lvm`: puede quedar `disabled/down`, porque fue reemplazado por Ceph.
- Pool activo: `storage1@ceph#ceph`.
- Tipo `ceph` con `volume_backend_name='ceph'`.

Desde `[STORAGE1]`:

```bash
rbd ls -l volumes
```

Resultado esperado: volúmenes Cinder visibles como objetos RBD.

---

## 11. Verificar Ceph

En `[STORAGE1]`:

```bash
ceph -s
ceph df
ceph osd tree
```

Resultado esperado:

```text
health: HEALTH_OK
mon: storage1 en quorum
mgr: active
osd: 1 up, 1 in
pgs: active+clean
```

Verificar pools RBD:

```bash
for pool in volumes images backups vms; do
  echo "--- $pool ---"
  rbd ls -l "$pool" || true
done
```

Puntos esperados:

- `volumes`: objetos de Cinder.
- `images`: imagen `cirros-rbd`.
- `vms`: disco ephemeral de la VM creada desde `cirros-rbd`.
- `backups`: puede estar vacío si no se configuró Cinder Backup.

---

## 12. Verificar Nova ephemeral RBD

En `[CONTROLLER]`:

```bash
openstack server list --all-projects
openstack server show test-rbd-ephemeral
```

Resultado esperado:

- `test-rbd-ephemeral`: `ACTIVE`.
- Host asignado: uno de los computes.

En `[STORAGE1]`:

```bash
rbd ls -l vms
```

Resultado esperado: disco con nombre similar a:

```text
<uuid>_disk  1 GiB  lock excl
```

---

## 13. Verificar Swift

En `[CONTROLLER]`:

```bash
swift stat
swift list
```

Verificar rings:

```bash
swift-ring-builder /etc/swift/account.builder
swift-ring-builder /etc/swift/container.builder
swift-ring-builder /etc/swift/object.builder
```

Resultado esperado:

- Account/container/object rings `up-to-date`.
- 3 replicas.
- 3 zones.
- 3 devices.
- Balance `0.00`.

Verificar object nodes:

```bash
for node in 203.0.113.245 203.0.113.246 203.0.113.247; do
  echo "=== $node ==="
  ssh uceda@$node "echo asdfghjkl | sudo -S bash -lc '
    hostname
    for s in swift-account swift-account-auditor swift-account-reaper swift-account-replicator \
             swift-container swift-container-auditor swift-container-replicator swift-container-updater \
             swift-object swift-object-auditor swift-object-reconstructor swift-object-replicator swift-object-updater rsync; do
      printf \"%-35s \" \"$s\"
      systemctl is-active \"$s\" 2>/dev/null || true
    done
    df -hT | grep -E \"/srv/node|/dev/vdb\" || true
  '"
done
```

Resultado esperado: servicios activos y `/srv/node/vdb` montado.

---

## 14. Prueba funcional mínima de OpenStack

En `[CONTROLLER]`:

```bash
source /root/admin-openrc
openstack server create \
  --flavor m1.tiny \
  --image cirros-rbd \
  --network selfservice-net \
  health-rbd-vm

for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  openstack server show health-rbd-vm -c name -c status -c OS-EXT-SRV-ATTR:host
  status=$(openstack server show health-rbd-vm -f value -c status 2>/dev/null || true)
  [ "$status" = ACTIVE ] && break
  [ "$status" = ERROR ] && break
  sleep 5
done
```

Si queda `ACTIVE`, Nova + Glance + Neutron + Ceph RBD funcionan juntos.

Eliminar VM de prueba:

```bash
openstack server delete health-rbd-vm
```

---

## 15. Cómo interpretar errores comunes

| Síntoma | Posible causa | Revisión |
|---------|---------------|----------|
| `openstack token issue` falla | Keystone/Apache o credenciales | `systemctl status apache2`, revisar `/root/admin-openrc` |
| API no responde | Servicio caído o endpoint incorrecto | `systemctl status <servicio>`, `openstack endpoint list` |
| Compute `down` | `nova-compute` caído o red mgmt rota | `journalctl -u nova-compute`, ping a controller |
| Neutron agent `xxx` | Agente caído o OVS con problema | `systemctl status neutron-openvswitch-agent openvswitch-switch` |
| Cinder backend `down` | `cinder-volume` o Ceph auth | `journalctl -u cinder-volume`, `ceph -s`, `rbd --id cinder ls volumes` |
| Glance upload falla | Backend RBD o permisos Ceph | `journalctl -u glance-api`, permisos de `/etc/ceph/ceph.conf` |
| VM queda en `ERROR` | Nova/Neutron/Ceph/libvirt | `openstack server event list`, `journalctl -u nova-compute` |
| Swift no lista objetos | Proxy/ring/object nodes | `swift stat`, rings, servicios swift en object nodes |

---

## 16. Estado esperado actual del laboratorio

Según la última validación realizada, el estado correcto esperado es:

- OpenStack APIs registradas y respondiendo.
- Todos los pings públicos y de gestión OK.
- `/etc/hosts` corregido en todos los nodos.
- Nova y los 4 computes `enabled/up`.
- Neutron con agentes OVS/L3/DHCP `UP`.
- Cinder usando `storage1@ceph` como backend activo.
- Ceph `HEALTH_OK`.
- Glance con imagen `cirros-rbd` activa en RBD.
- Swift operativo con 3 object nodes.
- `storage1@lvm disabled/down` es esperado porque fue reemplazado por RBD/Ceph.

---

## 17. Guardar evidencia de la verificación

En `[CONTROLLER]`:

```bash
mkdir -p /root/health-openstack-$(date +%Y%m%d-%H%M%S)
OUT=$(ls -td /root/health-openstack-* | head -1)

openstack service list > "$OUT/service-list.txt"
openstack endpoint list > "$OUT/endpoint-list.txt"
openstack compute service list > "$OUT/compute-services.txt"
openstack hypervisor list > "$OUT/hypervisors.txt"
openstack volume service list > "$OUT/volume-services.txt"
openstack volume backend pool list --long > "$OUT/cinder-pools.txt"
openstack network agent list > "$OUT/network-agents.txt"
openstack server list --all-projects > "$OUT/servers.txt"
openstack volume list --all-projects > "$OUT/volumes.txt"
swift stat > "$OUT/swift-stat.txt"

tar czf "$OUT.tar.gz" -C /root "$(basename "$OUT")"
ls -lh "$OUT.tar.gz"
```

En `[STORAGE1]`:

```bash
mkdir -p /root/health-ceph-$(date +%Y%m%d-%H%M%S)
OUT=$(ls -td /root/health-ceph-* | head -1)

ceph -s > "$OUT/ceph-status.txt"
ceph df > "$OUT/ceph-df.txt"
ceph osd tree > "$OUT/ceph-osd-tree.txt"
rbd ls -l volumes > "$OUT/rbd-volumes.txt"
rbd ls -l images > "$OUT/rbd-images.txt"
rbd ls -l vms > "$OUT/rbd-vms.txt"

tar czf "$OUT.tar.gz" -C /root "$(basename "$OUT")"
ls -lh "$OUT.tar.gz"
```
