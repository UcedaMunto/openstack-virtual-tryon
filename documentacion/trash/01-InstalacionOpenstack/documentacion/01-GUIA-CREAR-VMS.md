# Guía: Crear VMs en OpenStack — Lab ICC115

> **Convención de nodos en esta guía:**
> - `[CONTROLLER]` → ejecutar en `serverocontroller` — `ssh uceda@203.0.113.239`
> - `[COMPUTE1]` → ejecutar en `compute1` — `ssh uceda@203.0.113.240`
> - `[LAPTOP]` → ejecutar en tu ThinkPad local
>
> Todos los comandos `openstack` se ejecutan en el **controller**. Los comandos de verificación de bajo nivel (OVS, systemctl) se ejecutan en el nodo correspondiente.

### Estado de avance

| Paso | Tarea | Estado |
|------|-------|--------|
| 0 | Cargar credenciales | ✅ Hecho |
| 1a | Crear flavors (m1.tiny, m1.small) | ✅ Hecho |
| 1b | Crear red provider-net | ✅ Hecho |
| 1c | Crear subred provider-subnet | ✅ Hecho |
| 2 | Crear red self-service + subred | ✅ Hecho |
| 3 | Crear router y conectar redes | ✅ Hecho |
| 4 | Configurar security group | ✅ Hecho |
| 5 | Crear keypair | ✅ Hecho |
| 6 | Verificar imagen cirros | ✅ Hecho (2 imágenes activas) |
| 7 | Lanzar VM test-vm1 | ✅ Hecho (ID: f7f88261-aa8b-4c10-83dc-86846c243998) |
| 8 | Asignar Floating IP | ✅ Hecho (192.168.122.115 → 10.10.10.229) |
| 9 | Conectarse a la VM | ✅ Hecho (SSH vía qrouter namespace) |

---

## Paso 0 — Cargar credenciales de administrador ✅ HECHO

> **Nodo:** `[CONTROLLER]`

Antes de cualquier comando `openstack`, el cliente necesita saber a qué servidor conectarse y con qué usuario. Esto se hace exportando variables de entorno:

```bash
# [CONTROLLER] ssh uceda@203.0.113.239
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=icc115
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
```

> Estas variables le indican al cliente OpenStack que use Keystone en `http://controller:5000/v3` con el usuario `admin` del proyecto `admin`. Sin esto, todos los comandos fallan con "No password entered".

---

## Paso 1 — Flavors y red Provider ✅ HECHO

> **Nodo:** `[CONTROLLER]` — todos los comandos `openstack` se envían a la API de Nova/Neutron que corre en el controller.

### Flavors creados

Los flavors definen el perfil de recursos (vCPUs, RAM, disco) que tendrá cada VM. Sin flavor no se puede lanzar ninguna instancia.

```
# Ya creados:
openstack flavor list

+----+----------+------+------+-----------+-------+-----------+
| ID | Name     |  RAM | Disk | Ephemeral | VCPUs | Is Public |
+----+----------+------+------+-----------+-------+-----------+
| 1  | m1.tiny  |  512 |    1 |         0 |     1 | True      |
| 2  | m1.small | 2048 |   20 |         0 |     1 | True      |
+----+----------+------+------+-----------+-------+-----------+
```

> Para este lab usar `m1.tiny` — compute1 solo tiene 11 GB de disco disponibles.

---

### ¿Qué es la red provider?

Es la red que conecta directamente las VMs con la red física del host (tu laptop). Usa el bridge OVS `br-provider` que está conectado a `enp8s0`. Es de tipo **flat** (sin VLAN tagging). Se marca como `--external` para que Neutron sepa que es la red de salida al exterior.

En este lab, la red provider usa el rango `192.168.122.0/24` que es la red de la interfaz del bridge en tu laptop.

```bash
# [CONTROLLER] YA EJECUTADO — resultado obtenido:
openstack network create \
  --share \
  --external \
  --provider-physical-network provider \
  --provider-network-type flat \
  provider-net
# → id: bfb73be8-75c3-4fa6-8030-fe1ace43db7f  status: ACTIVE ✅
```

