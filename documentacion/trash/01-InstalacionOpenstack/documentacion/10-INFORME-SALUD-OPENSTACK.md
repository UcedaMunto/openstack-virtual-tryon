# Informe de salud OpenStack

> **Fecha:** 2026-07-19  
> **Estado general:** Operativo  
> **Resultado:** APIs, servicios, conectividad, Ceph/RBD, Swift y hosts validados. Se corrigieron entradas inconsistentes en `/etc/hosts` de todos los nodos.

---

## Resumen ejecutivo

El despliegue OpenStack queda saludable después de la integración RBD/Ceph:

| Área | Estado | Evidencia |
|------|--------|-----------|
| Catálogo Keystone | OK | Servicios `placement`, `glance`, `cinderv3`, `neutron`, `keystone`, `nova`, `swift` registrados |
| Endpoints API | OK | Endpoints public/internal/admin habilitados en `RegionOne` |
| APIs HTTP | OK | Keystone `200`, Nova `200`, Cinder `401`, Placement `200`, Glance `300`, Neutron `200`, Swift `404` en raíz |
| Nova | OK | Scheduler/conductor y `compute1`-`compute4` `enabled/up` |
| Hipervisores | OK | `compute1`-`compute4` `up` |
| Neutron | OK | L3, DHCP y OVS agents vivos (`:-)`) y `UP` |
| Cinder | OK | `storage1@ceph` `enabled/up`; `storage1@lvm` queda `disabled/down` |
| Glance | OK | `cirros-rbd` `active` |
| Ceph | OK | `HEALTH_OK`, MON/MGR/OSD activos, PGs `active+clean` |
| Swift | OK | Proxy activo, rings con 3 zonas/3 devices, object nodes activos |
| Pings | OK | Todas las IPs públicas y de gestión responden desde controller |
| Hosts | Corregido | `/etc/hosts` normalizado en controller, storage, computes y object nodes |

---

## Inventario validado

| Nodo | Hostname | IP pública | IP gestión | Rol |
|------|----------|------------|------------|-----|
| Controller | `serverocontroller` | `203.0.113.239` | `10.0.0.11` | APIs OpenStack, DB, RabbitMQ, Neutron, Swift proxy |
| Compute1 | `compute1` | `203.0.113.240` | `10.0.0.10` | Nova compute, Neutron OVS, libvirt |
| Compute2 | `compute2` | `203.0.113.241` | `10.0.0.12` | Nova compute, Neutron OVS, libvirt |
| Compute3 | `compute3` | `203.0.113.242` | `10.0.0.13` | Nova compute, Neutron OVS, libvirt |
| Compute4 | `compute4` | `203.0.113.243` | `10.0.0.14` | Nova compute, Neutron OVS, libvirt |
| Storage1 | `storage1` | `203.0.113.244` | `10.0.0.15` | Cinder volume, Ceph MON/MGR/OSD |
| Object1 | `object1` | `203.0.113.245` | `10.0.0.51` | Swift object/account/container |
| Object2 | `object2` | `203.0.113.246` | `10.0.0.52` | Swift object/account/container |
| Object3 | `object3` | `203.0.113.247` | `10.0.0.53` | Swift object/account/container |

---

## Conectividad validada

Desde `[CONTROLLER]` respondieron correctamente todas las IPs de gestión:

```text
10.0.0.10 OK
10.0.0.11 OK
10.0.0.12 OK
10.0.0.13 OK
10.0.0.14 OK
10.0.0.15 OK
10.0.0.51 OK
10.0.0.52 OK
10.0.0.53 OK
```

También respondieron todas las IPs públicas:

```text
203.0.113.239 OK
203.0.113.240 OK
203.0.113.241 OK
203.0.113.242 OK
203.0.113.243 OK
203.0.113.244 OK
203.0.113.245 OK
203.0.113.246 OK
203.0.113.247 OK
```

Y por nombre, después de corregir `/etc/hosts`:

```text
controller OK
compute1 OK
compute2 OK
compute3 OK
compute4 OK
storage1 OK
object1 OK
object2 OK
object3 OK
```

---

## Corrección de hosts aplicada

Se detectaron entradas inconsistentes en `/etc/hosts` en varios nodos, por ejemplo:

- `storage1` apuntando a `10.0.0.10` en un nodo.
- `compute3` y `compute4` con duplicados incorrectos usando `10.0.0.10`.
- Object nodes con inventario incompleto.

Se respaldó y normalizó `/etc/hosts` en los nueve nodos.

Backup creado en cada nodo:

```text
/etc/hosts.pre-health-hosts-fix-20260719-133500
```

Bloque final gestionado:

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

Resolución validada con `getent hosts` en los nodos.

---

## APIs y endpoints

Servicios registrados en Keystone:

```text
placement  placement
glance     image
cinderv3   volumev3
neutron    network
keystone   identity
nova       compute
swift      object-store
```

Endpoints habilitados en `RegionOne`:

| Servicio | Interfaces | URL base |
|----------|------------|----------|
| Keystone | public, internal, admin | `http://controller:5000/v3/` |
| Nova | public, internal, admin | `http://controller:8774/v2.1` |
| Cinder v3 | public, internal, admin | `http://controller:8776/v3/%(project_id)s` |
| Placement | public, internal, admin | `http://controller:8778` |
| Glance | public, internal, admin | `http://controller:9292` |
| Neutron | public, internal, admin | `http://controller:9696` |
| Swift | public, internal, admin | `http://controller:8080/v1...` |

Prueba HTTP local desde controller:

```text
http://controller:5000/v3/  200
http://controller:8774/v2.1 200
http://controller:8776/v3/  401
http://controller:8778      200
http://controller:9292      300
http://controller:9696      200
http://controller:8080      404
```

Notas:

- `401` en Cinder sin token es esperado.
- `300` en Glance raíz es esperado por versión/redirect de API.
- `404` en Swift raíz es esperado si se consulta sin ruta de cuenta autenticada.

---

## Servicios del controller

Servicios activos:

```text
apache2                         active
mariadb                         active
rabbitmq-server                 active
memcached                       active
etcd                            active
glance-api                      active
nova-api                        active
nova-scheduler                  active
nova-conductor                  active
neutron-server                  active
neutron-openvswitch-agent       active
neutron-l3-agent                active
neutron-dhcp-agent              active
neutron-metadata-agent          active
cinder-scheduler                active
swift-proxy                     active
```

`neutron-linuxbridge-agent` aparece `inactive`, pero el despliegue operativo usa `neutron-openvswitch-agent`, que está activo y reporta `UP` en Neutron.

Puertos principales escuchando:

```text
5000  Keystone
8774  Nova API
8776  Cinder API
8778  Placement
9292  Glance API
9696  Neutron API
8080  Swift proxy
3306  MariaDB en 10.0.0.11
5672  RabbitMQ
11211 Memcached en 10.0.0.11
```

---

## Nova y computes

Servicios Nova:

```text
nova-scheduler serverocontroller enabled/up
nova-conductor serverocontroller enabled/up
nova-compute   compute1          enabled/up
nova-compute   compute2          enabled/up
nova-compute   compute3          enabled/up
nova-compute   compute4          enabled/up
```

Hipervisores:

```text
compute1 QEMU 10.0.0.10 up
compute2 QEMU 10.0.0.12 up
compute3 QEMU 10.0.0.13 up
compute4 QEMU 10.0.0.14 up
```

Servicios por compute:

```text
nova-compute               active
neutron-openvswitch-agent  active
libvirtd                   active
virtlogd                   active
openvswitch-switch         active
```

Configuración RBD validada en los cuatro computes:

```ini
[libvirt]
rbd_user = cinder
rbd_secret_uuid = 457eb676-33da-42ec-9a8c-9293d545c337
images_type = rbd
images_rbd_pool = vms
images_rbd_ceph_conf = /etc/ceph/ceph.conf
```

Secreto libvirt presente en todos:

```text
457eb676-33da-42ec-9a8c-9293d545c337   ceph client.cinder secret
```

Instancias actuales:

```text
test-rbd-ephemeral ACTIVE  selfservice-net=10.10.10.144  cirros-rbd  m1.tiny
test-vm1           SHUTOFF selfservice-net=10.10.10.229, 192.168.122.115 cirros m1.tiny
```

---

## Neutron

