# Secuencia de Comandos: ceph-admin y OSDs

Este documento resume la secuencia de comandos que se ejecuta en:

- Nodo administrador: ceph-admin
- Nodos OSD: ceph-1, ceph-2, ceph-3

La secuencia se divide en dos fases:

1. Inicializacion del contenedor (scripts init-*.sh)
2. Bootstrap del cluster (scripts/setup-cluster.sh)

## 1) ceph-admin

### 1.1 Inicializacion (init-admin.sh)

Orden de ejecucion principal:

1. `apt-get update -qq`  
   Actualiza el indice de paquetes del contenedor para que todas las instalaciones usen versiones disponibles y coherentes.  
   Sin este paso, `apt-get install` puede fallar o instalar dependencias desactualizadas.

2. `apt-get install -y -qq ...` (utilidades base)  
   Comando completo: `apt-get install -y -qq curl gnupg2 iputils-ping lsb-release ubuntu-keyring openssh-server openssh-client procps vim net-tools htop wget`  
   Instala herramientas de red, diagnostico, SSH y utilidades de sistema necesarias para administrar el cluster desde `ceph-admin`.  
   Deja el contenedor listo para conectividad, scripting y debugging.

3. `mkdir -p /root/.ssh && chmod 700 /root/.ssh`  
   Crea el directorio de claves SSH con permisos correctos para uso de root.  
   Esto evita errores de seguridad de OpenSSH al usar llaves.

4. `ssh-keygen ...` (si no existe)  
   Comando completo: `if [[ ! -f /root/.ssh/id_rsa ]]; then ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa -q; fi`  
   Genera el par de llaves SSH que se distribuira a monitores y OSDs para acceso sin password.  
   Es la base de la orquestacion remota interna del laboratorio.

5. `mkdir -p /run/sshd`  
   Prepara la ruta de runtime que necesita `sshd` dentro del contenedor.  
   Evita fallos al iniciar servicios o comandos SSH dependientes.

6. Config SSH no interactiva (`StrictHostKeyChecking no`)  
   Comandos completos: `echo "StrictHostKeyChecking no" > /root/.ssh/config && echo "UserKnownHostsFile=/dev/null" >> /root/.ssh/config && chmod 600 /root/.ssh/config`  
   Fuerza conexiones SSH sin prompts de confirmacion de host key, util en entorno efimero de laboratorio.  
   Permite que scripts automatizados no se detengan esperando entrada manual.

7. Agregar repositorio de Ceph + `apt-get update -qq`  
   Comandos completos: `curl -s https://download.ceph.com/keys/release.asc | gpg --dearmor | tee /usr/share/keyrings/ceph-archive-keyring.gpg > /dev/null` y `echo "deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-quincy $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/ceph.list` y `apt-get update -qq`  
   Importa la llave GPG y registra el repo oficial de Ceph Quincy para instalar binarios compatibles.  
   Luego refresca indices para que `apt` conozca esos paquetes.

8. `apt-get install -y -qq ceph ceph-common ceph-mon ceph-osd ceph-mgr`  
   Instala el stack Ceph en el nodo admin para poder generar keyrings, consultar estado y configurar el cluster.  
   Habilita los comandos `ceph`, `rbd`, `ceph-authtool`, entre otros.

9. `apt-get clean -qq && apt-get autoremove -y -qq`  
   Limpia cache y dependencias no usadas para reducir tamaño del contenedor.  
   Mejora tiempos de arranque y consumo de disco en ejecuciones repetidas.

### 1.2 Bootstrap cluster (setup-cluster.sh) ejecutado desde host

Comandos relevantes que ejecuta en ceph-admin:

1. Extrae llave publica para distribuir SSH (`docker exec ... id_rsa.pub`)  
   Comando completo: `docker exec ceph-admin cat /root/.ssh/id_rsa.pub > /tmp/ceph_admin_key.pub`  
   Obtiene la llave creada en `ceph-admin` y la deja temporalmente en host para copiarla al resto de nodos.  
   Esto habilita autenticacion por llave entre contenedores.

2. Genera FSID (`uuidgen`)  
   Comando completo: `FSID=$(uuidgen)`  
   Crea el identificador unico del cluster Ceph que se usa en `ceph.conf`, monmap y metadata interna.  
   Sin un FSID consistente, los daemons no forman parte del mismo cluster.

3. Recibe `ceph.conf` (`docker cp`)  
   Comando completo: `docker cp /tmp/ceph.conf ceph-admin:/etc/ceph/ceph.conf`  
   Copia la configuracion global al admin para que comandos Ceph usen red, hosts y auth correctos.  
   Es el archivo base de funcionamiento para mon/mgr/osd.

4. Genera keyrings (`ceph-authtool`)  
   Comandos completos: `docker exec ceph-admin ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mgr 'allow *' --cap mds 'allow *'`; `docker exec ceph-admin ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'`; `docker exec ceph-admin ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring`  
   Crea credenciales de `client.admin` y `mon.` con sus capacidades y las combina en keyring de monitor.  
   Estas llaves autorizan operaciones administrativas y arranque de componentes.

