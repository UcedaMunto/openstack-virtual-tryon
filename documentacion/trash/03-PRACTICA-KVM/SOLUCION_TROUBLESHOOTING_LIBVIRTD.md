# Solución al Problema de libvirtd

## Problema Detectado

Durante la configuración de la práctica se detectó que existe un proceso `libvirtd` antiguo (PID 199476) corriendo desde el 10 de marzo que está bloqueando los archivos PID necesarios para iniciar una nueva instancia del servicio.

**Errores observados:**
```
Failed to acquire pid file '/run/libvirtd.pid': Resource temporarily unavailable
Failed to acquire pid file '/run/libvirt/network/driver.pid': Resource temporarily unavailable
```

## Estado Actual del Sistema

### Elementos Funcionando Correctamente
✅ **Bridge br0 creado y activo**
```bash
16: br0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500
    inet 192.168.100.1/24
```

✅ **KVM funcionando**
- Módulos cargados: `kvm_amd`
- Dispositivo `/dev/kvm` disponible
- VM existente corriendo (`ubuntu-guest`) en virbr0

✅ **Red virtual virbr0 operativa**
- Interface vnet0 conectada
- DHCP funcionando

### Problema
❌ **libvirtd socket no accesible**
- Socket `/var/run/libvirt/libvirt-sock` no existe
- Comandos `virsh` no pueden conectar al hipervisor

## Soluciones

### Solución 1: Reinicio del Sistema (Más Rápida y Segura)

La forma más rápida y segura de resolver este problema es reiniciar el sistema:

```bash
sudo reboot
```

**Después del reinicio:**
1. Verificar que libvirtd inicia correctamente:
```bash
sudo systemctl status libvirtd
sudo virsh net-list --all
```

2. El bridge br0 debe seguir configurado (es persistente)
3. Continuar con la práctica desde el paso de creación de la red virtual

### Solución 2: Forzar Eliminación del Proceso (Avanzada)

Si no puedes reiniciar, intenta esta secuencia de pasos:

```bash
# 1. Detener todos los servicios relacionados
sudo systemctl stop libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket
sudo systemctl stop virtlockd.socket virtlogd.socket

# 2. Identificar y matar el proceso libvirtd antiguo
PID=$(cat /run/libvirtd.pid 2>/dev/null || pgrep libvirtd)
sudo kill -9 $PID

# 3. Limpiar archivos PID bloqueados
sudo rm -f /run/libvirtd.pid
sudo rm -f /run/libvirt/network/driver.pid

# 4. Reiniciar servicios
sudo systemctl start libvirtd.socket
sudo systemctl start libvirtd

# 5. Verificar
sudo virsh net-list --all
```

### Solución 3: Usar QEMU Directamente (Sin libvirt)

Si las soluciones anteriores no funcionan, puedes crear y gestionar VMs directamente con QEMU. Ver el archivo `SCRIPTS_CREACION_VMS.sh` para ejemplos.

**Ventajas:**
- No depende de libvirtd
- Control total sobre la configuración
- Útil para entender cómo funciona la virtualización a bajo nivel

**Desventajas:**
- Más comandos para memorizar
- Sin interfaz gráfica fácil (virt-manager)
- Gestión manual de redes

---

## Continuar con la Práctica

### Opción A: Después de Solucionar libvirtd

Una vez que `sudo virsh net-list` funcione, continúa con:

1. Crear la red virtual br0-network:
   ```bash
   sudo virsh net-define /tmp/br0-network.xml
   sudo virsh net-start br0-network
   sudo virsh net-autostart br0-network
   ```

2. Crear las VMs con virt-install (ver guía principal)

### Opción B: Usar Enfoque Alternativo

Si prefieres no lidiar con libvirtd ahora, puedes:

1. Usar los scripts en `SCRIPTS_CREACION_VMS.sh`
2. Gestionar VMs directamente con QEMU
3. El bridge br0 seguirá funcionando correctamente

---

## Verificaciones Post-Solución

Después de aplicar cualquier solución, verifica:

```bash
# 1. libvirtd respondiendo
sudo virsh version

# 2. Redes disponibles
sudo virsh net-list --all

# 3. Bridge activo
ip addr show br0
bridge link show

# 4. Conexión del usuario
virsh -c qemu:///system version
```

**Resultado esperado:**
- Todos los comandos deben ejecutarse sin errores
- `virsh version` debe mostrar la versión de libvirt
- `net-list` debe mostrar al menos la red "default"

---

## Prevención Futura

Para evitar este problema en el futuro:

1. **Gestiona libvirtd con systemd:**
   ```bash
   # Iniciar
   sudo systemctl start libvirtd

   # Detener
   sudo systemctl stop libvirtd

   # NO ejecutar libvirtd manualmente con -d
   ```

2. **Verifica el estado antes de reiniciar:**
   ```bash
   sudo systemctl status libvirtd
   ```

3. **Si necesitas depurar, usa logs:**
   ```bash
   sudo journalctl -u libvirtd -f
   ```

---

## Notas Técnicas

### ¿Por qué ocurrió este problema?

El proceso libvirtd con PID 199476 fue iniciado manualmente (flag `-d` para daemon) fuera del control de systemd, probablemente con:
```bash
/usr/sbin/libvirtd -d
```

Cuando systemd intenta iniciar su propia instancia de libvirtd, encuentra que los archivos PID ya están bloqueados por el proceso manual, causando el conflicto.

### Arquitectura de libvirt en Ubuntu 24.04

Ubuntu 24.04 usa:
- **libvirt 10.0.0** (versión modular)
- **Sockets en** `/run/libvirt/` (antes `/var/run/libvirt/`)
- **Gestión por systemd** con sockets activados bajo demanda

---

## Script de Diagnóstico Rápido

Guarda este script como `diagnostico_libvirt.sh`:

```bash
#!/bin/bash
echo "=== Diagnóstico de libvirt ==="
echo ""
echo "1. Estado del servicio:"
sudo systemctl status libvirtd --no-pager | grep -E "Active|Main PID"
echo ""
echo "2. Procesos libvirtd:"
ps aux | grep libvirtd | grep -v grep
echo ""
echo "3. Archivos PID:"
ls -la /run/libvirtd.pid /run/libvirt/network/driver.pid 2>&1
echo ""
echo "4. Sockets:"
ls -la /run/libvirt/*sock 2>&1
echo ""
echo "5. Conectividad virsh:"
sudo virsh version 2>&1
echo ""
echo "6. Redes virtuales:"
sudo virsh net-list --all 2>&1
echo ""
echo "=== Fin del diagnóstico ==="
```

**Uso:**
```bash
chmod +x diagnostico_libvirt.sh
./diagnostico_libvirt.sh
```

---

## Recursos Adicionales

- Documentación oficial: https://libvirt.org/
- Ubuntu libvirt wiki: https://help.ubuntu.com/community/KVM/
- Logs en tiempo real: `sudo journalctl -u libvirtd -f`
