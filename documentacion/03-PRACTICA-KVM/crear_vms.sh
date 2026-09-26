#!/bin/bash

##############################################################################
# Script de Creación de Máquinas Virtuales para Práctica de Redes
# Fecha: 2026-03-12
# Propósito: Crear 2 VMs conectadas al bridge br0
##############################################################################

set -e  # Detener si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Script de Creación de VMs con Bridge${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

##############################################################################
# PARTE 1: VERIFICACIONES PREVIAS
##############################################################################

echo -e "${YELLOW}[1/6] Verificando requisitos...${NC}"

# Verificar que el usuario tiene permisos
if ! groups | grep -q "libvirt"; then
    echo -e "${RED}ERROR: El usuario no está en el grupo 'libvirt'${NC}"
    echo "Ejecuta: sudo usermod -aG libvirt $USER"
    echo "Luego cierra sesión y vuelve a entrar"
    exit 1
fi

# Verificar que KVM está disponible
if [ ! -e /dev/kvm ]; then
    echo -e "${RED}ERROR: /dev/kvm no existe. KVM no está habilitado${NC}"
    exit 1
fi

# Verificar que el bridge br0 existe
if ! ip addr show br0 &>/dev/null; then
    echo -e "${RED}ERROR: Bridge br0 no existe${NC}"
    echo "Ejecuta primero los pasos de creación del bridge"
    exit 1
fi

# Verificar que libvirtd está funcionando
if ! sudo virsh version &>/dev/null; then
    echo -e "${RED}ERROR: libvirtd no está funcionando correctamente${NC}"
    echo "Ver archivo SOLUCION_TROUBLESHOOTING_LIBVIRTD.md"
    echo ""
    echo "Solución rápida:"
    echo "  sudo reboot"
    echo "O continuar con la Opción B (QEMU directo)"
    exit 1
fi

echo -e "${GREEN}✓ Todos los requisitos están OK${NC}"
echo ""

##############################################################################
# PARTE 2: CONFIGURACIÓN DE RED VIRTUAL
##############################################################################

echo -e "${YELLOW}[2/6] Configurando red virtual br0-network...${NC}"

# Verificar si la red ya existe
if sudo virsh net-list --all | grep -q "br0-network"; then
    echo "Red br0-network ya existe. Saltando..."
else
    # Crear archivo XML de definición de red
    cat > /tmp/br0-network.xml << 'EOF'
<network>
  <name>br0-network</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>
EOF

    # Definir la red en libvirt
    sudo virsh net-define /tmp/br0-network.xml
    echo -e "${GREEN}✓ Red br0-network definida${NC}"
fi

# Iniciar la red si no está activa
if ! sudo virsh net-list | grep -q "br0-network"; then
    sudo virsh net-start br0-network
    echo -e "${GREEN}✓ Red br0-network iniciada${NC}"
fi

# Configurar autoarranque
sudo virsh net-autostart br0-network
echo -e "${GREEN}✓ Red configurada para autoarranque${NC}"
echo ""

##############################################################################
# PARTE 3: VERIFICAR/DESCARGAR IMAGEN ISO
##############################################################################

echo -e "${YELLOW}[3/6] Verificando imagen ISO...${NC}"

ISO_DIR="/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA"
ISO_NAME="ubuntu-22.04.5-live-server-amd64.iso"
ISO_PATH="$ISO_DIR/$ISO_NAME"
ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"

if [ -f "$ISO_PATH" ]; then
    echo -e "${GREEN}✓ ISO encontrada: $ISO_PATH${NC}"
else
    echo -e "${YELLOW}ISO no encontrada. Descargando...${NC}"
    echo "Esto puede tomar varios minutos dependiendo de tu conexión..."
    mkdir -p "$ISO_DIR"
    wget -O "$ISO_PATH" "$ISO_URL" || {
        echo -e "${RED}ERROR: No se pudo descargar la ISO${NC}"
        echo "Descárgala manualmente desde: $ISO_URL"
        echo "Y guárdala en: $ISO_PATH"
        exit 1
    }
    echo -e "${GREEN}✓ ISO descargada${NC}"
fi

echo ""

##############################################################################
# PARTE 4: CREAR DIRECTORIO PARA DISCOS VIRTUALES
##############################################################################

echo -e "${YELLOW}[4/6] Preparando almacenamiento...${NC}"

DISK_DIR="/var/lib/libvirt/images"
sudo mkdir -p "$DISK_DIR"
echo -e "${GREEN}✓ Directorio de discos: $DISK_DIR${NC}"
echo ""

##############################################################################
# PARTE 5: CREAR MÁQUINA VIRTUAL 1
##############################################################################

echo -e "${YELLOW}[5/6] Creando Máquina Virtual 1...${NC}"

VM1_NAME="vm1-practica-bridge"
VM1_DISK="$DISK_DIR/vm1-practica-bridge.qcow2"

# Verificar si la VM ya existe
if sudo virsh list --all | grep -q "$VM1_NAME"; then
    echo -e "${YELLOW}La VM '$VM1_NAME' ya existe.${NC}"
    read -p "¿Deseas eliminarla y recrearla? (s/N): " respuesta
    if [[ "$respuesta" =~ ^[Ss]$ ]]; then
        sudo virsh destroy "$VM1_NAME" 2>/dev/null || true
        sudo virsh undefine "$VM1_NAME" --remove-all-storage 2>/dev/null || true
        echo -e "${GREEN}VM anterior eliminada${NC}"
    else
        echo "Saltando creación de VM1..."
        VM1_SKIP=true
    fi
