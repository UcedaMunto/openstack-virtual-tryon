# Guía Completa de NIC (Network Interface Card)

**Fecha:** 2026-03-15
**Sistema:** Ubuntu 24.04 - ThinkPad L15 Gen 2a

---

## 📘 ¿Qué es una NIC?

### Definición

**NIC (Network Interface Card)** o **Tarjeta de Interfaz de Red** es un componente de hardware que permite a un dispositivo conectarse a una red. También se conoce como:

- **Adaptador de red**
- **Controlador de red**
- **Tarjeta Ethernet** (cuando es cableada)
- **Tarjeta WiFi** (cuando es inalámbrica)

### Función Principal

La NIC actúa como intermediaria entre el ordenador y la red, convirtiendo los datos digitales del ordenador en señales que pueden transmitirse a través de cables de red (Ethernet) o aire (WiFi).

### Componentes de una NIC

1. **Controlador**: Chip que gestiona la comunicación
2. **Puerto físico**: Conector RJ-45 (Ethernet) o antena (WiFi)
3. **MAC Address**: Dirección física única de hardware
4. **Buffer de memoria**: Almacena datos temporalmente
5. **LED indicadores**: Estado de conexión y actividad

### Tipos de NIC

| Tipo | Descripción | Velocidades Comunes |
|------|-------------|---------------------|
| **Ethernet** | Conexión por cable (RJ-45) | 10/100/1000 Mbps, 10 Gbps |
| **WiFi** | Conexión inalámbrica | 54 Mbps (802.11g), 300 Mbps (802.11n), 1.3 Gbps (802.11ac), 2.4 Gbps (802.11ax/WiFi 6) |
| **Fibra óptica** | Conexión por fibra | 1/10/40/100 Gbps |

---

## 🖥️ INFORMACIÓN DE TU NIC FÍSICA

### Resumen de tu Tarjeta de Red

```
Nombre de Interfaz: enp2s0f0
Fabricante:         Realtek Semiconductor Co., Ltd.
Modelo:             RTL8111/8168/8211/8411 PCI Express Gigabit Ethernet
Revisión:           0e
Driver:             r8169
Bus PCI:            0000:02:00.0
```

### Especificaciones Técnicas

```
Tipo:               Ethernet (Cable)
Velocidad:          1000 Mb/s (1 Gigabit/s) ✓ ACTIVA
Modo Duplex:        Full (transmisión bidireccional simultánea)
Puerto:             Twisted Pair (Par trenzado - cable RJ-45)
Auto-negociación:   Habilitada

Velocidades Soportadas:
  • 10baseT/Half
  • 10baseT/Full
  • 100baseT/Half
  • 100baseT/Full
  • 1000baseT/Full (Gigabit Ethernet) ← ACTUALMENTE EN USO
```

### Configuración de Red Actual

```
Dirección MAC:      88:a4:c2:37:e9:c7
Dirección IP:       192.168.0.195/24
Red:                192.168.0.0/24
Broadcast:          192.168.0.255
Gateway:            (192.168.0.1 - router)
Estado:             UP (Conectada y activa)
MTU:                1500 bytes
```

### Estadísticas de Tráfico

```
RECEPCIÓN (RX):
  Bytes recibidos:     5.97 GB (5,966,757,816 bytes)
  Paquetes recibidos:  4,744,354
  Errores:             0
  Paquetes perdidos:   0
  Multicast:           798

TRANSMISIÓN (TX):
  Bytes enviados:      323.68 MB (323,677,981 bytes)
  Paquetes enviados:   826,647
  Errores:             0
  Paquetes descartados: 158
  Colisiones:          0
```

**Interpretación:**
- ✓ Muy buen rendimiento (0 errores de recepción)
- ✓ Conexión estable (0 colisiones)
- ⚠️ 158 paquetes descartados en transmisión (normal, probablemente por control de flujo)

---

## 🔍 COMANDOS PARA CONSULTAR INFORMACIÓN DE NIC

### 1. Ver Todas las Interfaces de Red

```bash
ip link show
```

**Salida esperada:**
- Lista todas las interfaces (físicas y virtuales)
- Muestra estado (UP/DOWN)
- Muestra dirección MAC

