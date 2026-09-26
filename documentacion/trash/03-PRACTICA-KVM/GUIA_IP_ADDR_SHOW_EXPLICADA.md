# Guía Completa: Entendiendo la Salida de `ip addr show`

**Fecha:** 2026-03-15
**Sistema:** Ubuntu 24.04 - ThinkPad L15 Gen 2a
**Usuario:** uceda

---

## 📘 ANATOMÍA DEL COMANDO `ip addr show`

Este comando muestra **todas las interfaces de red** de tu sistema, tanto físicas como virtuales.

---

## 🔍 ESTRUCTURA DE CADA INTERFAZ

Cada interfaz muestra información en este formato:

```
[Número]: [Nombre]: <FLAGS> mtu [tamaño] qdisc [disciplina] state [estado] ...
    link/[tipo] [MAC] brd [broadcast]
    inet [IP/máscara] brd [broadcast] scope [alcance] ...
    inet6 [IPv6] scope [alcance] ...
```

---

## 📋 TUS INTERFACES DETALLADAS

### 1️⃣ **lo** (Loopback - Interfaz Local)

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
```

**¿Qué es?**
- Interfaz **virtual interna** del sistema
- El sistema la usa para comunicarse consigo mismo
- **SIEMPRE** debe existir y estar activa

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `1` | Primera interfaz (siempre es la loopback) |
| **Nombre** | `lo` | "Loopback" - interfaz local |
| **FLAGS** | `LOOPBACK,UP,LOWER_UP` | Tipo loopback, activa, capa física activa |
| **MTU** | `65536` | Tamaño máximo de paquete (muy grande porque es interna) |
| **qdisc** | `noqueue` | Sin cola de espera (no la necesita) |
| **state** | `UNKNOWN` | Estado desconocido (normal para loopback) |
| **MAC** | `00:00:00:00:00:00` | No tiene MAC real (es virtual) |
| **inet** | `127.0.0.1/8` | IPv4 local (localhost) |
| **inet6** | `::1/128` | IPv6 local |

**Uso típico:**
```bash
ping 127.0.0.1  # Probar que la red local funciona
ping localhost  # Mismo efecto
```

---

### 2️⃣ **enp2s0f0** (Ethernet - NIC Física)

```
2: enp2s0f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 88:a4:c2:37:e9:c7 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.195/24 brd 192.168.0.255 scope global dynamic noprefixroute enp2s0f0
       valid_lft 83250sec preferred_lft 83250sec
```

**¿Qué es?**
- Tu **tarjeta de red Ethernet física** (cable RJ-45)
- Realtek RTL8111 Gigabit Ethernet
- Conexión por **cable** a tu router

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `2` | Segunda interfaz del sistema |
| **Nombre** | `enp2s0f0` | **en**=Ethernet, **p2**=PCI bus 2, **s0**=slot 0, **f0**=función 0 |
| **FLAGS** | `BROADCAST,MULTICAST,UP,LOWER_UP` | Soporta broadcast, soporta multicast, activa, capa física activa |
| **MTU** | `1500` | Tamaño máximo de paquete estándar Ethernet |
| **qdisc** | `fq_codel` | Disciplina de cola "Fair Queue CoDel" (control de congestión) |
| **state** | `UP` | Interfaz activa y funcionando |
| **link/ether** | `88:a4:c2:37:e9:c7` | Dirección MAC de tu tarjeta Ethernet |
| **brd** | `ff:ff:ff:ff:ff:ff` | Dirección broadcast (para enviar a todos) |
| **inet** | `192.168.0.195/24` | Tu IP en la red local |
| **brd** | `192.168.0.255` | Dirección broadcast de la red |
| **scope** | `global` | Dirección accesible globalmente (en tu red) |
| **dynamic** | - | IP obtenida por DHCP (no estática) |
| **noprefixroute** | - | No agrega ruta de prefijo automática |
| **valid_lft** | `83250sec` | Tiempo válido del lease DHCP (~23 horas) |
| **preferred_lft** | `83250sec` | Tiempo preferido del lease DHCP |

**Desglose del nombre `enp2s0f0`:**
- `en` = Ethernet
- `p2` = PCI bus número 2
- `s0` = Slot 0
- `f0` = Función 0

**Datos clave:**
- 🌐 IP: **192.168.0.195/24**
- 📍 Red: 192.168.0.0/24 (256 IPs: .0 a .255)
- 🔌 MAC: **88:a4:c2:37:e9:c7**
- ⚡ Estado: **UP** (activa)

---

### 3️⃣ **wlp3s0** (WiFi - NIC Inalámbrica)

```
3: wlp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether c8:94:02:fb:49:0f brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.152/24 brd 192.168.0.255 scope global dynamic noprefixroute wlp3s0
       valid_lft 80814sec preferred_lft 80814sec
    inet6 fe80::d351:f1f9:8cbc:10ca/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
