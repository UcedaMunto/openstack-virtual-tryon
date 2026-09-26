# 03 — PRACTICA-KVM (LAB 1)

Fuente: `~/Documents/ESPECIALIZACION/LAB 1/PRACTICA`. Práctica de **KVM/QEMU/libvirt** con bridges, VLAN y PlantUML. Es la base conceptual de virtualización del proyecto.

## Qué hay aquí

| Archivo | Contenido |
|---|---|
| `DOCUMENTACION_UNIFICADA.md` | Documento maestro de la práctica |
| `GUIA_PRACTICA_BRIDGE_VLAN.md` | Bridges + VLAN sobre Linux |
| `GUIA_NIC_NETWORK_INTERFACE_CARD.md`, `GUIA_IP_ADDR_SHOW_EXPLICADA.md` | Fundamentos de red |
| `GUIA_USO_BRIDGE01DH.md`, `QUICKREF_BRIDGE01DH.md` | Uso del bridge `bridge01dh` |
| `GUIA_PLANTUML.md`, `CONFIGURACION_VSCODE_PLANTUML.md` | Renderizar diagramas |
| `crear_vms.sh`, `crear_vms_qemu.sh` | Crear VMs (libvirt y qemu directo) |
| `start_vm1_bridge01.sh`, `start_vm2_bridge01.sh`, `stop_vms_bridge01.sh`, `verificar_bridge01.sh` | Ciclo de vida VMs en bridge |
| `SOLUCION_TROUBLESHOOTING_LIBVIRTD.md` | Troubleshooting libvirtd |
| `relaciones.puml` | Diagrama de relaciones |

## Relevancia para el proyecto

- Fundamentos de **bridges/VLAN** → redes físicas del proyecto (V4 §67-68).
- Patrón de **scripts de arranque/parada de VMs** en bridges.
- Configuración de **PlantUML en VS Code** para los diagramas `diagrams/`.
