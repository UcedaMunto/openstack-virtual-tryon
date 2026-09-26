# Guía de instalación de WordPress usando OpenStack (acceso externo)

> **Fecha:** 2026-07-19  
> **Objetivo:** desplegar WordPress accesible desde Internet con Floating IP, usando recursos reales del cloud OpenStack.

---

## 1) Arquitectura a desplegar

- **`wp-web-01`** (VM web): Nginx + PHP-FPM + WordPress  
  - Red interna: `selfservice-net`  
  - Acceso externo: **Floating IP** en `provider-net`
- **`wp-db-01`** (VM base de datos): MariaDB  
  - Red interna: `selfservice-net`  
  - Sin Floating IP
- **Volumen Cinder RBD (Ceph) para DB**: `wp-db-data` (20 GB)

Notas de arquitectura Ceph:

- WordPress usa Ceph de forma indirecta por medio de Cinder (`volume type: ceph`).
- La VM `wp-db-01` monta ese volumen como disco local (`ext4` en `/var/lib/mysql`).
- Este enfoque evita exponer Ceph directamente dentro de la VM de aplicación.

---

## 2) Pre-chequeo real (obligatorio)

### Nodo: `[CONTROLLER]` (203.0.113.239)

```bash
ssh uceda@203.0.113.239
echo aslKDIUR24 | sudo -S -i
source /root/admin-openrc

openstack token issue
openstack compute service list
openstack hypervisor list
openstack network list
openstack subnet list
openstack router list
openstack image list --status active
openstack flavor list
openstack volume service list
openstack network agent list
```

---

## 3) Variables de despliegue y validación

### Nodo: `[CONTROLLER]`

```bash
export IMAGE_NAME="ubuntu-22.04"
export FLAVOR_NAME="wp.small"
export NET_NAME="selfservice-net"
export EXT_NET_NAME="provider-net"

export KEY_NAME="wp-key"
export WEB_VM="wp-web-01"
export DB_VM="wp-db-01"
export DB_VOL="wp-db-data"
export DB_VOL_SIZE=20
export DB_VOL_TYPE="ceph"

export WP_DB_NAME="wordpress"
export WP_DB_USER="wp_user"
export WP_DB_PASS="aslKDIUR24"
export WP_ADMIN_USER="uceda"
export WP_ADMIN_PASS="aslKDIUR24"
export WP_ADMIN_EMAIL="admin@example.com"

# Credenciales operativas solicitadas
export SSH_USER="uceda"
export SSH_PASS="aslKDIUR24"

# Datos reales obtenidos durante este despliegue
export WEB_IP="10.10.10.76"
export DB_IP="10.10.10.152"
export FIP_WEB="192.168.122.137"
export PUBLIC_WP_URL="http://203.0.113.239:8080"
export FIP_DB_TEMP="192.168.122.152"
export ROUTER_NS="qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0"

# validar recursos antes de crear
openstack image show "$IMAGE_NAME" >/dev/null
openstack flavor show "$FLAVOR_NAME" >/dev/null
openstack network show "$NET_NAME" >/dev/null
openstack network show "$EXT_NET_NAME" >/dev/null
openstack volume type show "$DB_VOL_TYPE" >/dev/null
openstack volume service list | grep -E "storage1@ceph|cinder-scheduler"
```

> Nota de ejecución real: en el laboratorio, la contraseña funcional para entrar a los nodos existentes fue `asdfghjkl`. La contraseña `aslKDIUR24` se mantiene como credencial definida para WordPress y MariaDB según lo solicitado.

---

## 4) Security Groups

### Nodo: `[CONTROLLER]`