```

**¿Qué es?**
- Tu **tarjeta WiFi**
- Conexión **inalámbrica** al mismo router
- ⚠️ **¡Tienes Ethernet Y WiFi conectados simultáneamente!**

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `3` | Tercera interfaz |
| **Nombre** | `wlp3s0` | **wl**=WiFi/WLAN, **p3**=PCI bus 3, **s0**=slot 0 |
| **state** | `UP` | WiFi activa |
| **MAC** | `c8:94:02:fb:49:0f` | MAC de tu adaptador WiFi |
| **inet** | `192.168.0.152/24` | IP diferente obtenida por WiFi |
| **inet6** | `fe80::d351:f1f9:8cbc:10ca/64` | IPv6 link-local |
| **scope link** | - | IPv6 solo para la red local |
| **valid_lft** | `80814sec` | Lease DHCP válido por ~22.4 horas |

**Datos clave:**
- 🌐 IP: **192.168.0.152/24** (diferente a Ethernet)
- 📍 Red: Misma red que Ethernet
- 🔌 MAC: **c8:94:02:fb:49:0f**
- ⚡ Estado: **UP** (activa)

**⚠️ NOTA IMPORTANTE:**
Tienes **DOS** conexiones activas al mismo tiempo:
- Ethernet: 192.168.0.195
- WiFi: 192.168.0.152

**¿Por qué?** Probablemente el WiFi se conectó automáticamente aunque ya tenías Ethernet. Esto puede causar problemas de routing.

**Recomendación:**
Desactiva WiFi si usas Ethernet:
```bash
nmcli radio wifi off
```

---

### 4️⃣ **docker0** (Bridge de Docker)

```
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether f2:84:d5:67:a2:f4 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
```

**¿Qué es?**
- Bridge virtual creado por **Docker**
- Red privada para contenedores Docker
- Estado DOWN porque no hay contenedores corriendo

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `4` | Cuarta interfaz |
| **Nombre** | `docker0` | Bridge de Docker |
| **FLAGS** | `NO-CARRIER,BROADCAST,MULTICAST,UP` | Sin portadora (sin nada conectado), pero interfaz UP |
| **state** | `DOWN` | Inactiva (no hay contenedores) |
| **inet** | `172.17.0.1/16` | IP del bridge (gateway para contenedores) |
| **Red** | `172.17.0.0/16` | Red privada de Docker (65,536 IPs) |

**Datos clave:**
- 🌐 IP: **172.17.0.1/16** (gateway de Docker)
- 📍 Red: 172.17.0.0/16 (red privada)
- ⚡ Estado: **DOWN** (sin contenedores activos)

---

### 5️⃣ **virbr0** (Bridge de libvirt/KVM - Red "default")

```
6: virbr0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 52:54:00:80:90:20 brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
       valid_lft forever preferred_lft forever
```

**¿Qué es?**
- Bridge virtual de **libvirt** (sistema de virtualización)
- Red NAT predeterminada para VMs de KVM
- Tiene una VM conectada (vnet0)

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `6` | Sexta interfaz (falta la 5, probablemente eliminada) |
| **Nombre** | `virbr0` | **vir**=virtual, **br**=bridge, **0**=número |
| **state** | `UP` | Activa (hay VM conectada) |
| **inet** | `192.168.122.1/24` | IP del bridge (gateway para VMs) |
| **Red** | `192.168.122.0/24` | Red privada de libvirt |

**Datos clave:**
- 🌐 IP: **192.168.122.1/24** (gateway para VMs)
- 📍 Red: 192.168.122.0/24 (254 IPs para VMs)
- ⚡ Estado: **UP** (VM activa conectada)
- 🔗 Conexión: vnet0 (interfaz de una VM)

---

### 6️⃣ **vnet0** (Interfaz Virtual de VM)

```
7: vnet0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master virbr0 state UNKNOWN group default qlen 1000
    link/ether fe:54:00:f5:63:7c brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fc54:ff:fef5:637c/64 scope link
       valid_lft forever preferred_lft forever
