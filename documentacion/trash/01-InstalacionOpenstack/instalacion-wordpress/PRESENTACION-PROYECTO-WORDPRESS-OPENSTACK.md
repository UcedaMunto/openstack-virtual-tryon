# Presentación del proyecto: WordPress sobre OpenStack con Ceph RBD

> **Fecha:** 2026-07-19  
> **Proyecto:** despliegue de WordPress usando recursos de OpenStack  
> **URL pública validada:** `http://203.0.113.239:8080/`  
> **Página de prueba validada:** `http://203.0.113.239:8080/?page_id=2`  
> **Guía técnica base:** `wordpress-openstack.md`

---

## 0) Conexión SSH desde la máquina anfitrión

Esta sección sirve para iniciar la demostración desde la máquina anfitrión, es decir, desde el equipo desde donde se administra el laboratorio OpenStack.

### Conectarse al controller

```bash
ssh uceda@203.0.113.239
```

Si se usa `sshpass` para ejecutar comandos no interactivos:

```bash
sshpass -p asdfghjkl ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  uceda@203.0.113.239
```

Una vez dentro del controller, elevar privilegios y cargar credenciales de OpenStack:

```bash
echo asdfghjkl | sudo -S -i
source /root/admin-openrc
```

Validar que la autenticación contra OpenStack funciona:

```bash
openstack token issue
```

<small>Si al ejecutar un comando como `openstack router list` aparece el error `Missing value auth-url required for auth plugin password`, significa que la terminal no tiene cargadas las variables de autenticación de OpenStack. No es un fallo del router ni de Horizon; falta cargar el archivo de credenciales.</small>

Comando correcto antes de usar la CLI de OpenStack:

```bash
source /root/admin-openrc
openstack router list
```

Si se está como usuario `uceda` y no como `root`, usar:

```bash
sudo su
source /root/admin-openrc
openstack router list
```

<small>`sudo su` cambia a `root`, pero no carga automáticamente las variables `OS_AUTH_URL`, `OS_USERNAME`, `OS_PASSWORD`, `OS_PROJECT_NAME`, etc. Por eso el comando sigue fallando hasta ejecutar `source /root/admin-openrc`.</small>

Para comprobar que las variables existen:

```bash
env | grep '^OS_'
```

Resultado esperado: deben verse variables como `OS_AUTH_URL`, `OS_USERNAME`, `OS_PROJECT_NAME` y `OS_USER_DOMAIN_NAME`.

### Conectarse al nodo de almacenamiento Ceph

```bash
ssh uceda@203.0.113.244
```

Validar salud de Ceph desde `storage1`:

```bash
echo asdfghjkl | sudo -S -i
ceph health
ceph status
rbd ls -l volumes
```

### Conectarse a los nodos compute

Los nodos compute ejecutan las instancias mediante Nova/KVM y mantienen servicios de virtualización y red como `nova-compute`, `libvirtd` y agentes Open vSwitch. En este laboratorio se accede a ellos desde la red de gestión.

```bash
ssh uceda@10.0.0.10
ssh uceda@10.0.0.12
ssh uceda@10.0.0.13
ssh uceda@10.0.0.14
```

Validaciones útiles dentro de cada compute:

```bash
echo asdfghjkl | sudo -S systemctl status nova-compute --no-pager
echo asdfghjkl | sudo -S systemctl status libvirtd --no-pager
echo asdfghjkl | sudo -S systemctl status openvswitch-switch --no-pager
echo asdfghjkl | sudo -S virsh list --all
ip addr
```

<small>Los comandos `openstack ...` normalmente se ejecutan desde el controller después de cargar `/root/admin-openrc`. En los computes se revisa principalmente el estado local del hipervisor, las interfaces, los bridges y las máquinas virtuales que Nova está ejecutando.</small>

### Conectarse a las VMs WordPress desde el controller

Las VMs `wp-web-01` y `wp-db-01` están en la red interna `10.10.10.0/24`. Para administrarlas de forma confiable desde el controller se usa el namespace del router de Neutron.

