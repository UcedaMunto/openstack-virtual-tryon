# Plan de desarrollo - guia de implementacion TI

Este plan transforma el diseno de la imagen en una implementacion reproducible usando KVM/libvirt.

Referencia maestra de topologia y conexiones:
- `00-estructura-conexiones.md`

Estado operativo validado e integracion paso a paso:
- `00-plan-integracion-operativo.md`

## Alcance

Se crean guias separadas y scripts por seccion:

1. Bases
2. Redes
3. DNS con CoreDNS
4. Balanceadores con Nginx
5. Backends Django
6. Datos (MariaDB Galera + MaxScale + Redis + nodo CephFS)
7. Validacion final

## Estrategia de trabajo

1. Ejecutar cada seccion en modo `plan` para generar comandos reproducibles.
2. Revisar y ajustar variables (IPs, passwords, MAC, redes).
3. Ejecutar cada seccion en modo `apply`.
4. Si un comando falla, corregir primero el `.md` y luego el `.sh` de la seccion.
5. Repetir hasta dejar las guias limpias para despliegue desde cero.

## Hallazgos en primera ejecucion

1. En este entorno, los archivos generados por `create-kvm-vm.sh --comandos` pueden incluir secuencias `\\n` en la linea `virt-install`, causando error `unrecognized arguments: n` al ejecutarlos directamente.
2. Mitigacion aplicada: cada script de seccion mantiene `plan` para trazabilidad, pero en `apply` ejecuta creacion directa con `create-kvm-vm.sh`.
3. En `02-redes.sh apply`, se agrego verificacion de red activa para evitar error cuando la red ya esta iniciada.

## Convenciones

- Carpeta de trabajo: `/home/uceda/Documents/cluster-ceph/proyecto-infraestructura`
- Automatizacion KVM: `/home/uceda/Documents/cluster-ceph/kvm-generic`
- Modo `plan`: solo genera archivo de comandos
- Modo `apply`: ejecuta comandos generados
- Las IP de la imagen son de referencia y pueden cambiarse via variables
- Para integrar toda la documentacion de datos, tomar Redis desde: `06-datos/redis-datos-creacion.md`

## Orden recomendado de ejecucion

1. `02-redes/02-redes.sh`
2. `01-bases/01-bases.sh`
3. `03-dns-coredns/03-dns-coredns.sh`
4. `04-balanceadores-nginx/04-balanceadores-nginx.sh` (crear VMs lb1/lb2)
5. `05-backends-django/05-backends-django.sh` (crear VMs app1/app2/app3)
6. `05-backends-django/05-configurar-django.sh` (instalar y configurar Django/Gunicorn)
7. `04-balanceadores-nginx/04-configurar-nginx.sh` (instalar y configurar Nginx)
8. `06-datos/06-datos.sh`
9. `06-datos/06-redis.sh` (instalar y configurar Redis en redis-1)
10. `06-datos/06-mysql-galera-maxscale.sh` (configurar Galera + MaxScale)
11. `99-validacion/99-validacion.sh`

## Comando maestro sugerido

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura

bash 02-redes/02-redes.sh plan
bash 01-bases/01-bases.sh plan
bash 03-dns-coredns/03-dns-coredns.sh plan
bash 04-balanceadores-nginx/04-balanceadores-nginx.sh plan
bash 05-backends-django/05-backends-django.sh plan
bash 04-balanceadores-nginx/04-configurar-nginx.sh plan
bash 06-datos/06-datos.sh plan
bash 06-datos/06-redis.sh plan
bash 06-datos/06-mysql-galera-maxscale.sh plan
bash 99-validacion/99-validacion.sh
```

Cuando la pasada `plan` este validada, repetir con `apply` seccion por seccion.