fi

if [ "$VM1_SKIP" != "true" ]; then
    echo "Creando $VM1_NAME..."
    sudo virt-install \
      --name "$VM1_NAME" \
      --ram 2048 \
      --vcpus 2 \
      --disk path="$VM1_DISK",size=20,format=qcow2 \
      --os-variant ubuntu22.04 \
      --network network=br0-network,model=virtio \
      --graphics vnc,listen=0.0.0.0 \
      --noautoconsole \
      --cdrom "$ISO_PATH"

    echo -e "${GREEN}✓ VM1 creada exitosamente${NC}"
    echo -e "${GREEN}  Nombre: $VM1_NAME${NC}"
    echo -e "${GREEN}  Disco: $VM1_DISK${NC}"
    echo -e "${GREEN}  RAM: 2 GB${NC}"
    echo -e "${GREEN}  CPUs: 2${NC}"
    echo -e "${GREEN}  Red: br0-network${NC}"
fi

echo ""

##############################################################################
# PARTE 6: CREAR MÁQUINA VIRTUAL 2
##############################################################################

echo -e "${YELLOW}[6/6] Creando Máquina Virtual 2...${NC}"

VM2_NAME="vm2-practica-bridge"
VM2_DISK="$DISK_DIR/vm2-practica-bridge.qcow2"

# Verificar si la VM ya existe
if sudo virsh list --all | grep -q "$VM2_NAME"; then
    echo -e "${YELLOW}La VM '$VM2_NAME' ya existe.${NC}"
    read -p "¿Deseas eliminarla y recrearla? (s/N): " respuesta
    if [[ "$respuesta" =~ ^[Ss]$ ]]; then
        sudo virsh destroy "$VM2_NAME" 2>/dev/null || true
        sudo virsh undefine "$VM2_NAME" --remove-all-storage 2>/dev/null || true
        echo -e "${GREEN}VM anterior eliminada${NC}"
    else
        echo "Saltando creación de VM2..."
        VM2_SKIP=true
    fi
fi

if [ "$VM2_SKIP" != "true" ]; then
    echo "Creando $VM2_NAME..."
    sudo virt-install \
      --name "$VM2_NAME" \
      --ram 2048 \
      --vcpus 2 \
      --disk path="$VM2_DISK",size=20,format=qcow2 \
      --os-variant ubuntu22.04 \
      --network network=br0-network,model=virtio \
      --graphics vnc,listen=0.0.0.0 \
      --noautoconsole \
      --cdrom "$ISO_PATH"

    echo -e "${GREEN}✓ VM2 creada exitosamente${NC}"
    echo -e "${GREEN}  Nombre: $VM2_NAME${NC}"
    echo -e "${GREEN}  Disco: $VM2_DISK${NC}"
    echo -e "${GREEN}  RAM: 2 GB${NC}"
    echo -e "${GREEN}  CPUs: 2${NC}"
    echo -e "${GREEN}  Red: br0-network${NC}"
fi

echo ""

##############################################################################
# RESUMEN FINAL
##############################################################################

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    CREACIÓN COMPLETADA${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Máquinas virtuales creadas y conectadas al bridge br0"
echo ""
echo -e "${YELLOW}Estado de las VMs:${NC}"
sudo virsh list --all | grep -E "vm.-practica-bridge|Id.*Name"
echo ""
echo -e "${YELLOW}Estado de las redes:${NC}"
sudo virsh net-list --all
echo ""
echo -e "${YELLOW}Interfaces del bridge br0:${NC}"
bridge link show | grep "master br0" || echo "  (Las VMs deben estar iniciadas para ver sus interfaces)"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    SIGUIENTE PASO${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Para acceder a las VMs e instalar el sistema operativo:"
echo ""
echo "1. Acceso gráfico con virt-manager:"
echo "   $ virt-manager"
echo ""
echo "2. Acceso por consola VNC:"
echo "   $ virt-viewer $VM1_NAME"
echo "   $ virt-viewer $VM2_NAME"
echo ""
echo "3. Consola de texto (después de instalar el SO):"
echo "   $ sudo virsh console $VM1_NAME"
echo "   $ sudo virsh console $VM2_NAME"
echo ""
echo "4. Ver información de la VM:"
echo "   $ sudo virsh dominfo $VM1_NAME"
echo ""
echo "5. Gestionar VMs:"
echo "   $ sudo virsh start $VM1_NAME      # Iniciar"
echo "   $ sudo virsh shutdown $VM1_NAME   # Apagar"
echo "   $ sudo virsh destroy $VM1_NAME    # Apagar forzado"
echo "   $ sudo virsh reboot $VM1_NAME     # Reiniciar"
echo ""
echo -e "${YELLOW}Nota:${NC} Las VMs están configuradas para arrancar desde el ISO."
echo "Después de instalar el SO, puedes desconectar el ISO con:"
echo "  $ sudo virsh change-media $VM1_NAME sda --eject"
echo ""
echo -e "${GREEN}¡Práctica lista para usar!${NC}"