**Ejemplo:**
```bash
ip link show
# Muestra: lo, enp2s0f0, wlp3s0, br0, etc.
```

---

### 2. Ver Información Detallada de una NIC Específica

```bash
ip addr show enp2s0f0
```

**Información que muestra:**
- Dirección IP
- Dirección MAC
- Estado de la interfaz
- MTU
- Broadcast

**Ejemplo de uso:**
```bash
# Ver tu NIC Ethernet
ip addr show enp2s0f0

# Ver tu NIC WiFi
ip addr show wlp3s0
```

---

### 3. Ver Estadísticas de Tráfico

```bash
ip -s link show enp2s0f0
```

**Información que muestra:**
- Bytes y paquetes RX (recibidos)
- Bytes y paquetes TX (transmitidos)
- Errores
- Paquetes perdidos

**Variante detallada:**
```bash
ip -s -s link show enp2s0f0
# El doble -s muestra aún más detalles
```

---

### 4. Ver Velocidad y Capacidades de la NIC

```bash
sudo ethtool enp2s0f0
```

**Información que muestra:**
- Velocidad actual (10/100/1000 Mbps)
- Modo duplex (Half/Full)
- Auto-negociación
- Modos de enlace soportados
- Estado del enlace

**Campos importantes:**
```
Speed: 1000Mb/s          → Velocidad actual
Duplex: Full             → Bidireccional simultáneo
Link detected: yes       → Cable conectado
Auto-negotiation: on     → Negociación automática habilitada
```

---

### 5. Ver Driver y Versión

```bash
ethtool -i enp2s0f0
```

**Información que muestra:**
- Nombre del driver (módulo del kernel)
- Versión del driver
- Versión del firmware
- Bus PCI

**Ejemplo de salida:**
```
driver: r8169              → Driver Realtek
version: 6.17.0-14-generic → Versión del kernel
bus-info: 0000:02:00.0     → Ubicación en PCI
```

---

### 6. Ver Información de Hardware PCI

```bash
lspci | grep -i ethernet
```

**Información que muestra:**
- Fabricante del chip
- Modelo del controlador
- Bus y slot PCI

**Variante detallada:**
```bash
lspci -v -s 02:00.0
# Muestra información MUY detallada del dispositivo PCI
```

---

### 7. Ver Módulo del Kernel Cargado

```bash
lsmod | grep r8169
```

**Información que muestra:**
- Módulos cargados para la NIC
- Dependencias del módulo
- Tamaño del módulo en memoria

---

### 8. Ver Información del Driver con modinfo

```bash
modinfo r8169
```

**Información que muestra:**
- Descripción del driver
- Autor
- Licencia
- Parámetros disponibles
- Versión

---

### 9. Probar Conectividad

```bash
ping -c 4 -I enp2s0f0 8.8.8.8
```

**Explicación:**
- `-c 4`: Enviar 4 paquetes
- `-I enp2s0f0`: Usar específicamente esta interfaz
- `8.8.8.8`: DNS de Google (o cualquier IP)

---

### 10. Ver Rutas de Red

```bash
ip route show
```

**Información que muestra:**
- Tabla de rutas
- Gateway predeterminado
- Redes accesibles por cada interfaz

---

### 11. Monitorear Tráfico en Tiempo Real

```bash
sudo iftop -i enp2s0f0
```

**Requiere instalación:**
```bash
sudo apt install iftop
```

**Alternativas:**
```bash
# Ver ancho de banda en tiempo real
sudo nethogs enp2s0f0

# Monitor simple
watch -n 1 'ip -s link show enp2s0f0'
```

---

### 12. Ver Conexiones Activas

```bash
ss -tunap
```

**Alternativa clásica:**
```bash
netstat -tunap
```

**Explicación de flags:**
- `-t`: TCP
- `-u`: UDP
- `-n`: Numérico (no resolver nombres)
- `-a`: Todas las conexiones
- `-p`: Procesos

---

### 13. Ver Configuración de NetworkManager

```bash
nmcli device show enp2s0f0
```

**Información que muestra:**
- Estado gestionado por NetworkManager
- DNS configurados
- Gateway
- Método de conexión (DHCP/Manual)