```bash
ip netns exec qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0 \
  ssh -i /root/.ssh/wp-key ubuntu@10.10.10.76
```

Ese comando entra a la VM web `wp-web-01`.

```bash
ip netns exec qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0 \
  ssh -i /root/.ssh/wp-key ubuntu@10.10.10.152
```

Ese comando entra a la VM de base de datos `wp-db-01`.

### Validar acceso web desde la máquina anfitrión

```bash
curl -I http://203.0.113.239:8080/
curl -I 'http://203.0.113.239:8080/?page_id=2'
curl -I http://203.0.113.239:8080/wp-login.php
```

Resultado esperado:

```text
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
```

### Resumen de accesos

Para los accesos a las VMs de WordPress, el valor que antes aparecía como `...` corresponde al namespace del router de Neutron. Se obtiene en el controller como `root`:

```bash
ip netns list | grep qrouter
```

En este despliegue el valor esperado es:

```text
qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0
```

También se puede guardar en una variable para no escribirlo completo:

```bash
ROUTER_NS=$(ip netns list | awk '/qrouter/ {print $1; exit}')
echo "$ROUTER_NS"
```

Uso con la variable:

```bash
ip netns exec "$ROUTER_NS" ssh -i /root/.ssh/wp-key ubuntu@10.10.10.76
ip netns exec "$ROUTER_NS" ssh -i /root/.ssh/wp-key ubuntu@10.10.10.152
```

<small>El namespace `qrouter-*` existe en el controller donde corre el agente L3 de Neutron. Si el comando devuelve vacío, revisar `openstack network agent list` y validar que el agente `L3 agent` esté vivo.</small>

| Destino | Comando / URL | Uso |
|---|---|---|
| Controller / APIs OpenStack | `ssh uceda@203.0.113.239` | Administrar Keystone, Nova, Neutron, Cinder, Horizon y reglas NAT/DNAT |
| Storage Ceph / Cinder backend | `ssh uceda@203.0.113.244` | Validar Ceph, RBD y backend de volúmenes |
| Compute 1 | `ssh uceda@10.0.0.10` | Revisar `nova-compute`, KVM/libvirt y OVS |
| Compute 2 | `ssh uceda@10.0.0.12` | Revisar hypervisor donde quedaron `wp-web-01` y `wp-db-01` |
| Compute 3 | `ssh uceda@10.0.0.13` | Revisar `nova-compute`, KVM/libvirt y OVS |
| Compute 4 | `ssh uceda@10.0.0.14` | Revisar `nova-compute`, KVM/libvirt y OVS |
| VM web | `ip netns exec "$ROUTER_NS" ssh -i /root/.ssh/wp-key ubuntu@10.10.10.76` | Administrar Nginx/WordPress |
| VM DB | `ip netns exec "$ROUTER_NS" ssh -i /root/.ssh/wp-key ubuntu@10.10.10.152` | Administrar MariaDB y volumen RBD |
| WordPress público | `http://203.0.113.239:8080/` | Consumir el servicio |
| Login WordPress | `http://203.0.113.239:8080/wp-login.php` | Administrar el sitio |

---

## 1) Resumen ejecutivo

Se implementó una solución completa de WordPress sobre una nube OpenStack funcional. El despliegue usa instancias Nova, red privada Neutron, Floating IP, reglas de seguridad, volumen Cinder respaldado por Ceph RBD, base de datos MariaDB y servidor web Nginx con PHP-FPM.

La solución fue desplegada y validada con acceso remoto, consumo del servicio web y gestión administrativa por SSH. Además, se verificó el estado de los servicios principales de OpenStack: Keystone, Nova, Neutron, Cinder y el backend Ceph.

---

## 2) Arquitectura implementada

### Nodos físicos / infraestructura

