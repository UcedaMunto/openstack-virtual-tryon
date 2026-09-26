# Setup Cluster Ceph con KVM

## Requisitos previos

Ejecuta estos comandos en orden:

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst cloud-image-utils wget cpu-checker
kvm-ok
ls ~/.ssh/id_rsa.pub
```

Si el último comando dice que el archivo no existe, ejecuta este:

```bash
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
```

---

## 1. Crear red KVM 192.168.5.0/24

```bash
cat > /tmp/ceph-net.xml <<EOF
<network>
  <name>ceph-net</name>
  <forward mode='nat'/>
  <ip address='192.168.5.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.5.100' end='192.168.5.200'/>
    </dhcp>
  </ip>
</network>
EOF
```

```bash
sudo virsh net-define /tmp/ceph-net.xml
```

```bash
sudo virsh net-start ceph-net
```

```bash
sudo virsh net-autostart ceph-net
```

```bash
sudo virsh net-list --all
```

---

## 2. Descargar imagen base Ubuntu 22.04

```bash
export IMG_DIR=/var/lib/libvirt/images
```

```bash
sudo wget -O $IMG_DIR/ubuntu-22.04-base.qcow2 https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

---

## 3. Crear VM ceph-admin (192.168.5.40)

### 3.1 Crear archivo cloud-init

```bash
cat > /tmp/user-data-ceph-admin.yaml <<EOF
#cloud-config
hostname: ceph-admin
manage_etc_hosts: false
users:
  - name: ceph
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub)
chpasswd:
  list: |
    root:ceph1234
    ceph:ceph1234
  expire: false
write_files:
  - path: /etc/hosts
    content: |
      127.0.0.1 localhost
      127.0.1.1 ceph-admin
      192.168.5.40 ceph-admin
      192.168.5.41 ceph-mon
      192.168.5.42 ceph-osd1
      192.168.5.43 ceph-osd2
      192.168.5.44 ceph-osd3
network:
  version: 2
  ethernets:
    enp1s0:
      addresses: [192.168.5.40/24]
      gateway4: 192.168.5.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
```

### 3.2 Crear disco del sistema

```bash
sudo qemu-img create -f qcow2 -b $IMG_DIR/ubuntu-22.04-base.qcow2 -F qcow2 $IMG_DIR/ceph-admin.qcow2 20G
```

### 3.3 Crear la VM

```bash
sudo virt-install --name ceph-admin --ram 2048 --vcpus 2 --disk path=$IMG_DIR/ceph-admin.qcow2,format=qcow2 --network network=ceph-net,model=virtio --os-variant ubuntu22.04 --cloud-init user-data=/tmp/user-data-ceph-admin.yaml --noautoconsole --import
```

---

## 4. Crear VM ceph-mon (192.168.5.41)

### 4.1 Crear archivo cloud-init

```bash
cat > /tmp/user-data-ceph-mon.yaml <<EOF
#cloud-config
hostname: ceph-mon
manage_etc_hosts: false
users:
  - name: ceph
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub)
chpasswd:
  list: |
    root:ceph1234
    ceph:ceph1234
  expire: false
write_files:
  - path: /etc/hosts
    content: |
      127.0.0.1 localhost
      127.0.1.1 ceph-mon
      192.168.5.40 ceph-admin
      192.168.5.41 ceph-mon
      192.168.5.42 ceph-osd1
      192.168.5.43 ceph-osd2
      192.168.5.44 ceph-osd3
network:
  version: 2
  ethernets:
    enp1s0:
      addresses: [192.168.5.41/24]
      gateway4: 192.168.5.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
```

### 4.2 Crear disco del sistema

```bash
sudo qemu-img create -f qcow2 -b $IMG_DIR/ubuntu-22.04-base.qcow2 -F qcow2 $IMG_DIR/ceph-mon.qcow2 20G
```

### 4.3 Crear la VM

```bash
sudo virt-install --name ceph-mon --ram 2048 --vcpus 2 --disk path=$IMG_DIR/ceph-mon.qcow2,format=qcow2 --network network=ceph-net,model=virtio --os-variant ubuntu22.04 --cloud-init user-data=/tmp/user-data-ceph-mon.yaml --noautoconsole --import
```

---

## 5. Crear VM ceph-osd1 (192.168.5.42)

### 5.1 Crear archivo cloud-init

```bash
cat > /tmp/user-data-ceph-osd1.yaml <<EOF
#cloud-config
hostname: ceph-osd1
manage_etc_hosts: false
users:
  - name: ceph
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub)
chpasswd:
  list: |
    root:ceph1234
    ceph:ceph1234
  expire: false
write_files:
  - path: /etc/hosts
    content: |
      127.0.0.1 localhost
      127.0.1.1 ceph-osd1
      192.168.5.40 ceph-admin
      192.168.5.41 ceph-mon
      192.168.5.42 ceph-osd1
      192.168.5.43 ceph-osd2
      192.168.5.44 ceph-osd3
network:
  version: 2
  ethernets:
    enp1s0:
      addresses: [192.168.5.42/24]
      gateway4: 192.168.5.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
```

### 5.2 Crear disco del sistema

```bash
sudo qemu-img create -f qcow2 -b $IMG_DIR/ubuntu-22.04-base.qcow2 -F qcow2 $IMG_DIR/ceph-osd1.qcow2 20G
```

### 5.3 Crear disco de datos para OSD

```bash
sudo qemu-img create -f qcow2 $IMG_DIR/ceph-osd1-data.qcow2 50G
```

### 5.4 Crear la VM

