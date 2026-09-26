# 05 — redes-xml-kvm

Fuente: `~/Documents/redes-xml-kvm`. Definiciones **XML de redes libvirt** para OpenStack, mínimas y listas para usar.

## Archivos

| Archivo | Red |
|---|---|
| `openstack-admin.xml` | Red de administración/gestión (mgmt) |
| `openstack-public.xml` | Red pública / acceso externo |
| `openstack-provider.xml` | Red provider (tráfico de instancias) |

## Relevancia

- Son los 3 planos mínimos de OpenStack (admin/public/provider), equivalentes a mgmt/external/tunnel.
- Útiles como referencia mínima junto a los XML comentados de `01-InstalacionOpenstack/openstack-ansible/networks/`.
