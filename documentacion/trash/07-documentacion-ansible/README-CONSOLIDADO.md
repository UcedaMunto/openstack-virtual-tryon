# 07 — documentacion-ansible

Fuente: `~/Documents/InstalacionOpenstack/documentacion_ansible`. **Ansible para OpenStack**: guías conceptuales + código real (playbooks, roles, inventario).

## Qué hay aquí

| Archivo | Contenido |
|---|---|
| `00-INDICE.md` | Índice de la guía completa |
| `01-CONCEPTOS-ANSIBLE.md` | Ansible: inventario, playbooks, roles, tasks, handlers, variables, templates, módulos |
| `02-CONCEPTOS-REDES.md` | Redes del lab: KVM, Linux bridges, OVS, VXLAN, br-mgmt/br-vlan/br-vxlan |
| `03-ESTRUCTURA-PROYECTO.md` | Árbol de directorios y buenas prácticas |
| `04-INVENTARIO.md` | Declarar nodos, grupos, host_vars |
| `05-VARIABLES-ROLES.md` | Precedencia de variables, group_vars, roles |
| `06/07/08-...` | Fases: bridges, controller, computes |
| `09-EJECUCION.md` | Instalar Ansible, SSH, ejecutar fases |
| `ansible/` | **Código real**: `inventory/`, `playbooks/`, `roles/{linux-bridges,ovs-bridges,nova-compute,neutron-ovs-agent}` |

## Relevancia para el proyecto

- Es la **base de automatización** para las etapas 1.5, 3.5 y 59.x de V4 (playbooks `00_connectivity` … `90_validation`).
- Los roles `linux-bridges` y `ovs-bridges` se reutilizan para preparar los nodos bare-metal antes de Kolla-Ansible.
- Enseña **idempotencia**, el criterio clave que diferencia un script bash de Ansible.