| Rol | Host | IP | Función |
|---|---:|---:|---|
| Controller | `serverocontroller` | `203.0.113.239` | APIs OpenStack, Horizon, Neutron L3/DHCP/OVS, NAT temporal para publicación externa |
| Compute | `compute1` | `10.0.0.10` | Hypervisor Nova/KVM |
| Compute | `compute2` | `10.0.0.12` | Hypervisor Nova/KVM donde quedaron `wp-web-01` y `wp-db-01` |
| Compute | `compute3` | `10.0.0.13` | Hypervisor Nova/KVM |
| Compute | `compute4` | `10.0.0.14` | Hypervisor Nova/KVM |
| Storage | `storage1` | `203.0.113.244` | Cinder/Ceph RBD |

### Recursos OpenStack usados por WordPress

| Recurso | Valor |
|---|---|
| Imagen | `ubuntu-22.04` |
| Flavor | `wp.small` (`1 vCPU`, `1024 MB RAM`, `8 GB disk`) |
| Red interna | `selfservice-net` |
| Red externa | `provider-net` |
| Router | `router1` |
| VM web | `wp-web-01` |
| VM DB | `wp-db-01` |
| Volumen DB | `wp-db-data` |
| Tipo de volumen | `ceph` |
| Backend Cinder | `storage1@ceph#ceph` |
| Objeto RBD | `volume-16dfbd99-dcb1-47a1-9bbe-ae063541fd35` |
| Floating IP web | `192.168.122.137` |
| Publicación externa | `203.0.113.239:8080 -> 192.168.122.137:80` |

### Servicios dentro de las VMs

| VM | IP interna | Servicios | Almacenamiento |
|---|---:|---|---|
| `wp-web-01` | `10.10.10.76` | Nginx, PHP-FPM, WordPress | Disco raíz de la instancia |
| `wp-db-01` | `10.10.10.152` | MariaDB | `/var/lib/mysql` montado desde `/dev/vdb1` respaldado por Ceph RBD |

---

## 3) Cumplimiento según rúbrica

| Aspecto de valoración | Descripción según la tarea | Evidencia del proyecto | Nota objetivo |
|---|---|---|---:|
| Supera los aprendizajes | Configura toda la solución según las especificaciones establecidas; despliega y se autentica correctamente en Horizon; despliega la instancia requerida usando volumen provisto por RBD; accede vía consola VNC y de manera remota; consume el servicio de la instancia; gestiona vía SSH. | La solución usa Nova, Neutron, Cinder, Ceph RBD, Floating IP, SSH, WordPress público y backend MariaDB persistente. El volumen `wp-db-data` está en `storage1@ceph#ceph` y visible como RBD. El servicio web responde `200 OK` en `http://203.0.113.239:8080/?page_id=2`. | 10 |
| Domina los aprendizajes | Configura toda la solución, despliega y se autentica en Horizon, despliega instancia requerida, accede vía consola VNC/remota y consume el servicio. | VMs `wp-web-01` y `wp-db-01` activas, servicio WordPress consumible, APIs OpenStack operativas. | 8-9 |
| Alcanza aprendizajes | Configura la mayoría de servicios respetando especificaciones y se autentica correctamente en Horizon. | La instalación supera este nivel porque también usa RBD, Floating IP, SSH y servicio publicado. | 6-7 |
| Próximo a alcanzar | Realiza algunas configuraciones con operación correcta. | No aplica; se configuró la solución completa. | 4-5 |
| No alcanza | No realiza configuraciones según especificaciones. | No aplica. | 0-3 |

**Conclusión:** el proyecto apunta al nivel **Supera los aprendizajes (10)** porque incluye despliegue funcional, persistencia sobre Ceph RBD, servicio consumible, acceso remoto y verificación de nodos/APIs.

---

## 4) Evidencias principales para presentar

### Servicio WordPress publicado

```bash
curl -I http://203.0.113.239:8080/
curl -I 'http://203.0.113.239:8080/?page_id=2'
```

Resultado esperado:

```text
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
```

### Login de WordPress