5. Genera monmap (`monmaptool --create --add ...`)  
   Comando completo: `docker exec ceph-admin monmaptool --create --add ceph-mon 192.168.122.10 --fsid "$FSID" /tmp/monmap`  
   Construye el mapa inicial de monitores con nombre, IP y FSID del cluster.  
   El monitor usa este archivo para inicializar su estado de quorum.

6. Inicializa manager (`ceph auth get-or-create mgr...` + arranque daemon)  
   Comandos completos: `docker exec ceph-admin ceph auth get-or-create mgr.ceph-admin mon 'allow profile mgr' osd 'allow *' mds 'allow *' -o /var/lib/ceph/mgr/ceph-ceph-admin/keyring` y `docker exec -d ceph-admin bash -lc '/usr/bin/ceph-mgr -i ceph-admin --setuser root --setgroup root -f'`  
   Crea identidad y keyring del manager, luego arranca `ceph-mgr` en foreground desacoplado.  
   Habilita servicios de manager, incluyendo API y dashboard.

7. Bootstrap OSD key (`client.bootstrap-osd`)  
   Comandos completos: `docker exec ceph-admin ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring || docker exec ceph-admin ceph auth get-or-create client.bootstrap-osd mon 'allow profile bootstrap-osd' -o /var/lib/ceph/bootstrap-osd/ceph.keyring`; `docker exec ceph-admin cp /var/lib/ceph/bootstrap-osd/ceph.keyring /etc/ceph/ceph.client.bootstrap-osd.keyring`  
   Obtiene o crea la credencial usada por `ceph-volume` para registrar nuevos OSDs en el monitor.  
   Luego la copia a rutas esperadas por cada OSD.

8. Pool RBD (`ceph osd pool create` + `rbd pool init`)  
   Comandos completos: `docker exec ceph-admin ceph osd pool ls | grep -qx rbd || docker exec ceph-admin ceph osd pool create rbd 128 128 replicated`; `docker exec ceph-admin rbd pool init rbd`  
   Crea el pool logico de bloques `rbd` si aun no existe y lo inicializa para uso de imagenes RBD.  
   Deja almacenamiento base listo para pruebas o integraciones.

9. Dashboard web (`ceph mgr module enable dashboard` + config)  
   Comandos completos: `docker exec ceph-admin ceph mgr module enable dashboard`; `docker exec ceph-admin ceph dashboard create-self-signed-cert`; `docker exec ceph-admin ceph config set mgr mgr/dashboard/server_addr 0.0.0.0`; `docker exec ceph-admin ceph config set mgr mgr/dashboard/server_port 8443`; `docker exec ceph-admin ceph dashboard ac-user-show "$DASHBOARD_USER" || docker exec ceph-admin ceph dashboard ac-user-create "$DASHBOARD_USER" "$DASHBOARD_PASSWORD" administrator`; `docker exec ceph-admin ceph dashboard ac-user-set-password "$DASHBOARD_USER" "$DASHBOARD_PASSWORD"`  
   Habilita el modulo dashboard, genera certificado TLS y configura bind/puerto.  
   Crea o actualiza usuario admin para acceso en `https://localhost:8443`.

## 2) OSDs (ceph-1, ceph-2, ceph-3)

## 2.1 Inicializacion (init-osd.sh)

Orden de ejecucion por cada nodo OSD:

1. `apt-get update -qq`  
   Actualiza el indice de paquetes para garantizar resolucion correcta de dependencias OSD.  
   Es requisito previo para instalaciones repetibles.

2. `apt-get install -y -qq ...` (dependencias OSD)  
   Comando completo: `apt-get install -y -qq curl gnupg2 iputils-ping lsb-release ubuntu-keyring openssh-server openssh-client procps python3-packaging udev util-linux kmod vim net-tools htop lvm2 ceph-volume`  
   Instala herramientas de sistema, red y almacenamiento (`ceph-volume`, `lvm2`, `udev`, etc.).  
   Permite preparar, activar y depurar OSDs dentro del contenedor.

3. `mkdir -p /root/.ssh && chmod 700 /root/.ssh`  
   Prepara carpeta SSH de root con permisos seguros para futuras copias de llaves.  
   Evita advertencias o rechazo de OpenSSH.

4. `mkdir -p /run/sshd`  
   Crea estructura runtime necesaria para procesos SSH en contenedor.  
   Facilita comandos remotos y pruebas de conectividad interna.

5. `sed -i` en `sshd_config` (root + pubkey)  
   Comandos completos: `sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config`; `sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config`  
   Ajusta SSH para aceptar autenticacion por llave y login de root en entorno controlado de laboratorio.  
   Esto simplifica la orquestacion automatica entre nodos.

6. Agregar repo Ceph + `apt-get update -qq`  
   Comandos completos: `curl -s https://download.ceph.com/keys/release.asc | gpg --dearmor | tee /usr/share/keyrings/ceph-archive-keyring.gpg > /dev/null` y `echo "deb [signed-by=/usr/share/keyrings/ceph-archive-keyring.gpg] https://download.ceph.com/debian-quincy $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/ceph.list` y `apt-get update -qq`  
   Registra repositorio Quincy e incorpora su indice al sistema de paquetes del OSD.  
   Asegura versionado compatible con el resto del cluster.