Agentes reportados vivos y `UP`:

```text
L3 agent           serverocontroller UP
DHCP agent         serverocontroller UP
OVS agent          serverocontroller UP
OVS agent          compute1          UP
OVS agent          compute2          UP
OVS agent          compute3          UP
OVS agent          compute4          UP
```

Redes:

```text
selfservice-net  10.10.10.0/24
provider-net     192.168.122.0/24
router1          ACTIVE/UP
```

---

## Cinder y Ceph RBD

Cinder:

```text
cinder-scheduler          serverocontroller enabled/up
cinder-volume storage1@ceph enabled/up
cinder-volume storage1@lvm  disabled/down
```

Pool activo:

```text
storage1@ceph#ceph
storage_protocol='ceph'
volume_backend_name='ceph'
free_capacity_gb='18.84'
total_capacity_gb='18.84'
```

Tipo de volumen:

```text
ceph  volume_backend_name='ceph'
```

Volumen actual:

```text
test-rbd-vol in-use 1 GiB attached to test-vm1 on /dev/vdb
```

Ceph:

```text
health: HEALTH_OK
mon: 1 daemon, quorum storage1
mgr: storage1 active
osd: 1 up, 1 in
pools: 5
pgs: 129 active+clean
```

Pools:

```text
.mgr
volumes
images
backups
vms
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

---

## Glance

Imágenes activas:

```text
cirros
cirros
cirros-rbd active
```

`cirros-rbd` está almacenada en RBD y existe como objeto en el pool `images`.

---

## Swift

Swift está operativo:

```text
swift-proxy active
swift stat OK
```

Cuenta Swift:

```text
Containers: 1
Objects: 1
Bytes: 11
```

Container/objeto existente:

```text
test-container
tmp/swift-test.txt
```

Rings:

```text
account.ring.gz   up-to-date, 3 replicas, 3 zones, 3 devices, balance 0.00
container.ring.gz up-to-date, 3 replicas, 3 zones, 3 devices, balance 0.00
object.ring.gz    up-to-date, 3 replicas, 3 zones, 3 devices, balance 0.00
```

Dispositivos Swift:

```text
object1 10.0.0.51 vdb /srv/node/vdb active
object2 10.0.0.52 vdb /srv/node/vdb active
object3 10.0.0.53 vdb /srv/node/vdb active
```

Servicios activos en los tres object nodes:

```text
swift-account
swift-account-auditor
swift-account-reaper
swift-account-replicator
swift-container
swift-container-auditor
swift-container-replicator
swift-container-updater
swift-object
swift-object-auditor
swift-object-reconstructor
swift-object-replicator
swift-object-updater
rsync
```

---

## Observaciones

1. `storage1@lvm` aparece `disabled/down` porque fue reemplazado por `storage1@ceph`. No es un fallo.
2. `neutron-linuxbridge-agent` está `inactive` en controller, pero el despliegue usa OVS; `neutron-openvswitch-agent` está activo y los agentes Neutron reportan `UP`.
3. `br-vxlan` aparece `DOWN` o `UNKNOWN` en algunos nodos con IP `/32`; esto es consistente con el diseño corregido del lab para evitar rutas duplicadas sobre `10.0.0.0/24`. La conectividad de gestión y los agentes Neutron están OK.
4. Swift conserva `test-container/tmp/swift-test.txt` de una prueba anterior. No afecta salud.
5. `/etc/hosts` fue corregido en todos los nodos; los respaldos quedaron en `/etc/hosts.pre-health-hosts-fix-20260719-133500`.

---

## Comandos útiles de reverificación

Desde `[CONTROLLER]`:

```bash
source /root/admin-openrc
openstack service list
openstack endpoint list
openstack compute service list
openstack hypervisor list
openstack volume service list
openstack volume backend pool list --long
openstack network agent list
openstack server list --all-projects
openstack volume list --all-projects
swift stat
```

Desde `[STORAGE1]`:

```bash
ceph -s
ceph df
ceph osd tree
rbd ls -l volumes
rbd ls -l images
rbd ls -l vms
```

Desde cualquier nodo:

```bash
getent hosts controller compute1 compute2 compute3 compute4 storage1 object1 object2 object3
```
