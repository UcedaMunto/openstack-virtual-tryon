# Guia - Balanceadores con Nginx

Objetivo: crear 2 VMs de balanceo (`lb1`, `lb2`) y configurar Nginx upstream a backends Django.

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

## Plan de trabajo

1. Crear VMs de balanceo (`lb1`, `lb2`).
2. Verificar acceso SSH y conectividad interna desde ambos balanceadores.
3. Configurar Nginx de forma automatizada en los dos nodos con `plan/apply`.
4. Validar respuestas HTTP en `lb1`/`lb2` y revisar alcance a `app1`/`app2`/`app3`.
5. Repetir validacion despues de desplegar Django para confirmar balanceo real de trafico.

## Secuencia VM

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/04-balanceadores-nginx
bash 04-balanceadores-nginx.sh plan
bash 04-balanceadores-nginx.sh apply
```

Nota operativa: `plan` genera comandos; `apply` ejecuta creacion directa de VMs para evitar errores de sintaxis en ciertos archivos generados por `--comandos`.

## Secuencia Nginx automatizada

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/04-balanceadores-nginx
bash 04-configurar-nginx.sh plan
bash 04-configurar-nginx.sh apply
```

Variables utiles (opcionales):

```bash
SSH_USER=admin \
SSH_KEY=/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa \
LB1_IP=192.168.3.50 \
LB2_IP=192.168.3.51 \
APP1_IP=192.168.3.52 \
APP2_IP=192.168.3.53 \
APP3_IP=192.168.3.54 \
APP_PORT=8000 \
SERVER_NAME='mimas.net *.mimas.net lb1.mimas.net lb2.mimas.net' \
bash 04-configurar-nginx.sh apply
```

## Secuencia Nginx manual (referencia)

```bash
sudo apt update
sudo apt install -y nginx

cat <<'EOF' | sudo tee /etc/nginx/sites-available/django-lb.conf
upstream django_cluster {
    server 192.168.3.52:8000 max_fails=3 fail_timeout=10s;
    server 192.168.3.53:8000 max_fails=3 fail_timeout=10s;
    server 192.168.3.54:8000 max_fails=3 fail_timeout=10s;
}

server {
    listen 80;
    server_name mimas.net *.mimas.net;

    location / {
        proxy_pass http://django_cluster;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/django-lb.conf /etc/nginx/sites-enabled/django-lb.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable --now nginx
```

## Validar

```bash
curl -I http://192.168.3.50
curl -I http://192.168.3.51
```

Si Django aun no esta desplegado en `app1`/`app2`/`app3`, Nginx igual debe quedar `active`, pero puedes ver respuestas `502` temporalmente.