---

### 14. Ver ARP Table (Dispositivos en tu Red)

```bash
ip neigh show dev enp2s0f0
```

**Información que muestra:**
- IPs de dispositivos conectados en tu red local
- MACs de esos dispositivos
- Estado (REACHABLE, STALE, etc.)

---

### 15. Cambiar Estado de la NIC

```bash
# Desactivar
sudo ip link set enp2s0f0 down

# Activar
sudo ip link set enp2s0f0 up
```

**⚠️ CUIDADO:** Desactivar tu NIC te desconectará de la red.

---

## 📊 TABLA RESUMEN DE COMANDOS

| Comando | Propósito | Requiere sudo |
|---------|-----------|---------------|
| `ip link show` | Listar todas las interfaces | No |
| `ip addr show <nic>` | Ver IP y configuración | No |
| `ip -s link show <nic>` | Ver estadísticas de tráfico | No |
| `ethtool <nic>` | Ver velocidad y capacidades | Sí |
| `ethtool -i <nic>` | Ver driver y versión | No |
| `lspci \| grep -i ethernet` | Ver hardware PCI | No |
| `modinfo <driver>` | Información del módulo | No |
| `nmcli device show <nic>` | Configuración NetworkManager | No |
| `ip neigh show dev <nic>` | Ver tabla ARP | No |
| `iftop -i <nic>` | Monitor de tráfico en tiempo real | Sí |

---

## 🔧 COMANDOS ESPECÍFICOS PARA TU SISTEMA

### Ver Estado de tu NIC Ethernet

```bash
ip addr show enp2s0f0
```

### Ver Velocidad Actual

```bash
sudo ethtool enp2s0f0 | grep Speed
```

### Ver Tráfico Acumulado

```bash
ip -s link show enp2s0f0
```

### Ver Driver Cargado

```bash
ethtool -i enp2s0f0
```

### Ver Dispositivos en tu Red Local

```bash
ip neigh show dev enp2s0f0
```

### Reiniciar tu NIC (si hay problemas)

```bash
sudo ip link set enp2s0f0 down
sleep 2
sudo ip link set enp2s0f0 up
```

---

## 🌐 TU CONFIGURACIÓN ACTUAL

### Interfaz Física (Ethernet)

```
Nombre:      enp2s0f0
Hardware:    Realtek RTL8111/8168/8211/8411 Gigabit Ethernet
Driver:      r8169
MAC:         88:a4:c2:37:e9:c7
IP:          192.168.0.195/24
Red:         192.168.0.0/24
Gateway:     192.168.0.1 (probablemente)
Velocidad:   1000 Mb/s (Gigabit)
Estado:      UP y ACTIVA
```

### Interfaz WiFi (Desactivada)

```
Nombre:      wlp3s0
MAC:         c8:94:02:fb:49:0f
Estado:      DOWN (no está en uso)
```

### Interfaces Virtuales

```
br0:         Bridge virtual (192.168.100.1/24) ← Creado en esta práctica
br1:         Bridge virtual (preexistente)
virbr0:      Bridge de libvirt (192.168.122.1/24)
docker0:     Bridge de Docker (172.17.0.1/16)
tap0:        Interface TAP para VM1
tap1:        Interface TAP para VM2
vnet0:       Interface virtual de libvirt
```

---

## 📝 INTERPRETACIÓN DE NOMBRES DE INTERFACES

### Nomenclatura Moderna (Predictable Network Interface Names)

Ubuntu usa nombres predecibles basados en el hardware:

**Formato:** `<tipo><bus><slot><función>`

**Ejemplos de tu sistema:**

| Interfaz | Significado |
|----------|-------------|
| `enp2s0f0` | **en**=Ethernet, **p2**=PCI bus 2, **s0**=slot 0, **f0**=función 0 |
| `wlp3s0` | **wl**=WiFi/WLAN, **p3**=PCI bus 3, **s0**=slot 0 |
| `lo` | **lo**=Loopback (interfaz local) |

### Nomenclatura Antigua (eth0, wlan0)

