# openstack-virtual-tryon

Plataforma SaaS de **Virtual Try-On** sobre **OpenStack (Kolla-Ansible) + Kubernetes + FASHN-VTON 1.5**, sobre 3 nodos físicos Ubuntu 24.04 en red local.

## ✅ Estado actual

| Componente | Estado |
|---|---|
| **OpenStack (Kolla-Ansible 21.3.0)** | ✅ Reconstruido — 28 contenedores, 3 hypervisors `up` |
| **Cinder (bloque, LVM)** | ✅ Operativo — `cinder-volume` up, volúmenes creables |
| **GPU NVIDIA RTX 3060 (12 GB)** | ✅ Operativa en `server` |
| **Kubernetes (k3s)** | ⚠️ Borrado (clúster preexistente con la app VTON; no es parte de la nube OpenStack) |

## 🔑 Acceso a interfaces de administración

| Interfaz | URL | Acceso |
|---|---|---|
| **OpenStack Horizon** | `http://icc115.openstack.com/` (o `http://192.168.0.200/`) | usuario `admin` · password en `/etc/kolla/passwords.yml` (o `source /etc/kolla/admin-openrc.sh`) |
| **Kubernetes Dashboard** | `https://icc115.kubernetes.com:30443` (o `https://192.168.0.10:30443`) | token: `kubectl -n kubernetes-dashboard create token admin-user` |
| **kubectl** | CLI | configurado en `~/.kube/config` |

> 🌐 **DNS local** (dnsmasq en `anfitrion`, script `15-dns.sh`): `icc115.openstack.com → 192.168.0.200` y `icc115.kubernetes.com → 192.168.0.10`.

---

## 📚 Documentación

- **Arquitectura:** [`ARQUITECTURA_SAAS_IA_OPENSTACK_KOLLA_K8S_V4.md`](ARQUITECTURA_SAAS_IA_OPENSTACK_KOLLA_K8S_V4.md)
- **Diagramas:** [`diagrams/`](diagrams/)
- **Base de conocimiento (implementaciones previas):** [`documentacion/`](documentacion/)
  - Punto de entrada: [`documentacion/README.md`](documentacion/README.md)
  - Verificación de factibilidad: [`documentacion/VERIFICACION-PLAN-Y-FACTIBILIDAD.md`](documentacion/VERIFICACION-PLAN-Y-FACTIBILIDAD.md)
  - Inventario de equipos: [`documentacion/INVENTARIO-EQUIPOS.md`](documentacion/INVENTARIO-EQUIPOS.md)

## 🚀 Instalación automatizada (`implementacion/`)

Toda la instalación está automatizada en **scripts secuenciales e idempotentes** (Ubuntu 24.04), re-desplegables en otras redes editando un solo archivo:

- **Guía y secuencia completa:** [`implementacion/README.md`](implementacion/README.md)
- **Scripts (00–11):** [`implementacion/scripts/`](implementacion/scripts/) — índice en [`implementacion/scripts/README.md`](implementacion/scripts/README.md)
- **Inventario de la red (fuente de verdad):** [`implementacion/inventory/nodes.env`](implementacion/inventory/nodes.env)
- **Detalle por paso:** [`implementacion/docs/00-orden-de-instalacion.md`](implementacion/docs/00-orden-de-instalacion.md)
- **Errores y percances:** [`implementacion/docs/ERRORES-Y-PERCANCES.md`](implementacion/docs/ERRORES-Y-PERCANCES.md)
- **Reconstrucción desde cero (borrado + rebuild):** [`implementacion/docs/REBUILD-DESDE-CERO.md`](implementacion/docs/REBUILD-DESDE-CERO.md)

```bash
# Desplegar todo desde cero en otra red:
cd implementacion
vim inventory/nodes.env          # 1) editar IPs/nombres/roles
bash scripts/run-all.sh          # 2) instalar dependencias (00-09)
bash scripts/10-verificar.sh     # 3) verificar
bash scripts/11-kolla-deploy.sh  # 4) desplegar OpenStack (deploy + post-deploy)
```

