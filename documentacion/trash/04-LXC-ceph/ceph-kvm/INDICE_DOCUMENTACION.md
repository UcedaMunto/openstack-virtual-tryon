# Índice de Documentación - Ceph KVM

Documentación completa del proyecto Ceph con KVM/libvirt.

---

## 📚 Documentos Principales

### Para Comenzar

| Documento | Propósito | Tiempo |
|-----------|-----------|--------|
| **[QUICK_START.md](QUICK_START.md)** | Levantar cluster en 5 minutos | 5 min |
| **[SECUENCIA_COMANDOS.md](SECUENCIA_COMANDOS.md)** | Guía completa paso a paso con explicaciones | 30-40 min |
| **[DETALLES_SCRIPTS_HOST.md](DETALLES_SCRIPTS_HOST.md)** | Qué ejecuta cada script (00, 10, 20, 30) en HOST | 15-20 min |
| **[COMANDOS_EN_VMS.md](COMANDOS_EN_VMS.md)** | Qué comandos corre cada script DENTRO de las VMs | 15-20 min |

### Para Operar

| Documento | Cuando Usar |
|-----------|------------|
| **[CHEAT_SHEET.md](CHEAT_SHEET.md)** | Referencia rápida de comandos frecuentes |
| [GUIA_CEPH_KVM.md](GUIA_CEPH_KVM.md) | Entender conceptos y arquitectura |
| [README.md](README.md) | Overview del proyecto |

---

## 🗂️ Estructura de la Carpeta

```
ceph-kvm/
├── 📋 Documentación
│   ├── QUICK_START.md          (Inicio rápido - 5 min)
│   ├── SECUENCIA_COMANDOS.md   (Guía completa - ⭐ COMIENZA AQUÍ)
│   ├── DETALLES_SCRIPTS_HOST.md (Qué hace cada script - 🖥️ HOST)
│   ├── COMANDOS_EN_VMS.md      (Qué corre adentro - 🔧 VMs)
│   ├── CHEAT_SHEET.md          (Referencia rápida)
│   ├── GUIA_CEPH_KVM.md        (Arquitectura y conceptos)
│   ├── README.md               (Overview)
│   └── INDICE_DOCUMENTACION.md (Este archivo)
│
├── ⚙️ Scripts de Ciclo de Vida
│   ├── up.sh                   (Levantar todo)
│   ├── start.sh                (Iniciar VMs existentes)
│   ├── stop.sh                 (Apagar VMs)
│   ├── reset.sh                (Destroy + Up)
│   ├── destroy.sh              (Borrar TODO)
│   └── status.sh               (Ver estado)
│
├── 🔧 Scripts de Infraestructura
│   └── scripts/
│       ├── common.sh           (Funciones compartidas)
│       ├── 00-check-prereqs.sh (Verificar prerequisitos)
│       ├── 10-create-networks.sh (Crear redes libvirt)
│       ├── 20-create-vms.sh    (Crear VMs con cloud-init)
│       ├── 30-bootstrap-ceph.sh (Instalar y configurar Ceph)
│       ├── prepare-infra.sh    (Wrapper fases 0-2)
│       └── setup-cluster.sh    (Wrapper fase 3)
│
├── ⚙️ Configuración
│   └── config/
│       └── cluster.env         (Variables configurables: IPs, passwords, tamaños)
│
└── ☁️ Cloud-Init
    └── cloud-init/
        └── (Plantillas cloud-init para provisioning)
```

---

## 🚀 Flujos de Trabajo