7. `apt-get install -y -qq ceph ceph-osd ceph-common ceph-volume`  
   Instala binarios OSD y utilidades de inicializacion/activacion de discos Ceph.  
   Habilita comandos `ceph-osd` y `ceph-volume` usados en bootstrap.

8. Crear usuario `ceph` si no existe (`id ceph || useradd ...`)  
   Comando completo: `id ceph &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin ceph`  
   Garantiza cuenta de sistema requerida por scripts y herramientas Ceph para ownership/ejecucion.  
   Evita fallos de tipo "ceph user is not available".

9. Crear directorios (`/var/lib/ceph/osd`, `/etc/ceph`, `/data`)  
   Comando completo: `mkdir -p /var/lib/ceph/osd /etc/ceph /data`  
   Prepara estructura base para metadata OSD, configuracion y almacenamiento simulado.  
   Cada ruta cumple una funcion especifica en el arranque.

10. Crear almacenamiento simulado (`/data/osd-<id>.img`)  
   Comandos completos: `mkdir -p /data/osd`; `if [[ ! -f /data/osd-${OSD_ID}.img ]]; then truncate -s "${OSD_DEVICE_SIZE:-5G}" "/data/osd-${OSD_ID}.img"; fi`  
   Crea archivo de bloque por OSD (5G default) que luego se asocia a loop device.  
   Simula un disco dedicado sin requerir hardware adicional.

11. `apt-get clean -qq && apt-get autoremove -y -qq`  
   Reduce basura de instalacion y mantiene contenedor mas liviano.  
   Ayuda en iteraciones frecuentes de `down -v` y `up`.

### 2.2 Bootstrap OSDs (setup-cluster.sh) por cada i=0,1,2

Para cada OSD i:

1. Determina contenedor destino (mapa i -> ceph-N)  
   Comando completo: `OSD_HOST="ceph-$((i + 1))"`  
   Traduce el id logico de OSD al contenedor fisico donde se ejecutara la preparacion del disco.  
   Mantiene correlacion fija entre OSD 0/1/2 y ceph-1/2/3.

2. Prepara loop device (en ese contenedor)  
   Comandos completos: limpieza/reuso/alta con `losetup`, por ejemplo `LOOP_DEV=$(docker exec "$OSD_HOST" bash -lc 'IMG="/data/osd-'"$i"'.img"; mkdir -p /data; [[ -f "$IMG" ]] || truncate -s 5G "$IMG"; EXISTING=$(losetup -j "$IMG" | cut -d: -f1 | head -n1); if [[ -n "$EXISTING" ]]; then echo "$EXISTING"; else losetup -f --show "$IMG"; fi')`  
   Limpia loops stale, asegura existencia de la imagen y devuelve un `/dev/loopX` usable.  
   Es la capa que convierte archivo `.img` en dispositivo de bloque para Ceph.

3. Prepara OSD con `ceph-volume raw prepare`  
   Comando completo: `docker exec "$OSD_HOST" bash -lc "CEPH_VOLUME_ALLOW_LOOP_DEVICES=true ceph-volume raw prepare --bluestore --data $LOOP_DEV --osd-id $i"`  
   Inicializa metadata OSD sobre el loop device y registra el OSD id en el cluster.  
   La variable `CEPH_VOLUME_ALLOW_LOOP_DEVICES=true` habilita este modo de laboratorio.

4. Activa OSD con `ceph-volume raw activate`  
   Comando completo: `docker exec "$OSD_HOST" bash -lc "CEPH_VOLUME_ALLOW_LOOP_DEVICES=true ceph-volume raw activate --device $LOOP_DEV --no-systemd --no-tmpfs"`  
   Completa enlaces/disposicion del OSD para que el daemon pueda arrancar sin systemd.  
   Usa `--no-systemd --no-tmpfs` para entorno contenedor.

5. Arranca daemon `ceph-osd` en background  
   Comando completo: `docker exec -d "$OSD_HOST" bash -lc "/usr/bin/ceph-osd -i $i --setuser root --setgroup root -f"`  
   Levanta el proceso OSD real con `docker exec -d` y parametros de id/cuenta.  
   Es el paso final para que el OSD aparezca como `up`.

Despues del loop de los 3 OSDs:

- se valida que queden up/in con `ceph osd stat`  
   Comando completo: `docker exec ceph-admin ceph osd stat`  
   El script consulta estado global y verifica conteo esperado de OSDs activos e insertados.  
   Si no converge, devuelve error y detiene bootstrap.

## 3) Mapeo rapido OSD

- OSD 0
  - Contenedor: ceph-1
  - Admin IP: 192.168.122.11
  - Data IP: 192.168.5.11
  - Imagen: /data/osd-0.img

- OSD 1
  - Contenedor: ceph-2
  - Admin IP: 192.168.122.12
  - Data IP: 192.168.5.12
  - Imagen: /data/osd-1.img

- OSD 2
  - Contenedor: ceph-3
  - Admin IP: 192.168.122.13
  - Data IP: 192.168.5.13
  - Imagen: /data/osd-2.img
