# 📦 Ansible — estructura del numeral 58 (ARQUITECTURA)

> Estructura **Ansible** alineada con la sección **§58 "Estructura propuesta del
> proyecto Ansible"** del documento de arquitectura. Roles + playbooks
> idempotentes, reutilizables en otras empresas/redes.

## Estructura

```
ansible/
├── ansible.cfg                # config (inventario por defecto, SSH, become)
├── requirements.yml           # collections/roles de Galaxy
├── inventory/
│   ├── baremetal.yml          # grupos por rol (control/network/compute/...) + physical_nodes/gpu_compute/vault
│   └── openstack.yml          # inventario dinámico de VMs (futuro)
├── group_vars/
│   ├── all.yml                # variables comunes (NO secretas)
│   ├── physical_nodes.yml     # IPs/nombres/NICs de los 3 nodos
│   ├── gpu_compute.yml        # variables del nodo GPU
│   └── vault.yml              # secretos (ENCRIPTADO con ansible-vault)
├── playbooks/
│   ├── site.yml               # Playbook MAESTRO
│   ├── 00_connectivity.yml
│   ├── 01_base_os.yml
│   ├── 02_network.yml
│   ├── 03_hardening.yml
│   ├── 04_kolla_prerequisites.yml
│   ├── 05_kolla_deploy.yml
│   ├── 06_gpu_host.yml
│   ├── 10_vm_base.yml         # (futuro)
│   ├── 11_kubernetes_prerequisites.yml
│   ├── 12_gpu_worker.yml      # (futuro)
│   ├── 20_monitoring_agents.yml  # (placeholder)
│   ├── 30_backup.yml             # (placeholder)
│   ├── 90_validation.yml
│   ├── 15_dns.yml             # extra: dnsmasq (dominios)
│   ├── 16_k8s_cluster.yml     # extra: k3s + Dashboard
│   └── 17_openstack_recursos.yml # extra: flavors/imagen/SG/red/Cinder
└── roles/
    ├── common/                # paquetes base + NTP + zona horaria
    ├── network/               # resolución única + avahi
    ├── hardening/             # sudo/SSH/firewall
    ├── container_runtime/     # Docker CE + containerd
    ├── kolla_host/            # Kolla-Ansible (venv) + clientes
    ├── gpu_host/              # nvidia-container-toolkit
    ├── kubernetes_node/       # kubectl/helm/sysctl
    ├── monitoring_agent/      # (placeholder)
    └── backup_agent/          # (placeholder)
```

## Uso

```bash
cd implementacion/ansible

# Validar inventario y conectividad:
ansible -i inventory/baremetal.yml all -m ping

# Despliegue COMPLETO (numeral 58 + extras):
ansible-playbook playbooks/site.yml --vault-password-file <(printf 'asdfghjkl')

# Solo una fase (tags):
ansible-playbook playbooks/site.yml --tags base_os
ansible-playbook playbooks/site.yml --tags kolla_deploy
ansible-playbook playbooks/site.yml --tags validation

# Un playbook individual:
ansible-playbook playbooks/15_dns.yml
```

## Secretos (Ansible Vault — §60)

Los secretos están en `group_vars/vault.yml`, **encriptado** con `ansible-vault`
(no se versionan en claro). Para usarlo:

```bash
# Descifrar/editar:
ansible-vault edit group_vars/vault.yml --vault-password-file <(printf 'asdfghjkl')

# Ejecutar playbooks:
ansible-playbook playbooks/site.yml --vault-password-file <(printf 'asdfghjkl')
```

> La contraseña del vault y la sudo coinciden por defecto (`asdfghjkl`, el valor
> de `nodes.env`); para otra red, cámbiala y re-cifra el vault.

## Relación scripts bash ↔ estructura Ansible

| Script (`scripts/`) | Playbook / rol (`ansible/`) |
|---|---|
| `00-bootstrap.sh` | `03_hardening.yml` + `00_connectivity.yml` |
| `01-base.sh` | `01_base_os.yml` + rol `common` |
| `02-docker.sh` | `04_kolla_prerequisites.yml` + rol `container_runtime` |
| `03-kolla-ansible.sh` / `04-openstack-cli.sh` | rol `kolla_host` |
| `05-k8s-tools.sh` | `11_kubernetes_prerequisites.yml` + rol `kubernetes_node` |
| `06-nvidia-runtime.sh` | `06_gpu_host.yml` + rol `gpu_host` |
| `07..09, 11` | `04_kolla_prerequisites.yml` + `05_kolla_deploy.yml` |
| `10-verificar.sh` | `90_validation.yml` |
| `12-openstack-recursos.sh` / `13-openstack-cinder.sh` | `17_openstack_recursos.yml` |
| `15-dns.sh` | `15_dns.yml` |
| `16-k8s.sh` | `16_k8s_cluster.yml` |

> **Clave del patrón Ansible:** en vez de `for nodo in ...` (bash), el playbook
> usa `hosts: physical_nodes` (o `control`, `gpu_compute`) y Ansible ejecuta la
> tarea en todos los nodos automáticamente.