### Flujo 1: "Dame Todo Ya" (5 minutos)

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
chmod +x *.sh scripts/*.sh
./up.sh
./status.sh
# Dashboard: https://192.168.130.100:8443
```

→ **Ir a:** [QUICK_START.md](QUICK_START.md)

---

### Flujo 2: "Quiero Entender Cada Paso" (30-40 minutos)

1. Lee: [SECUENCIA_COMANDOS.md - Requisitos previos](SECUENCIA_COMANDOS.md#requisitos-previos-del-host)
2. Ejecuta cada fase:
   ```bash
   bash scripts/00-check-prereqs.sh
   bash scripts/10-create-networks.sh
   bash scripts/20-create-vms.sh
   # Espera 2-3 minutos
   bash scripts/30-bootstrap-ceph.sh
   ./status.sh
   ```

→ **Ir a:** [SECUENCIA_COMANDOS.md - Modo Paso a Paso](SECUENCIA_COMANDOS.md#modo-paso-a-paso-con-explicaciones-detalladas)

---

### Flujo 3: "El Cluster Está Roto"

1. Verifica estado actual:
   ```bash
   ./status.sh
   ```
2. Consulta troubleshooting:
   - [CHEAT_SHEET.md - Troubleshooting](CHEAT_SHEET.md#-troubleshooting)
   - [SECUENCIA_COMANDOS.md - Troubleshooting](SECUENCIA_COMANDOS.md#notas-importantes)
3. Si todo falla, reset:
   ```bash
   ./reset.sh
   ```

→ **Ir a:** [CHEAT_SHEET.md](CHEAT_SHEET.md#-troubleshooting)

---

### Flujo 4: "Operaciones Diarias"

- **Ver estado:** `./status.sh`
- **Apagar:** `./stop.sh` + `./start.sh`
- **Recrear:** `./reset.sh`
- **Borrar:** `./destroy.sh`

→ **Ir a:** [CHEAT_SHEET.md - Operaciones Principales](CHEAT_SHEET.md#-operaciones-principales)

---

### Flujo 5: "Necesito un Comando Específico"

→ **Consultar:** [CHEAT_SHEET.md](CHEAT_SHEET.md)

Ejemplos:
- SSH a nodos
- Verificar estado
- Administrar RBD
- Cambiar configuración

---

## 🎓 Matriz de Decisión

```
¿Cuál es tu situación?

├─ Quiero levantar ya
│  └─ LECTURA: QUICK_START.md (5 min)
│     LUEGO: ./up.sh
│
├─ Quiero entender qué hace cada comando
│  └─ LECTURA: SECUENCIA_COMANDOS.md (30 min)
│     LUEGO: Ejecutar cada fase
│
├─ Quiero hacer operaciones comunes (start/stop/reset)
│  └─ REFERENCIA: CHEAT_SHEET.md
│
├─ Necesito troubleshooting
│  └─ CONSULTAR: 
│     1. CHEAT_SHEET.md#troubleshooting
│     2. SECUENCIA_COMANDOS.md#notas-importantes
│
├─ Quiero entender la arquitectura
│  └─ LECTURA: GUIA_CEPH_KVM.md
│
└─ No sé por dónde empezar
   └─ VER ESTE DOCUMENTO (que estás leyendo)
```

---

## 📊 Documentos por Tipo

### 🏃 Para Ejecutar (Solo Comandos)

- [QUICK_START.md](QUICK_START.md)
- [CHEAT_SHEET.md](CHEAT_SHEET.md)

### 📖 Para Aprender (Con Explicaciones)

- [SECUENCIA_COMANDOS.md](SECUENCIA_COMANDOS.md) - COMPLETO
- [GUIA_CEPH_KVM.md](GUIA_CEPH_KVM.md)
- [README.md](README.md)

### 📝 Para Consultar (Referencia)

- [CHEAT_SHEET.md](CHEAT_SHEET.md)
- config/cluster.env

---

## 🔗 Enlace a Documentación Externa

- **Documentación Ceph:** https://docs.ceph.com/en/quincy/
- **Guía KVM/libvirt:** https://libvirt.org/
- **Cloud-init:** https://cloud-init.io/

---

## ✅ Checklist de Primeros Pasos

**Primero (requisitos previos del host):**
```bash
[ ] sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients virtinst cloud-image-utils qemu-utils
[ ] sudo usermod -aG libvirt "$USER"
[ ] newgrp libvirt
[ ] virsh list --all  # Debería funcionar sin sudo
```

**Luego (levantar cluster):**
```bash
[ ] cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
[ ] chmod +x *.sh scripts/*.sh
[ ] ./up.sh
[ ] sleep 30 && ./status.sh
[ ] ssh -i ~/.ssh/id_rsa ubuntu@192.168.130.100 'sudo ceph -s'
```

**Acceso:**
```bash
[ ] Abrir https://192.168.130.100:8443 en navegador
[ ] Login: admin / AdminCeph2026!
```

---

## 📞 Referencia de Soporte

### Problema: Las VMs no arrancan
→ Ver: [SECUENCIA_COMANDOS.md - Fase 3](SECUENCIA_COMANDOS.md#fase-3-crear-máquinas-virtuales-con-cloud-init)

### Problema: SSH timeout
→ Ver: [SECUENCIA_COMANDOS.md - Fase 4](SECUENCIA_COMANDOS.md#fase-4-esperar-inicialización-cloud-init)

### Problema: Ceph no inicia
→ Ver: [SECUENCIA_COMANDOS.md - Fase 5](SECUENCIA_COMANDOS.md#fase-5-bootstrap-del-cluster-ceph)

### Problema: Cluster en HEALTH_WARN
→ Ver: [CHEAT_SHEET.md - Troubleshooting](CHEAT_SHEET.md#cluster-en-health_warn)

---

## 📈 Actualizaciones Recientes

| Fecha | Cambio |
|-------|--------|
| Apr 24, 2026 | Creación de SECUENCIA_COMANDOS.md, QUICK_START.md, CHEAT_SHEET.md, INDICE_DOCUMENTACION.md |
| - | Cambio: package_update en cloud-init a false para boot rápido |
| - | Cambio: SSH wait timeout a 200 intentos (17 minutos) |

---

## 🎯 Objetivo del Proyecto

Proporcionar un laboratorio Ceph **completamente automatizado** en KVM/libvirt con:

✅ 5 VMs (1 admin, 1 mon, 3 OSDs)  
✅ Dos redes virtuales (admin + data)  
✅ Cluster Ceph Quincy funcional  
✅ Dashboard web  
✅ Almacenamiento RBD listo  
✅ Ciclo de vida (up/down/reset)  
✅ Documentación completa en español  

---

**Próxima lectura recomendada:**
1. Si tienes prisa: [QUICK_START.md](QUICK_START.md)
2. Si tienes tiempo: [SECUENCIA_COMANDOS.md](SECUENCIA_COMANDOS.md)
3. Si necesitas referencia: [CHEAT_SHEET.md](CHEAT_SHEET.md)

---

**Versión:** 1.0 | **Fecha:** April 24, 2026 | **Ceph:** Quincy 17.2.9