```bash
curl -I http://203.0.113.239:8080/wp-login.php
```

Credenciales de WordPress:

| Campo | Valor |
|---|---|
| URL | `http://203.0.113.239:8080/wp-login.php` |
| Usuario | `uceda` |
| Password | `aslKDIUR24` |
| Email | `admin@example.com` |

### Base de datos WordPress

| Campo | Valor |
|---|---|
| DB name | `wordpress` |
| DB user | `wp_user` |
| DB password | `aslKDIUR24` |
| DB host | `10.10.10.152` |
| DB port | `3306` |

---

## 5) Correcciones realizadas durante la implementación

1. **Flavor inicial insuficiente:** `m1.small` no permitió crear la instancia. Se creó `wp.small` con recursos adecuados.
2. **Imagen Ubuntu no disponible:** se importó `ubuntu-22.04` a Glance y quedó almacenada sobre RBD.
3. **Reglas SSH incorrectas:** las reglas iniciales usaban `10.0.0.0/24`, pero las VMs quedaron en `10.10.10.0/24`. Se corrigieron los Security Groups.
4. **Acceso de administración a VMs:** se usó el namespace `qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0` para administrar las VMs por IP interna.
5. **`provider-net` sin gateway real:** se creó gateway temporal `192.168.122.1/24` en `br-provider` y NAT hacia `enp1s0`.
6. **Salida a Internet en VMs:** se agregó `Acquire::ForceIPv4 "true";` para evitar fallos de `apt` por resolución IPv6 en una red sin salida IPv6.
7. **Volumen DB sin filesystem:** se formateó `/dev/vdb1` en `ext4`, se montó en `/var/lib/mysql` y se registró por UUID en `/etc/fstab`.
8. **Publicación externa:** como `192.168.122.137` solo era alcanzable desde el controller, se publicó el sitio con DNAT en `203.0.113.239:8080`.
9. **Restauración posterior:** al no cargar la página, se detectó que las VMs estaban `SHUTOFF`, el L3 agent no estaba vivo para Neutron y la regla DNAT se había perdido. Se reinició `neutron-l3-agent`, se arrancaron las VMs y se restauró NAT/DNAT.

---

## 6) Comandos que podrían pedir para mostrar redes, rangos y hosts

Ejecutar en `[CONTROLLER]`:

```bash
ssh uceda@203.0.113.239
echo asdfghjkl | sudo -S -i
source /root/admin-openrc
```

### Redes y subredes OpenStack

```bash
openstack network list
openstack network show selfservice-net
openstack network show provider-net
openstack subnet list
openstack subnet show selfservice-subnet
openstack subnet show provider-subnet
```

Sirven para mostrar redes creadas, tipo de red, IDs, CIDR, gateway y rangos DHCP/allocation pools.

### Routers, interfaces y Floating IPs

```bash
openstack router list
openstack router show router1
openstack router port list router1
openstack floating ip list
openstack port list
```

Sirven para explicar cómo se conecta `selfservice-net` con `provider-net` y qué Floating IP apunta a cada instancia.

### Rangos IP usados en el proyecto

```bash
openstack subnet list -f table
openstack subnet show provider-subnet -f yaml
openstack subnet show selfservice-subnet -f yaml
```

Rangos importantes:

| Red | Rango | Uso |
|---|---:|---|
| Gestión | `10.0.0.0/24` | Comunicación interna entre nodos OpenStack |
| Tenant/selfservice | `10.10.10.0/24` | IPs privadas de VMs WordPress |
| Provider/Floating | `192.168.122.0/24` | Floating IPs y gateway temporal `192.168.122.1` |
| Externa laboratorio | `203.0.113.0/24` | Acceso al controller y publicación por `203.0.113.239:8080` |

### Hosts y ubicación de instancias

```bash
openstack hypervisor list
openstack hypervisor show compute1
openstack hypervisor show compute2
openstack hypervisor show compute3
openstack hypervisor show compute4
openstack server list --long
openstack server show wp-web-01 -f yaml
openstack server show wp-db-01 -f yaml
```