```bash
# WEB
openstack security group create sg-wordpress-web --description "WordPress Web SG" || true
openstack security group rule create --proto tcp --dst-port 80 sg-wordpress-web || true
openstack security group rule create --proto tcp --dst-port 443 sg-wordpress-web || true
openstack security group rule create --proto icmp sg-wordpress-web || true
# Ajusta CIDR SSH a tu red de administración
openstack security group rule create --proto tcp --dst-port 22 --remote-ip 10.10.10.0/24 sg-wordpress-web || true
openstack security group rule create --proto tcp --dst-port 22 --remote-ip 192.168.122.0/24 sg-wordpress-web || true

# DB
openstack security group create sg-wordpress-db --description "WordPress DB SG" || true
openstack security group rule create --proto tcp --dst-port 3306 --remote-group sg-wordpress-web sg-wordpress-db || true
openstack security group rule create --proto tcp --dst-port 22 --remote-ip 10.10.10.0/24 sg-wordpress-db || true
openstack security group rule create --proto tcp --dst-port 22 --remote-ip 192.168.122.0/24 sg-wordpress-db || true
openstack security group rule create --proto icmp sg-wordpress-db || true
```

---

## 5) Keypair, volumen y VMs

### Nodo: `[CONTROLLER]`

```bash
# keypair (sin sobreescribir si ya existe)
[ -f /root/.ssh/wp-key ] || ssh-keygen -t ed25519 -f /root/.ssh/wp-key -N ""
openstack keypair show "$KEY_NAME" >/dev/null 2>&1 || \
  openstack keypair create --public-key /root/.ssh/wp-key.pub "$KEY_NAME"
```

```bash
# volumen DB sobre Ceph (Cinder RBD)
openstack volume create --size "$DB_VOL_SIZE" --type "$DB_VOL_TYPE" "$DB_VOL"
openstack volume show "$DB_VOL"
```

```bash
# VM DB
openstack server create \
  --flavor "$FLAVOR_NAME" \
  --image "$IMAGE_NAME" \
  --network "$NET_NAME" \
  --security-group sg-wordpress-db \
  --key-name "$KEY_NAME" \
  "$DB_VM"

# VM WEB
openstack server create \
  --flavor "$FLAVOR_NAME" \
  --image "$IMAGE_NAME" \
  --network "$NET_NAME" \
  --security-group sg-wordpress-web \
  --key-name "$KEY_NAME" \
  "$WEB_VM"
```

```bash
# esperar ACTIVE
openstack server list --name wp-
```

```bash
# adjuntar volumen a DB
openstack server add volume "$DB_VM" "$DB_VOL"
openstack server volume list "$DB_VM"
```

Validar que el volumen usa backend Ceph:

```bash
openstack volume show "$DB_VOL" -f yaml | grep -E "type:|os-vol-host-attr:host"
```

### Nodo: `[STORAGE1]` (validación RBD)

```bash
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER"@203.0.113.244 \
"echo $SSH_PASS | sudo -S rbd ls -l volumes"
```

Resultado esperado: debe aparecer un objeto `volume-<uuid>` correspondiente a `wp-db-data`.

Obtener IPs privadas de forma robusta:

```bash
DB_IP=$(openstack server show "$DB_VM" -f value -c addresses | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
WEB_IP=$(openstack server show "$WEB_VM" -f value -c addresses | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
echo "DB_IP=$DB_IP WEB_IP=$WEB_IP"
```

---

## 6) Floating IP para acceso externo

### Nodo: `[CONTROLLER]`

```bash
FIP_WEB=$(openstack floating ip create "$EXT_NET_NAME" -f value -c floating_ip_address)
openstack server add floating ip "$WEB_VM" "$FIP_WEB"
openstack server show "$WEB_VM" -c addresses -f yaml
echo "URL WordPress: http://$FIP_WEB"
```

Estado real actual:

- `wp-web-01`: `ACTIVE`, IP interna `10.10.10.76`, Floating IP `192.168.122.137`.
- `wp-db-01`: `ACTIVE`, IP interna `10.10.10.152`, Floating IP temporal `192.168.122.152` para administración.
- `wp-db-data`: volumen Cinder tipo `ceph`, adjunto a `wp-db-01` como `/dev/vdb`.
- Backend confirmado: `storage1@ceph#ceph`, volumen `16dfbd99-dcb1-47a1-9bbe-ae063541fd35`.
- Ceph validado en `[STORAGE1]`: `HEALTH_OK`; objeto RBD `volume-16dfbd99-dcb1-47a1-9bbe-ae063541fd35` visible en pool `volumes`.
- SSH interno validado tras corregir reglas de seguridad para `10.10.10.0/24`.
- Se corrigió salida de `provider-net` creando gateway temporal `192.168.122.1/24` en `br-provider` y NAT hacia `enp1s0` en `[CONTROLLER]`.
- MariaDB quedó instalado y activo en `wp-db-01`; `/var/lib/mysql` está montado desde `/dev/vdb1` con `ext4`.
- Base `wordpress` creada; usuario `wp_user@10.10.10.76` creado con password `aslKDIUR24`.
- Nginx, PHP-FPM y WordPress quedaron instalados en `wp-web-01`.
- WordPress quedó inicializado con WP-CLI. URL pública validada: `http://203.0.113.239:8080/`.
- Login validado: `http://203.0.113.239:8080/wp-login.php`.

Acceso administrativo temporal desde `[CONTROLLER]` mientras se ajusta el acceso por Floating IP:

```bash
ip netns exec "$ROUTER_NS" ssh -i /root/.ssh/wp-key ubuntu@"$DB_IP"
ip netns exec "$ROUTER_NS" ssh -i /root/.ssh/wp-key ubuntu@"$WEB_IP"
```

Corrección aplicada para salida externa de `provider-net` en el laboratorio:

```bash
ip link set br-provider up
ip addr add 192.168.122.1/24 dev br-provider
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 192.168.122.0/24 -o enp1s0 -j MASQUERADE
iptables -A FORWARD -i br-provider -o enp1s0 -j ACCEPT
iptables -A FORWARD -i enp1s0 -o br-provider -m state --state RELATED,ESTABLISHED -j ACCEPT
```

> Si estos comandos ya existen, no repetirlos sin comprobar con `ip addr show br-provider` e `iptables -t nat -S POSTROUTING`.

Publicación externa adicional hacia la red de administración del laboratorio:

```bash
iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 8080 -j DNAT --to-destination 192.168.122.137:80
iptables -A FORWARD -i enp1s0 -o br-provider -p tcp -d 192.168.122.137 --dport 80 -j ACCEPT
```

Con esta regla, el acceso externo validado queda en:

```text
http://203.0.113.239:8080/
```

Correcciones aplicadas durante la ejecución:

1. **Flavor insuficiente:** `m1.small` no permitió crear la VM por `No valid host was found`. Se creó y usó `wp.small` (`1 vCPU`, `1024 MB RAM`, `8 GB disk`).
2. **Imagen base:** no existía imagen Ubuntu utilizable para WordPress. Se importó `ubuntu-22.04` y quedó activa en Glance/RBD.
3. **SSH a VMs:** las reglas iniciales usaban `10.0.0.0/24`, pero las VMs quedaron en `10.10.10.0/24`. Se agregaron reglas SSH para `10.10.10.0/24` y acceso temporal desde `192.168.122.0/24`.
4. **Acceso a VMs durante instalación:** como el acceso directo por Floating IP no era consistente al principio, se usó el namespace `qrouter-926f615c-e741-4aee-a1d0-37cf6b0482b0` para entrar a las VMs por IP interna.
5. **Salida externa de `provider-net`:** el gateway `192.168.122.1` no existía en el laboratorio. Se levantó `192.168.122.1/24` en `br-provider`, se habilitó forwarding y se agregó NAT hacia `enp1s0`.
6. **Apt/DNS en VMs:** tras corregir NAT, `apt` resolvía registros IPv6 primero en un entorno sin salida IPv6. Se agregó `Acquire::ForceIPv4 "true";` en `/etc/apt/apt.conf.d/99force-ipv4`.
7. **Volumen DB:** `/dev/vdb1` existía pero no tenía filesystem. Se formateó con `ext4`, se montó en `/var/lib/mysql`, se registró por UUID en `/etc/fstab` y se restauraron los datos iniciales de MariaDB.
8. **Comillas en SSH anidado:** para evitar fallos de quoting con `sudo bash -lc` e `ip netns exec`, se trabajó con scripts temporales copiados por `scp` y validados con `bash -n`.
9. **Publicación externa real:** el Floating IP `192.168.122.137` era accesible desde el controller, pero no directamente desde la red de gestión. Se publicó el sitio por DNAT en `203.0.113.239:8080` hacia `192.168.122.137:80`.

