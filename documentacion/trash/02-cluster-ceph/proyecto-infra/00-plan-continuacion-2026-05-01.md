# Plan de continuacion - 2026-05-01

## Contexto actual confirmado
Estado de plataforma despues de las ultimas ejecuciones:

- Infra KVM/libvirt: OK.
- DNS interno (CoreDNS): OK.
- Balanceadores Nginx (lb1/lb2): OK.
- Backends Django (app1/app2/app3): OK con gunicorn en puerto 8000.
- Redis (redis-1): OK. **[A1 COMPLETADO]** claves lab:redis:app1/2/3 confirmadas.
- MariaDB Galera (mariadb-1/2/3): OK. **[A2 COMPLETADO]** escritura app1 + lectura cruzada app2 confirmada via script /tmp/lab_galera_probe.py.
- MaxScale (maxscale-1): **✅ COMPLETADO** — MaxScale 24.02.9 instalado, activo, 3 nodos Galera visibles (Master+2xSlave, Synced, Running).

## Objetivo de esta etapa
Cerrar la integracion funcional completa entre capas de aplicacion y datos, y definir el estado final de MaxScale para produccion del laboratorio.

## Alcance de trabajo inmediato

1. Validar que Django use Redis como cache real.
2. Validar que Django use Galera para lectura/escritura real.
3. Resolver decision de arquitectura para MaxScale.
4. Ejecutar validacion final consolidada y registrar evidencia.

## Fase A - Integracion App -> Datos

### A1. Django + Redis ✅ COMPLETADO
Resultado esperado:
- Las apps leen/escriben en Redis sin errores.

Pasos:
1. Revisar configuracion Django en app1/app2/app3 (`settings.py`).
2. Definir backend de cache Redis con endpoint `192.168.3.56:6379`.
3. Ejecutar prueba de cache desde shell Django o endpoint de prueba.
4. Validar en redis-1:
   - `redis-cli INFO clients`
   - `redis-cli MONITOR` (prueba breve)

Criterio de aceptacion:
- Evidencia de operaciones de cache desde app hacia redis-1.

### A2. Django + Galera ✅ COMPLETADO
Resultado esperado:
- Las apps pueden ejecutar lectura/escritura SQL contra cluster Galera.

Evidencia confirmada (2026-05-01):
- Migraciones Django aplicadas (13 OK contra lab_django en Galera).
- Script `/tmp/lab_galera_probe.py` ejecutado en app1: INSERT id=1 source=app1 ok-galera.
- Script ejecutado en app2: leyo registro de app1 y añadio id=4 source=app2. Replicacion Galera confirmada.

Pasos:
1. Definir `DATABASES` en Django apuntando a Galera (inicio con mariadb-1).
2. Crear usuario y base de datos de aplicacion en Galera.
3. Ejecutar `python manage.py migrate` en cada backend (o pipeline central).
4. Probar endpoint o shell ORM con insercion y lectura.
5. Verificar consistencia en cluster con consultas desde nodos DB.

Criterio de aceptacion:
- Migraciones aplicadas y transacciones correctas sin errores de conectividad.

## Fase B - Decision MaxScale

### Opcion 1 (preferida): habilitar MaxScale ✅ COMPLETADO (2026-05-01)
- MaxScale 24.02.9 instalado via `mariadb_repo_setup` en maxscale-1 (Ubuntu 22.04).
- Usuario `maxscale` creado en Galera con grants para IP y hostname.
- Config en `/etc/maxscale.cnf` con monitor `galeramon` y servicio `readwritesplit`.
- `maxctrl list servers`: mariadb-1 Master+Synced, mariadb-2/3 Slave+Synced.
- Servicio `maxscale.service` enabled y active.

Pasos:
1. Intentar instalacion por repositorio alterno compatible con Ubuntu 22.04.
2. Configurar monitor y servicio readwritesplit.
3. Validar estado de servidores backend en MaxScale.
4. Cambiar Django temporalmente a MaxScale y revalidar pruebas A2.

Criterio de aceptacion:
- Consultas de app fluyen por MaxScale sin degradar funcionalidad.

### Opcion 2 (fallback oficial): operar sin MaxScale
Resultado esperado:
- Cierre de etapa sin bloquear despliegue.

Pasos:
1. Mantener Django contra Galera directo.
2. Documentar explicitamente limitacion del entorno.
3. Dejar backlog de MaxScale para iteracion futura.

Criterio de aceptacion:
- Documentacion alineada y laboratorio funcional sin MaxScale.

## Fase C - Validacion final y cierre

Pruebas de humo minimas:
1. DNS resuelve nombres internos (`app1.mimas.net`, `lb1.mimas.net`).
2. LB responde HTTP 200 en `lb1` y `lb2`.
3. App responde 200 directo en `app1/app2/app3:8000`.
4. Redis responde PONG y evidencia trafico de cache.
5. Galera mantiene `wsrep_cluster_size=3`, `Primary`, `wsrep_ready=ON`.
6. MaxScale: estado final definido (operativo o pendiente formal).

Comandos base de cierre:

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura
bash 99-validacion/99-validacion.sh
```

## Entregables de esta continuacion

1. Evidencias de integracion App -> Redis.
2. Evidencias de integracion App -> Galera (y/o MaxScale).
3. Documento final de estado con decision MaxScale.
4. Lista de riesgos residuales y acciones pendientes.

## Riesgos abiertos

- Disponibilidad de paquete MaxScale en repositorios del entorno.
- Divergencia de configuracion Django entre nodos si se configura manualmente.
- Cambios de IP/hostnames fuera de estandar documentado.

## Orden de ejecucion recomendado (continuacion)

1. Configurar y probar Redis en Django.
2. Configurar y probar Galera en Django.
3. Intentar MaxScale (si falla, activar fallback formal).
4. Ejecutar validacion final y actualizar documentacion.
