
#
#   INFORMACION DE INTERFACES DE RED EN EL HOST
#
ip -br addr show {nombre-bridge} 

brctl show
##### ver las ips asignadas al bridge
    ip -br addr | grep ju11

# Ver puertos conectados a bridges
bridge link

# tabla mac aprendida por los bridges
bridge fdb show br-admin-ju11

# Ver qué vnet corresponde a qué VM
virsh domiflist mv1-ju11
virsh domiflist mv2-ju11
virsh domiflist mv3-ju11

# DISCOS DIFERENCIALES EN 
cd /var/lib/libvirt/images
#CREAR LA VM
virt-install --name mv10-ju11 --memory 1024 --vcpus 1 \
    --disk path=/var/lib/libvirt/images/mv10-ju11.qcow2,format=qcow2 \
    --network bridge=br-admin-ju11,model=virtio \
    --network bridge=br-share-ju11,model=virtio \
    --network bridge=br-ext-ju11,model=virtio \
    --os-variant ubuntu24.04 --import --noautoconsole \
    --serial pty --console pty,target_type=serial && echo "mv1 OK"

sudo virt-customize --no-network -d mv10-ju11 \
  --write '/etc/netplan/50-cloud-init.yaml:network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [192.168.50.19/24]
    enp2s0:
      dhcp4: false
      dhcp6: false
      link-local: []
      addresses: [10.0.0.19/24]
    enp3s0:
      dhcp4: true
      dhcp6: false
      link-local: []
' \
  --hostname mv10-ju11 \
  --ssh-inject uceda:file:/home/uceda/.ssh/id_rsa.pub \
  --password uceda:password:ubuntu


# servicios estén registrados.
openstack service list
# apis disponibles
openstack endpoint list
# todos los endpoints disponibles
openstack catalog list
# comprobar keystone
openstack token issue
# hipervisores de nova
openstack hypervisor list
# ver uso
openstack usage list


# ver redes 
openstack network list
# ver subredes
openstack subnet list
# ver routers
openstack router list
# ver puertos 
openstack port list
# ips flotantes
openstack floating ip list
# agentes de red
openstack network agent list
#volumenes
open stack volume list

##########################################################
# 1. Ver el estado de todos los servicios de OpenStack
##########################################################
sudo systemctl list-units --type=service | grep -E "nova|neutron|glance|keystone|placement|ovs"
##########################################################
# 2. Estado de un servicio específico
sudo systemctl status neutron-server
sudo systemctl status neutron-openvswitch-agent
sudo systemctl status neutron-l3-agent
sudo systemctl status neutron-dhcp-agent
sudo systemctl status glance-api
sudo systemctl status apache2
##########################################################
# 3. Ver los últimos logs (journalctl)
##########################################################
sudo journalctl -u nova-api -n 100
sudo journalctl -u nova-scheduler -n 100
sudo journalctl -u nova-conductor -n 100
sudo journalctl -u nova-compute -n 100
sudo journalctl -u neutron-server -n 100
sudo journalctl -u neutron-openvswitch-agent -n 100
sudo journalctl -u neutron-l3-agent -n 100
sudo journalctl -u neutron-dhcp-agent -n 100
sudo journalctl -u glance-api -n 100
sudo journalctl -u apache2 -n 100

##########################################################
# 4. Ver logs en tiempo real (tail -f)
##########################################################
sudo journalctl -fu nova-api
sudo journalctl -fu nova-scheduler
sudo journalctl -fu nova-conductor
sudo journalctl -fu nova-compute
sudo journalctl -fu neutron-server
sudo journalctl -fu neutron-openvswitch-agent
sudo journalctl -fu neutron-l3-agent
sudo journalctl -fu neutron-dhcp-agent
sudo journalctl -fu glance-api
##########################################################
# 5. Ver errores recientes solamente
##########################################################
sudo journalctl -p err -b
# Solo errores desde el último arranque.
##########################################################
# 6. Ver todos los logs de hoy
##########################################################
sudo journalctl --since today
# Excelente para revisar todo lo ocurrido hoy.
##########################################################
# 7. Buscar una palabra dentro de los logs
##########################################################
sudo journalctl | grep ERROR
sudo journalctl | grep Exception
sudo journalctl | grep Traceback
##########################################################
# 8. Ver los archivos de log clásicos
##########################################################
ls -lh /var/log/nova
ls -lh /var/log/neutron
ls -lh /var/log/glance
ls -lh /var/log/apache2
ls -lh /var/log/openvswitch
##########################################################
# 9. Leer un archivo de log
##########################################################
sudo tail -100 /var/log/nova/nova-api.log
sudo tail -100 /var/log/nova/nova-compute.log
sudo tail -100 /var/log/neutron/server.log
sudo tail -100 /var/log/neutron/openvswitch-agent.log
sudo tail -100 /var/log/glance/api.log
##########################################################
# 10. Seguir un log en vivo
##########################################################

sudo tail -f /var/log/nova/nova-api.log
sudo tail -f /var/log/neutron/server.log
sudo tail -f /var/log/neutron/openvswitch-agent.log

# Similar a journalctl -f.


##########################################################
# 11. Logs de Open vSwitch
##########################################################

sudo ovs-vsctl show
sudo ovs-ofctl show br-int
sudo ovs-ofctl show br-tun
sudo ovs-ofctl show br-provider

sudo ovs-appctl vlog/list

# Estado y configuración de OVS.


##########################################################
# 12. Ver logs del kernel
##########################################################

dmesg -T

# Problemas de discos, NICs, memoria, etc.


##########################################################
# 13. Ver reinicios o caídas de servicios
##########################################################

journalctl -u nova-api --since yesterday
journalctl -u neutron-server --since yesterday

# Muy útil para saber cuándo falló un servicio.


##########################################################
# 14. Buscar Tracebacks de Python
##########################################################

grep -Ri Traceback /var/log/nova
grep -Ri Traceback /var/log/neutron
grep -Ri Traceback /var/log/glance

# Encuentra excepciones completas.


##########################################################
# 15. Buscar errores comunes
##########################################################

grep -Ri ERROR /var/log/nova
grep -Ri ERROR /var/log/neutron
grep -Ri CRITICAL /var/log
grep -Ri WARNING /var/log

# Resume los errores registrados.


##########################################################
# 16. Ver el arranque completo del sistema
##########################################################

journalctl -b

# Todo el proceso de boot.


##########################################################
# 17. Ver únicamente los servicios fallidos
##########################################################

systemctl --failed

# Muestra los servicios que no iniciaron correctamente.


##########################################################
# 18. Reiniciar un servicio y observar el log
##########################################################

sudo systemctl restart nova-api

sudo journalctl -fu nova-api

# Muy útil para depuración.