---

## 7) Configurar MariaDB (VM DB)

### Nodo: `[DB-VM: wp-db-01]`

```bash
ssh -i /root/.ssh/wp-key ubuntu@"$DB_IP"
```

> **Importante:** montar volumen primero, luego instalar MariaDB.

```bash
sudo apt update
sudo apt install -y parted
lsblk

# si el volumen es /dev/vdb
sudo parted /dev/vdb --script mklabel gpt mkpart primary ext4 0% 100%
sudo mkfs.ext4 /dev/vdb1
sudo mkdir -p /var/lib/mysql
echo '/dev/vdb1 /var/lib/mysql ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
sudo mount -a
```

```bash
sudo apt install -y mariadb-server
sudo systemctl enable --now mariadb
sudo chown -R mysql:mysql /var/lib/mysql
```

Permitir conexiones internas y crear DB:

```bash
sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb
sudo ss -lntp | grep 3306
```

```bash
sudo mysql <<SQL
CREATE DATABASE ${WP_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${WP_DB_USER}'@'${WEB_IP}' IDENTIFIED BY '${WP_DB_PASS}';
GRANT ALL PRIVILEGES ON ${WP_DB_NAME}.* TO '${WP_DB_USER}'@'${WEB_IP}';
FLUSH PRIVILEGES;
SQL
```

---

## 8) Configurar WordPress (VM WEB)

### Nodo: `[WEB-VM: wp-web-01]`

```bash
ssh -i /root/.ssh/wp-key ubuntu@"$FIP_WEB"
```

```bash
sudo apt update
sudo apt install -y nginx php-fpm php-mysql php-curl php-gd php-xml php-mbstring php-zip php-intl unzip rsync curl default-mysql-client
sudo systemctl enable --now nginx
```

Validar conectividad web->db:

```bash
mysql -h "$DB_IP" -u "$WP_DB_USER" -p"$WP_DB_PASS" -e "SHOW DATABASES;"
```

```bash
cd /tmp
curl -LO https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
sudo mkdir -p /var/www/wordpress
sudo rsync -av wordpress/ /var/www/wordpress/
sudo chown -R www-data:www-data /var/www/wordpress
sudo find /var/www/wordpress -type d -exec chmod 755 {} \;
sudo find /var/www/wordpress -type f -exec chmod 644 {} \;
```

```bash
cd /var/www/wordpress
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/${WP_DB_NAME}/" wp-config.php
sed -i "s/username_here/${WP_DB_USER}/" wp-config.php
sed -i "s/password_here/${WP_DB_PASS}/" wp-config.php
sed -i "s/localhost/${DB_IP}/" wp-config.php
```

Hardening mínimo:

```bash
sudo tee -a /var/www/wordpress/wp-config.php >/dev/null <<'PHP'
define('DISALLOW_FILE_EDIT', true);
define('WP_AUTO_UPDATE_CORE', 'minor');
PHP
```

Configurar Nginx:

```bash
PHP_SOCK=$(find /run/php -name "php*-fpm.sock" | head -n1)

sudo tee /etc/nginx/sites-available/wordpress.conf >/dev/null <<NGINX
server {
    listen 80;
    server_name _;
    root /var/www/wordpress;
    index index.php index.html;

    access_log /var/log/nginx/wordpress_access.log;
    error_log  /var/log/nginx/wordpress_error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCK};
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-enabled/wordpress.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

---

## 9) Instalación inicial desde navegador externo

### Nodo: `[CLIENTE EXTERNO]`

Abrir:

- `http://<FIP_WEB>/`

Completar asistente:

- Título del sitio
- Usuario admin: `uceda`
- Password admin: `aslKDIUR24`
- Email admin: `admin@example.com`

En esta ejecución se completó automáticamente con WP-CLI:

```bash
wp core install \
  --path=/var/www/wordpress \
  --url="http://203.0.113.239:8080" \
  --title="WordPress OpenStack" \
  --admin_user="uceda" \
  --admin_password="aslKDIUR24" \
  --admin_email="admin@example.com" \
  --skip-email
```

---

## 10) Verificación final

### Nodo: `[CONTROLLER]`

```bash
openstack server list --name wp-
openstack floating ip list
```

### Nodo: `[WEB-VM]`

```bash
curl -I http://127.0.0.1
sudo tail -n 50 /var/log/nginx/wordpress_error.log
```

### Nodo: `[DB-VM]`

```bash
sudo ss -lntp | grep 3306
sudo journalctl -u mariadb --no-pager | tail -n 50
```

---

## 11) Credenciales y bases (en este mismo archivo)

Credenciales operativas para acceso a nodos:

- **Usuario:** `uceda`
- **Contraseña:** `aslKDIUR24`

Uso en comandos (opcional con `sshpass`):

```bash
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER"@203.0.113.239
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER"@"$FIP_WEB"
```

Registro de base de datos WordPress:

- DB Name: `wordpress`
- DB User: `wp_user`
- DB Host: `$DB_IP`
- DB Port: `3306`
- DB Password: valor de `WP_DB_PASS`

Registro de administración WordPress:

- Admin User: `uceda`
- Admin Password: `aslKDIUR24`
- Admin Email: `admin@example.com`

---

## 12) Backups recomendados

### Nodo: `[DB-VM]`

```bash
mkdir -p /var/backups/mariadb
mysqldump -u root -p wordpress > /var/backups/mariadb/wordpress-$(date +%F).sql
```

### Nodo: `[CONTROLLER]`

```bash
openstack volume snapshot create --volume wp-db-data wp-db-data-snap-$(date +%F)
openstack volume snapshot list
```

### Nodo: `[STORAGE1]` (verificar objetos/snapshots en Ceph)

```bash
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER"@203.0.113.244 \
"echo $SSH_PASS | sudo -S rbd ls -l volumes"
```

### Nodo: `[WEB-VM]`

```bash
sudo tar czf /var/backups/wordpress-files-$(date +%F).tar.gz /var/www/wordpress
```

---

## 13) Checklist de ejecución (marcar durante despliegue)

Estado sugerido:

- `[x]` Pre-chequeo OpenStack OK (`token`, `hypervisor`, `network`, `volume service`)
- `[x]` SG web/db creados y reglas corregidas para SSH interno `10.10.10.0/24`
- `[x]` Keypair `wp-key` disponible
- `[x]` Imagen `ubuntu-22.04` importada en Glance/RBD
- `[x]` Flavor `wp.small` creado y validado
- `[x]` Volumen `wp-db-data` creado con tipo `ceph`
- `[x]` VM `wp-db-01` en `ACTIVE` (`10.10.10.152`)
- `[x]` VM `wp-web-01` en `ACTIVE` (`10.10.10.76`, FIP `192.168.122.137`)
- `[x]` Volumen adjunto a `wp-db-01` como `/dev/vdb`
- `[x]` Objeto RBD visible en `storage1` (`volume-16dfbd99-dcb1-47a1-9bbe-ae063541fd35`)
- `[x]` DNS/salida a Internet desde VMs corregida para `apt` usando gateway `192.168.122.1` en `br-provider`
- `[x]` MariaDB instalado y activo
- `[x]` `/var/lib/mysql` montado sobre volumen Ceph `/dev/vdb1`
- `[x]` Base `wordpress` y usuario `wp_user@10.10.10.76` creados
- `[x]` Conectividad `wp-web-01 -> wp-db-01` validada
- `[x]` Nginx y PHP-FPM activos en `wp-web-01`
- `[x]` WordPress descargado y configurado en `/var/www/wordpress`
- `[x]` WordPress inicializado con usuario admin `uceda`
- `[x]` Floating IP asociada y WordPress visible desde controller en `http://192.168.122.137/`
- `[x]` WordPress visible desde red externa de gestión en `http://203.0.113.239:8080/`
- `[ ]` Snapshot de volumen y backup SQL ejecutados