```

**¿Qué es?**
- Interfaz TAP de una **máquina virtual** antigua
- Conectada al bridge `virbr0`
- Creada por libvirt/KVM

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `7` | Séptima interfaz |
| **Nombre** | `vnet0` | **v**=virtual, **net**=network, **0**=número |
| **master** | `virbr0` | "Esclava" del bridge virbr0 |
| **state** | `UNKNOWN` | Estado desconocido (normal para vnet) |
| **MAC** | `fe:54:00:f5:63:7c` | MAC virtual asignada a la VM |

**Datos clave:**
- 🔗 Conectada a: **virbr0**
- ⚡ Estado: **UP** (VM corriendo)
- 📝 Nota: VM preexistente (no creada en esta práctica)

---

### 7️⃣ **br1** (Bridge Preexistente)

```
15: br1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 56:57:f3:a4:71:6e brd ff:ff:ff:ff:ff:ff
```

**¿Qué es?**
- Bridge virtual creado anteriormente
- NO tiene IP asignada
- NO tiene nada conectado (NO-CARRIER)

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `15` | Interfaz número 15 (numeración con saltos) |
| **Nombre** | `br1` | **br**=bridge, **1**=número |
| **FLAGS** | `NO-CARRIER` | Sin nada conectado |
| **state** | `DOWN` | Inactiva |

**Datos clave:**
- ⚡ Estado: **DOWN** (inactiva)
- 📝 Nota: Probablemente de una práctica anterior

---

### 8️⃣ **br0** (Bridge de la Práctica Actual) ⭐

```
16: br0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 32:b2:63:63:71:71 brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.1/24 brd 192.168.100.255 scope global noprefixroute br0
       valid_lft forever preferred_lft forever
    inet6 fe80::4f90:aea0:b73b:6775/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
```

**¿Qué es?**
- ⭐ **Bridge que creamos en la práctica de hoy**
- Red virtual para las VMs (VM1 y VM2)
- Tiene tap0 y tap1 conectadas

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `16` | Interfaz número 16 |
| **Nombre** | `br0` | **br**=bridge, **0**=número |
| **state** | `UP` | Activa y funcionando |
| **inet** | `192.168.100.1/24` | IP del bridge (gateway para VMs) |
| **scope** | `global` | Dirección global |
| **noprefixroute** | - | No agrega ruta automática |
| **valid_lft** | `forever` | IP permanente (no DHCP) |

**Datos clave:**
- 🌐 IP: **192.168.100.1/24** (gateway para VM1 y VM2)
- 📍 Red: 192.168.100.0/24 (254 IPs disponibles)
- ⚡ Estado: **UP** (activa)
- 🔗 Conexiones: tap0 (VM1), tap1 (VM2)

---

### 9️⃣ **tap0** (VM1 de la Práctica) ⭐

```
17: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master br0 state UNKNOWN group default qlen 1000
    link/ether fe:8a:62:d8:da:ab brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fc8a:62ff:fed8:daab/64 scope link
       valid_lft forever preferred_lft forever
```

**¿Qué es?**
- ⭐ Interfaz TAP de **VM1** (vm1-practica)
- Conectada al bridge `br0`
- Creada por QEMU cuando iniciaste VM1

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `17` | Interfaz número 17 |
| **Nombre** | `tap0` | **tap**=interfaz TAP, **0**=número |
| **master** | `br0` | Conectada al bridge br0 |
| **state** | `UNKNOWN` | Normal para TAP |
| **MAC** | `fe:8a:62:d8:da:ab` | MAC asignada a VM1 |

**Datos clave:**
- 🔗 Conectada a: **br0**
- 🖥️ VM: **VM1 (vm1-practica)**
- ⚡ Estado: **UP** (VM1 corriendo)

---

### 🔟 **tap1** (VM2 de la Práctica) ⭐

```
18: tap1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master br0 state UNKNOWN group default qlen 1000
    link/ether fe:e7:f8:bc:98:3b brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fce7:f8ff:febc:983b/64 scope link
       valid_lft forever preferred_lft forever
