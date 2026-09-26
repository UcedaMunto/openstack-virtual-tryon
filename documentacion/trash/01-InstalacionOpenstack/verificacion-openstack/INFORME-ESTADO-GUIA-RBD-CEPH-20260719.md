# Informe de estado según guía RBD/Ceph OpenStack

> **Fecha:** 2026-07-19  
> **Guía base:** `documentacion/09-GUIA-RBD-CEPH-OPENSTACK.md`  
> **Objetivo:** revisar el proyecto y validar paso a paso el estado actual del despliegue OpenStack contra la guía RBD/Ceph.

---

## 1. Plan de validación basado en la guía

| Bloque | Fases guía | Qué se valida | Estado |
|--------|------------|---------------|--------|
| Inventario y backup | Fase 0 | Documentación, respaldos, hosts y conectividad | OK |
| Preparación de storage | Fases 1-3 | `storage1`, Ceph bootstrap, OSD en `/dev/vdb` | OK |
| Pools y usuarios Ceph | Fases 4-6 | Pools `volumes/images/backups/vms`, keyrings y permisos | OK |
| Libvirt/Nova auth RBD | Fases 7 y 9 | Secreto libvirt y configuración en computes | OK |
| Cinder RBD | Fases 8 y 10 | Backend `storage1@ceph`, volumen RBD y attach | OK |
| Glance RBD | Fase 11 | Imagen `cirros-rbd` en pool `images` | OK |
| Nova ephemeral RBD | Fase 12 | VM nueva con disco en pool `vms` | OK |
| Verificación final | Fase 13 | APIs, servicios, redes, Ceph, Swift | OK tras estabilizar memoria del controller |

---

## 2. Documentos del proyecto revisados

Se revisó la estructura actual del proyecto y se confirmó la existencia de:

```text
documentacion/09-GUIA-RBD-CEPH-OPENSTACK.md
documentacion/10-INFORME-SALUD-OPENSTACK.md
verificacion-openstack/GUIA-VERIFICACION-OPENSTACK.md
```

La guía `09-GUIA-RBD-CEPH-OPENSTACK.md` ya contiene la bitácora de ejecución hasta Fase 13 y marca Cinder RBD, Glance RBD y Nova ephemeral RBD como ejecutados y validados.

---

## 3. Estado general actual

Resultado actual: **OpenStack operativo**.

| Área | Estado actual | Comentario |
|------|---------------|------------|
| Conectividad entre nodos | OK | Todos los nombres principales responden por ping desde controller |
| Keystone/API base | OK | Hubo un `HTTP 500` transitorio en `token issue/service list`; al repetir, quedó OK |
| Nova | OK | Scheduler/conductor y computes activos; hipervisores `up` |
| Neutron | OK | Agentes L3, DHCP y OVS vivos y `UP` |
| Cinder | OK | Backend activo `storage1@ceph`; backend antiguo `storage1@lvm` `disabled/down` esperado |
| Glance | OK | Imagen `cirros-rbd` activa |
| Ceph | OK | `HEALTH_OK`, OSD `up/in`, PGs `active+clean` |
| Swift | OK | Proxy/rings/object nodes activos |
| Hosts | OK | Resolución correcta de `controller`, computes, storage y object nodes |
| Controller memoria | Corregido | Se añadió swap persistente de 2 GiB para evitar timeouts por presión de memoria |

---

## 4. Validación de conectividad y hosts

Desde `[CONTROLLER]` se validó resolución:

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

Ping por nombre:

```text
controller   OK
compute1     OK
compute2     OK
compute3     OK
compute4     OK
storage1     OK
object1      OK
object2      OK
object3      OK
```

Conclusión: la corrección previa de `/etc/hosts` sigue vigente y funcional.

---

## 5. APIs HTTP

Prueba HTTP desde controller:

```text
http://controller:5000/v3/          200
http://controller:8774/v2.1         200
http://controller:8776/v3/          401
http://controller:8778              200
http://controller:9292              300
http://controller:9696              200
http://controller:8080              404
```

Interpretación:

| API | Resultado | Interpretación |
|-----|-----------|----------------|
| Keystone | `200` | OK |
| Nova | `200` | OK |
| Cinder | `401` | Normal sin token autenticado |
| Placement | `200` | OK |
| Glance | `300` | Normal por endpoint/versionado |
| Neutron | `200` | OK |
| Swift | `404` | Normal al consultar raíz sin cuenta/ruta |

---

## 6. Keystone y catálogo

Durante la primera ejecución se observó:

```text
Internal Server Error (HTTP 500)
```

Afectó de forma transitoria a:

```text
openstack token issue
openstack service list
openstack endpoint list
openstack compute service list
```

Se revisaron servicios base del controller:

```text
apache2                   active
mariadb                   active
rabbitmq-server           active
memcached                 active
etcd                      active
glance-api                active
nova-api                  active
nova-scheduler            active
nova-conductor            active
neutron-server            active
cinder-scheduler          active
```

Al repetir, Keystone respondió correctamente:

```text
openstack token issue  OK
openstack service list OK
curl http://controller:5000/v3/ HTTP/1.1 200 OK
```

Servicios Keystone registrados:

```text
placement  placement
glance     image
cinderv3   volumev3
neutron    network
keystone   identity
nova       compute
swift      object-store
```

Conclusión: el `HTTP 500` fue transitorio. No queda como fallo activo, pero conviene vigilar logs si reaparece.

---

## 7. Nova y computes

Hipervisores actuales:

```text
compute1 QEMU 10.0.0.10 up
compute2 QEMU 10.0.0.12 up
compute3 QEMU 10.0.0.13 up
compute4 QEMU 10.0.0.14 up
```

Servicios en los computes:

```text
compute1: nova-compute active, neutron-openvswitch-agent active, libvirtd active, openvswitch-switch active
compute2: nova-compute active, neutron-openvswitch-agent active, libvirtd active, openvswitch-switch active
compute3: nova-compute active, neutron-openvswitch-agent active, libvirtd active, openvswitch-switch active
compute4: nova-compute active, neutron-openvswitch-agent active, libvirtd active, openvswitch-switch active
```

Configuración Nova RBD validada en los cuatro computes:

```ini
rbd_user = cinder
rbd_secret_uuid = 457eb676-33da-42ec-9a8c-9293d545c337
images_type = rbd
images_rbd_pool = vms
images_rbd_ceph_conf = /etc/ceph/ceph.conf
```

Secreto libvirt presente:

```text
457eb676-33da-42ec-9a8c-9293d545c337 ceph client.cinder secret
```

Instancias actuales:

```text
test-rbd-ephemeral ACTIVE  selfservice-net=10.10.10.144  cirros-rbd  m1.tiny
test-vm1           SHUTOFF selfservice-net=10.10.10.229, 192.168.122.115 cirros m1.tiny
```

Conclusión: Nova está funcional; `test-vm1` apagada no es error si se dejó así intencionalmente.

### Validación adicional y corrección aplicada

Al continuar el plan se intentó crear una VM temporal `health-rbd-vm` desde `cirros-rbd` para una prueba punta a punta. Durante esa prueba, las llamadas `openstack server list/show` empezaron a hacer timeout y el controller mostró presión fuerte de memoria:

```text
Mem: 5.6Gi usados de 5.6Gi
Mem available: 6-15 MiB
Swap: 0B
load average: hasta 60+
kswapd0 alto
```

No quedó una VM `health-rbd-vm` creada. El problema era operativo del controller, no de Ceph/RBD.

Corrección aplicada en `[CONTROLLER]`:

```bash
fallocate -l 2G /swapfile-openstack
chmod 600 /swapfile-openstack
mkswap /swapfile-openstack
swapon /swapfile-openstack
echo "/swapfile-openstack none swap sw 0 0" >> /etc/fstab
```

Estado posterior:

```text
Swap: 2.0 GiB activo
/swapfile-openstack usado inicialmente: ~282 MiB
openstack server list --all-projects: OK
openstack server show test-rbd-ephemeral: OK
openstack compute service list: OK
health-rbd-vm: no existe, no quedó basura de la prueba
```

VM RBD existente validada después de activar swap:

```text
test-rbd-ephemeral ACTIVE
host: compute2
IP: selfservice-net=10.10.10.144
vm_state: active
```

---

## 8. Neutron

Agentes reportados:

```text
L3 agent           serverocontroller alive UP
DHCP agent         serverocontroller alive UP
OVS agent          serverocontroller alive UP
OVS agent          compute1          alive UP
OVS agent          compute2          alive UP
OVS agent          compute3          alive UP
OVS agent          compute4          alive UP
```

Conclusión: Neutron está operativo con OVS.

---

## 9. Cinder RBD

Servicios Cinder:

```text
cinder-scheduler serverocontroller enabled/up
cinder-volume    storage1@ceph     enabled/up
cinder-volume    storage1@lvm      disabled/down
```

`storage1@lvm disabled/down` es esperado porque la guía dejó Ceph como backend activo y LVM como backend antiguo.

Pool activo:

```text
storage1@ceph#ceph
storage_protocol='ceph'
volume_backend_name='ceph'
free_capacity_gb='18.84'
total_capacity_gb='18.84'
```

Configuración relevante en `/etc/cinder/cinder.conf`:

```ini
enabled_backends = ceph
volume_driver = cinder.volume.drivers.rbd.RBDDriver
volume_backend_name = ceph
rbd_pool = volumes
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_user = cinder
rbd_secret_uuid = 457eb676-33da-42ec-9a8c-9293d545c337
```

Volumen actual:

```text
test-rbd-vol in-use 1 GiB attached to test-vm1 on /dev/vdb
```

Conclusión: Cinder RBD está funcional.

---

## 10. Ceph/RBD

Estado Ceph:

```text
health: HEALTH_OK
mon: 1 daemon, quorum storage1
mgr: storage1 active
osd: 1 up, 1 in
pools: 5
pgs: 129 active+clean
```

Capacidad:

```text
20 GiB total
164 MiB usados
20 GiB libres
```

OSD tree:

```text
host storage1
osd.0 up/in
```

Objetos RBD:

```text
pool volumes:
volume-23ef3eda-7d5b-4b9d-a756-38fc1c22d380  1 GiB

pool images:
0b5c228d-a6e3-416e-87b3-5421e1c8cc6e       44 MiB
0b5c228d-a6e3-416e-87b3-5421e1c8cc6e@snap  44 MiB protected

pool backups:
Sin objetos

pool vms:
5715b01e-7e73-4958-9d9f-90c026c0c439_disk  1 GiB lock excl
```

Conclusión: Ceph y RBD están funcionales.

---

## 11. Glance RBD

Imágenes actuales:

```text
cirros     active
cirros     active
cirros-rbd active
```

`cirros-rbd` existe en el pool RBD `images`.

Conclusión: Glance RBD está validado.

---

## 12. Swift

Swift stat:

```text
Containers: 1
Objects: 1
Bytes: 11
```

Container visible:

```text
test-container
```

Rings:

```text
account.ring.gz   up-to-date, 3 replicas, 3 zones, 3 devices, balance 0.00
container.ring.gz up-to-date, 3 replicas, 3 zones, 3 devices, balance 0.00
object.ring.gz    up-to-date, 3 replicas, 3 zones, 3 devices, balance 0.00
```

Object nodes:

```text
object1: swift-account active, swift-container active, swift-object active, rsync active, /srv/node/vdb mounted
object2: swift-account active, swift-container active, swift-object active, rsync active, /srv/node/vdb mounted
object3: swift-account active, swift-container active, swift-object active, rsync active, /srv/node/vdb mounted
```

Conclusión: Swift está funcional.

---

## 13. Hallazgos y errores actuales

| Severidad | Hallazgo | Estado | Acción |
|-----------|----------|--------|--------|
| Media | `HTTP 500` transitorio en Keystone/OpenStack CLI durante la primera pasada | No activo al repetir | Vigilar logs si reaparece |
| Media | Timeouts en `openstack server list/show` al intentar VM temporal `health-rbd-vm` | Corregido | Se activó swap persistente de 2 GiB en controller; Nova volvió a responder |
| Baja | `storage1@lvm disabled/down` | Esperado | No corregir; backend activo es Ceph |
| Baja | `test-vm1 SHUTOFF` | No necesariamente error | Arrancarla solo si se necesita usarla |
| Baja | `pool backups` vacío | Esperado | Solo se usará si se configura Cinder Backup |
| Baja | Swift mantiene `test-container` con 1 objeto | Esperado/prueba previa | Borrarlo solo si se quiere limpiar el lab |

No se detectan fallos activos bloqueantes en Nova, Neutron, Cinder, Glance, Ceph, Swift ni conectividad.

---

## 14. Recomendación operativa

1. Mantener `storage1@ceph` como backend activo de Cinder.
2. No reactivar `storage1@lvm` salvo que se haga rollback explícito.
3. Mantener el swapfile `/swapfile-openstack` activo en controller; con 5.6 GiB RAM y todos los servicios OpenStack, el nodo queda muy justo sin swap.
4. Vigilar Keystone si vuelve a aparecer `HTTP 500`:

```bash
journalctl -u apache2 --since "30 minutes ago" --no-pager
less /var/log/keystone/keystone-wsgi-public.log
```

5. Para una prueba completa de punta a punta, crear una VM temporal desde `cirros-rbd`, confirmar `ACTIVE`, verificar `rbd ls -l vms` y borrar la VM. Usar `timeout` para evitar clientes CLI colgados.
6. Si se desea dejar Swift limpio, borrar `test-container` después de confirmar que no se necesita.

---

## 15. Estado final

El estado actual del proyecto queda alineado con la guía `09-GUIA-RBD-CEPH-OPENSTACK.md`:

```text
OpenStack APIs: funcionales
Conectividad: OK
Nova: OK
Neutron: OK
Cinder RBD: OK
Glance RBD: OK
Nova ephemeral RBD: OK
Ceph: HEALTH_OK
Swift: OK
Errores activos bloqueantes: ninguno
Corrección aplicada: swap persistente de 2 GiB en controller por presión de memoria
Observación: Keystone tuvo un HTTP 500 transitorio, recuperado al repetir; Nova server list/show tuvo timeouts antes de activar swap y quedó recuperado
```
