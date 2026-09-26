# 📚 Índice General — Base de Conocimiento del Proyecto

> **Proyecto objetivo:** `proyecto-en-kubernetes` — Plataforma SaaS de Virtual Try-On
> **Stack objetivo:** OpenStack (Kolla-Ansible) + Kubernetes + FASHN-VTON 1.5 · 3 nodos físicos
> **Fecha de consolidación:** 2026-09-24
> **Origen:** 7 implementaciones de laboratorio previas (todas verificadas y funcionando en su momento), preprocesadas, comprimidas y organizadas por tema.

---

## 🎯 Para qué sirve esta carpeta

Esta carpeta es la **base de conocimiento reutilizable** extraída de las implementaciones que ya se levantaron con éxito. Su objetivo es **acelerar el levantamiento del proyecto actual**: en lugar de releer 7 proyectos dispersos, aquí está todo el conocimiento consolidado por tecnología, con los scripts/XML/PlantUML/guías originales como referencia ejecutable.

**Cómo usarla:**
1. Lee este índice para ubicarte.
2. Entra a `09-consolidado/00-MAPA-DE-CONOCIMIENTO.md` para el resumen técnico consolidado.
3. Usa `09-consolidado/01-CHECKLIST-LEVANTAMIENTO.md` como hoja de ruta accionable.
4. Consulta las carpetas `01..07` cuando necesites el detalle original (scripts, XML, manifests, puml).

---

## 🗂️ Estructura

| Carpeta | Fuente original | Contenido clave |
|---|---|---|
| `01-InstalacionOpenstack/` | `~/Documents/InstalacionOpenstack` | OpenStack manual (OSA) + **lab Kolla-Ansible + Kubernetes** + PlantUML + scripts |
| `02-cluster-ceph/` | `~/Documents/cluster-ceph` | Infra HA/HC KVM: Ceph, MariaDB/MaxScale, Redis, NGINX, DNS, Django |
| `03-PRACTICA-KVM/` | `~/Documents/ESPECIALIZACION/LAB 1/PRACTICA` | KVM/QEMU/libvirt, bridges, VLAN, VXLAN, cloud-init, PlantUML |
| `04-LXC-ceph/` | `~/Documents/ESPECIALIZACION/LXC` | Ceph con Docker Compose + Ceph sobre KVM/libvirt |
| `05-redes-xml-kvm/` | `~/Documents/redes-xml-kvm` | Definiciones XML de redes libvirt (openstack-admin/public/provider) |
| `06-guias123/` | `~/Documents/ESPECIALIZACION/guias123` | Guías consolidadas: bridge Linux, LXC, KVM básico, networking |
| `07-documentacion-ansible/` | `~/Documents/InstalacionOpenstack/documentacion_ansible` | Ansible (conceptos + playbooks/roles reales para OpenStack) |
| `09-consolidado/` | *(síntesis nueva)* | Documentos consolidados y checklist de levantamiento |

---

## 🧭 Mapa: qué conocimiento aporta cada fuente al proyecto actual

| Necesidad del proyecto (V4) | Dónde está el conocimiento |
|---|---|
| **OpenStack Kolla-Ansible** (inventario `multinode`, grupos control/network/compute/storage) | `01-InstalacionOpenstack/openstack-ansible/ansible/inventory/multinode` · `hosts-minimal-backup.ini` |
| **Redes OpenStack** (mgmt / tunnel / external = br-mgmt / br-vxlan / br-ex) | `01-InstalacionOpenstack/openstack-ansible/networks/*.xml` · `01-.../puml/` · `07-.../02-CONCEPTOS-REDES.md` |
| **cloud-init + seed.iso** para aprovisionar nodos | `01-InstalacionOpenstack/openstack-ansible/cloud-init/` · `scripts/gen-user-data.sh` |
| **Kubernetes kubeadm + Calico + MetalLB + Rook-Ceph + manifests** | `01-InstalacionOpenstack/openstack-ansible/kubernetes/` (scripts, `tmp/*.yaml`, `doc/`, `net/`, `puml/`) |
| **Ceph** (docker, KVM, y dentro de K8s vía Rook) | `02-cluster-ceph/` · `04-LXC-ceph/` · `01-.../openstack-ansible/kubernetes/tmp/03-rook-cluster.yaml` |
| **KVM/libvirt: crear VMs, redes, XML, bridges** | `02-cluster-ceph/kvm-generic/` · `03-PRACTICA-KVM/` · `05-redes-xml-kvm/` |
| **Ansible como capa de automatización** | `07-documentacion-ansible/` (conceptos + roles `linux-bridges`, `ovs-bridges`, `nova-compute`, `neutron-ovs-agent`) |
| **Buenas prácticas: idempotencia, inventarios, variables** | `07-documentacion-ansible/01-CONCEPTOS-ANSIBLE.md` · `05-VARIABLES-ROLES.md` |
| **Hardening/HA de datos (MariaDB/Galera, Redis, MaxScale, NGINX L7)** | `02-cluster-ceph/proyecto-manual-infraestructura/` |
| **Observabilidad / healthcheck** | `02-cluster-ceph/proyecto-manual-infraestructura/tools-sh/` |

---

## ⚠️ Notas de seguridad

- Las carpetas contienen **credenciales de laboratorio** (ficheros `admin.conf`, `*.keyring.txt`, `secrets.yaml`, `.env`) copiados tal cual del origen. **Son credenciales de prueba local, no reutilizar en producción.**
- Las claves privadas SSH (`id_rsa`, `id_ed25519`) **fueron excluidas** deliberadamente del copiado.
- Los binarios pesados (ISO, `.qcow2`, `.img`, PDF, DOCX, imágenes, `plantuml.jar`) también fueron excluidos para mantener el árbol ligero y versionable.

---

## 🔁 Reproducir el copiado

```bash
# Re-ejecutable: regenera toda la base desde los proyectos origen.
bash documentacion/_copiar-conocimientos.sh
```
