# ✅ Verificación de Factibilidad y Revisión del Plan

> **Une:** `ARQUITECTURA_SAAS_IA_OPENSTACK_KOLLA_K8S_V4.md` ↔ `documentacion/` (base de conocimiento consolidada).
> **Objetivo:** verificar que cada etapa del plan (§92 de V4) es **factible** con lo ya demostrado en los laboratorios, y revisar que el **orden** y la **lógica** de los pasos son correctos.
> **Fecha:** 2026-09-24

---

## 1. Veredicto general

| Juicio | Resultado |
|---|---|
| **Factibilidad global** | ✅ **Factible.** Los 7 laboratorios demostraron, por separado, **todas** las piezas que V4 requiere. |
| **Coherencia del orden** | ✅ **Correcta.** Respeta la cadena de dependencias hardware → Ansible → Kolla → VMs → Kubernetes → servicios → app. |
| **Hallazgos bloqueantes** | 🔴 **Ninguno.** |
| **Hallazgos a cerrar** | ⚠️ 8 puntos menores (ver §4) + 1 pieza de mayor riesgo (GPU vía Nova, ver §3·Etapa 2 y §5). |

La arquitectura es **internamente consistente** y su §97 ("Revisión de lógica y concordancia") ya anticipa correctamente la mayoría de los riesgos.

---

## 2. Referencias V4 → documentación

| Sección V4 | Tema | Referencia en `documentacion/` |
|---|---|---|
| §10-11, §57.2 | Kolla-Ansible (inventario `multinode`) | `01-InstalacionOpenstack/openstack-ansible/ansible/inventory/multinode` + `hosts-minimal-backup.ini` |
| §55-61 | Ansible (roles, playbooks, inventario, vault) | `07-documentacion-ansible/ansible/` (roles `linux-bridges`, `ovs-bridges`, `nova-compute`, `neutron-ovs-agent`) |
| §57.1, §58 | Inventario bare-metal + estructura | `07-documentacion-ansible/ansible/inventory/hosts.yml` + `group_vars/` |
| §67-68 | Red física / VLANs / bridges | `01-InstalacionOpenstack/openstack-ansible/networks/*.xml` + `05-redes-xml-kvm/` + `03-PRACTICA-KVM/` |
| §17, §59.7 | GPU passthrough / IOMMU | `01-InstalacionOpenstack/openstack-ansible/backups/libvirt-vms/*.xml` (patrón a nivel libvirt) |
| §69-70 | Almacenamiento / Ceph | `04-LXC-ceph/` (docker+kvm) + `02-cluster-ceph/` + `01-.../kubernetes/tmp/03-rook-cluster.yaml` |
| §13-16, Etapa 4 | Kubernetes (kubeadm+Calico+MetalLB+Rook) | `01-InstalacionOpenstack/openstack-ansible/kubernetes/scripts/` + `tmp/*.yaml` + `net/k8s-lab-network.xml` |
| §26, §36 | Cola RabbitMQ | `01-.../kubernetes/tmp/07-wordpress-cephfs.yaml` (patrón servicio+persistencia) + `02-cluster-ceph` (patrón broker) |
| §32 | Object Storage (MinIO/Swift/S3) | Swift: `trash/01-InstalacionOpenstack/documentacion/08-GUIA-SWIFT-NODOS-OBJECT.md` · S3/CephFS: `kubernetes/tmp/{03,04,05}.yaml` |
| §33-35, §85 | PostgreSQL / Redis HA | `02-cluster-ceph/proyecto-manual-infraestructura/` (Galera+MaxScale+Redis) |
| §50-52 | Observabilidad | `02-cluster-ceph/.../tools-sh/healthcheck-infra.sh` + `kubernetes/tmp/{10,11}.yaml` |
| §53-54 | Backups / DR | `02-cluster-ceph/.../configuraciones-backups.sh` |

> **Mapa completo + checklist accionable:** `README.md` (§3 y §4).

---