```

**¿Qué es?**
- ⭐ Interfaz TAP de **VM2** (vm2-practica)
- Conectada al bridge `br0`
- Creada por QEMU cuando iniciaste VM2

**Explicación de cada campo:**

| Campo | Valor | Significado |
|-------|-------|-------------|
| **Número** | `18` | Interfaz número 18 |
| **Nombre** | `tap1` | **tap**=interfaz TAP, **1**=número |
| **master** | `br0` | Conectada al bridge br0 |
| **state** | `UNKNOWN` | Normal para TAP |
| **MAC** | `fe:e7:f8:bc:98:3b` | MAC asignada a VM2 |

**Datos clave:**
- 🔗 Conectada a: **br0**
- 🖥️ VM: **VM2 (vm2-practica)**
- ⚡ Estado: **UP** (VM2 corriendo)

---

## 📊 GLOSARIO DE TÉRMINOS

### FLAGS (Banderas)

| Flag | Significado |
|------|-------------|
| `UP` | Interfaz está activada |
| `LOWER_UP` | Capa física activa (hay señal/conexión) |
| `DOWN` | Interfaz desactivada |
| `BROADCAST` | Soporta envío a múltiples destinatarios |
| `MULTICAST` | Soporta multidifusión |
| `LOOPBACK` | Interfaz de bucle local |
| `NO-CARRIER` | Sin portadora (nada conectado físicamente) |
| `RUNNING` | Interfaz en ejecución |

### Otros Campos

| Campo | Significado |
|-------|-------------|
| **MTU** | Maximum Transmission Unit - Tamaño máximo de paquete |
| **qdisc** | Queueing Discipline - Algoritmo de gestión de cola |
| **state** | Estado actual de la interfaz |
| **link/ether** | Dirección MAC (Media Access Control) |
| **brd** | Broadcast - Dirección para enviar a todos |
| **inet** | Dirección IPv4 |
| **inet6** | Dirección IPv6 |
| **scope** | Alcance de la dirección (host/link/global) |
| **valid_lft** | Lifetime - Tiempo de vida válido |
| **preferred_lft** | Tiempo de vida preferido |
| **master** | Bridge al que está conectada la interfaz |
| **dynamic** | IP asignada por DHCP (no estática) |
| **noprefixroute** | No crear ruta de prefijo automática |

### Tipos de qdisc

| qdisc | Descripción |
|-------|-------------|
| `noqueue` | Sin cola (virtual, no necesita) |
| `fq_codel` | Fair Queue CoDel - Control avanzado de congestión |
| `pfifo_fast` | Priority FIFO - Cola por prioridad |

### Scopes (Alcances)

| Scope | Significado |
|-------|-------------|
| `host` | Solo este host (127.0.0.1) |
| `link` | Solo en el enlace local |
| `global` | Alcance global (accesible en la red) |

---

## 📈 TABLA RESUMEN DE TUS INTERFACES

| # | Nombre | Tipo | IP | Estado | Uso |
|---|--------|------|----|---------|----|
| 1 | lo | Loopback | 127.0.0.1 | UP | Sistema interno |
| 2 | enp2s0f0 | Ethernet | 192.168.0.195 | UP | **Conexión por cable** |
| 3 | wlp3s0 | WiFi | 192.168.0.152 | UP | **Conexión WiFi** ⚠️ |
| 4 | docker0 | Bridge | 172.17.0.1 | DOWN | Docker (sin contenedores) |
| 6 | virbr0 | Bridge | 192.168.122.1 | UP | VMs de libvirt |
| 7 | vnet0 | TAP | - | UP | VM antigua (ubuntu-guest) |
| 15 | br1 | Bridge | - | DOWN | Bridge sin uso |
| 16 | **br0** | Bridge | **192.168.100.1** | UP | **VMs de la práctica** ⭐ |
| 17 | **tap0** | TAP | - | UP | **VM1 (vm1-practica)** ⭐ |
| 18 | **tap1** | TAP | - | UP | **VM2 (vm2-practica)** ⭐ |

**Leyenda:**
- ⚠️ = Atención: posible problema
- ⭐ = Creado en esta práctica

---

## 🚨 OBSERVACIONES IMPORTANTES

### ⚠️ Problema: Ethernet y WiFi Activos Simultáneamente

Tienes **DOS** conexiones activas en la misma red:
- **Ethernet**: 192.168.0.195
- **WiFi**: 192.168.0.152

**¿Por qué es un problema?**
- Conflictos de routing (¿por dónde sale el tráfico?)
- Desperdicio de DHCP leases
- Posible confusión del sistema

**Solución recomendada:**

Si usas Ethernet, desactiva WiFi:
```bash
nmcli radio wifi off
```

Si prefieres WiFi, desactiva Ethernet:
```bash
nmcli connection down "netplan-zz-all-en"
```

Ver conexiones activas:
```bash
nmcli connection show --active
```

---

## 🗺️ MAPA DE RED

```
INTERNET
   │
   │
