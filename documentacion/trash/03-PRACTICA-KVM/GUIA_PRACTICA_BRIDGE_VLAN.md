# Guía Práctica: Configuración de Bridge y VLAN en KVM

**Fecha:** 2026-03-12
**Sistema:** Ubuntu con KVM/libvirt
**Interfaz física principal:** enp2s0f0 (192.168.0.195/24)

## Índice
1. [Verificación de KVM](#1-verificación-de-kvm)
2. [Creación del Bridge (br0)](#2-creación-del-bridge-br0)
3. [Validación del Bridge](#3-validación-del-bridge)
4. [Creación de VLAN para KVM](#4-creación-de-vlan-para-kvm)
5. [Creación de Máquinas Virtuales](#5-creación-de-máquinas-virtuales)
6. [Verificación Final](#6-verificación-final)

---

## 1. Verificación de KVM

### 1.1 Verificar módulos KVM cargados
```bash
lsmod | grep kvm
```

**Resultado esperado:**
```
kvm_amd       (o kvm_intel para procesadores Intel)
kvm
```

**Explicación:** Este comando lista los módulos del kernel relacionados con KVM. Si ves `kvm_amd` o `kvm_intel`, significa que tu procesador soporta virtualización y los módulos están cargados.

### 1.2 Verificar que KVM puede ser usado
```bash
kvm-ok
```

**Resultado esperado:**
```
INFO: /dev/kvm exists
KVM acceleration can be used
```

**Explicación:** `kvm-ok` verifica que el dispositivo `/dev/kvm` existe y que el sistema puede usar aceleración por hardware para virtualización.

### 1.3 Verificar estado actual de interfaces de red
```bash
ip addr show
```

**Explicación:** Muestra todas las interfaces de red y sus direcciones IP. Identifica tu interfaz física principal (en este caso `enp2s0f0`).

### 1.4 Verificar permisos de usuario
```bash
groups
```

**Verificar que el usuario esté en el grupo `libvirt`:**
```bash
sudo usermod -aG libvirt $USER
```

**Explicación:** El grupo `libvirt` permite gestionar máquinas virtuales sin necesidad de sudo. Necesitarás cerrar sesión y volver a entrar para que el cambio surta efecto.

---

## 2. Creación del Bridge (br0)

### Diagrama de Referencia
Según el diagrama, el bridge `br0` conectará:
- Interfaz física: `enp0s1` (en tu caso: **enp2s0f0**)
- Interfaces virtuales: `vnet0, vnet1, etc.` (una por cada VM)

```
┌─────────────────────────────────────────────────────────┐
│                    HOST (Anfitrión Linux)               │
│                                                         │
│    ┌──────────────────────────────────────┐            │
│    │     Bridge Virtual: br0              │            │
│    │                                      │            │
│    │  br0 -> [Ports]                      │            │
│    │         ├─ eth0 (vnet0, enp0s1)      │            │
│    └──────────┬──────────────┬────────────┘            │
│               │              │                         │
│          [vnet0]        [enp2s0f0] ← Física            │
│               │              │                         │
└───────────────┼──────────────┼─────────────────────────┘
                │              │
                │              └──→ Internet (192.168.0.x)
                │
          ┌─────┴─────┐
          │    VM     │
          └───────────┘
```

### 2.1 Opción A: Bridge sin conectar la interfaz física (Práctica segura)

Esta opción crea el bridge pero NO lo conecta a tu interfaz física principal, evitando interrupciones de red.

#### Crear el bridge br0
```bash
sudo nmcli connection add type bridge \
  ifname br0 \
  con-name bridge-br0 \
  ipv4.method manual \
  ipv4.addresses 192.168.100.1/24
```

**Explicación:**
- `connection add type bridge`: Crea una nueva conexión de tipo bridge
- `ifname br0`: Nombra la interfaz del bridge como "br0"
- `con-name bridge-br0`: Nombra la conexión NetworkManager como "bridge-br0"
- `ipv4.method manual`: Configura IP estática
- `ipv4.addresses 192.168.100.1/24`: Asigna la IP 192.168.100.1 con máscara /24 al bridge

#### Activar el bridge
```bash
sudo nmcli connection up bridge-br0
```

**Explicación:** Activa la conexión del bridge. El bridge ahora está operativo pero solo para tráfico local entre VMs.

### 2.2 Opción B: Bridge conectado a interfaz física (Producción)

**⚠️ ADVERTENCIA:** Esto interrumpirá temporalmente tu conexión de red. Solo úsalo si tienes acceso físico a la máquina o conexión por otro medio.

#### Crear el bridge br0 con DHCP
```bash
sudo nmcli connection add type bridge \
  ifname br0 \
  con-name bridge-br0 \
  ipv4.method auto
```

**Explicación:** Similar al anterior pero usa DHCP (`ipv4.method auto`) para obtener IP automáticamente del router, igual que la interfaz física actual.

#### Agregar la interfaz física como esclava del bridge
```bash
sudo nmcli connection add type ethernet \
  ifname enp2s0f0 \
  con-name bridge-br0-slave-enp2s0f0 \
  master bridge-br0
```

**Explicación:**
- `type ethernet`: Crea una conexión ethernet
- `ifname enp2s0f0`: Especifica la interfaz física
- `master bridge-br0`: Conecta esta interfaz como "esclava" del bridge br0
- Una vez conectada, el bridge gestiona todo el tráfico de la interfaz física

#### Bajar la conexión actual de enp2s0f0
```bash
sudo nmcli connection down netplan-zz-all-en
```

**Explicación:** Desactiva la conexión actual de la interfaz física para poder activar la nueva configuración con el bridge.

#### Activar el bridge y su esclava
```bash
sudo nmcli connection up bridge-br0
sudo nmcli connection up bridge-br0-slave-enp2s0f0
```

**Explicación:** Activa tanto el bridge como la interfaz esclava. El bridge ahora maneja el tráfico de red del host y de las VMs.

---

## 3. Validación del Bridge

### 3.1 Verificar estado del bridge
```bash
ip addr show br0
```

**Resultado esperado:**
- El bridge br0 debe tener una dirección IP
- Estado: UP

**Explicación:** Muestra la configuración IP y el estado del bridge.

### 3.2 Verificar conexiones de NetworkManager
```bash
nmcli connection show --active
```

**Resultado esperado:**
- `bridge-br0` debe aparecer como ACTIVO
- Si usaste Opción B: `bridge-br0-slave-enp2s0f0` también debe estar activo

**Explicación:** Lista todas las conexiones activas gestionadas por NetworkManager.

### 3.3 Verificar configuración del bridge
```bash
bridge link show
```

**Resultado esperado (si usaste Opción B):**
```
2: enp2s0f0: <BROADCAST,MULTICAST,UP,LOWER_UP> master br0
```

**Explicación:** Muestra qué interfaces están conectadas al bridge y su estado.

### 3.4 Probar conectividad
```bash
ping -c 4 8.8.8.8
```

**Explicación:** Verifica que el host aún tiene conectividad a Internet a través del bridge.

---

## 4. Creación de VLAN para KVM

### 4.1 Verificar redes virtuales existentes en libvirt
```bash
sudo virsh net-list --all
```

**Explicación:** Lista todas las redes virtuales configuradas en libvirt. Por defecto verás la red "default" que usa virbr0.

### 4.2 Crear archivo de definición de red con bridge

Crear el archivo `/tmp/br0-network.xml`:
```xml
<network>
  <name>br0-network</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>
```

**Explicación:**
- `<forward mode="bridge"/>`: Indica que esta red usa un bridge existente
- `<bridge name="br0"/>`: Especifica que el bridge es br0 (el que creamos con nmcli)
- Este tipo de red conecta directamente las VMs al bridge del host, permitiéndoles tener IPs en la misma red que el host

#### Comando para crear el archivo
```bash
cat > /tmp/br0-network.xml << 'EOF'
<network>
  <name>br0-network</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>
EOF
```

### 4.3 Opción alternativa: Red NAT con VLAN (Aislamiento)

Si prefieres crear una red NAT con VLANs aisladas:

Crear el archivo `/tmp/vlan-network.xml`:
```xml
<network>
  <name>vlan-network</name>
  <forward mode='nat'/>
  <bridge name='virbr10' stp='on' delay='0'/>
  <ip address='192.168.10.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.10.2' end='192.168.10.254'/>
    </dhcp>
  </ip>
</network>
```

**Explicación:**
- `<forward mode='nat'/>`: Las VMs usan NAT para salir a Internet
- `<bridge name='virbr10'/>`: Crea un bridge virtual interno llamado virbr10
- `<ip address='192.168.10.1'/>`: IP del gateway (el host)
- `<dhcp>`: Servidor DHCP para asignar IPs a las VMs automáticamente

#### Comando para crear el archivo
```bash
cat > /tmp/vlan-network.xml << 'EOF'
<network>
  <name>vlan-network</name>
  <forward mode='nat'/>
  <bridge name='virbr10' stp='on' delay='0'/>
  <ip address='192.168.10.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.10.2' end='192.168.10.254'/>
    </dhcp>
  </ip>
</network>
EOF
```

### 4.4 Definir y activar la red en libvirt

Para la red con bridge (Opción 1):
```bash
sudo virsh net-define /tmp/br0-network.xml
sudo virsh net-start br0-network
sudo virsh net-autostart br0-network
```

Para la red NAT con VLAN (Opción 2):
```bash
sudo virsh net-define /tmp/vlan-network.xml
sudo virsh net-start vlan-network
sudo virsh net-autostart vlan-network
```

**Explicación:**
- `net-define`: Crea la definición de la red en libvirt
- `net-start`: Inicia la red virtual
- `net-autostart`: Configura la red para iniciarse automáticamente al arrancar el sistema

### 4.5 Verificar que la red está activa
```bash
sudo virsh net-list --all
```

**Resultado esperado:**
```
 Name           State    Autostart   Persistent
------------------------------------------------
 br0-network    active   yes         yes
 default        active   yes         yes
```

---

## 5. Creación de Máquinas Virtuales

### 5.1 Preparar imagen de disco

Necesitas una imagen de sistema operativo. Por ejemplo, Ubuntu Server:

```bash
# Descargar imagen de Ubuntu Server (ejemplo)
cd /home/uceda/Documents/ESPECIALIZACION/LAB\ 1/PRACTICA/
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso
```

**Explicación:** Descarga la imagen ISO de Ubuntu Server que usaremos para instalar las VMs.

### 5.2 Crear directorio para discos virtuales
```bash
sudo mkdir -p /var/lib/libvirt/images
```

**Explicación:** Directorio estándar donde libvirt almacena los discos virtuales de las VMs.

### 5.3 Crear VM1 con virt-install

```bash
sudo virt-install \
  --name vm1-bridge \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/vm1-bridge.qcow2,size=20 \
  --os-variant ubuntu22.04 \
  --network network=br0-network,model=virtio \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole \
  --cdrom /home/uceda/Documents/ESPECIALIZACION/LAB\ 1/PRACTICA/ubuntu-22.04.5-live-server-amd64.iso
```

**Explicación detallada de cada parámetro:**
- `--name vm1-bridge`: Nombre de la VM
- `--ram 2048`: 2 GB de RAM
- `--vcpus 2`: 2 CPUs virtuales
- `--disk path=...,size=20`: Crea un disco virtual de 20 GB en formato qcow2
- `--os-variant ubuntu22.04`: Optimizaciones para Ubuntu 22.04
- `--network network=br0-network,model=virtio`: Conecta la VM a la red br0-network usando el driver virtio (alto rendimiento)
- `--graphics vnc,listen=0.0.0.0`: Habilita acceso VNC para la consola gráfica
- `--noautoconsole`: No abre la consola automáticamente
- `--cdrom`: Ruta a la imagen ISO para instalar el SO

### 5.4 Crear VM2 con virt-install

```bash
sudo virt-install \
  --name vm2-bridge \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/vm2-bridge.qcow2,size=20 \
  --os-variant ubuntu22.04 \
  --network network=br0-network,model=virtio \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole \
  --cdrom /home/uceda/Documents/ESPECIALIZACION/LAB\ 1/PRACTICA/ubuntu-22.04.5-live-server-amd64.iso
```

**Explicación:** Similar a VM1, pero con nombre y disco diferentes. Ambas VMs estarán en la misma red (br0-network).

### 5.5 Verificar VMs creadas
```bash
sudo virsh list --all
```

**Resultado esperado:**
```
 Id   Name         State
-----------------------------
 1    vm1-bridge   running
 2    vm2-bridge   running
```

**Explicación:** Lista todas las VMs (corriendo y apagadas) gestionadas por libvirt.

---

## 6. Verificación Final

### 6.1 Verificar interfaces virtuales creadas
```bash
ip addr show | grep -E "br0|vnet"
```

**Resultado esperado:**
- `br0`: debe tener una IP
- `vnet0, vnet1`: interfaces virtuales conectadas al bridge

**Explicación:** Cada VM conectada al bridge crea una interfaz `vnetX` en el host que se conecta automáticamente al bridge.

### 6.2 Verificar bridge y sus puertos
```bash
bridge link show
```

**Resultado esperado:**
```
X: enp2s0f0: <...> master br0
Y: vnet0: <...> master br0
Z: vnet1: <...> master br0
```

**Explicación:** Muestra qué interfaces están "esclavizadas" al bridge. Deberías ver la interfaz física y las interfaces virtuales de las VMs.

### 6.3 Verificar conectividad del host
```bash
ping -c 4 8.8.8.8
```

**Explicación:** Verifica que el host aún tiene acceso a Internet.

### 6.4 Acceder a las VMs por consola

#### Consola texto (virsh):
```bash
sudo virsh console vm1-bridge
```

**Explicación:** Abre una consola de texto para interactuar con la VM. Para salir presiona `Ctrl + ]`.

#### Consola gráfica (virt-manager):
```bash
virt-manager
```

**Explicación:** Abre el gestor gráfico de máquinas virtuales donde puedes ver y controlar todas tus VMs.

### 6.5 Verificar conectividad desde las VMs

Dentro de cada VM (después de instalar el SO):
```bash
# Verificar IP asignada
ip addr show

# Probar conectividad al gateway
ping -c 4 192.168.0.1

# Probar conectividad a Internet
ping -c 4 8.8.8.8

# Probar entre VMs
ping -c 4 <IP_de_otra_VM>
```

**Explicación:** Verifica que las VMs tienen:
1. Una IP asignada (por DHCP o estática)
2. Conectividad al gateway/router
3. Acceso a Internet
4. Conectividad entre ellas (misma red)

---

## Comandos de Gestión Útiles

### Listar todas las conexiones de NetworkManager
```bash
nmcli connection show
```

### Ver estado de todas las redes virtuales
```bash
sudo virsh net-list --all
```

### Detener una red virtual
```bash
sudo virsh net-destroy <nombre-red>
```

### Eliminar definición de red virtual
```bash
sudo virsh net-undefine <nombre-red>
```

### Apagar una VM
```bash
sudo virsh shutdown <nombre-vm>
```

### Forzar apagado de una VM
```bash
sudo virsh destroy <nombre-vm>
```

### Eliminar una VM
```bash
sudo virsh undefine <nombre-vm> --remove-all-storage
```

### Eliminar un bridge de NetworkManager
```bash
sudo nmcli connection delete bridge-br0
```

---

## Resumen de la Arquitectura

**Flujo de datos:**

1. **VM → Host → Internet:**
   - VM envía paquetes a través de vnet0
   - vnet0 está conectado a br0
   - br0 está conectado a enp2s0f0
   - enp2s0f0 envía paquetes a Internet

2. **Internet → Host → VM:**
   - Paquetes llegan a enp2s0f0
   - enp2s0f0 los pasa a br0
   - br0 los distribuye a la vnetX correspondiente
   - La VM recibe los paquetes

**Ventajas del Bridge:**
- Las VMs tienen presencia directa en la red local
- Pueden obtener IP del mismo router DHCP que el host
- Otros dispositivos en la red pueden comunicarse directamente con las VMs

**Diferencia con NAT:**
- Con NAT, las VMs están en una red privada y el host hace traducción de direcciones
- Con Bridge, las VMs están en la misma red que el host

---

## Troubleshooting

### Problema: "Failed to connect to the hypervisor"
**Solución:**
```bash
sudo systemctl start libvirtd.socket
# O intentar con el servicio modular
sudo systemctl start virtqemud.socket
```

### Problema: Sin permisos para gestionar VMs
**Solución:**
```bash
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
# Cerrar sesión y volver a entrar
```

### Problema: Bridge no tiene conectividad
**Solución:**
```bash
# Verificar que el forwarding está habilitado
sudo sysctl net.ipv4.ip_forward
# Si es 0, habilitarlo:
sudo sysctl -w net.ipv4.ip_forward=1
# Para hacerlo permanente:
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
```

### Problema: VMs no obtienen IP por DHCP
**Solución:**
```bash
# Verificar que el servidor DHCP de la red está activo
sudo virsh net-dumpxml <nombre-red>
# Reiniciar la red
sudo virsh net-destroy <nombre-red>
sudo virsh net-start <nombre-red>
```

---

## Notas Finales

- **Persistencia:** Todas las configuraciones con nmcli y virsh son persistentes y sobrevivirán reinicios
- **Seguridad:** El bridge expone las VMs en tu red local. Asegúrate de configurar firewalls apropiados
- **Respaldo:** Antes de modificar la red del host, documenta la configuración actual con `nmcli connection show`
- **Alternativa segura:** Para prácticas, usa la Opción A (bridge sin interfaz física) o redes NAT para evitar interrupciones

---

## Referencias

- Documentación oficial de libvirt: https://libvirt.org/
- NetworkManager bridge configuration: `man nm-settings`
- KVM networking: https://wiki.libvirt.org/Networking.html