Sirven para demostrar en qué compute corren las instancias y qué recursos consumen.

### Puertos Neutron de las VMs

```bash
openstack port list --server wp-web-01
openstack port list --server wp-db-01
openstack port show <PORT_ID>
```

Sirven para mostrar MAC, IP fija, Security Groups y asociación con Floating IP.

### Namespaces de red en el controller

```bash
ip netns list
ip netns exec qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0 ip -br addr
ip netns exec qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0 ip route
ip netns exec qdhcp-7c228e0a-a4d3-4bcc-89b2-0df8207692db ip -br addr
```

Sirven para explicar cómo Neutron implementa DHCP y routing dentro del controller.

---

## 7) Comandos para demostrar Horizon

### Acceso al portal Horizon

Abrir en navegador:

```text
http://203.0.113.239/horizon
```

Validar desde terminal que el servicio web responde:

```bash
curl -I http://203.0.113.239/horizon
```

Comprobaciones que se pueden mostrar en Horizon:

- Proyecto activo.
- Instancias `wp-web-01` y `wp-db-01`.
- Volumen `wp-db-data` adjunto a `wp-db-01`.
- Red `selfservice-net`.
- Router `router1`.
- Floating IP `192.168.122.137` asociado a `wp-web-01`.
- Consola VNC de las instancias.

---

## 8) Comandos básicos para analizar el estado de OpenStack y sus nodos

### Autenticación y APIs

```bash
source /root/admin-openrc
openstack token issue
openstack endpoint list
openstack catalog list
```

Sirven para validar Keystone y el catálogo de APIs.

### Nova / Compute

```bash
openstack compute service list
openstack hypervisor list
openstack hypervisor stats show
openstack server list --all-projects
openstack server list --name wp-
```

Sirven para validar servicios Nova, hypervisors y estado de instancias.

### Neutron / Red

```bash
openstack network agent list
openstack network list
openstack subnet list
openstack router list
openstack floating ip list
openstack security group list
openstack security group rule list sg-wordpress-web
openstack security group rule list sg-wordpress-db
```

Sirven para validar agentes L3/DHCP/OVS, redes, routers, Floating IPs y reglas de firewall.

### Cinder / Volúmenes

```bash
openstack volume service list
openstack volume type list
openstack volume list
openstack volume show wp-db-data
openstack server volume list wp-db-01
```

Sirven para validar Cinder y el volumen usado por MariaDB.

### Glance / Imágenes

```bash
openstack image list
openstack image show ubuntu-22.04
```

Sirven para validar que la imagen base Ubuntu esté disponible.

### Ceph / RBD

Ejecutar en `[STORAGE1]`:

```bash
ssh uceda@203.0.113.244
echo asdfghjkl | sudo -S -i
ceph health
ceph status
rbd ls -l volumes
rbd info volumes/volume-16dfbd99-dcb1-47a1-9bbe-ae063541fd35
```

Sirven para demostrar que Cinder usa Ceph RBD y que el volumen existe en el pool `volumes`.

### Servicios systemd en controller

```bash
systemctl status apache2 --no-pager
systemctl status nova-api --no-pager
systemctl status nova-scheduler --no-pager
systemctl status nova-conductor --no-pager
systemctl status neutron-server --no-pager
systemctl status neutron-l3-agent --no-pager
systemctl status neutron-dhcp-agent --no-pager
systemctl status neutron-openvswitch-agent --no-pager
systemctl status cinder-scheduler --no-pager
```

Sirven para validar que los servicios principales estén arriba desde el sistema operativo.

### Servicios systemd en computes

Ejecutar en cada compute:

```bash
systemctl status nova-compute --no-pager
systemctl status neutron-openvswitch-agent --no-pager
virsh list --all
ip -br addr
```

Sirven para demostrar que el hypervisor y el agente OVS están funcionando.

---

## 9) Comandos para demostrar consumo y administración de WordPress