- `--share`: visible para todos los proyectos
- `--external`: es la red de salida/flotante
- `--provider-physical-network provider`: nombre que mapea al `bridge_mappings = provider:br-provider` en OVS
- `--provider-network-type flat`: sin VLAN, tráfico directo

```bash
# [CONTROLLER] YA EJECUTADO — resultado obtenido:
openstack subnet create \
  --network provider-net \
  --allocation-pool start=192.168.122.100,end=192.168.122.200 \
  --dns-nameserver 8.8.8.8 \
  --gateway 192.168.122.1 \
  --subnet-range 192.168.122.0/24 \
  provider-subnet
# → id: 0117bb8c-29e9-4624-b576-a8d613a2b98d  pool: 192.168.122.100-200 ✅
```

- `--allocation-pool`: rango de IPs que Neutron puede asignar a floating IPs y VMs directas
- `--gateway 192.168.122.1`: gateway que usará el router virtual de Neutron
- `--subnet-range`: el bloque CIDR completo de la red

---

## Paso 2 — Crear la red Self-Service (red interna / VXLAN) ✅ HECHO

> **Nodo:** `[CONTROLLER]`

### ¿Qué es la red self-service?

Es la red privada de las VMs. Usa **VXLAN** para encapsular el tráfico entre el compute y el controller a través del túnel en la interfaz `enp7s0` (red de management `10.0.0.x`). Las VMs en esta red tienen IPs privadas (`10.10.10.x`) y solo pueden salir al exterior a través del router virtual de Neutron.

```bash
# [CONTROLLER] YA EJECUTADO — resultado obtenido:
openstack network create selfservice-net
# → id: 7c228e0a-a4d3-4bcc-89b2-0df8207692db
# → provider:network_type: vxlan   VNI: 640   status: ACTIVE ✅
# → mtu: 1450 (reducido 50 bytes por overhead del encapsulado VXLAN)
```

```bash
# [CONTROLLER] YA EJECUTADO:
openstack subnet create --network selfservice-net --dns-nameserver 8.8.8.8 --gateway 10.10.10.1 --subnet-range 10.10.10.0/24 selfservice-subnet
# → id: 426cf5ef-4ffb-4035-8468-8d948eb6f68b   cidr: 10.10.10.0/24 ✅
```

- `10.10.10.0/24`: rango privado solo visible dentro de OpenStack
- `10.10.10.1`: IP del router virtual en este lado

---

## Paso 3 — Crear el Router virtual y conectar las redes ✅ HECHO

> **Nodo:** `[CONTROLLER]` para comandos `openstack`. El namespace del router se crea automáticamente en el `[CONTROLLER]` (es donde corre `neutron-l3-agent`).

### ¿Qué hace el router?

El router virtual de Neutron (gestionado por `neutron-l3-agent` en el controller) hace **NAT** entre la red self-service y la red provider. Permite que las VMs internas accedan al exterior y que se les asignen Floating IPs para acceso desde fuera.

```bash
# [CONTROLLER] YA EJECUTADO:
openstack router create router1
openstack router set router1 --external-gateway provider-net
openstack router add subnet router1 selfservice-subnet
# → router1 status: ACTIVE ✅
# → external gateway: 192.168.122.122 (del pool provider)
# → interfaz interna: 10.10.10.1
```

```bash
# [CONTROLLER] YA VERIFICADO — namespaces creados:
sudo ip netns list
# qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0  ← router NAT ✅
# qdhcp-7c228e0a-...  ← DHCP de selfservice-net ✅
# qdhcp-bfb73be8-...  ← DHCP de provider-net ✅
```

---

## Paso 4 — Configurar el Security Group ✅ HECHO

> **Nodo:** `[CONTROLLER]`

### ¿Qué es un security group?

Es el firewall virtual de OpenStack. Por defecto, el grupo `default` **bloquea todo el tráfico entrante** a las VMs. Necesitas crear reglas para permitir ping (ICMP) y SSH (TCP/22).

