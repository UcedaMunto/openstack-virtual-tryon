# Guía Rápida - Completar la Práctica AHORA (Sin Reiniciar)

**Fecha:** 2026-03-12
**Situación:** libvirtd bloqueado, pero bridge br0 funcional

---

## 🎯 OPCIONES DISPONIBLES

### ✅ Opción 1: Usar QEMU Directo (SIN libvirt)

**Ventajas:**
- ✅ No necesita libvirtd
- ✅ Control total
- ✅ Funciona AHORA mismo

**Estado:** Script creado (`crear_vms_qemu.sh`)

**Problema actual:** Está descargando la ISO de Ubuntu (2 GB) - tardará ~7 minutos

**Acción:**
```bash
# Esperar a que termine la descarga O
# Detener (Ctrl+C) y descargar más tarde
```

---

### ✅ Opción 2: Usar ISO Alternativa (Más Pequeña)

Si tienes otra distribución Linux más ligera:

**Alpine Linux** (~180 MB):
```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA"
wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-standard-3.19.1-x86_64.iso
```

**Tiny Core Linux** (~23 MB):
```bash
wget http://tinycorelinux.net/14.x/x86_64/release/CorePure64-14.0.iso
```

Luego edita el script para usar esa ISO.

---

### ✅ Opción 3: Reiniciar el Sistema (MÁS SIMPLE)

**Si puedes reiniciar ahora:**

1. ```bash
   sudo reboot
   ```

2. Después del reinicio:
   ```bash
   cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA"
   ./crear_vms.sh  # El script original con libvirt
   ```

---

## 🚀 RECOMENDACIÓN URGENTE

**La opción más rápida depende de tu situación:**

### Si PUEDES REINICIAR (5 minutos total):
```
Reiniciar → Ejecutar crear_vms.sh → Listo
```

### Si NO PUEDES REINICIAR (10-15 minutos):
```
Esperar descarga ISO → Ejecutar crear_vms_qemu.sh → Iniciar VMs
```

### Si NO TIENES TIEMPO (hazlo después):
```
Detener todo → Reiniciar cuando puedas → Continuar
```

---

## 📊 Estado Actual del Sistema

### ✅ Completado
- Bridge br0 creado (192.168.100.1/24)
- KVM funcionando
- Documentación completa
- Scripts de QEMU listos

### ⏸️ En Progreso
- Descarga de ISO Ubuntu 22.04 (2 GB)
- Estima: 7 minutos restantes

### ⏳ Pendiente
- Inicio de VMs
- Instalación de SO en VMs
- Pruebas de conectividad

---

## 🛠️ Comandos Útiles

### Ver progreso de descarga ISO
```bash
ls -lh "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/"*.iso
```

### Cancelar descarga y reiniciar después
```bash
# Presionar Ctrl+C en el terminal donde corre el script
sudo reboot
```

### Continuar con QEMU (después de descarga)
```bash
cd "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/vms"
./start_vm1.sh
./start_vm2.sh

# Conectar con VNC
vncviewer localhost:1  # VM1
vncviewer localhost:2  # VM2
```

---

## ❓ FAQ Rápido

**P: ¿Cuánto falta para la descarga?**
R: ~7 minutos (2 GB a velocidad promedio)

**P: ¿Qué es mejor, QEMU o libvirt?**
R: Para producción: libvirt. Para aprender: QEMU directo es educativo.

**P: ¿Puedo hacer ambos?**
R: Sí, son compatibles. Puedes tener VMs con QEMU y otras con libvirt.

**P: ¿El bridge br0 funciona con ambos?**
R: Sí, ambos pueden usar el mismo bridge.

---

## 📋 Resumen de Archivos

```
/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA/
├── INDEX.md                                  ← Inicio
├── RESUMEN_EJECUTIVO.md                      ← Estado completo
├── GUIA_PRACTICA_BRIDGE_VLAN.md              ← Guía detallada
├── GUIA_RAPIDA_ALTERNATIVAS.md               ← Este archivo
├── SOLUCION_TROUBLESHOOTING_LIBVIRTD.md      ← Troubleshooting
├── DIAGRAMA_ARQUITECTURA.md                  ← Arquitectura
├── crear_vms.sh                              ← Script libvirt (necesita reboot)
├── crear_vms_qemu.sh                         ← Script QEMU (funciona ahora)
└── ubuntu-22.04.5-live-server-amd64.iso      ← Descargando...
```

---

## ⏰ Línea de Tiempo

### Ahora (Sin Reiniciar)
```
Tiempo 0:    Descarga ISO iniciada
Tiempo +7min: ISO descargada
Tiempo +8min: Crear discos virtuales
Tiempo +9min: Iniciar VMs
Tiempo +10min: Conectar por VNC
Tiempo +30min: Instalar SO en VM1
Tiempo +60min: Instalar SO en VM2
Tiempo +65min: ¡Práctica completa!
```

### Con Reinicio
```
Tiempo 0:    Reiniciar sistema
Tiempo +2min: Sistema arrancado
Tiempo +3min: Ejecutar crear_vms.sh
Tiempo +15min: Script descarga ISO y crea VMs
Tiempo +20min: VMs listas, conectar con virt-manager
Tiempo +50min: Instalar SOs
Tiempo +55min: ¡Práctica completa!
```

---

## 💡 Decisión Rápida

**¿Qué hago AHORA?**

1. **Si tengo prisa y puedo reiniciar:**
   ```bash
   sudo reboot
   ```

2. **Si no puedo reiniciar pero tengo 10 minutos:**
   - Esperar a que termine la descarga
   - Seguir con QEMU

3. **Si no tengo tiempo ahora:**
   - Ctrl+C para cancelar
   - Continuar en otro momento

---

**La práctica ESTÁ CASI COMPLETA. Solo falta crear e iniciar las VMs.**

---

**Archivo creado:** 2026-03-12 21:21
