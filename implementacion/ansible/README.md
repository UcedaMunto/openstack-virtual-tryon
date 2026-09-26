# 📦 Ansible (YAML) — playbooks de gestión declarativa

> Versión **Ansible** de la automatización. Cada script bash de `scripts/` tiene su
> **playbook equivalente** aquí (idempotente, reutilizable en otras empresas/redes).

## Estructura

```
ansible/
├── inventory/
│   └── hosts.yml              # Inventario (grupos Kolla + grupo "nodes")
├── group_vars/
│   └── all.yml                # Variables comunes (IPs, nombres, credenciales)
└── playbooks/
    ├── site.yml               # Playbook MAESTRO (ejecuta todo en orden)
    ├── 00-bootstrap.yml       # Ubuntu 24.04 + sudo NOPASSWD
    ├── 01-base.yml            # Paquetes base + chrony
    ├── 02-docker.yml          # Docker CE + Compose
    ├── 03-kolla-ansible.yml   # Kolla-Ansible (venv) en el control
    ├── 04-openstack-cli.yml   # python-openstackclient
    ├── 05-k8s-tools.yml       # kubectl + helm
    ├── 06-nvidia-runtime.yml  # nvidia-container-toolkit (GPU)
    ├── 07-kolla-config.yml    # multinode + globals.yml + passwords
    ├── 08-kolla-bootstrap.yml # bootstrap-servers + prechecks
    ├── 09-kolla-hosts.yml     # /etc/hosts único + desactivar avahi
    ├── 11-kolla-deploy.yml    # deploy + post-deploy
    ├── 12-openstack-recursos.yml # flavors/imagen/keypair/SG/red
    ├── 13-openstack-cinder.yml   # Cinder LVM
    ├── 15-dns.yml             # dnsmasq (dominios del proyecto)
    ├── 16-k8s.yml             # k3s + Dashboard + IngressRouteTCP
    └── verify.yml             # verificación final
```

## Uso

```bash
cd implementacion/ansible

# Validar inventario y conectividad:
ansible -i inventory/hosts.yml all -m ping

# Despliegue COMPLETO (equivale a scripts/run-all.sh):
ansible-playbook playbooks/site.yml

# Solo una fase (tags):
ansible-playbook playbooks/site.yml --tags bootstrap
ansible-playbook playbooks/site.yml --tags docker
ansible-playbook playbooks/site.yml --tags deploy
ansible-playbook playbooks/site.yml --tags verify

# Ejecutar un playbook individual:
ansible-playbook playbooks/15-dns.yml
```

> La contraseña sudo se inyecta con `export SUDO_PASSWORD=...` (igual que en
> `nodes.env`). Sin ella, se usa el valor por defecto de `group_vars/all.yml`.

## Relación scripts bash ↔ playbooks

| Script (`scripts/`) | Playbook (`playbooks/`) |
|---|---|
| `00-bootstrap.sh` | `00-bootstrap.yml` |
| `01-base.sh` | `01-base.yml` |
| `02-docker.sh` | `02-docker.yml` |
| `03-kolla-ansible.sh` | `03-kolla-ansible.yml` |
| `04-openstack-cli.sh` | `04-openstack-cli.yml` |
| `05-k8s-tools.sh` | `05-k8s-tools.yml` |
| `06-nvidia-runtime.sh` | `06-nvidia-runtime.yml` |
| `07-kolla-config.sh` | `07-kolla-config.yml` |
| `08-kolla-bootstrap.sh` | `08-kolla-bootstrap.yml` |
| `09-kolla-hosts.sh` | `09-kolla-hosts.yml` |
| `10-verificar.sh` | `verify.yml` |
| `11-kolla-deploy.sh` | `11-kolla-deploy.yml` |
| `12-openstack-recursos.sh` | `12-openstack-recursos.yml` |
| `13-openstack-cinder.sh` | `13-openstack-cinder.yml` |
| `15-dns.sh` | `15-dns.yml` |
| `16-k8s.sh` | `16-k8s.yml` |

> **Clave del patrón Ansible:** en vez de `for nodo in ...` (bash), el playbook
> usa `hosts: nodes` y Ansible ejecuta la tarea en los 3 nodos automáticamente.