```bash
# [CONTROLLER] YA EJECUTADO:
SG_ID=$(openstack security group list --project admin -f value -c ID)
openstack security group rule create --proto icmp $SG_ID
# → regla ICMP ingress 0.0.0.0/0 ✅
openstack security group rule create --proto tcp --dst-port 22 $SG_ID
# → regla TCP/22 ingress 0.0.0.0/0 ✅
```

> El tráfico **saliente** desde la VM está permitido por defecto. Solo necesitas configurar el entrante.

---

## Paso 5 — Crear un Keypair (clave SSH) ✅ HECHO

> **Nodo:** `[CONTROLLER]` para crear el keypair. El par de claves queda registrado en OpenStack — la clave pública se inyecta en las VMs, la privada la guardas tú.

### ¿Qué es un keypair?

OpenStack inyecta una clave pública SSH dentro de la VM al crearla (a través de cloud-init). Así puedes conectarte sin contraseña. Necesitas registrar tu clave pública en OpenStack.

```bash
# [CONTROLLER] YA EJECUTADO:
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
# → keypair 'mykey' registrado  fingerprint: 0b:8c:56:26:3c:0a:44:b7:94:0b:97:5d:80:2f:08:05 ✅
```

> Para copiar la clave privada a tu laptop y conectarte a las VMs directamente desde él:
> ```bash
> # [LAPTOP] Ejecutar en tu ThinkPad:
> scp uceda@203.0.113.239:/root/.ssh/id_rsa ~/mykey-openstack.pem
> chmod 600 ~/mykey-openstack.pem
> ```
> **Nota:** el `scp` falla si lo ejecutas desde dentro del controller. Debe hacerse desde el laptop.

---

## Paso 6 — Verificar la imagen disponible ✅ HECHO

> **Nodo:** `[CONTROLLER]` — Glance almacena las imágenes en `/var/lib/glance/images/` del controller.

Las imágenes son los sistemas operativos base para las VMs. Ya hay dos imágenes `cirros` en Glance. **Cirros** es una imagen mínima de ~20 MB diseñada para pruebas en OpenStack — arranca en segundos.

```bash
# [CONTROLLER]
openstack image list
```

Deberías ver:
```
+--------------------------------------+--------+--------+
| ID                                   | Name   | Status |
+--------------------------------------+--------+--------+
| 08a1b944-...                         | cirros | active |
| d0d3e2ce-...                         | cirros | active |
+--------------------------------------+--------+--------+
```

Usaremos `cirros` para las pruebas. Credenciales por defecto de cirros:
- Usuario: `cirros`
- Password: `gocubsgo`

---

## Paso 7 — Lanzar la primera VM ✅ HECHO

> **Nodo:** `[CONTROLLER]` para el comando `openstack server create`. La VM se crea y corre **físicamente en `[COMPUTE1]`**.

### Errores encontrados y corregidos

| Error | Causa | Corrección |
|-------|-------|------------|
| `m1.tyny` | Typo en el nombre del flavor | Usar `m1.tiny` |
| `More than one Image exists with the name 'cirros'` | Hay 2 imágenes con ese nombre | Usar el ID en vez del nombre |
| VM en estado ERROR | `[service_user] auth_url = https://controller/identity` incorrecto en `nova.conf` de compute1 | Cambiar a `http://controller:5000/v3` y reiniciar `nova-compute` |

### Imágenes disponibles

```
08a1b944-03b4-4f6e-b8ad-7a72116204fb  cirros  active  ← usar este
d0d3e2ce-ffe8-4b84-a6bc-f414d573d21f  cirros  active
```

### ¿Qué hace `openstack server create`?

1. `[CONTROLLER]` Nova Scheduler selecciona compute1
2. `[CONTROLLER]` Nova API envía la orden a `nova-compute` vía RabbitMQ
3. `[COMPUTE1]` Libvirt/KVM crea la VM con QEMU
4. `[COMPUTE1]` Neutron OVS agent conecta la interfaz de red al bridge `br-int`
5. `[CONTROLLER]` El agente DHCP asigna IP de la subred self-service
6. `[COMPUTE1]` Cloud-init inyecta el keypair SSH

