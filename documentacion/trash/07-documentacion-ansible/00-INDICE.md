# OpenStack con Ansible — Guía completa del laboratorio ICC115

> **Fecha:** 2026-07-08  
> **Objetivo:** Automatizar con Ansible el despliegue completo del cluster OpenStack  
> de 5 nodos (1 controller + 4 computes) que se construyó manualmente en la guía 01–06.  
> **Nivel:** Introductorio-intermedio. Se explican todos los conceptos desde cero.

---

## ¿Para qué sirve esta carpeta?

Esta carpeta contiene **dos cosas en paralelo**:

1. **Guías conceptuales** — explican qué es Ansible, cómo funciona, y por qué las redes de OpenStack funcionan como funcionan.
2. **Código Ansible real** — playbooks, roles e inventario listos para ejecutar contra este cluster específico.

La idea es que al terminar de leer y ejecutar todo esto, entiendas:
- Cómo Ansible orquesta cambios en múltiples nodos a la vez.
- Por qué el modelo de red de OpenStack (OVS + Linux bridges + VXLAN) está diseñado así.
- Cómo automatizar un despliegue que normalmente se hace a mano.

---

## Índice de guías

| Archivo | Contenido | Tiempo de lectura |
|---------|-----------|-------------------|
| [01-CONCEPTOS-ANSIBLE.md](01-CONCEPTOS-ANSIBLE.md) | Qué es Ansible, inventario, playbooks, roles, tasks, handlers, variables, templates, módulos clave | ~20 min |
| [02-CONCEPTOS-REDES.md](02-CONCEPTOS-REDES.md) | Arquitectura de red del lab: KVM, Linux bridges, OVS, VXLAN, br-mgmt/br-vlan/br-vxlan | ~25 min |
| [03-ESTRUCTURA-PROYECTO.md](03-ESTRUCTURA-PROYECTO.md) | Árbol de directorios del proyecto Ansible, convenciones y buenas prácticas | ~10 min |
| [04-INVENTARIO.md](04-INVENTARIO.md) | Cómo declarar los 5 nodos, grupos, variables de host | ~15 min |
| [05-VARIABLES-ROLES.md](05-VARIABLES-ROLES.md) | Precedencia de variables, `group_vars`, `host_vars`, estructura de roles | ~20 min |
| [06-FASE1-BRIDGES.md](06-FASE1-BRIDGES.md) | Playbook para crear `br-mgmt`, `br-vlan`, `br-vxlan` en todos los nodos | ~20 min |
| [07-FASE2-CONTROLLER.md](07-FASE2-CONTROLLER.md) | Playbook para configurar/verificar servicios del controller | ~20 min |
| [08-FASE3-COMPUTES.md](08-FASE3-COMPUTES.md) | Playbook para configurar computes: nova, neutron-OVS, libvirt | ~20 min |
| [09-EJECUCION.md](09-EJECUCION.md) | Cómo instalar Ansible, preparar SSH, ejecutar cada fase | ~15 min |

---

## Índice del código Ansible

```
documentacion_ansible/
  ansible/
    inventory/
      hosts.yml              ← Inventario YAML con los 5 nodos
      group_vars/
        all.yml              ← Variables comunes a todos los nodos
        controller.yml       ← Variables del controller
        compute.yml          ← Variables de los computes
    playbooks/
      site.yml               ← Playbook maestro (ejecuta todo en orden)
      bridges.yml            ← Fase 1: Linux bridges en todos los nodos
      controller.yml         ← Fase 2: Servicios del controller
      computes.yml           ← Fase 3: Servicios de los computes
      verify.yml             ← Verificación final del cluster
    roles/
      common/                ← Tareas compartidas (APT, sysctl, hosts)
      linux-bridges/         ← Crear/verificar br-mgmt, br-vlan, br-vxlan
      ovs-bridges/           ← Asegurar br-provider con br-vlan
      nova-compute/          ← Instalar y configurar nova-compute
      neutron-ovs-agent/     ← Configurar neutron OVS agent
```

---

## Estado actual del cluster vs estado objetivo

| Componente | Estado actual (manual) | Estado objetivo (Ansible) |
|-----------|----------------------|--------------------------|
| Linux bridges (br-mgmt etc.) | ✅ Configurados a mano (guía 06) | ✅ Gestionados por Ansible |
| OVS bridges | ✅ Funcionales | ✅ Idempotencia garantizada |
| nova-compute en computes | ✅ Activo | ✅ Ansible verifica y corrige |
| neutron-ovs-agent | ✅ Activo | ✅ Ansible verifica y corrige |
| Registrar compute en controller | ✅ Hecho a mano | ✅ Automatizado via Ansible |
| Idempotencia total | ❌ Scripts no seguros de re-ejecutar | ✅ Ansible re-ejecutable siempre |

---

## Concepto fundamental: idempotencia

> **Idempotencia** significa que puedes ejecutar el playbook 10 veces seguidas y el resultado es siempre el mismo — sin errores, sin duplicados, sin cambios si ya está correcto.

Esto es la gran diferencia entre un script bash y Ansible:

```bash
# Script bash — NO idempotente
ovs-vsctl add-br br-provider   # La segunda vez: ERROR "already exists"
apt install nova-compute       # La segunda vez: reinstala sin necesidad
```

```yaml
# Ansible — SÍ idempotente
- name: Asegurar br-provider existe
  openvswitch_bridge:
    bridge: br-provider
    state: present     # Si ya existe → "ok" (sin cambios). Si no → lo crea.
```

---

## Prerequisitos para seguir estas guías

| Requisito | Verificación |
|-----------|-------------|
| Cluster corriendo (guías 01-06) | `openstack compute service list` muestra 4 computes `up` |
| SSH sin contraseña del laptop a los nodos | `ssh uceda@203.0.113.239` sin pedir password |
| Python 3 en el laptop | `python3 --version` |
| Ansible instalado en el laptop | `ansible --version` |

> El laptop actúa como **nodo de control** Ansible. Los nodos del cluster son los **nodos gestionados**. Ansible NO necesita instalarse en los nodos gestionados — solo Python 3.