┌──┴────────────────────────────────────────────────────┐
│              ROUTER (192.168.0.1)                     │
└──┬──────────────────────────────────┬─────────────────┘
   │                                  │
   │ Ethernet                         │ WiFi
   │ (cable)                          │ (inalámbrico)
   │                                  │
┌──┴──────────────────┐         ┌────┴───────────────┐
│  enp2s0f0           │         │  wlp3s0            │
│  192.168.0.195      │         │  192.168.0.152     │
│  88:a4:c2:37:e9:c7  │         │  c8:94:02:fb:49:0f │
└─────────────────────┘         └────────────────────┘
          │
          │ HOST (tu laptop)
          │
   ┌──────┴──────────────────────────────────┐
   │                                         │
   │  Bridges Virtuales:                     │
   │  ├─ docker0 (172.17.0.1)    DOWN        │
   │  ├─ virbr0 (192.168.122.1)  UP          │
   │  │   └─ vnet0 (VM antigua)              │
   │  ├─ br1                     DOWN        │
   │  └─ br0 (192.168.100.1)     UP ⭐       │
   │      ├─ tap0 (VM1)                      │
   │      └─ tap1 (VM2)                      │
   └─────────────────────────────────────────┘
              │           │
         ┌────┴───┐  ┌───┴────┐
         │  VM1   │  │  VM2   │
         │ Alpine │  │ Alpine │
         │        │  │        │
         │ tap0   │  │ tap1   │
         └────────┘  └────────┘
```

---

## 🔍 COMANDOS ÚTILES

### Ver solo interfaces activas (UP)
```bash
ip link show | grep -B 1 "state UP"
```

### Ver solo IPs asignadas
```bash
ip -4 addr show | grep inet
```

### Ver tabla de routing
```bash
ip route show
```

### Ver conexiones de NetworkManager
```bash
nmcli connection show
```

### Ver estadísticas de una interfaz
```bash
ip -s link show enp2s0f0
```

### Ver qué interfaces están en un bridge
```bash
bridge link show
```

### Ver ARP (dispositivos en tu red)
```bash
ip neigh show
```

---

## 📝 SCRIPT DE RESUMEN

```bash
#!/bin/bash
# Script: resumen_interfaces.sh

echo "=== RESUMEN DE INTERFACES ==="
echo ""
echo "Físicas:"
ip link show enp2s0f0 | grep -oP 'state \K\w+' | xargs echo "  Ethernet (enp2s0f0):"
ip link show wlp3s0 | grep -oP 'state \K\w+' | xargs echo "  WiFi (wlp3s0):"
echo ""
echo "Bridges:"
ip link show br0 | grep -oP 'state \K\w+' | xargs echo "  br0 (práctica):"
ip link show virbr0 | grep -oP 'state \K\w+' | xargs echo "  virbr0 (libvirt):"
ip link show docker0 | grep -oP 'state \K\w+' | xargs echo "  docker0:"
echo ""
echo "VMs:"
ip link show tap0 2>/dev/null | grep -oP 'state \K\w+' | xargs echo "  VM1 (tap0):"
ip link show tap1 2>/dev/null | grep -oP 'state \K\w+' | xargs echo "  VM2 (tap1):"
echo ""
echo "IPs asignadas:"
ip -4 addr show | grep inet | grep -v 127.0.0.1 | awk '{print "  "$NF": "$2}'
```

---

**Archivo:** `GUIA_IP_ADDR_SHOW_EXPLICADA.md`
**Ubicación:** `/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/`
**Última actualización:** 2026-03-15 10:25