### Consumo HTTP del servicio

```bash
curl -I http://203.0.113.239:8080/
curl -I 'http://203.0.113.239:8080/?page_id=2'
curl -I http://203.0.113.239:8080/wp-login.php
```

### Administración por SSH vía namespace del router

En `[CONTROLLER]`:

```bash
ip netns exec qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0 \
  ssh -i /root/.ssh/wp-key ubuntu@10.10.10.76

ip netns exec qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0 \
  ssh -i /root/.ssh/wp-key ubuntu@10.10.10.152
```

### Validar servicios dentro de las VMs

En `wp-web-01`:

```bash
systemctl is-active nginx
systemctl is-active php8.1-fpm
curl -I http://127.0.0.1
sudo nginx -t
```

En `wp-db-01`:

```bash
systemctl is-active mariadb
sudo ss -lntp | grep 3306
findmnt /var/lib/mysql
lsblk -f /dev/vdb
sudo mysql -e "SHOW DATABASES;"
sudo mysql -e "SELECT User, Host FROM mysql.user WHERE User='wp_user';"
```

---

## 10) Comandos para recuperar el servicio si vuelve a no cargar

### Levantar L3, VMs y publicación externa

Ejecutar en `[CONTROLLER]`:

```bash
source /root/admin-openrc

systemctl restart neutron-l3-agent
openstack server start wp-db-01 || true
openstack server start wp-web-01 || true

ip link set br-provider up
ip addr show br-provider | grep -q 192.168.122.1/24 || ip addr add 192.168.122.1/24 dev br-provider
sysctl -w net.ipv4.ip_forward=1

iptables -t nat -C POSTROUTING -s 192.168.122.0/24 -o enp1s0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 192.168.122.0/24 -o enp1s0 -j MASQUERADE

iptables -t nat -C PREROUTING -i enp1s0 -p tcp --dport 8080 -j DNAT --to-destination 192.168.122.137:80 2>/dev/null || \
  iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 8080 -j DNAT --to-destination 192.168.122.137:80

iptables -C FORWARD -i enp1s0 -o br-provider -p tcp -d 192.168.122.137 --dport 80 -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i enp1s0 -o br-provider -p tcp -d 192.168.122.137 --dport 80 -j ACCEPT
```

### Validar recuperación

```bash
openstack server list --name wp-
openstack network agent list
ip netns list | grep qrouter
iptables -t nat -S PREROUTING | grep 8080
curl -I 'http://203.0.113.239:8080/?page_id=2'
```

---

## 11) Guion breve de presentación

1. Mostrar Horizon y autenticación.
2. Mostrar instancias `wp-web-01` y `wp-db-01`.
3. Mostrar consola VNC de una instancia.
4. Mostrar volumen `wp-db-data` adjunto a `wp-db-01`.
5. Mostrar en terminal que el volumen está respaldado por Ceph RBD.
6. Mostrar redes `selfservice-net`, `provider-net`, router y Floating IP.
7. Abrir `http://203.0.113.239:8080/?page_id=2`.
8. Entrar por SSH a la VM web o DB.
9. Ejecutar comandos de estado de OpenStack: `compute service list`, `network agent list`, `volume service list`.
10. Concluir que se cumple el nivel de máxima valoración por integrar OpenStack, RBD, acceso remoto, VNC, SSH y servicio consumible.

---

## 12) Conclusión

El proyecto demuestra una implementación funcional y defendible de una aplicación web sobre OpenStack. Se usaron recursos de cómputo, red, almacenamiento persistente y publicación externa. La base de datos usa un volumen Cinder respaldado por Ceph RBD, el servicio WordPress es accesible por HTTP y las instancias pueden ser administradas por SSH y consola VNC desde Horizon.

La solución cumple los criterios del nivel **Supera los aprendizajes** porque no solo despliega la instancia requerida, sino que también integra almacenamiento RBD, validación de servicios OpenStack, consumo externo del servicio y gestión remota.