# Quick Start Ceph KVM

## El Más Rápido Posible (5 minutos)

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm
chmod +x *.sh scripts/*.sh
./up.sh
sleep 30
./status.sh
```

**Dashboard:** `https://192.168.130.100:8443` | Admin / `AdminCeph2026!`

---

## Con Explicaciones (Paso a Paso)

**→ VER:** [SECUENCIA_COMANDOS.md](SECUENCIA_COMANDOS.md)

Contiene:
- ✅ Requisitos del host (instalación packages)
- ✅ Modo Rápido (3 comandos)
- ✅ **Modo Paso a Paso COMPLETO** con explicaciones de cada fase
- ✅ Operaciones diarias (start, stop, reset, destroy)
- ✅ Verificación del cluster
- ✅ Troubleshooting

---

## Operaciones Comunes

```bash
cd /home/uceda/Documents/ESPECIALIZACION/LXC/ceph-kvm

# Ver estado
./status.sh

# Apagar (sin borrar)
./stop.sh

# Reactivar
./start.sh

# Reset completo
./reset.sh

# Borrar TODO
./destroy.sh
```

---

## Si Algo Falla

1. **Lee primera:** [SECUENCIA_COMANDOS.md](SECUENCIA_COMANDOS.md#troubleshooting)
2. **Verificar SSH:** 
   ```bash
   ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@192.168.130.100 "echo OK"
   ```
3. **Reset completo:**
   ```bash
   ./reset.sh
   ```

---

**Documentación detallada:** Ver [SECUENCIA_COMANDOS.md](SECUENCIA_COMANDOS.md)
