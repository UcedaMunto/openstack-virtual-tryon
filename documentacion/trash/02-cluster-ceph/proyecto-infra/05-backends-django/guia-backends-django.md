# Guia - Backends Django

Objetivo: crear 3 nodos Django (`app1`, `app2`, `app3`).

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

## Secuencia VM

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/05-backends-django
bash 05-backends-django.sh plan
bash 05-backends-django.sh apply
```

Nota operativa: `plan` genera comandos; `apply` ejecuta creacion directa de VMs para evitar errores de sintaxis en ciertos archivos generados por `--comandos`.

## Secuencia de instalacion Django (en cada backend)

Automatizacion recomendada:

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/05-backends-django
bash 05-configurar-django.sh plan
bash 05-configurar-django.sh apply
bash 05-configurar-django.sh check
```

Este flujo deja en cada nodo:
- Python virtualenv en `/opt/apps/venv`
- Proyecto Django base en `/opt/apps/mi-proyecto`
- Servicio `django-gunicorn` en puerto `8000`

## Prueba cruzada Django -> Galera (comando validado)

Para evitar errores de escape en SQL al usar `manage.py shell -c` en una sola linea, usar un script Python remoto:

```bash
SSH_KEY=/home/uceda/Documents/cluster-ceph/kvm-generic/ssh-keys/id_rsa

cat >/tmp/lab_galera_probe.py <<'PY'
#!/usr/bin/env python3
import os, sys, socket
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
sys.path.insert(0, "/opt/apps/mi-proyecto")
import django
django.setup()
from django.db import connection

host = socket.gethostname()
c = connection.cursor()
c.execute("""
CREATE TABLE IF NOT EXISTS integration_probe (
	id INT AUTO_INCREMENT PRIMARY KEY,
	source VARCHAR(64),
	note VARCHAR(255),
	created TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
""")
c.execute("INSERT INTO integration_probe (source, note) VALUES (%s, %s)", [host, "ok-galera"])
c.execute("SELECT id, source, note, created FROM integration_probe ORDER BY id")
for row in c.fetchall():
		print(row)
PY

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" /tmp/lab_galera_probe.py admin@192.168.3.52:/tmp/
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" /tmp/lab_galera_probe.py admin@192.168.3.53:/tmp/

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" admin@192.168.3.52 \
	"sudo -u django bash -lc 'source /opt/apps/venv/bin/activate && cd /opt/apps/mi-proyecto && python /tmp/lab_galera_probe.py'"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" admin@192.168.3.53 \
	"sudo -u django bash -lc 'source /opt/apps/venv/bin/activate && cd /opt/apps/mi-proyecto && python /tmp/lab_galera_probe.py'"
```

Resultado esperado: app2 debe ver registros insertados por app1 (base compartida Galera).

Secuencia manual (alternativa):

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip git build-essential libmariadb-dev pkg-config

sudo mkdir -p /opt/apps
sudo useradd -m -s /bin/bash django || true
sudo chown -R django:django /opt/apps

sudo -u django bash -lc '
cd /opt/apps
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip wheel
pip install django gunicorn mysqlclient redis
'
```

Servicio gunicorn (adaptar ruta de proyecto):

```bash
cat <<'EOF' | sudo tee /etc/systemd/system/django-gunicorn.service
[Unit]
Description=Gunicorn Django
After=network.target

[Service]
User=django
Group=django
WorkingDirectory=/opt/apps/mi-proyecto
Environment="PATH=/opt/apps/venv/bin"
ExecStart=/opt/apps/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 config.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now django-gunicorn
sudo systemctl status django-gunicorn --no-pager
```