## 3. Factibilidad por etapa

| Etapa | Factibilidad | Evidencia / referencia | Nota |
|---|---|---|---|
| **0 · Direccionamiento** | ✅ | `.env` del proyecto + `networks/*.xml` | Trivial (papel). |
| **1 · Hardware/BIOS/red** | ✅ | `03-PRACTICA-KVM/` (bridges/VLAN), `05-redes-xml-kvm/` | GPU passthrough a nivel host demostrado (vfio/IOMMU). |
| **1.5 · Bootstrap Ansible** | ✅ | `07-documentacion-ansible/ansible/` | Roles `common`/`linux-bridges`/`ovs-bridges` reutilizables casi directos. |
| **2 · OpenStack Kolla-Ansible** | ✅ | `ansible/inventory/multinode` + `networks/*.xml` | ⚠️ **la parte más arriesgada: PCI passthrough *a través de Nova* no está demostrada** (los labs lo hicieron a nivel libvirt, no Nova). |
| **3 / 3.5 · VMs base + config** | ✅ | `cloud-init/*` + `scripts/gen-user-data.sh` + `kubernetes/scripts/create-k8s-lab-vms.sh` | Patrón exacto. |
| **4 · Kubernetes** | ✅ | `kubernetes/scripts/bootstrap-cluster.sh` + `deploy-manifests.sh` | Runtime containerd `SystemdCgroup=true`, Calico, MetalLB, Rook probados. GPU worker = adaptar runtime `nvidia`. |
| **5 · Servicios plataforma** | ✅ | `02-cluster-ceph` (DB/Redis) + `kubernetes/tmp/*` (storage) | PostgreSQL en VM `database-01` y Object Storage en `storage-01` son el patrón del lab cluster-ceph. |
| **6 · Worker FASHN-VTON** | ⚠️ | Patrón GPU worker + cola RabbitMQ; **FASHN-VTON en sí es trabajo nuevo** | Requiere benchmark (no hay lab previo del modelo). |
| **7 · App SaaS** | ⚠️ | Patrón de manifests numerados (`tmp/01..13`) | Auth/billing/metering son desarrollo nuevo; la infraestructura sí está probada. |
| **8 · Seguridad/obs/recup.** | ✅ | `tools-sh/healthcheck-infra.sh`, `configuraciones-backups.sh`, dashboards | |
| **9 · Capacidad comercial** | 🔴 | Sin lab previo | Depende del benchmark de la GPU elegida (decisión §91.3 aún abierta). |

**Conclusión de factibilidad:** las etapas de **infraestructura** (0–5, 8) están respaldadas por evidencia directa; las etapas de **producto** (6, 7, 9) dependen de trabajo nuevo de aplicación y del benchmark, no de la infraestructura.


---

## 4. Hallazgos de coherencia / lógica

Ordenados por impacto (ninguno bloqueante):

### ⚠️ H1 — RabbitMQ de la aplicación vs RabbitMQ de Kolla
Kolla-Ansible despliega su **propio** RabbitMQ/MariaDB/Memcached para los servicios internos de OpenStack (§10). La cola de la aplicación (§26, §36, §89) es **otro** broker. El plan debe evitar la tentación de reutilizar el broker interno de Kolla para los trabajos de Try-On.
**Recomendación:** desplegar RabbitMQ de aplicación como workload propio de Kubernetes (patrón `kubernetes/tmp/07`), separado del de Kolla.

### ⚠️ H2 — "Listo cuando" de la Etapa 2 es ambicioso
La Etapa 2 (§92) fija como criterio de cierre que OpenStack pueda "crear una VM con la GPU asignada". Eso mezcla el despliegue de Kolla con la validación del passthrough Nova→VM, que es justo la pieza más compleja.
**Recomendación:** cerrar la Etapa 2 con `openstack service list` + `openstack hypervisor list`; mover "VM con GPU" a la Etapa 3/6.

