# kolla/inventory/ — Inventario de Kolla-Ansible

El inventario `multinode` (formato INI) se **genera automáticamente** en
`/etc/kolla/multinode` por el playbook `05_kolla_deploy.yml` a partir de
`ansible/group_vars/physical_nodes.yml`.

No se versiona aquí porque incluye los mapeos `:children` estándar de
Kolla-Ansible (se copian desde el paquete instalado en `/opt/kolla-ansible`).
