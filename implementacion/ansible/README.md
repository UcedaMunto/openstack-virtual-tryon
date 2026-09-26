# 📦 Ansible (YAML) — gestión declarativa de la infraestructura

> Complementa a los scripts bash (`scripts/`). Aquí están los **archivos YAML** usados con Ansible/Kolla para describir la infraestructura de forma declarativa y reutilizable en otras empresas/redes.

## Archivos

| Archivo | Propósito |
|---|---|
| `inventory/hosts.yml` | Inventario Ansible (YAML) de los 3 nodos con sus roles (grupos Kolla) |
| (relación) `../kolla/globals.yml.example` | Plantilla YAML de configuración de Kolla-Ansible |

## Uso

```bash
# Validar inventario y conectividad:
ansible -i inventory/hosts.yml all -m ping

# Ejecutar un comando en los computes:
ansible -i inventory/hosts.yml compute -m shell -a 'uptime'

# El despliegue de OpenStack lo hace Kolla (scripts/11):
kolla-ansible deploy -i /etc/kolla/multinode
```

## Relación scripts bash ↔ YAML

- `inventory/nodes.env` (bash) ↔ `inventory/hosts.yml` (YAML): **misma información**, dos formatos.
- `/etc/kolla/globals.yml` (generado) ↔ `kolla/globals.yml.example` (plantilla documentada).
- Los scripts `00..13` automatizan el flujo completo; los YAML permiten gestionar/auditar de forma declarativa.

> Para producción/empresas, el patrón recomendado es: **inventario YAML + playbooks Ansible** (idempotentes) en lugar de scripts bash. Los scripts bash de esta carpeta son un primer nivel de automatización rápido y sin dependencias.
