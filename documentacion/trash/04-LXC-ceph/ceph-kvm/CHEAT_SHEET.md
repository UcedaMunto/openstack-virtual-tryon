# Cheat Sheet - Comandos Útiles Ceph KVM

Referencia rápida de comandos frecuentes.

---

## 🚀 Operaciones Principales

### Levantar Cluster Completo

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
chmod +x *.sh scripts/*.sh          # Primera vez
./up.sh                             # Levanta infraestructura + bootstrap
./status.sh                         # Ver estado
```

### Apagar y Reactivar

```bash
./stop.sh                           # Apaga todo gracefully
./start.sh                          # Reactiva desde donde estaba
./status.sh                         # Verificar estado
```

### Reset Completo

```bash
./reset.sh                          # Destroy + Up (5-7 minutos)
# O manualmente:
./destroy.sh                        # Borra TODO
sleep 10
./up.sh                             # Levanta nuevo
```

---

## 🔍 Verificación y Estado

### Estado General

```bash
# Desde host
./status.sh                         # VMs + redes

# Desde admin VM (SSH)
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph -s'
```

### OSDs y Pools

```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph osd tree'
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph osd pool ls'
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph df'
```

### Health Check

```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph health detail'
```

### Dashboard

```bash
# Abrir navegador:
# https://192.168.130.100:8443
# Usuario: admin
# Contraseña: AdminCeph2026!

# O ver URL desde línea de comandos:
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph mgr services'
```

---

## 📊 Monitoreo en Vivo

### Ver cambios en tiempo real

```bash
# Monitorear status del cluster
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'watch -n 1 "sudo ceph -s"'

# Monitorear PGs
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'watch -n 1 "sudo ceph pg stat"'

# Monitorear OSDs
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'watch -n 1 "sudo ceph osd status"'
```

---

## 🗄️ Administración RBD (Block Storage)

### Crear Imagen RBD

```bash
# Crear imagen de 1GB
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd create test-image --pool rbd --size 1024'

# Crear con snapshot
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd create my-disk --size 10240'
```

### Listar Imágenes

```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd ls --pool rbd'
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd info rbd/test-image'
```

### Mapear a Kernel

```bash
# Mapear imagen
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd map rbd/test-image'

# Formatear
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo mkfs.ext4 /dev/rbd0'

# Montar
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo mount /dev/rbd0 /mnt && df -h /mnt'

# Desmontar y desmapar
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo umount /mnt && sudo rbd unmap /dev/rbd0'
```

### Crear Snapshots

```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd snap create rbd/test-image@snap1'
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd snap ls rbd/test-image'
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo rbd snap rm rbd/test-image@snap1'
```

---

## 🔧 Troubleshooting

### VMs no tienen IP

```bash
# Esperar cloud-init (toma tiempo)
sleep 120

# Verificar IPs
virsh domifaddr ceph-admin

# Si sigue sin IP
sudo tail -f /var/log/libvirt/qemu/ceph-admin.log
```

### SSH no responde

```bash
# Aumentar timeout manualmente
ssh -o ConnectTimeout=30 -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'echo ok'

# Verificar que VM está running
virsh list --all | grep ceph-admin
```

### Cluster en HEALTH_WARN

```bash
# Esto es normal en instalación nueva
# Para llevar a HEALTH_OK:

ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph config set mon mon_warn_on_insecure_global_id_reclaim_allowed false'

ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph mon enable-msgr2'

# Verificar
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph -s'
```

### Recrear desde cero

```bash
./destroy.sh            # Destruye TODO
sleep 10
./up.sh                 # Levanta nuevo limpio
```

---

## 🔐 Configuración y Cambios

### Ver/Editar Configuración

```bash
# Ver todos los parámetros configurables
cat config/cluster.env | grep -E "^[A-Z_]+=" | sort

# Editar (requiere reset después)
nano config/cluster.env

# Luego:
./reset.sh
```

### Cambios Comunes

```bash
# Cambiar tamaño de VMs
# En config/cluster.env:
# VM_MEMORY_MB=4096          → VM_MEMORY_MB=8192
# VM_CPUS=2                  → VM_CPUS=4

# Cambiar dashboard password (en VM admin)
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph dashboard ac-user-set-password admin -i /tmp/newpass.txt'

# Cambiar IPs (requiere reset)
# En config/cluster.env, editar CEPH_XXX_IP variables
```

---

## 📁 Estructura Importante

```bash
# Archivos de configuración
config/cluster.env          # Todos los parámetros

# Scripts de ciclo de vida
up.sh                       # Levanta completo
start.sh                    # Reactiva VMs
stop.sh                     # Apaga VMs
reset.sh                    # Destroy + Up
destroy.sh                  # Borra TODO
status.sh                   # Ver estado

# Fases individuales (debugging)
scripts/00-check-prereqs.sh
scripts/10-create-networks.sh
scripts/20-create-vms.sh
scripts/30-bootstrap-ceph.sh

# Datos generados
/var/tmp/ceph-kvm/images/   # Disco base Ubuntu
/var/tmp/ceph-kvm/vms/      # Discos VM (QCOW2)
/var/tmp/ceph-kvm/seed/     # Cloud-init ISOs
```

---

## 🔗 Referencia Rápida SSH

### Alias Útiles

```bash
# Agregar a ~/.bashrc para tener siempre disponible:

alias ssh-admin='ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@192.168.130.100'
alias ssh-mon='ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@192.168.130.10'
alias ssh-osd1='ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@192.168.130.11'

# Luego usar:
ssh-admin 'sudo ceph -s'
ssh-mon 'uptime'
```

### Comandos Frecuentes

```bash
# Ejecutar comando en admin
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'COMANDO'

# Con sudo
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo COMANDO'

# Múltiples comandos
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'cmd1 && cmd2 && cmd3'

# Shell interactivo
ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100
```

---

## 📞 Contacto con VMs

### Acceso de Consola (si SSH falla)

```bash
# Terminal de VM (admin)
virsh console ceph-admin --force

# Salir: Ctrl + ]

# Listar todas las consolas
virsh list --all
```

### Verificar Conectividad

```bash
# Ping a VMs desde host
for vm in admin mon 1 2 3; do
  ip="192.168.130.$([ "$vm" = "admin" ] && echo 100 || [ "$vm" = "mon" ] && echo 10 || echo 1$vm)"
  ping -c 1 -W 1 "$ip" && echo "✓ $vm OK" || echo "✗ $vm FAIL"
done

# Ver MAC addresses asignadas
virsh domiflist ceph-admin
virsh domiflist ceph-mon
virsh domiflist ceph-1
```

---

## 🎓 Aprender Más

- Guía completa: [SECUENCIA_COMANDOS.md](SECUENCIA_COMANDOS.md)
- Conceptos: [GUIA_CEPH_KVM.md](GUIA_CEPH_KVM.md)
- Quick start: [QUICK_START.md](QUICK_START.md)

---

**Última actualización:** April 24, 2026 | **Versión:** Ceph Quincy 17.2.9