### ⚠️ H3 — `kolla-ansible pull` es opcional
El flujo §59.6/§92 incluye `pull`; `deploy` ya descarga las imágenes. No es incorrecto, pero añade tiempo.
**Recomendación:** mantener `pull` sólo si se quiere pre-descargar; si no, `bootstrap-servers → prechecks → deploy → post-deploy` es suficiente.

### ⚠️ H4 — Object Storage: MinIO vs Swift (decisión §91.6 abierta)
Los labs tienen **Swift** (OSA: `08-GUIA-SWIFT-NODOS-OBJECT.md`) y **CephFS/Rook**; **MinIO no aparece** en ningún lab.
**Recomendación:** si se elige Swift, reutilizar el patrón de nodos swift del lab OSA; si MinIO, es despliegue nuevo (sencillo, pero sin evidencia previa). Decidir antes de la Etapa 5.

### ⚠️ H5 — Versión de OpenStack sin fijar (§91.16)
**Recomendación:** fijar la versión de OpenStack/Kolla antes de la Etapa 2 (el inventario `multinode` del lab referencia grupos OVN/valkey/etc. de una versión reciente).

### ⚠️ H6 — "Metrics Server" (Etapa 4) vs Prometheus (§51)
La Etapa 4 lista "Metrics Server"; la observabilidad (§51) usa Prometheus. Son cosas distintas: Metrics Server habilita HPA; Prometheus es monitoreo.
**Recomendación:** instalar ambos si se quiere HPA; documentar el propósito de cada uno.

### ⚠️ H7 — DNS/NTP en `10.10.0.1` (gateway)
`.env` asume que el router/firewall local provee DNS y NTP. Es un **prerrequisito externo** no declarado.
**Recomendación:** confirmar que el gateway resuelve DNS/NTP, o levantar un servicio en NODE-01 (patrón `02-cluster-ceph` DNS).

### ⚠️ H8 — `monitoring-01` como VM vs monitoring en Kubernetes
La Etapa 3 crea la VM `monitoring-01`, pero §89 dibuja el monitoring dentro de Kubernetes.
**Recomendación:** aclarar si Prometheus/Grafana corren en la VM `monitoring-01` o como pods; no mezclar ambos sin definir responsabilidades.

---

## 5. Correcciones recomendadas al plan (resumen)

1. **Etapa 2:** cierre = servicios activos + 3 hypervisors; **mover la validación de GPU a Etapa 3/6.**
2. **Etapa 2:** documentar que el RabbitMQ de Kolla **no** es el de la aplicación.
3. **Etapa 4:** añadir runtime `nvidia` (containerd) y `nvidia-device-plugin` al worker GPU; decidir Metrics Server sí/no.
4. **Etapa 5:** decidir Object Storage (Swift vs MinIO) antes de empezar; PostgreSQL en `database-01` como VM (ya lo dice §33).
5. **Pre-Etapa 2:** fijar versión de OpenStack/Kolla y confirmar DNS/NTP del gateway.
6. **Etapa 9:** el benchmark de la GPU es prerrequisito para cerrar §91.3 y el coste por generación.

---

## 6. Estado de las decisiones abiertas (§91)

| # | Decisión | Estado según labs | Referencia |
|---|---|---|---|
| 3 | GPU exacta | Pendiente → condiciona benchmark | — |
| 6 | Object Storage (MinIO vs Swift) | Swift demostrado; MinIO no | `trash/01-.../08-GUIA-SWIFT-NODOS-OBJECT.md` |
| 16 | Versión OpenStack/Kolla | Pendiente → fijar antes Etapa 2 | `ansible/inventory/multinode` |
| 5 | Switch/velocidad red | 10 GbE recomendado; 1 GbE viable en piloto | `networks/*.xml` |
| 4 | Capacidad almacenamiento | Pendiente | §69-70 |

> El resto de decisiones (§91: pagos, SLA, retención, estimación de usuarios) son de **negocio/producto**, no de infraestructura, y no bloquean las etapas 0–5.
