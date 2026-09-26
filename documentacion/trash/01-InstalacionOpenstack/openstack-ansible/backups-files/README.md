# Respaldo de configuraciones críticas — Laboratorio Kubernetes + CephFS

Generado: 2026-08-23. Contiene copias de todo lo necesario para
reconstruir o auditar el laboratorio sin depender únicamente del estado
en vivo de las VMs.

> **Archivos sensibles:** `kubeconfig/k8-master-admin.conf` (acceso
> `cluster-admin` completo), `ceph/client.k8.keyring.txt` (credencial
> CephX) y `k8s-manifests/*-full.yaml` (contienen secretos en base64:
> contraseñas de MariaDB/WordPress, llave CSI, certificado TLS). No
> subir esta carpeta a un repositorio público. Permisos restringidos a
> `600`/`700` aplicados sobre los archivos y carpeta.

## Contenido

- `guia/` — la guía completa (`guia_kubernetes_ubuntu_24_04_con_vms_kvm_REVISADA_PDF.md`)
  y el reporte de verificación (`VERIFICACION_REQUISITOS_2026-08-23.md`),
  copiados tal como estaban en `kubernetes/` al momento del respaldo.
- `libvirt/` — definición de la red `k8s-lab` (XML original del repo +
  volcado en vivo de `virsh net-dumpxml`) y el listado de VMs/redes
  activas en el host al momento del respaldo.
- `kubeconfig/` — `k8-master-admin.conf` (kubeconfig con credenciales
  `cluster-admin`) y un comando `kubeadm join` válido generado en el
  momento del respaldo (los tokens expiran a las 24h; genera uno nuevo
  con `kubeadm token create --print-join-command` si ya venció).
- `ceph/` — estado del clúster Ceph (`ceph -s`, `fs status`, pools,
  `auth ls`), la keyring completa de `client.k8` (usada por Ceph CSI) y
  el `ceph.conf` local del mon `os-storage01` (incluye el ajuste
  `mon_auth_emergency_allowed_ciphers`, ver sección 24.2.2 de la guía).
- `k8s-manifests/` — volcado en vivo (`kubectl get ... -o yaml`) de todo
  lo aplicado al clúster que solo existía como archivos temporales en
  `k8-master` (no versionados en el repo): `StorageClass`, ConfigMaps y
  Secret de Ceph CSI, namespace/Secrets/PVCs/Deployment/Service/Ingress
  de WordPress, y el `IPAddressPool`/`L2Advertisement` de MetalLB.

## Cómo restaurar con este respaldo

1. Recrear las VMs siguiendo la guía (secciones 0.1 en adelante); si se
   reutiliza el mismo hardware, la red `k8s-lab` puede re-registrarse
   directamente con `libvirt/k8s-lab-network.xml`.
2. Copiar `kubeconfig/k8-master-admin.conf` a `~/.kube/config` en el
   equipo desde el que se administre el clúster.
3. Si Ceph se reconstruye desde cero (sección 24.0 de la guía), usar
   `ceph/client.k8.keyring.txt` para reimportar la identidad CephX con
   `ceph auth import -i <archivo>`, y aplicar el ajuste de
   `mon_auth_emergency_allowed_ciphers` de `ceph/mon-os-storage01-config.txt`
   solo si el nuevo clúster presenta el mismo bug de llaves de 32 bytes.
4. Reaplicar los manifiestos de `k8s-manifests/` con `kubectl apply -f`
   (quitar antes los campos `resourceVersion`, `uid` y `status` si
   `kubectl apply` los rechaza por inmutabilidad).