```bash
# [CONTROLLER] ← EJECUTAR ESTO AHORA
NET_ID=$(openstack network show selfservice-net -f value -c id)

openstack server create \
  --flavor m1.tiny \
  --image 08a1b944-03b4-4f6e-b8ad-7a72116204fb \
  --nic net-id=$NET_ID \
  --security-group default \
  --key-name mykey \
  test-vm1
```

- `--flavor m1.tiny`: 1 vCPU, 512 MB RAM, 1 GB disco
- `--image cirros`: imagen base a usar
- `--nic net-id=$NET_ID`: conectar a la red self-service
- `--security-group default`: aplicar las reglas de firewall configuradas
- `--key-name mykey`: inyectar la clave SSH pública

```bash
# [CONTROLLER] Ver el estado de la VM (esperar que pase de BUILD a ACTIVE):
openstack server list

# [CONTROLLER] Ver el log de arranque (útil para diagnóstico):
openstack console log show test-vm1

# [CONTROLLER] Ver detalles completos:
openstack server show test-vm1
```

```bash
# [COMPUTE1] Verificar que la VM existe en libvirt:
sudo virsh list --all
# Debe aparecer la VM con estado 'running'
```

---

## Paso 8 — Asignar una Floating IP (acceso externo) ✅ HECHO

> **Nodo:** `[CONTROLLER]` — Neutron L3 agent configura la regla NAT en el namespace `qrouter` del controller.

La VM tiene IP privada (`10.10.10.x`). Para acceder desde fuera del cluster necesitas una **Floating IP** del pool de la red provider.

```bash
# [CONTROLLER] Crear una Floating IP del pool provider-net
openstack floating ip create provider-net

# [CONTROLLER] Ver la IP asignada
openstack floating ip list

# [CONTROLLER] Asociar la Floating IP a la VM
FIP=$(openstack floating ip list -f value -c "Floating IP Address" | head -1)
openstack server add floating ip test-vm1 $FIP

echo "La VM es accesible en: $FIP"
```

---

## Paso 9 — Conectarse a la VM ✅ HECHO

> **Nodo:** El SSH y VNC se pueden hacer desde `[CONTROLLER]` o desde `[LAPTOP]`.

### ⚠️ Problema de conectividad — causa y solución

**Problema 1 — El controller no tiene ruta a `192.168.122.x`:**  
El namespace principal del controller (enp1s0/enp7s0) no tiene interfaz en la red provider `192.168.122.x`. Los paquetes se pierden por enp1s0 hacia internet. La Floating IP `192.168.122.115` solo existe dentro del **namespace Neutron `qrouter`**.

**Solución:** lanzar SSH desde dentro del namespace del router usando `ip netns exec`.

**Problema 2 — Incompatibilidad de tipo de clave RSA:**  
Ubuntu 24.04 no envía claves RSA-1 por defecto en OpenSSH moderno. La VM cirros usa una versión antigua de dropbear SSH que requiere `ssh-rsa`. Sin el flag `-o PubkeyAcceptedKeyTypes=+ssh-rsa` el handshake falla aunque la clave sea correcta.

### Por SSH desde el controller (método correcto):

```bash
# [CONTROLLER] Conectar via namespace del router Neutron:
sudo ip netns exec qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0 \
  ssh -o StrictHostKeyChecking=no \
  -o PubkeyAcceptedKeyTypes=+ssh-rsa \
  -i /root/.ssh/id_rsa \
  cirros@192.168.122.115

# Credenciales alternativas (si no funciona la clave):
# usuario: cirros  |  password: gocubsgo
```

> `ip netns exec qrouter-...` ejecuta el comando dentro del namespace del router virtual de Neutron, que sí tiene la interfaz `qg-...` con IP `192.168.122.122` y la Floating IP `192.168.122.115/32` asignada.

### Por SSH desde tu laptop (a través del controller):
```bash
# [LAPTOP] Usar ProxyJump para llegar al namespace:
ssh -J uceda@203.0.113.239 \
  -o PubkeyAcceptedKeyTypes=+ssh-rsa \
  -i ~/mykey-openstack.pem \
  cirros@192.168.122.115
# Nota: solo funciona si el laptop tiene ruta a 192.168.122.x via el controller
```

