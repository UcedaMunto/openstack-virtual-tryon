# ICC115 — Guía de Laboratorio: Ansible

> **Origen:** versión Markdown de `icc115-ansible.pdf` (Universidad de El Salvador — FIA — EISI).
> **Fecha de esta revisión:** 2026-08-05
> **Alcance:** laboratorio **desde cero**, con VMs nuevas y una red/subred nueva, independiente de la
> infraestructura OpenStack del resto de este repositorio (esa infraestructura solo se referencia como
> ejemplo de convenciones de trabajo: `virt-customize`, netplan v2, tags `[NODO]`, tablas de estado, etc.).
> **Convención de nodos usada en esta guía:**
> - `[LAPTOP]` → host físico con KVM/libvirt (donde se crean las VMs).
> - `[CTRL]` → VM `ansible-ctrl`, nodo de control de Ansible.
> - `[SRV1]`, `[SRV2]`, `[SRV3]` → VMs `server1`, `server2`, `server3` (nodos gestionados / grupo `gluster`).

---

## Índice

0. [Errores detectados en la guía original y correcciones aplicadas](#0-errores-detectados-en-la-guía-original-y-correcciones-aplicadas)
1. [Resultados de aprendizaje](#1-resultados-de-aprendizaje)
2. [Arquitectura del laboratorio (desde cero)](#2-arquitectura-del-laboratorio-desde-cero)
3. [Fase 0 — Crear las 4 VMs nuevas](#3-fase-0--crear-las-4-vms-nuevas)
4. [Instalación de Ansible en el nodo de control](#4-instalación-de-ansible-en-el-nodo-de-control)
5. [Acceso SSH desde el nodo de control hacia los nodos gestionados](#5-acceso-ssh-desde-el-nodo-de-control-hacia-los-nodos-gestionados)
6. [Configurando el inventario](#6-configurando-el-inventario)
7. [Prueba de conexión y comandos ad-hoc](#7-prueba-de-conexión-y-comandos-ad-hoc)
8. [Playbooks](#8-playbooks)
9. [Requerimientos de laboratorio (resueltos)](#9-requerimientos-de-laboratorio-resueltos)
10. [Tabla de comprobación final](#10-tabla-de-comprobación-final)
11. [Anexo — Limpieza / reinicio del laboratorio](#11-anexo--limpieza--reinicio-del-laboratorio)

---

## 0. Errores detectados en la guía original y correcciones aplicadas

| # | Problema en `icc115-ansible.pdf` | Corrección aplicada en esta guía |
|---|-----------------------------------|-----------------------------------|
| 1 | La sección 4.1 pide `ssh-copy-id` hacia **root** *antes* de habilitar `PermitRootLogin` y fijar contraseña de root (sección 4.1.1). Con la config. por defecto de OpenSSH (`PermitRootLogin prohibit-password`), `ssh-copy-id` a root **falla** porque no hay forma de autenticarse aún. | Se invierte el orden: primero se habilita SSH root + contraseña ([§5.1](#51-habilitar-acceso-ssh-temporal-en-los-nodos-gestionados)), y **solo después** se copian las llaves. |
| 2 | `sudo echo "..." \| sudo tee /etc/sudoers.d/ansible` — el primer `sudo` es redundante (no falla, pero confunde) y falta validar sintaxis/permisos del archivo. | Se usa `echo "..." \| sudo tee ...`, se fija `chmod 0440` y se valida con `visudo -c`. |
| 3 | No se ejecuta `apt update` explícito tras añadir el PPA `ppa:ansible/ansible`. En modo no interactivo (scripts) esto puede dejar el índice de paquetes desactualizado. | Se agrega `sudo apt update` explícito después de añadir el repositorio. |
| 4 | El PPA `ppa:ansible/ansible` a veces no publica build para la versión de Ubuntu más reciente (ej. 24.04 "noble") el mismo día del lanzamiento. La guía original asume Ansible 2.13.x / Python 3.10 (valores de 2022, Ubuntu 22.04). | Se agrega verificación de disponibilidad del PPA y una alternativa sin PPA (`apt install ansible` directo desde universe, que en Ubuntu 24.04 ya trae Ansible ≥ 2.16). |
| 5 | No se crea `/etc/ansible` antes de editar `/etc/ansible/hosts` (en instalaciones limpias el directorio puede no existir). | Se agrega `sudo mkdir -p /etc/ansible` con verificación. |
| 6 | Los ejemplos de inventario usan `192.168.122.x`, que es la misma subred que usa `provider-net` de OpenStack en este mismo host (red `default` de libvirt). Reusarla causaría colisión de DHCP/ARP. | Esta guía define una red libvirt **nueva y aislada**: `ansible-lab`, `192.168.60.0/24` (ver [§2](#2-arquitectura-del-laboratorio-desde-cero)). |
| 7 | No hay pasos de verificación/confirmación entre tareas; si algo falla a mitad de la guía es difícil saber en qué paso quedó mal. | Se agrega un bloque **✅ Verificación** después de cada tarea relevante, con el comando y la salida esperada. |
| 8 | El requerimiento de laboratorio #2 pide un grupo `gluster` "correspondiente a los nodos configurados en la clase asociada", sin detallar cuáles son esos nodos si se parte de cero. | Se documenta explícitamente: el grupo `gluster` = `server1`, `server2`, `server3` (las 3 VMs nuevas), y se agrega un playbook opcional que instala y deja listo GlusterFS siguiendo el Quick Start oficial. |
| 9 | Todos los comandos aparecen sin comentarios de qué hace cada uno. | Se agregan comentarios `#` explicando cada línea relevante en todos los bloques de código. |
| 10 | Si se ejecuta `virt-customize` (§3.4) sin haber corrido antes §3.2 (descarga de la imagen base) y §3.3 (creación de un disco por VM), falla con `libguestfs error: /var/lib/libvirt/images/<vm>.qcow2: No such file or directory`. Es fácil caer en esto si se copian los bloques de la Opción B en una terminal distinta o en otra sesión, sin haber corrido antes 3.1-3.3 en esa misma máquina. | Se agrega una comprobación previa obligatoria al inicio de §3.4 que valida con `ls` que los 4 discos existan antes de ejecutar cualquiera de las dos opciones, con instrucciones de volver a §3.2/§3.3 si falta alguno. |
| 11 | El `--run-command "id -u uceda &>/dev/null \|\| useradd ..."` de §3.4 usa `&>/dev/null`, un bashismo que **no funciona** con `/bin/sh` (dash, el shell real del guest en Ubuntu): el `\|\|` nunca ejecuta `useradd` porque el redirect vacío resultante devuelve éxito. El usuario `uceda` nunca se crea y `--ssh-inject uceda:...` falla con `the user uceda does not exist on the guest`. | Se reemplaza por la forma POSIX portable `id -u uceda >/dev/null 2>&1 \|\| useradd ...` en los 5 bloques (Opción A y B). |
| 12 | En §3.6, si se reconstruye el disco de alguna VM (por ejemplo tras aplicar la corrección #11), esa VM obtiene una llave SSH de host **nueva** (se regenera a propósito en §3.4). Si esa IP ya estaba en `~/.ssh/known_hosts` de un intento previo, SSH la rechaza con `Host key verification failed` como si fuera un ataque MITM, aunque la VM esté sana. | Se agrega en §3.6 un paso de limpieza con `ssh-keygen -R <ip>` para las 4 IPs antes de probar la conectividad, y una nota aclarando cómo distinguir este falso positivo de un fallo real de red. |
| 13 | `qemu-img resize ... 10G` (§3.3) solo agranda el archivo `.qcow2`; **no** agranda la partición ni el filesystem de adentro, que se quedan en el tamaño de la imagen base (~3.5G). Como §3.4 deshabilita `cloud-init` por completo (que normalmente haría ese `growpart`/`resize` en el primer arranque), ese crecimiento nunca ocurre. Síntoma: instalaciones de paquetes (`apt install ansible`, etc.) fallan a mitad con `No space left on device`, aunque `qemu-img info` reporte 10G. | Se agregan `growpart /dev/sda 1` y `resize2fs /dev/sda1` como `--run-command` en §3.4 (Opción A y B), antes de deshabilitar cloud-init, para crecer la partición/filesystem al tamaño real del disco durante el customize (offline). |
| 14 | `virt-customize` (libguestfs/supermin) necesita **leer** `/boot/vmlinuz-*` del host para construir su appliance interno. En algunos hosts ese archivo queda en `0600` (solo root), lo que hace fallar `virt-customize` con el mensaje genérico `libguestfs error: guestfs_launch failed`, sin indicar la causa real salvo corriendo con `LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1` (donde se ve `cp: cannot open '/boot/vmlinuz-...' for reading: Permission denied`). | Se agrega en §3.4, antes de la Opción A/B, un paso que verifica y corrige el permiso con `sudo chmod 0644 /boot/vmlinuz-*`, junto con una recomendación de usar `libguestfs-test-tool` para descartar otras causas si el problema persiste. |
| 15 | La Opción A de §3.4 tenía comentarios `` `# texto` `` (command substitution con backticks) intercalados dentro del comando `virt-customize` multilínea, como truco para documentar sin romper la continuación con `\`. Con terminales que usan editores de línea avanzados (ble.sh, zsh+autosugerencias, etc.), pegar un comando así de largo —con comillas anidadas y backticks— puede corromper el pegado y producir el mismo error genérico `guestfs_launch failed` sin relación real con libguestfs. | Se quitan los comentarios `` `# ...` `` de dentro del comando en la Opción A (se mueven a un bloque de notas antes del bloque de código) y se agrega una advertencia recomendando guardar el comando en un archivo `.sh` y ejecutarlo con `bash archivo.sh` en vez de pegarlo directo si se usa ble.sh u otro autocompletado. |
| 16 | §5.1 solo cambiaba `PermitRootLogin` en `/etc/ssh/sshd_config`, pero las imágenes cloud de Ubuntu traen `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` con `PasswordAuthentication no`. Como el `Include` de `sshd_config.d/*.conf` está al inicio de `sshd_config` y sshd usa la primera coincidencia de cada directiva, ese `no` gana sobre cualquier `PasswordAuthentication yes` puesto después. Síntoma: `ssh-copy-id` a `root` falla con `Permission denied (publickey)` sin pedir password nunca, aunque `PermitRootLogin` ya esté en `yes`. | Se agrega en §5.1 un `sed` adicional sobre `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` para poner `PasswordAuthentication yes`, y la verificación ahora revisa ambos archivos con `grep -rn`. |
| 17 | §5.3 usaba `ssh-copy-id ansible@<ip>` para instalar la llave del usuario `ansible`, pero ese usuario se crea con el módulo `user` de Ansible **sin contraseña fijada** (queda bloqueada, `!` en `/etc/shadow`). El resultado es inconsistente: en algunos nodos el password tecleado "cuela" (o el usuario acierta por casualidad) y en otros da `Permission denied, please try again` repetido. Si además ya se corrió el paso siguiente (`usermod -L ansible`) antes de lograr copiar la llave en todos los nodos, ese nodo queda **sin llave y sin password**, completamente inaccesible como `ansible`. | Se reemplaza `ssh-copy-id ansible@<ip>` por un `ansible ... -u root -m authorized_key` que instala la llave usando el acceso por llave de `root` (ya establecido en §5.2), sin depender de ningún password del usuario `ansible`. |

---

## 1. Resultados de aprendizaje

- Configurar Ansible como orquestador de operaciones sobre infraestructura.
- Configurar Ansible como herramienta para la automatización de procesos sobre infraestructura.
- Establecer un ecosistema de servicios automatizados con Ansible.

---

## 2. Arquitectura del laboratorio (desde cero)

Todas las VMs de este laboratorio son **nuevas**, con una red libvirt **nueva** para no interferir con
las redes `openstack-public` (203.0.113.0/24), `openstack-admin` (10.0.0.0/24) ni `openstack-provider`
(192.168.122.0/24) que ya existen en este host para el laboratorio OpenStack.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  HOST — KVM/libvirt (mismo laptop del laboratorio OpenStack)              │
│                                                                            │
│  Red libvirt NUEVA: ansible-lab   bridge: virbr-ansible                   │
│  Subred NUEVA:      192.168.60.0/24   gateway: 192.168.60.1  (NAT)        │
│                                                                            │
│   ┌───────────────┐   ┌───────────────┐  ┌───────────────┐ ┌───────────┐ │
│   │  ansible-ctrl │   │   server1     │  │   server2     │ │  server3  │ │
│   │ 192.168.60.10 │   │ 192.168.60.11 │  │ 192.168.60.12 │ │60.13      │ │
│   │  Ansible core │──▶│ grupo: gluster│  │ grupo: gluster│ │grupo:     │ │
│   │  (control)    │ SSH│              │  │               │ │gluster    │ │
│   └───────────────┘   └───────────────┘  └───────────────┘ └───────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

| Rol | Hostname | VM libvirt | IP | vCPU | RAM | Disco |
|-----|----------|-----------|----|----|-----|-------|
| Control Ansible | `ansible-ctrl` | `ansible-ctrl` | 192.168.60.10 | 2 | 1536 MB | 10 GB |
| Nodo gestionado 1 | `server1` | `server1` | 192.168.60.11 | 1 | 1024 MB | 10 GB |
| Nodo gestionado 2 | `server2` | `server2` | 192.168.60.12 | 1 | 1024 MB | 10 GB |
| Nodo gestionado 3 | `server3` | `server3` | 192.168.60.13 | 1 | 1024 MB | 10 GB |

Usuario local de acceso en todas las VMs: `uceda` (mismo usuario que el resto del repositorio),
más el usuario dedicado `ansible` que se crea en [§5.3](#53-crear-usuario-dedicado-ansible-recomendado).

---

## 3. Fase 0 — Crear las 4 VMs nuevas

> **Nodo: `[LAPTOP]`**

> ⚠️ **Orden estricto, sin saltos:** ejecuta 3.1 → 3.2 → 3.3 → 3.4 → 3.5 **en ese orden, en el mismo
> host y sin cerrar la terminal entre pasos** (o al menos verificando cada `✅ Verificación` antes de
> continuar). El error más común de esta fase es ejecutar directamente los comandos de §3.4
> (`virt-customize`) sin haber corrido antes §3.2 (descarga de la imagen base) y §3.3 (creación del
> disco de cada VM); el síntoma es `libguestfs error: ... No such file or directory` porque el
> archivo `.qcow2` de esa VM simplemente no existe todavía. Si ves ese error, **no reintentes §3.4**:
> vuelve primero a §3.2/§3.3 y confirma con `ls` que los 4 discos existen.

### 3.1. Crear la red libvirt aislada `ansible-lab`

> **Nodo: `[LAPTOP]`**

```bash
# Definir el XML de una red NAT nueva y aislada del resto del laboratorio.
cat > /tmp/ansible-lab-net.xml <<'EOF'
<network>
  <name>ansible-lab</name>
  <bridge name='virbr-ansible' stp='on' delay='0'/>
  <forward mode='nat'/>            <!-- da salida a Internet vía NAT, igual que la red 'default' -->
  <ip address='192.168.60.1' netmask='255.255.255.0'>
    <dhcp>
      <!-- Rango DHCP alto (100-200); las VMs usarán IP estática fuera de este rango -->
      <range start='192.168.60.100' end='192.168.60.200'/>
    </dhcp>
  </ip>
</network>
EOF

# Registrar la red en libvirt a partir del XML anterior.
sudo virsh net-define /tmp/ansible-lab-net.xml

# Marcar la red para que se active automáticamente al reiniciar el host.
sudo virsh net-autostart ansible-lab

# Iniciar la red ahora mismo.
sudo virsh net-start ansible-lab
```

**✅ Verificación**

```bash
# Debe listar 'ansible-lab' como 'active' y 'yes' en autostart.
sudo virsh net-list --all
```

Salida esperada:

```text
 Name          State    Autostart   Persistent
--------------------------------------------------
 ansible-lab   active   yes         yes
 default       active   yes         yes
```

### 3.2. Descargar la imagen base (cloud image de Ubuntu 24.04)

> **Nodo: `[LAPTOP]`**

```bash
sudo mkdir -p /var/lib/libvirt/images

# Descargar la imagen cloud oficial de Ubuntu 24.04 (Noble) si aún no existe.
sudo curl -L -o /var/lib/libvirt/images/noble-base.qcow2 \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

**✅ Verificación**

```bash
# Debe reportar 'QEMU QCOW2 Image' y una versión de formato.
qemu-img info /var/lib/libvirt/images/noble-base.qcow2
```

### 3.3. Crear un disco por VM a partir de la imagen base

> **Nodo: `[LAPTOP]`**

```bash
for vm in ansible-ctrl server1 server2 server3; do
  # Copia independiente de la imagen base para cada VM (no usamos backing file
  # para evitar dependencias cruzadas entre discos).
  sudo cp /var/lib/libvirt/images/noble-base.qcow2 \
          /var/lib/libvirt/images/${vm}.qcow2

  # Redimensionar cada disco a 10G (la imagen base trae ~3.5G).
  sudo qemu-img resize /var/lib/libvirt/images/${vm}.qcow2 10G

  # Propietario correcto para que libvirt-qemu pueda leer/escribir el disco.
  sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/${vm}.qcow2
done
```

**✅ Verificación**

```bash
# Deben aparecer los 4 discos con tamaño virtual 10G. Si falta alguno, o el 'for' de arriba
# terminó con errores (por ejemplo "No space left on device"), repite el 'for' antes de seguir.
for vm in ansible-ctrl server1 server2 server3; do
  f="/var/lib/libvirt/images/${vm}.qcow2"
  if sudo test -f "$f"; then
    ls -lh "$f"
  else
    echo "❌ FALTA: $f  -> repite el bloque de §3.3 para esta VM"
  fi
done

# Confirma también que hay espacio suficiente en la partición (cada disco pesa 10G virtuales).
df -h /var/lib/libvirt/images
```

### 3.4. Configurar cada disco con `virt-customize` (hostname, red estática, usuario, llaves únicas)

> **Nodo: `[LAPTOP]`**

> Requiere `libguestfs-tools`: `sudo apt install -y libguestfs-tools`
> Se usa `--no-network` porque `libguestfs` con `passt` puede fallar con `sudo` (ver nota de la
> guía `documentacion/02-GUIA-SEGUNDO-COMPUTE-INSTALACION.md` de este mismo repositorio).
> Se genera `ssh_host_*` y `machine-id` **en el momento del customize** (no se deja para el primer
> arranque) porque los 4 discos parten del mismo archivo base y, si no se regeneran aquí, las 4 VMs
> compartirían el mismo `machine-id` y las mismas llaves SSH de host.

> Esta sección ofrece dos formas equivalentes de aplicar la misma configuración: **Opción A**
> con un bucle `for` (compacta, recomendada) y **Opción B** a pie, un bloque `virt-customize`
> completo por cada VM, sin bucle ni variables `${...}`, útil si prefieres ejecutar/leer cada
> comando por separado o copiarlos uno a uno en la terminal.

> ⚠️ **Si tu terminal usa ble.sh (bash line editor), zsh con autosugerencias, o algún plugin de
> autocompletado** (verás algo como `[ble: exit N]` en tu prompt): estos comandos son largos,
> multilínea y con comillas anidadas (el `--write "...netplan..."` incluye saltos de línea reales
> dentro de una cadena). Pegar eso directo en una terminal con autocompletado activo puede
> corromper el pegado (líneas partidas, comillas mal cerradas, etc.) y producir errores confusos
> como `guestfs_launch failed` que en realidad no tienen nada que ver con libguestfs. Para
> evitarlo, guarda el bloque completo en un archivo y ejecútalo, en vez de pegarlo directo:
> ```bash
> nano ansible-ctrl.sh   # pega ahí el bloque completo (Opción A o el de una VM en Opción B)
> bash ansible-ctrl.sh
> ```

#### ⚠️ Comprobación previa obligatoria (antes de la Opción A o B)

> **Requisito:** haber terminado §3.2 (descarga de `noble-base.qcow2`) y §3.3 (creación de un
> disco por VM). Si ejecutas `virt-customize` sin esto, falla con
> `libguestfs error: ... No such file or directory`, como ocurre si se corre la Opción B en una
> terminal/sesión distinta a la que se usó para 3.1-3.3, o si §3.3 quedó a medias (por ejemplo por
> falta de espacio en disco durante el `cp`/`qemu-img resize`).

```bash
# Aborta con un mensaje claro si falta cualquiera de los 4 discos, en vez de dejar que
# virt-customize falle más adelante con un error menos obvio.
faltan=0
for vm in ansible-ctrl server1 server2 server3; do
  f="/var/lib/libvirt/images/${vm}.qcow2"
  if ! sudo test -f "$f"; then
    echo "❌ FALTA: $f"
    faltan=1
  fi
done
if [ "$faltan" -eq 1 ]; then
  echo "⛔ Vuelve a §3.2 y §3.3 antes de continuar con §3.4 (no ejecutes virt-customize todavía)."
else
  echo "✅ Los 4 discos existen, puedes continuar con la Opción A o B."
fi
```

> **Requisito adicional (host):** `virt-customize` necesita **leer** el kernel del host
> (`/boot/vmlinuz-*`) para construir su appliance interno (libguestfs/supermin). En algunos
> equipos ese archivo queda con permisos `0600` (solo root puede leerlo), lo que hace fallar
> `virt-customize` con el mensaje genérico `libguestfs error: guestfs_launch failed` (sin más
> detalle, salvo corriendo con `LIBGUESTFS_DEBUG=1`). Corrige el permiso una sola vez por host:

```bash
ls -l /boot/vmlinuz-*
sudo chmod 0644 /boot/vmlinuz-*
ls -l /boot/vmlinuz-*   # debe quedar en -rw-r--r-- root root
```

> Si después de esto `virt-customize` sigue fallando, corre `libguestfs-test-tool 2>&1 | tail -60`
> para descartar otras causas (espacio en disco, KVM, memoria) antes de reintentar.

#### Opción A — con bucle `for`

> **Notas sobre las líneas del bloque de abajo:**
> - El netplan usa `dhcp6: false` y `link-local: []` para evitar el bug de systemd-networkd
>   "Failed to configure DHCPv6 client" visto en Ubuntu 24.04 en este laboratorio.
> - `growpart /dev/sda 1` + `resize2fs /dev/sda1`: `qemu-img resize` (§3.3) solo agranda el
>   archivo `.qcow2`; la partición y el filesystem de adentro siguen en ~3.5G hasta que algo
>   los crece. Como abajo se deshabilita cloud-init (que normalmente haría ese crecimiento
>   automático en el primer arranque), hay que crecerlos aquí a mano. libguestfs siempre
>   expone el disco como `/dev/sda` dentro del `--run-command`, sin importar el bus real
>   (virtio) de la VM.
> - `id -u uceda >/dev/null 2>&1 || useradd ...`: usa la forma POSIX, **no** `&>/dev/null`
>   (bashismo); el guest ejecuta `--run-command` con `/bin/sh` (dash en Ubuntu), donde `&>`
>   no hace lo esperado y hace que `useradd` nunca se ejecute.
> - `rm -f /etc/machine-id ...` + `ssh-keygen -A`: regeneran machine-id y host keys únicos
>   por VM (evita IDs/llaves duplicadas al venir todas del mismo disco base).
> - El bloque de grub/serial-getty habilita consola serie, útil si el netplan queda mal y se
>   pierde acceso SSH.

```bash
# Declarar IP estática y hostname por VM (mismo orden que las variables del for).
declare -A IP=( [ansible-ctrl]=192.168.60.10 [server1]=192.168.60.11 \
                [server2]=192.168.60.12 [server3]=192.168.60.13 )

for vm in ansible-ctrl server1 server2 server3; do
  echo "=== Configurando ${vm} (${IP[$vm]}) ==="

  sudo virt-customize -a /var/lib/libvirt/images/${vm}.qcow2 \
    --no-network \
    --hostname "${vm}" \
    --write "/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [${IP[$vm]}/24]
      routes: [{to: default, via: 192.168.60.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
" \
    --run-command "growpart /dev/sda 1 || true" \
    --run-command "resize2fs /dev/sda1 || true" \
    --run-command "touch /etc/cloud/cloud-init.disabled" \
    --run-command "id -u uceda >/dev/null 2>&1 || useradd -m -s /bin/bash uceda" \
    --run-command "echo 'uceda ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/uceda && chmod 440 /etc/sudoers.d/uceda" \
    --root-password password:asdfghjkl \
    --password uceda:password:asdfghjkl \
    --ssh-inject uceda:file:$HOME/.ssh/id_rsa.pub \
    --ssh-inject root:file:$HOME/.ssh/id_rsa.pub \
    --run-command "rm -f /etc/machine-id /var/lib/dbus/machine-id" \
    --run-command "systemd-machine-id-setup" \
    --run-command "rm -f /etc/ssh/ssh_host_*" \
    --run-command "ssh-keygen -A" \
    --run-command "sed -i 's/^GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8\"/' /etc/default/grub" \
    --run-command "update-grub" \
    --run-command "systemctl enable serial-getty@ttyS0.service" \
    --run-command "sed -i \"s/^127\\.0\\.1\\.1 .*/127.0.1.1 ${vm}/\" /etc/hosts"
done
```

> ⚠️ Si tu llave local no es `~/.ssh/id_rsa.pub` (por ejemplo usas `ed25519`), ajusta la ruta en
> `--ssh-inject` antes de ejecutar.

#### Opción B — a pie, un bloque por VM (sin `for`)

> Mismo resultado que la Opción A, pero cada comando queda completo y explícito (IP, hostname y
> ruta de disco ya sustituidos), para ejecutar de uno en uno. Ejecuta los 4 bloques en orden;
> no hace falta declarar variables antes.

```bash
# === ansible-ctrl (192.168.60.10) ===
sudo virt-customize -a /var/lib/libvirt/images/ansible-ctrl.qcow2 \
  --no-network \
  --hostname "ansible-ctrl" \
  --write "/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [192.168.60.10/24]
      routes: [{to: default, via: 192.168.60.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
" \
  --run-command "growpart /dev/sda 1 || true" \
  --run-command "resize2fs /dev/sda1 || true" \
  --run-command "touch /etc/cloud/cloud-init.disabled" \
  --run-command "id -u uceda >/dev/null 2>&1 || useradd -m -s /bin/bash uceda" \
  --run-command "echo 'uceda ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/uceda && chmod 440 /etc/sudoers.d/uceda" \
  --root-password password:asdfghjkl \
  --password uceda:password:asdfghjkl \
  --ssh-inject uceda:file:$HOME/.ssh/id_rsa.pub \
  --ssh-inject root:file:$HOME/.ssh/id_rsa.pub \
  --run-command "rm -f /etc/machine-id /var/lib/dbus/machine-id" \
  --run-command "systemd-machine-id-setup" \
  --run-command "rm -f /etc/ssh/ssh_host_*" \
  --run-command "ssh-keygen -A" \
  --run-command "sed -i 's/^GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8\"/' /etc/default/grub" \
  --run-command "update-grub" \
  --run-command "systemctl enable serial-getty@ttyS0.service" \
  --run-command "sed -i \"s/^127\\.0\\.1\\.1 .*/127.0.1.1 ansible-ctrl/\" /etc/hosts"

# === server1 (192.168.60.11) ===
sudo virt-customize -a /var/lib/libvirt/images/server1.qcow2 \
  --no-network \
  --hostname "server1" \
  --write "/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [192.168.60.11/24]
      routes: [{to: default, via: 192.168.60.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
" \
  --run-command "growpart /dev/sda 1 || true" \
  --run-command "resize2fs /dev/sda1 || true" \
  --run-command "touch /etc/cloud/cloud-init.disabled" \
  --run-command "id -u uceda >/dev/null 2>&1 || useradd -m -s /bin/bash uceda" \
  --run-command "echo 'uceda ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/uceda && chmod 440 /etc/sudoers.d/uceda" \
  --root-password password:asdfghjkl \
  --password uceda:password:asdfghjkl \
  --ssh-inject uceda:file:$HOME/.ssh/id_rsa.pub \
  --ssh-inject root:file:$HOME/.ssh/id_rsa.pub \
  --run-command "rm -f /etc/machine-id /var/lib/dbus/machine-id" \
  --run-command "systemd-machine-id-setup" \
  --run-command "rm -f /etc/ssh/ssh_host_*" \
  --run-command "ssh-keygen -A" \
  --run-command "sed -i 's/^GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8\"/' /etc/default/grub" \
  --run-command "update-grub" \
  --run-command "systemctl enable serial-getty@ttyS0.service" \
  --run-command "sed -i \"s/^127\\.0\\.1\\.1 .*/127.0.1.1 server1/\" /etc/hosts"

# === server2 (192.168.60.12) ===
sudo virt-customize -a /var/lib/libvirt/images/server2.qcow2 \
  --no-network \
  --hostname "server2" \
  --write "/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [192.168.60.12/24]
      routes: [{to: default, via: 192.168.60.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
" \
  --run-command "growpart /dev/sda 1 || true" \
  --run-command "resize2fs /dev/sda1 || true" \
  --run-command "touch /etc/cloud/cloud-init.disabled" \
  --run-command "id -u uceda >/dev/null 2>&1 || useradd -m -s /bin/bash uceda" \
  --run-command "echo 'uceda ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/uceda && chmod 440 /etc/sudoers.d/uceda" \
  --root-password password:asdfghjkl \
  --password uceda:password:asdfghjkl \
  --ssh-inject uceda:file:$HOME/.ssh/id_rsa.pub \
  --ssh-inject root:file:$HOME/.ssh/id_rsa.pub \
  --run-command "rm -f /etc/machine-id /var/lib/dbus/machine-id" \
  --run-command "systemd-machine-id-setup" \
  --run-command "rm -f /etc/ssh/ssh_host_*" \
  --run-command "ssh-keygen -A" \
  --run-command "sed -i 's/^GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8\"/' /etc/default/grub" \
  --run-command "update-grub" \
  --run-command "systemctl enable serial-getty@ttyS0.service" \
  --run-command "sed -i \"s/^127\\.0\\.1\\.1 .*/127.0.1.1 server2/\" /etc/hosts"

# === server3 (192.168.60.13) ===
sudo virt-customize -a /var/lib/libvirt/images/server3.qcow2 \
  --no-network \
  --hostname "server3" \
  --write "/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [192.168.60.13/24]
      routes: [{to: default, via: 192.168.60.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
" \
  --run-command "growpart /dev/sda 1 || true" \
  --run-command "resize2fs /dev/sda1 || true" \
  --run-command "touch /etc/cloud/cloud-init.disabled" \
  --run-command "id -u uceda >/dev/null 2>&1 || useradd -m -s /bin/bash uceda" \
  --run-command "echo 'uceda ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/uceda && chmod 440 /etc/sudoers.d/uceda" \
  --root-password password:asdfghjkl \
  --password uceda:password:asdfghjkl \
  --ssh-inject uceda:file:$HOME/.ssh/id_rsa.pub \
  --ssh-inject root:file:$HOME/.ssh/id_rsa.pub \
  --run-command "rm -f /etc/machine-id /var/lib/dbus/machine-id" \
  --run-command "systemd-machine-id-setup" \
  --run-command "rm -f /etc/ssh/ssh_host_*" \
  --run-command "ssh-keygen -A" \
  --run-command "sed -i 's/^GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8\"/' /etc/default/grub" \
  --run-command "update-grub" \
  --run-command "systemctl enable serial-getty@ttyS0.service" \
  --run-command "sed -i \"s/^127\\.0\\.1\\.1 .*/127.0.1.1 server3/\" /etc/hosts"
```

> ⚠️ Si tu llave local no es `~/.ssh/id_rsa.pub` (por ejemplo usas `ed25519`), ajusta la ruta en
> `--ssh-inject` en los 4 bloques antes de ejecutar.

**✅ Verificación (Opción A u Opción B)**

```bash
# No debe reportar errores; el comando termina con "Finishing off" en cada VM.
echo "Sin salida de error arriba = OK"
```

#### 🔍 Si `virt-customize` falla con `libguestfs error: guestfs_launch failed`

> Este mensaje es genérico y no dice la causa real. Antes de nada revisa la corrección #14
> (§0): `sudo chmod 0644 /boot/vmlinuz-*`. Si ya lo corregiste y sigue fallando, vuelve a
> ejecutar **el mismo bloque que falló** (Opción A o el bloque de esa VM en Opción B) pero
> anteponiendo `LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1 sudo -E` en vez de `sudo`, y agregando
> `2>&1 | tail -120` al final. Por ejemplo, para `ansible-ctrl` (Opción B):

```bash
LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1 sudo -E virt-customize -a /var/lib/libvirt/images/ansible-ctrl.qcow2 \
  --no-network \
  --hostname "ansible-ctrl" \
  --write "/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [192.168.60.10/24]
      routes: [{to: default, via: 192.168.60.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
" \
  --run-command "growpart /dev/sda 1 || true" \
  --run-command "resize2fs /dev/sda1 || true" \
  --run-command "touch /etc/cloud/cloud-init.disabled" \
  --run-command "id -u uceda >/dev/null 2>&1 || useradd -m -s /bin/bash uceda" \
  --run-command "echo 'uceda ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/uceda && chmod 440 /etc/sudoers.d/uceda" \
  --root-password password:asdfghjkl \
  --password uceda:password:asdfghjkl \
  --ssh-inject uceda:file:$HOME/.ssh/id_rsa.pub \
  --ssh-inject root:file:$HOME/.ssh/id_rsa.pub \
  --run-command "rm -f /etc/machine-id /var/lib/dbus/machine-id" \
  --run-command "systemd-machine-id-setup" \
  --run-command "rm -f /etc/ssh/ssh_host_*" \
  --run-command "ssh-keygen -A" \
  --run-command "sed -i 's/^GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8\"/' /etc/default/grub" \
  --run-command "update-grub" \
  --run-command "systemctl enable serial-getty@ttyS0.service" \
  --run-command "sed -i \"s/^127\\.0\\.1\\.1 .*/127.0.1.1 ansible-ctrl/\" /etc/hosts" \
  2>&1 | tail -120
```

> Para las otras VMs, sustituye `ansible-ctrl.qcow2`, el `--hostname`, la IP en el `--write` y el
> `127.0.1.1` final por los de `server1`/`server2`/`server3` (mismo patrón que la Opción B de
> arriba). Con `--no-network` presente, el trace no debería tocar `passt`; busca en la salida la
> primera línea que diga `error` para identificar la causa real (permisos, KVM, espacio, memoria).
> Si no es obvio, revisa también `libguestfs-test-tool 2>&1 | tail -60`.

### 3.5. Definir y arrancar las 4 VMs con `virt-install`

> **Nodo: `[LAPTOP]`**

> Igual que en §3.4, hay dos formas equivalentes: **Opción A** con un bucle `for` (compacta) y
> **Opción B** a pie, un comando `virt-install` completo por VM, sin bucle ni variables `${...}`.

#### Opción A — con bucle `for`

```bash
declare -A RAM=( [ansible-ctrl]=1536 [server1]=1024 [server2]=1024 [server3]=1024 )
declare -A VCPU=( [ansible-ctrl]=2 [server1]=1 [server2]=1 [server3]=1 )

for vm in ansible-ctrl server1 server2 server3; do
  sudo virt-install \
    --name "${vm}" \
    --memory "${RAM[$vm]}" \
    --vcpus "${VCPU[$vm]}" \
    --disk path=/var/lib/libvirt/images/${vm}.qcow2,format=qcow2,bus=virtio \
    --network network=ansible-lab,model=virtio \
    --os-variant ubuntu24.04 \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --noautoconsole
done
```

#### Opción B — a pie, un bloque por VM (sin `for`)

> Mismo resultado que la Opción A, con RAM/vCPU y ruta de disco ya sustituidos por VM. Ejecuta
> los 4 bloques en orden; no hace falta declarar variables antes.

```bash
# === ansible-ctrl (2 vCPU, 1536 MB) ===
sudo virt-install \
  --name "ansible-ctrl" \
  --memory 1536 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/ansible-ctrl.qcow2,format=qcow2,bus=virtio \
  --network network=ansible-lab,model=virtio \
  --os-variant ubuntu24.04 \
  --graphics none \
  --console pty,target_type=serial \
  --import \
  --noautoconsole

# === server1 (1 vCPU, 1024 MB) ===
sudo virt-install \
  --name "server1" \
  --memory 1024 \
  --vcpus 1 \
  --disk path=/var/lib/libvirt/images/server1.qcow2,format=qcow2,bus=virtio \
  --network network=ansible-lab,model=virtio \
  --os-variant ubuntu24.04 \
  --graphics none \
  --console pty,target_type=serial \
  --import \
  --noautoconsole

# === server2 (1 vCPU, 1024 MB) ===
sudo virt-install \
  --name "server2" \
  --memory 1024 \
  --vcpus 1 \
  --disk path=/var/lib/libvirt/images/server2.qcow2,format=qcow2,bus=virtio \
  --network network=ansible-lab,model=virtio \
  --os-variant ubuntu24.04 \
  --graphics none \
  --console pty,target_type=serial \
  --import \
  --noautoconsole

# === server3 (1 vCPU, 1024 MB) ===
sudo virt-install \
  --name "server3" \
  --memory 1024 \
  --vcpus 1 \
  --disk path=/var/lib/libvirt/images/server3.qcow2,format=qcow2,bus=virtio \
  --network network=ansible-lab,model=virtio \
  --os-variant ubuntu24.04 \
  --graphics none \
  --console pty,target_type=serial \
  --import \
  --noautoconsole
```

**✅ Verificación (Opción A u Opción B)**

```bash
# Las 4 VMs deben aparecer 'running'.
sudo virsh list --all
```

Salida esperada:

```text
 Id   Name           State
--------------------------------
 1    ansible-ctrl   running
 2    server1        running
 3    server2        running
 4    server3        running
```

### 3.6. Primera conexión y confirmación de red

> **Nodo: `[LAPTOP]`** (se conecta por SSH hacia las 4 VMs desde el host)

> ⚠️ **Si reconstruiste algún disco** (repetiste §3.3/§3.4 para arreglar un error, por ejemplo el
> bashismo `&>/dev/null` corregido en la tabla de errores #11), esa VM tiene una **llave SSH de
> host nueva** (se regenera a propósito en §3.4 con `ssh-keygen -A`). Si esa IP ya estaba guardada
> en tu `~/.ssh/known_hosts` de un intento anterior, SSH detecta el cambio de llave como un posible
> ataque MITM y falla con `Host key verification failed`, **aunque la VM esté perfectamente bien**.
> Limpia las entradas viejas antes de probar:

```bash
# Elimina cualquier llave de host guardada previamente para estas 4 IPs (evita falsos
# positivos de "Host key verification failed" al reconstruir discos).
for vm_ip in 192.168.60.10 192.168.60.11 192.168.60.12 192.168.60.13; do
  ssh-keygen -R "$vm_ip" >/dev/null 2>&1
done
```

```bash
# Espera ~30-60s a que arranque cloud-init/systemd-networkd antes de probar SSH.
for vm_ip in 192.168.60.10 192.168.60.11 192.168.60.12 192.168.60.13; do
  printf "%-16s " "$vm_ip"
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 uceda@"$vm_ip" \
    "hostname && ip -4 -br addr show enp1s0" 2>&1 | tr '\n' ' '
  echo
done
```

**✅ Verificación esperada** (por cada IP, debe imprimir el hostname correcto y la IP estática asignada):

```text
192.168.60.10    ansible-ctrl enp1s0 UP 192.168.60.10/24
192.168.60.11    server1 enp1s0 UP 192.168.60.11/24
192.168.60.12    server2 enp1s0 UP 192.168.60.12/24
192.168.60.13    server3 enp1s0 UP 192.168.60.13/24
```

> Si el nombre de la interfaz no es `enp1s0` (puede variar según el orden PCI asignado por
> `virt-install`), entra por consola serie (`sudo virsh console <vm>`), revisa con `ip -br addr`
> y corrige `/etc/netplan/50-cloud-init.yaml` con el nombre real antes de continuar.
>
> Si en vez de "Host key verification failed" ves que **de verdad** no responde (timeout, sin IP,
> u hostname incorrecto), ese sí es un problema real de esa VM: revisa con
> `sudo virsh console <vm>` si arrancó bien y si el netplan quedó con la IP correcta.

```bash
# Confirma que la raíz de cada VM realmente creció a ~10G (y no se quedó en los ~3.5G de la
# imagen base). Si ves 'growpart'/'resize2fs' con error o el tamaño sigue en ~3.5G, revisa la
# corrección #13 de la tabla de errores (§0) antes de instalar paquetes en esa VM.
for vm_ip in 192.168.60.10 192.168.60.11 192.168.60.12 192.168.60.13; do
  printf "%-16s " "$vm_ip"
  ssh -o ConnectTimeout=3 uceda@"$vm_ip" "df -h / | tail -1"
done
```

---

## 4. Instalación de Ansible en el nodo de control

> **Nodo: `[CTRL]`** — `ssh uceda@192.168.60.10`

### 4.1. Repositorio y paquete

> **Nodo: `[CTRL]`**

```bash
# Repositorio oficial de la comunidad Ansible (builds recientes de ansible-core + collections).
sudo add-apt-repository -y ppa:ansible/ansible

# Corrección respecto al PDF: forzar 'apt update' explícito (no depender del modo interactivo).
sudo apt update

# Si el PPA aún no publica build para esta versión de Ubuntu, apt update mostrará un 404/'not found'
# para ese repo. En ese caso, usa la alternativa sin PPA (Ubuntu 24.04 trae Ansible >= 2.16 en universe):
#   sudo apt-add-repository --remove ppa:ansible/ansible
#   sudo apt update

sudo apt install -y ansible
```

### 4.2. Paquetes complementarios de Python

> **Nodo: `[CTRL]`**

```bash
# Autocompletado de comandos ansible-* en bash.
sudo apt install -y python3-argcomplete
sudo activate-global-python-argcomplete3
```

**✅ Verificación**

```bash
ansible --version
```

Salida esperada (versión exacta puede variar, lo importante es que no falle):

```text
ansible [core 2.16.x]
  config file = /etc/ansible/ansible.cfg
  ...
  python version = 3.12.x
```

### 4.3. Crear el directorio de inventario si no existe

> **Nodo: `[CTRL]`**

```bash
# Corrección respecto al PDF: en instalaciones limpias /etc/ansible puede no existir todavía.
sudo mkdir -p /etc/ansible
```

**✅ Verificación**

```bash
ls -ld /etc/ansible
```

---

## 5. Acceso SSH desde el nodo de control hacia los nodos gestionados

### 5.1. Habilitar acceso SSH temporal en los nodos gestionados

> **Nodos: `[SRV1]`, `[SRV2]`, `[SRV3]`**
> Corrección respecto al PDF: este paso **debe ir antes** de copiar la llave a `root` (sección 5.2),
> porque `PermitRootLogin prohibit-password` (valor por defecto) bloquea `ssh-copy-id` hasta que se
> habilite el login por password.
>
> **Corrección adicional:** las imágenes cloud de Ubuntu traen `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf`
> con `PasswordAuthentication no`. Como el `Include` de `sshd_config.d/*.conf` está al inicio de
> `sshd_config` y sshd usa la **primera** coincidencia de cada directiva, ese `no` gana aunque
> `sshd_config` diga `yes`. Sin arreglar esto, `ssh-copy-id` falla con `Permission denied
> (publickey)` sin siquiera pedir password, aunque `PermitRootLogin` ya esté en `yes`.

```bash
# Ejecutar en cada uno de los 3 nodos (server1, server2, server3):
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
sudo systemctl restart ssh

# Ya se fijó contraseña de root en el virt-customize (§3.4): asdfghjkl.
# Si quieres cambiarla manualmente en un nodo puntual:
#   sudo passwd
```

**✅ Verificación**

```bash
# Debe mostrar 'PermitRootLogin yes' y ningún 'PasswordAuthentication no' activo.
grep -rn "PasswordAuthentication\|PermitRootLogin" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf
```

### 5.2. Generar la llave SSH del nodo de control y copiarla a `root` en cada nodo

> **Nodo: `[CTRL]`**

```bash
# Genera un par de llaves RSA 4096 dedicado a Ansible (Enter en todas las preguntas = sin passphrase).
ssh-keygen -t rsa -b 4096 -C "Ansible key" -f ~/.ssh/id_rsa -N ""

# Copia la llave pública a la cuenta root de cada nodo gestionado.
for ip in 192.168.60.11 192.168.60.12 192.168.60.13; do
  ssh-copy-id -i ~/.ssh/id_rsa.pub root@"$ip"
done
```

**✅ Verificación**

```bash
# Debe conectar SIN pedir password.
for ip in 192.168.60.11 192.168.60.12 192.168.60.13; do
  printf "%-16s " "$ip"
  ssh -o BatchMode=yes root@"$ip" "hostname"
done
```

### 5.3. Crear usuario dedicado `ansible` (recomendado)

> **Nodos: `[SRV1]`, `[SRV2]`, `[SRV3]`** (repetir en cada uno, o hacerlo vía Ansible ad-hoc una vez
> que `root` ya responde, ver comando alterno abajo).

```bash
# En cada nodo gestionado:
sudo adduser ansible                      # pedirá password: usar una fuerte
echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible
sudo chmod 0440 /etc/sudoers.d/ansible     # permisos correctos (el PDF no lo indicaba)
sudo visudo -c                             # valida sintaxis de todos los archivos en sudoers.d
```

Alternativa más rápida, **una sola vez desde `[CTRL]`** usando el acceso root ya configurado
(evita entrar manualmente a cada nodo):

```bash
# [CTRL] — crea el usuario ansible y su regla sudo NOPASSWD en los 3 nodos a la vez.
ansible all -i "192.168.60.11,192.168.60.12,192.168.60.13," -u root -m user \
  -a "name=ansible shell=/bin/bash create_home=yes"

ansible all -i "192.168.60.11,192.168.60.12,192.168.60.13," -u root -m copy \
  -a "content='ansible ALL=(ALL) NOPASSWD:ALL' dest=/etc/sudoers.d/ansible mode=0440"
```

Copiar la llave del control hacia el usuario `ansible` en cada nodo:

> **Nodo: `[CTRL]`**
> Corrección: **no** usar `ssh-copy-id ansible@<ip>` aquí — el usuario `ansible` recién creado
> con el módulo `user` de Ansible **no tiene contraseña fijada** (queda bloqueada, `!` en
> `/etc/shadow`), así que `ssh-copy-id` pedirá un password que no existe de forma confiable
> (puede fallar en unos nodos sí y en otros no, de forma inconsistente). En vez de eso,
> se instala la llave usando el acceso por llave de `root` que ya funciona (§5.2), con el
> módulo `authorized_key`, sin depender de ningún password del usuario `ansible`:

```bash
# [CTRL] — instala la llave pública en ~ansible/.ssh/authorized_keys de los 3 nodos,
# autenticándose como root (ya tiene acceso por llave) en vez de como 'ansible'.
ansible all -i "192.168.60.11,192.168.60.12,192.168.60.13," -u root -m authorized_key \
  -a "user=ansible key=\"{{ lookup('file', '~/.ssh/id_rsa.pub') }}\" state=present manage_dir=yes"
```

Deshabilitar login por password del usuario `ansible` (solo llave pública desde ahora):

> **Nodo: `[CTRL]`**

```bash
for ip in 192.168.60.11 192.168.60.12 192.168.60.13; do
  ssh root@"$ip" "usermod -L ansible"
done
```

**✅ Verificación**

```bash
# Debe conectar sin password y mostrar sudo sin pedir password.
for ip in 192.168.60.11 192.168.60.12 192.168.60.13; do
  printf "%-16s " "$ip"
  ssh -o BatchMode=yes ansible@"$ip" "sudo whoami"
done
```

Salida esperada: `root` impreso 3 veces (una por nodo).

---

## 6. Configurando el inventario

> **Nodo: `[CTRL]`**

```bash
sudo tee /etc/ansible/hosts > /dev/null <<'EOF'
# Grupo con los 3 nodos gestionados que usaremos para el laboratorio de Gluster
# (requerimiento #2: grupo de servidores llamado "gluster").
[gluster]
server1 ansible_host=192.168.60.11
server2 ansible_host=192.168.60.12
server3 ansible_host=192.168.60.13

# Grupo de variables aplicado a TODOS los hosts del inventario.
[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=ansible
EOF
```

**✅ Verificación**

```bash
# Lista los hosts que Ansible reconoce, agrupados.
ansible-inventory --list -y
```

---

## 7. Prueba de conexión y comandos ad-hoc

> **Nodo: `[CTRL]`**

```bash
# Módulo 'ping' de Ansible: NO es un ICMP ping, verifica que puede conectar por SSH,
# ejecutar Python en el nodo remoto y devolver 'pong'.
ansible all -m ping
```

**✅ Verificación esperada**

```text
server1 | SUCCESS => {"changed": false, "ping": "pong"}
server2 | SUCCESS => {"changed": false, "ping": "pong"}
server3 | SUCCESS => {"changed": false, "ping": "pong"}
```

Otros comandos ad-hoc útiles (equivalentes a los del PDF, con comentario de qué hacen):

```bash
# Muestra el uso de disco de cada nodo (equivalente remoto de 'df -h').
ansible all -a "df -h"

# Actualiza el índice de paquetes apt en todos los nodos (requiere privilegios -> --become).
ansible all -b -m apt -a "update_cache=yes"

# Filtra solo un host del inventario en vez de todo el grupo.
ansible server1 -m ping
```

> Nota: como ya configuramos `ansible_user=ansible` en `[all:vars]`, **no** hace falta `-u root`
> como en el PDF original; si se quisiera forzar otro usuario puntualmente, sí se usa `-u <usuario>`.

---

## 8. Playbooks

> **Nodo: `[CTRL]`** (todos los playbooks de esta sección se crean y ejecutan desde el nodo de control)

> Crear un directorio de trabajo ordenado para los playbooks.

```bash
# [CTRL]
mkdir -p ~/ansible-lab/playbooks
cd ~/ansible-lab/playbooks
```

> ⚠️ Si al guardar un playbook con `nano` te da el error `Error writing
> /home/uceda/ansible-lab/playbooks/NN-archivo.yml: No such file or directory`, es porque el
> `mkdir -p` de arriba no se ejecutó (o se ejecutó en otra terminal/sesión) antes de abrir el
> editor. Confirma con `pwd` que estás parado en `~/ansible-lab/playbooks` y que el directorio
> existe antes de crear cada archivo `.yml`, por ejemplo:
> ```bash
> mkdir -p ~/ansible-lab/playbooks
> cd ~/ansible-lab/playbooks
> nano 01-hostname.yml
> ```

### 8.1. Playbook: hostname de cada nodo (requerimiento #3)

> **Nodo: `[CTRL]`** (playbook aplicado sobre el grupo `gluster`: `[SRV1]`, `[SRV2]`, `[SRV3]`)

```yaml
# ~/ansible-lab/playbooks/01-hostname.yml
# Objetivo: asegurar que el hostname de cada nodo coincide con su nombre en el inventario
# (server1, server2, server3), usando el módulo 'hostname' de Ansible.
---
- name: Configurar hostname en los nodos del grupo gluster
  hosts: gluster            # aplica solo a server1/server2/server3
  become: true               # todas las tareas se ejecutan con sudo
  tasks:
    - name: Fijar hostname == nombre del inventario
      ansible.builtin.hostname:
        name: "{{ inventory_hostname }}"   # server1, server2 o server3 según el nodo

    - name: Confirmar hostname aplicado
      ansible.builtin.command: hostname
      register: hostname_actual
      changed_when: false                  # es una tarea de solo lectura, no reporta 'changed'

    - name: Mostrar el hostname reportado por cada nodo
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} -> {{ hostname_actual.stdout }}"
```

Ejecutar:

```bash
ansible-playbook 01-hostname.yml
```

**✅ Verificación**

```bash
# Debe imprimir server1/server2/server3 respectivamente.
ansible gluster -m command -a "hostname"
```

### 8.2. Playbook: `/etc/hosts` consistente en todos los nodos (requerimiento #4)

> **Nodo: `[CTRL]`** (playbook aplicado sobre el grupo `gluster`: `[SRV1]`, `[SRV2]`, `[SRV3]`)

```yaml
# ~/ansible-lab/playbooks/02-etc-hosts.yml
# Objetivo: que los 3 nodos (y el control) se resuelvan por nombre entre sí, usando la IP de
# la red 'ansible-lab' (192.168.60.0/24) definida en esta guía.
---
- name: Configurar /etc/hosts en los nodos del grupo gluster
  hosts: gluster
  become: true
  tasks:
    - name: Insertar/actualizar bloque de hosts del laboratorio
      ansible.builtin.blockinfile:
        path: /etc/hosts
        marker: "# {mark} ANSIBLE LAB HOSTS"   # delimita el bloque para poder re-ejecutar sin duplicar
        block: |
          192.168.60.10 ansible-ctrl
          192.168.60.11 server1
          192.168.60.12 server2
          192.168.60.13 server3
```

Ejecutar:

```bash
ansible-playbook 02-etc-hosts.yml
```

**✅ Verificación**

```bash
# Cada nodo debe poder resolver y hacer ping (dentro de la red virtual) a los otros dos.
ansible gluster -m command -a "getent hosts server1 server2 server3"
```

### 8.3. Playbook: instalar y configurar `chrony` (requerimiento #5)

> **Nodo: `[CTRL]`** (playbook aplicado sobre el grupo `gluster`: `[SRV1]`, `[SRV2]`, `[SRV3]`)

```yaml
# ~/ansible-lab/playbooks/03-chrony.yml
# Objetivo: instalar chrony y forzar el servidor NTP institucional
# 'ntp.ues.edu.sv iburst' en /etc/chrony/chrony.conf de cada nodo.
---
- name: Instalar y configurar chrony
  hosts: gluster
  become: true
  tasks:
    - name: Instalar el paquete chrony
      ansible.builtin.apt:
        name: chrony
        state: present
        update_cache: true

    - name: Comentar los servidores NTP por defecto (pool.ntp.org)
      ansible.builtin.replace:
        path: /etc/chrony/chrony.conf
        regexp: '^(pool .*)$'
        replace: '# \1'

    - name: Asegurar la línea "server ntp.ues.edu.sv iburst"
      ansible.builtin.lineinfile:
        path: /etc/chrony/chrony.conf
        line: "server ntp.ues.edu.sv iburst"
        insertafter: EOF
      notify: Reiniciar chrony               # dispara el handler solo si hubo cambio

  handlers:
    - name: Reiniciar chrony
      ansible.builtin.systemd:
        name: chrony
        state: restarted
        enabled: true
```

Ejecutar:

```bash
ansible-playbook 03-chrony.yml
```

**✅ Verificación**

```bash
# Debe mostrar la línea agregada, sin duplicados.
ansible gluster -m command -a "grep ntp.ues.edu.sv /etc/chrony/chrony.conf"

# Debe reportar el servicio activo y, con el tiempo, el estado de sincronización.
ansible gluster -m command -a "systemctl is-active chrony"
ansible gluster -b -m command -a "chronyc sources"
```

### 8.4. Playbook opcional: preparar GlusterFS en el grupo `gluster` (apoyo al requerimiento #2)

> **Nodo: `[CTRL]`** (playbook aplicado sobre el grupo `gluster`: `[SRV1]`, `[SRV2]`, `[SRV3]`)

> El requerimiento #2 solo pide **nombrar el grupo** `gluster` en el inventario (ya hecho en
> [§6](#6-configurando-el-inventario)). Este playbook es un extra para dejar los 3 nodos listos con
> GlusterFS instalado y en pool de confianza, siguiendo el Quick Start oficial de Gluster
> (`https://docs.gluster.org/en/main/Quick-Start-Guide/Quickstart/`), ya que en este laboratorio
> partimos de VMs nuevas y no hay nodos previos de una clase anterior.

```yaml
# ~/ansible-lab/playbooks/04-gluster-setup.yml
---
- name: Instalar GlusterFS en el grupo gluster
  hosts: gluster
  become: true
  tasks:
    - name: Instalar glusterfs-server
      ansible.builtin.apt:
        name: glusterfs-server
        state: present
        update_cache: true

    - name: Habilitar y arrancar glusterd
      ansible.builtin.systemd:
        name: glusterd
        state: started
        enabled: true

- name: Formar el trusted pool (probe entre nodos)
  hosts: server1                              # el probe se ejecuta desde un único nodo
  become: true
  tasks:
    - name: Probe hacia server2
      ansible.builtin.command: gluster peer probe server2
      register: probe2
      changed_when: "'already in the peer list' not in probe2.stdout"

    - name: Probe hacia server3
      ansible.builtin.command: gluster peer probe server3
      register: probe3
      changed_when: "'already in the peer list' not in probe3.stdout"
```

Ejecutar:

```bash
ansible-playbook 04-gluster-setup.yml
```

**✅ Verificación**

```bash
# Debe listar 2 peers en estado 'Connected'.
ansible server1 -b -m command -a "gluster peer status"

# Debe mostrar glusterd activo en los 3 nodos.
ansible gluster -m command -a "systemctl is-active glusterd"
```

---

## 9. Requerimientos de laboratorio (resueltos)

| # | Requerimiento | Dónde se resuelve |
|---|---------------|--------------------|
| 1 | Configurar Ansible para gestionar nodos remotos | [§4](#4-instalación-de-ansible-en-el-nodo-de-control) + [§5](#5-acceso-ssh-desde-el-nodo-de-control-hacia-los-nodos-gestionados) |
| 2 | Grupo de servidores `gluster` | [§6](#6-configurando-el-inventario) (grupo `[gluster]` con `server1`, `server2`, `server3`); preparación opcional de GlusterFS en [§8.4](#84-playbook-opcional-preparar-glusterfs-en-el-grupo-gluster-apoyo-al-requerimiento-2) |
| 3 | Playbook que configura el hostname de cada nodo | [§8.1](#81-playbook-hostname-de-cada-nodo-requerimiento-3) |
| 4 | Playbook que configura `/etc/hosts` | [§8.2](#82-playbook-etchosts-consistente-en-todos-los-nodos-requerimiento-4) |
| 5 | Playbook que instala `chrony` con `server ntp.ues.edu.sv iburst` | [§8.3](#83-playbook-instalar-y-configurar-chrony-requerimiento-5) |

Para ejecutar los 3 playbooks obligatorios en orden y confirmar todo de una vez:

> **Nodo: `[CTRL]`**

```bash
# [CTRL]
cd ~/ansible-lab/playbooks
ansible-playbook 01-hostname.yml 02-etc-hosts.yml 03-chrony.yml
```

---

## 10. Tabla de comprobación final

> **Nodo: `[CTRL]`** — ejecutar todo junto como checklist de cierre.

```bash
echo "== 1. Conectividad Ansible =="
ansible all -m ping

echo "== 2. Hostnames =="
ansible gluster -m command -a "hostname"

echo "== 3. /etc/hosts =="
ansible gluster -m command -a "getent hosts server1 server2 server3"

echo "== 4. chrony =="
ansible gluster -m command -a "systemctl is-active chrony"
ansible gluster -m command -a "grep ntp.ues.edu.sv /etc/chrony/chrony.conf"

echo "== 5. gluster (opcional) =="
ansible gluster -m command -a "systemctl is-active glusterd" || true
```

| Verificación | Comando | Resultado esperado |
|--------------|---------|---------------------|
| Ansible instalado en control | `ansible --version` | Sin error, muestra versión |
| SSH sin password control → nodos | `ssh ansible@192.168.60.1{1,2,3}` | Entra sin pedir password |
| Inventario correcto | `ansible-inventory --list -y` | Muestra grupo `gluster` con 3 hosts |
| Conectividad Ansible | `ansible all -m ping` | `pong` en los 3 nodos |
| Hostname aplicado | `ansible gluster -m command -a hostname` | `server1`, `server2`, `server3` |
| `/etc/hosts` propagado | `getent hosts server1 server2 server3` | Resuelve las 3 IPs `192.168.60.11-13` |
| chrony activo con NTP institucional | `systemctl is-active chrony` + `grep ntp.ues.edu.sv` | `active` + línea presente |
| (Opcional) Gluster pool formado | `gluster peer status` en `server1` | 2 peers `Connected` |

---

## 11. Anexo — Limpieza / reinicio del laboratorio

> **Nodo: `[LAPTOP]`**

> Útil si algo queda mal a mitad de la guía y se prefiere **empezar de cero** de nuevo.
> ⚠️ Esto es destructivo: borra las 4 VMs y sus discos. No afecta a las VMs del laboratorio
> OpenStack (`controller`, `compute1-4`), que viven en discos y red distintos.

```bash
# [LAPTOP]
for vm in ansible-ctrl server1 server2 server3; do
  # Apaga la VM de forma forzosa (equivalente a quitar el cable de energía).
  sudo virsh destroy "$vm" 2>/dev/null || true
  # Elimina la definición de la VM junto con su disco asociado.
  sudo virsh undefine "$vm" --remove-all-storage 2>/dev/null || true
done

# Detener y eliminar la red libvirt del laboratorio.
sudo virsh net-destroy ansible-lab 2>/dev/null || true
sudo virsh net-undefine ansible-lab 2>/dev/null || true
```

**✅ Verificación**

```bash
# No deben aparecer las VMs ni la red 'ansible-lab'.
sudo virsh list --all
sudo virsh net-list --all
```