---

## 14) HTTPS recomendado (despues de validar HTTP)

### Nodo: `[WEB-VM]`

Requisitos:

- Un dominio publico apuntando al `FIP_WEB`
- Puerto `443` permitido en `sg-wordpress-web`

Instalacion y certificado:

```bash
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d TU_DOMINIO -m "$WP_ADMIN_EMAIL" --agree-tos --redirect --non-interactive
```

Validacion:

```bash
curl -I https://TU_DOMINIO
sudo systemctl status certbot.timer --no-pager
```

Si el sitio ya esta en HTTPS, activar en `wp-config.php`:

```php
define('FORCE_SSL_ADMIN', true);
```

---

## 15) Hardening minimo adicional

### Nodo: `[WEB-VM]`

```bash
sudo apt install -y ufw
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose
```

Permisos recomendados WordPress:

```bash
sudo chown -R www-data:www-data /var/www/wordpress
sudo find /var/www/wordpress -type d -exec chmod 755 {} \;
sudo find /var/www/wordpress -type f -exec chmod 644 {} \;
```

### Nodo: `[DB-VM]`

```bash
sudo mysql -e "SHOW VARIABLES LIKE 'bind_address';"
sudo mysql -e "SELECT user,host FROM mysql.user;"
```

Objetivo: confirmar que `wp_user` solo existe con host de `WEB_IP`.

---

## 16) Troubleshooting rapido (OpenStack + Ceph + WordPress)

1. Sintoma: la web no abre desde Internet.
Acciones:

```bash
openstack floating ip list
openstack server show "$WEB_VM" -c addresses
openstack security group rule list sg-wordpress-web
ssh -i /root/.ssh/wp-key ubuntu@"$FIP_WEB" "sudo ss -lntp | grep -E '(:80|:443)'"
```

2. Sintoma: WordPress no conecta a MariaDB.
Acciones:

```bash
ssh -i /root/.ssh/wp-key ubuntu@"$DB_IP" "sudo ss -lntp | grep 3306"
ssh -i /root/.ssh/wp-key ubuntu@"$WEB_IP" "mysql -h '$DB_IP' -u '$WP_DB_USER' -p'$WP_DB_PASS' -e 'SHOW DATABASES;'"
ssh -i /root/.ssh/wp-key ubuntu@"$DB_IP" "sudo journalctl -u mariadb --no-pager | tail -n 80"
```

3. Sintoma: volumen no aparece en DB VM.
Acciones:

```bash
openstack server volume list "$DB_VM"
openstack volume show "$DB_VOL"
ssh -i /root/.ssh/wp-key ubuntu@"$DB_IP" "lsblk"
```

4. Sintoma: dudas de backend Ceph.
Acciones:

```bash
openstack volume show "$DB_VOL" -f yaml | grep -E "type:|os-vol-host-attr:host"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER"@203.0.113.244 "echo $SSH_PASS | sudo -S rbd ls -l volumes"
```

---

## 17) Limpieza / rollback del despliegue

### Nodo: `[CONTROLLER]`

Eliminar servicios WordPress si necesitas rehacer desde cero:

```bash
openstack server delete "$WEB_VM" "$DB_VM"
sleep 10
openstack volume delete "$DB_VOL"

# liberar floating IP asociada (si aplica)
openstack floating ip list
# openstack floating ip delete <FIP_WEB>

# opcional: limpiar SG y keypair
# openstack security group delete sg-wordpress-web sg-wordpress-db
# openstack keypair delete "$KEY_NAME"
```

Validar limpieza:

```bash
openstack server list --name wp-
openstack volume list | grep wp-db-data || true
openstack floating ip list
```

---