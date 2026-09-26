# Plan de integracion operativo (2026-04-30)

## Objetivo
Construir una ruta de integracion completa y repetible del laboratorio, iniciando por pruebas aisladas de cada componente y avanzando por fases con criterios de aceptacion.

## Resumen de verificacion realizada
Se ejecutaron pruebas aisladas por componente y validaciones de conectividad/servicios.

### 1) Pruebas de scripts por separado
- Validacion de sintaxis Bash de todos los scripts: OK.
- Ejecucion de modo `plan` en todas las fases (01, 02, 03, 04, 05, 06, 99): OK.
- Generacion de archivos de comandos en fases de aprovisionamiento: OK.

### 2) Estado funcional actual por componente
- Infra VMs y red libvirt: OK (VMs activas, red `net-192-168-3` activa/autostart).
- DNS CoreDNS (`dns-1`): OK (servicio `coredns` activo y resolviendo `app1.mimas.net`/`lb1.mimas.net`).
- Balanceadores Nginx (`lb1`, `lb2`): OK (`nginx` activo y `nginx -t` exitoso).
- Redis (`redis-1`): OK (`redis-server` activo, `PING -> PONG`).
- MariaDB Galera (`mariadb-1/2/3`): OK (`wsrep_cluster_size=3`, `Primary`, `wsrep_ready=ON`).
- Backends Django (`app1/app2/app3`): OK (`django-gunicorn` activo en `:8000` en los 3 nodos).
- Integracion Nginx -> Django: OK (LB responde HTTP 200 en `lb1` y `lb2`).
- MaxScale (`maxscale-1`): OK (`24.02.9` instalado, servicio activo, monitor Galera en `Running`).

## Verificacion de documentacion
Documentacion encontrada por fase:
- `00-estructura-conexiones.md`
- `00-plan-general.md`
- `01-bases/guia-bases.md`
- `02-redes/guia-redes.md`
- `03-dns-coredns/guia-dns-coredns.md`
- `04-balanceadores-nginx/guia-balanceadores-nginx.md`
- `05-backends-django/guia-backends-django.md`
- `06-datos/guia-datos.md`
- `06-datos/guia-redis.md`
- `06-datos/guia-mysql-galera-maxscale.md`
- `06-datos/redis-datos-creacion.md`
- `99-validacion/guia-validacion.md`

Cobertura documental: COMPLETA por fases.
Brecha principal detectada entre documentacion y estado real: historicamente estaba en DNS/MaxScale; actualmente ambos servicios ya quedaron operativos.

## Plan de integracion por fases

## Fase 0 - Baseline (hecha)
Criterio de aceptacion:
- Scripts validos y en modo `plan` sin fallas.
- VMs y red base visibles en `99-validacion.sh`.

Evidencia:
- `bash 99-validacion/99-validacion.sh`.

## Fase 1 - Componentes aislados (hecha parcialmente)
Objetivo: cada componente funcional por separado.

Checklist:
1. Red e infraestructura base: OK.
2. DNS CoreDNS: OK.
3. Nginx en `lb1/lb2`: OK.
4. Backends Django (`app1/app2/app3`): OK.
5. Redis: OK.
6. Galera: OK.
7. MaxScale: OK (proxy SQL activo sobre Galera, estado de servidores `Synced, Running`).

Acciones para cerrar Fase 1 al 100%:
1. Completada: instalacion de MaxScale desde repo oficial MariaDB y validacion con `maxctrl list servers`.

## Fase 2 - Integracion por capas (siguiente paso)
Orden recomendado:
1. DNS -> validar resolucion interna.
2. Backends Django -> validar endpoint de salud en cada app.
3. Nginx -> validar upstream a apps por IP y por nombre.
4. Redis -> validar conexion desde app Django.
5. Galera -> validar lectura/escritura desde app Django.
6. MaxScale (si aplica) -> cambiar endpoint SQL de app a proxy y revalidar.

Criterios de aceptacion minimos:
- `lb1` y `lb2` responden HTTP 200/30x y proxyean a apps.
- App Django lee/escribe cache en Redis.
- App Django lee/escribe DB en Galera (o MaxScale si disponible).
- Resolucion DNS interna funcional para nombres del laboratorio.

## Fase 3 - Validacion end-to-end
Pruebas de humo:
1. Cliente -> `lb1/lb2` (HTTP).
2. Nginx -> `app1/app2/app3` (upstream).
3. App -> Redis (cache).
4. App -> DB (Galera/MaxScale).
5. DNS interno resolviendo nombres de nodos.

Comando base:
- `cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/99-validacion && bash 99-validacion.sh`

## Plan de ejecucion inmediato
1. Completar CoreDNS en `dns-1` y validar puerto 53 + consultas DNS.
2. Decidir ruta de MaxScale:
   - Ruta A: instalar desde repositorio alterno compatible.
   - Ruta B: declarar pendiente y operar con Galera directo.
3. Integrar Django + Nginx + Redis + Galera con pruebas de smoke.
4. Ejecutar validacion final y registrar resultados.

## Riesgos y mitigaciones
- MaxScale no disponible en repositorios del entorno.
  - Mitigacion: mantener Galera activo como backend directo y dejar MaxScale como mejora futura.
- DNS interno no activado aun.
  - Mitigacion: completar instalacion CoreDNS antes de pruebas de integracion por nombre.

## Registro sugerido de resultados
Crear una bitacora por corrida con:
- Fecha/hora.
- Scripts ejecutados (plan/apply).
- Resultado por componente (OK/PENDIENTE/ERROR).
- Evidencia clave (salidas cortas de estado).