### Por consola VNC desde el controller:
```bash
# [CONTROLLER] Obtener la URL de VNC:
openstack console url show test-vm1
# Formato: http://controller:6080/vnc_auto.html?token=XXXX
# Abre esa URL en un navegador dentro del controller (si tiene GUI)
```

### Por consola VNC desde tu laptop (más común):
```bash
# [LAPTOP] Crear túnel SSH para redirigir el puerto 6080:
ssh -L 6080:10.0.0.11:6080 uceda@203.0.113.239
# Deja esta terminal abierta

# [CONTROLLER] En otra terminal, obtener la URL:
openstack console url show test-vm1
# Luego abre en tu navegador: http://localhost:6080/vnc_auto.html?token=XXXX
```

> El proxy VNC (`nova-novncproxy`) corre en el `[CONTROLLER]` puerto 6080. La VM corre en `[COMPUTE1]` pero el proxy reenvía la conexión.

---

## Paso 10 — Verificar conectividad de red ⬜ PENDIENTE

> **Nodo:** Los comandos de ping se ejecutan **dentro de la VM** (por VNC o SSH a la VM). Los comandos de diagnóstico OVS se ejecutan en `[CONTROLLER]` o `[COMPUTE1]`.

### Dentro de la VM:
```bash
# [DENTRO DE LA VM] Ver IP asignada por DHCP
ip addr
# Debe mostrar: eth0  inet 10.10.10.X/24

# [DENTRO DE LA VM] Ping al gateway del router Neutron
ping -c3 10.10.10.1

# [DENTRO DE LA VM] Ping a DNS (verifica NAT hacia exterior)
ping -c3 8.8.8.8

# [DENTRO DE LA VM] Ping entre VMs (si creas más de una)
ping -c3 10.10.10.Y
```

### Diagnóstico OVS desde los nodos (si hay problemas de red):
```bash
# [CONTROLLER] Ver namespaces de red creados por Neutron:
sudo ip netns list
# Esperado: qrouter-XXXX (router), qdhcp-XXXX (DHCP)

# [CONTROLLER] Ver interfaces dentro del namespace del router:
sudo ip netns exec qrouter-XXXX ip addr

# [COMPUTE1] Ver que la VM tiene su tap interface en br-int:
sudo ovs-vsctl show | grep tap

# [COMPUTE1] Ver que la VM está corriendo en libvirt:
sudo virsh list --all
```

---

## Resumen de arquitectura de red creada

```
Internet / Tu laptop
       │
  192.168.122.0/24  (red física del bridge en el host)
       │
  [enp8s0] → [br-provider OVS] → [br-int OVS]
                                       │
                              Neutron L3 router
                              (namespace qrouter)
                              NAT: 10.10.10.0/24 ↔ 192.168.122.x
                                       │
                              [br-tun OVS] → VXLAN tunnel → compute1
                                                                 │
                                                         [br-int compute1]
                                                                 │
                                                          tap interface
                                                                 │
                                                         [VM test-vm1]
                                                         IP: 10.10.10.x
                                                         Floating: 192.168.122.1xx
```

---

## Comandos de verificación rápida

```bash
# Estado general del cluster
openstack compute service list
openstack network agent list

# Ver todas las VMs
openstack server list

# Ver redes y subredes
openstack network list
openstack subnet list

# Ver el router y sus IPs
openstack router show router1

# Ver floating IPs
openstack floating ip list

# Ver uso de recursos del hypervisor
openstack hypervisor show compute1
```

---

## Limpieza (si quieres borrar todo y empezar de nuevo)

```bash
# Borrar la VM
openstack server delete test-vm1

# Liberar la floating IP
openstack floating ip delete $FIP

# Quitar subred del router y borrar router
openstack router remove subnet router1 selfservice-subnet
openstack router unset router1 --external-gateway
openstack router delete router1

# Borrar redes
openstack network delete selfservice-net
openstack network delete provider-net

# Borrar keypair
openstack keypair delete mykey
```