Antes se usaban nombres genéricos:
- `eth0`: Primera interfaz Ethernet
- `wlan0`: Primera interfaz WiFi
- `eth1`: Segunda interfaz Ethernet

**Ventaja del nuevo sistema:** Los nombres no cambian si agregas/quitas hardware.

---

## 🛠️ TROUBLESHOOTING COMÚN

### Problema: NIC no tiene IP

```bash
# Verificar estado
ip addr show enp2s0f0

# Si no tiene IP, intentar DHCP
sudo dhclient enp2s0f0
```

### Problema: Conexión lenta

```bash
# Verificar velocidad actual
sudo ethtool enp2s0f0 | grep Speed

# Si está en 100Mbps en vez de 1000Mbps:
# - Revisar cable (debe ser Cat5e o superior)
# - Revisar switch/router
# - Probar forzar velocidad:
sudo ethtool -s enp2s0f0 speed 1000 duplex full autoneg on
```

### Problema: Muchos errores en estadísticas

```bash
# Ver errores detallados
ip -s -s link show enp2s0f0

# Si hay muchos errores:
# - Cable defectuoso
# - Puerto del switch dañado
# - Driver desactualizado
```

### Problema: NIC no aparece

```bash
# Verificar que el hardware es detectado
lspci | grep -i ethernet

# Verificar módulo cargado
lsmod | grep r8169

# Si no está cargado, cargarlo:
sudo modprobe r8169
```

---

## 📖 GLOSARIO

- **MTU** (Maximum Transmission Unit): Tamaño máximo de paquete (1500 bytes es estándar)
- **Duplex Full**: Transmisión y recepción simultánea
- **Duplex Half**: Solo transmisión O recepción a la vez
- **Auto-negociación**: La NIC y el switch acuerdan la mejor velocidad automáticamente
- **MAC Address**: Dirección de hardware única (ej: 88:a4:c2:37:e9:c7)
- **RX**: Received (recibido)
- **TX**: Transmitted (transmitido)
- **Link detected**: Si hay cable conectado y señal
- **Carrier**: Señal portadora (indica conexión física)

---

## 🎯 SCRIPT DE INFORMACIÓN COMPLETA

Guarda este script para ver toda la información de tu NIC:

```bash
#!/bin/bash
# Script: info_nic.sh
# Propósito: Mostrar información completa de la NIC

NIC="enp2s0f0"

echo "=========================================="
echo "  INFORMACIÓN COMPLETA DE NIC"
echo "=========================================="
echo ""

echo "=== CONFIGURACIÓN IP ==="
ip addr show $NIC
echo ""

echo "=== VELOCIDAD Y ESTADO ==="
sudo ethtool $NIC | grep -E "Speed|Duplex|Link detected|Auto-negotiation"
echo ""

echo "=== DRIVER ==="
ethtool -i $NIC
echo ""

echo "=== ESTADÍSTICAS ==="
ip -s link show $NIC
echo ""

echo "=== HARDWARE ==="
lspci | grep -i ethernet
echo ""

echo "=========================================="
```

**Uso:**
```bash
chmod +x info_nic.sh
./info_nic.sh
```

---

## ✅ CHECKLIST DE SALUD DE TU NIC

- [x] NIC detectada por el sistema
- [x] Driver cargado correctamente (r8169)
- [x] Velocidad óptima (1000 Mbps)
- [x] Duplex Full habilitado
- [x] Cable conectado (Link detected: yes)
- [x] IP asignada (192.168.0.195)
- [x] 0 errores de recepción
- [x] 0 colisiones
- [x] Tráfico normal

**Estado: ✅ EXCELENTE** - Tu NIC está funcionando perfectamente.

---

## 📚 RECURSOS ADICIONALES

**Documentación:**
- `man ip`
- `man ethtool`
- `man nmcli`

**Archivos de configuración:**
- `/etc/network/interfaces` (Debian/Ubuntu antiguo)
- `/etc/netplan/*.yaml` (Ubuntu moderno)
- `/etc/NetworkManager/` (NetworkManager)

---

**Archivo:** `GUIA_NIC_NETWORK_INTERFACE_CARD.md`
**Ubicación:** `/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/`
**Última actualización:** 2026-03-15 10:05