```bash
sudo virt-install --name ceph-osd1 --ram 2048 --vcpus 2 --disk path=$IMG_DIR/ceph-osd1.qcow2,format=qcow2 --disk path=$IMG_DIR/ceph-osd1-data.qcow2,format=qcow2 --network network=ceph-net,model=virtio --os-variant ubuntu22.04 --cloud-init user-data=/tmp/user-data-ceph-osd1.yaml --noautoconsole --import
```

---

## 6. Crear VM ceph-osd2 (192.168.5.43)

### 6.1 Crear archivo cloud-init

```bash
cat > /tmp/user-data-ceph-osd2.yaml <<EOF
#cloud-config
hostname: ceph-osd2
manage_etc_hosts: false
users:
  - name: ceph
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub)
chpasswd:
  list: |
    root:ceph1234
    ceph:ceph1234
  expire: false
write_files:
  - path: /etc/hosts
    content: |
      127.0.0.1 localhost
      127.0.1.1 ceph-osd2
      192.168.5.40 ceph-admin
      192.168.5.41 ceph-mon
      192.168.5.42 ceph-osd1
      192.168.5.43 ceph-osd2
      192.168.5.44 ceph-osd3
network:
  version: 2
  ethernets:
    enp1s0:
      addresses: [192.168.5.43/24]
      gateway4: 192.168.5.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
```

### 6.2 Crear disco del sistema

```bash
sudo qemu-img create -f qcow2 -b $IMG_DIR/ubuntu-22.04-base.qcow2 -F qcow2 $IMG_DIR/ceph-osd2.qcow2 20G
```

### 6.3 Crear disco de datos para OSD

```bash
sudo qemu-img create -f qcow2 $IMG_DIR/ceph-osd2-data.qcow2 50G
```

### 6.4 Crear la VM

```bash
sudo virt-install --name ceph-osd2 --ram 2048 --vcpus 2 --disk path=$IMG_DIR/ceph-osd2.qcow2,format=qcow2 --disk path=$IMG_DIR/ceph-osd2-data.qcow2,format=qcow2 --network network=ceph-net,model=virtio --os-variant ubuntu22.04 --cloud-init user-data=/tmp/user-data-ceph-osd2.yaml --noautoconsole --import
```

---

## 7. Crear VM ceph-osd3 (192.168.5.44)

### 7.1 Crear archivo cloud-init

```bash
cat > /tmp/user-data-ceph-osd3.yaml <<EOF
#cloud-config
hostname: ceph-osd3
manage_etc_hosts: false
users:
  - name: ceph
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub)
chpasswd:
  list: |
    root:ceph1234
    ceph:ceph1234
  expire: false
write_files:
  - path: /etc/hosts
    content: |
      127.0.0.1 localhost
      127.0.1.1 ceph-osd3
      192.168.5.40 ceph-admin
      192.168.5.41 ceph-mon
      192.168.5.42 ceph-osd1
      192.168.5.43 ceph-osd2
      192.168.5.44 ceph-osd3
network:
  version: 2
  ethernets:
    enp1s0:
      addresses: [192.168.5.44/24]
      gateway4: 192.168.5.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
```

### 7.2 Crear disco del sistema

```bash
sudo qemu-img create -f qcow2 -b $IMG_DIR/ubuntu-22.04-base.qcow2 -F qcow2 $IMG_DIR/ceph-osd3.qcow2 20G
```

### 7.3 Crear disco de datos para OSD

```bash
sudo qemu-img create -f qcow2 $IMG_DIR/ceph-osd3-data.qcow2 50G
```

### 7.4 Crear la VM

```bash
sudo virt-install --name ceph-osd3 --ram 2048 --vcpus 2 --disk path=$IMG_DIR/ceph-osd3.qcow2,format=qcow2 --disk path=$IMG_DIR/ceph-osd3-data.qcow2,format=qcow2 --network network=ceph-net,model=virtio --os-variant ubuntu22.04 --cloud-init user-data=/tmp/user-data-ceph-osd3.yaml --noautoconsole --import
```

---

## 8. Verificar estado de las VMs

```bash
sudo virsh list --all
```

Salida esperada:

```text
 Id   Name         State
---------------------------
 1    ceph-admin   running
 2    ceph-mon     running
 3    ceph-osd1    running
 4    ceph-osd2    running
 5    ceph-osd3    running
```

---

## 9. Verificar conectividad

Espera unos 60 segundos para que termine cloud-init y luego ejecuta:

```bash
ping -c 3 192.168.5.40
```

```bash
ping -c 3 192.168.5.41
```

```bash
ping -c 3 192.168.5.42
```

```bash
ping -c 3 192.168.5.43
```

```bash
ping -c 3 192.168.5.44
```

```bash
ssh ceph@192.168.5.40
```

```bash
ssh ceph@192.168.5.41
```

```bash
ssh ceph@192.168.5.42
```

```bash
ssh ceph@192.168.5.43
```

```bash
ssh ceph@192.168.5.44
```

---

## Resumen de la infraestructura

| VM         | IP           | RAM  | vCPUs | Disco OS | Disco OSD |
|------------|--------------|------|-------|----------|-----------|
| ceph-admin | 192.168.5.40 | 2 GB | 2     | 20 GB    | -         |
| ceph-mon   | 192.168.5.41 | 2 GB | 2     | 20 GB    | -         |
| ceph-osd1  | 192.168.5.42 | 2 GB | 2     | 20 GB    | 50 GB     |
| ceph-osd2  | 192.168.5.43 | 2 GB | 2     | 20 GB    | 50 GB     |
| ceph-osd3  | 192.168.5.44 | 2 GB | 2     | 20 GB    | 50 GB     |

Notas:

- Usuario por defecto: `ceph`
- Contrasena por defecto: `ceph1234`
- En los nodos OSD, el disco extra normalmente aparecera como `vdb`
- Si tu version de `virt-install` no soporta `--cloud-init`, hay que cambiar el metodo a `cloud-localds`
