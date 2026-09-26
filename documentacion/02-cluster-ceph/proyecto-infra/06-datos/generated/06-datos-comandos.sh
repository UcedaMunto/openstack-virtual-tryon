#!/usr/bin/env bash
set -euo pipefail

# Archivo generado por create-kvm-vm.sh --comandos
# Ejecuta este archivo cuando quieras crear las VMs manualmente.

# 2026-04-30 23:17:58 ------------------------------------------------
# VM: redis-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/redis-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/redis-1.qcow2 30G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-redis-1.yaml <<'EOF'
#cloud-config
hostname: redis-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$S0yTsmOiRTCULL6T$xBcF63nvSzOH9QoPqgLh8err6Hsl.O4oVj/sLprw5jItjQRF9MEC2chDyfZ5NwloTyvkgATp3IvI5cAYULSXQ0
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 redis-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAACFwAAAAdzc2gtcn
      NhAAAAAwEAAQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5FDS4gPZbQAnf3Zeg7TJok
      FKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87xvjyCXSKF3FRGkoDZLJOd
      gUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz11tsMBacc8E/jyzXqjxl9
      QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDPIf59O9mf2m+muZKfq8KZ
      j0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T8fQBaRS3Cmu/d3m9LRYZ
      XU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5ELOGb4pFl0y3e4uXRnbBr
      Wa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5mqrE0DXd/9zXQjYbAfGa
      tPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrDnfFIv38LOphPD3tAq0Op
      cMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jwyc8tbD/GZwxqezZ8J7+p
      L3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e0KLaPwEX35W3+edKykhl
      MAAAdYd5mCNXeZgjUAAAAHc3NoLXJzYQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5F
      DS4gPZbQAnf3Zeg7TJokFKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87x
      vjyCXSKF3FRGkoDZLJOdgUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz1
      1tsMBacc8E/jyzXqjxl9QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDP
      If59O9mf2m+muZKfq8KZj0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T
      8fQBaRS3Cmu/d3m9LRYZXU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5E
      LOGb4pFl0y3e4uXRnbBrWa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5
      mqrE0DXd/9zXQjYbAfGatPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrD
      nfFIv38LOphPD3tAq0OpcMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jw
      yc8tbD/GZwxqezZ8J7+pL3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e
      0KLaPwEX35W3+edKykhlMAAAADAQABAAACAFfMFbrepyBIShmIMXaW8pwp7ueWvE8VSOKC
      /ZiobQojDYhXu/+UJ9T3SqKk1TqUC+0Pul9IXQ11o/o8ikkHaNsGpxzgemxDQO44tS4aCG
      WHiNnxFfqxgJf3hh9FqksLIZUrD954+9aXPknvrcTVtq0BfAlT44cnV4kMXVXTyWwH+NXR
      jjWvkVzy3PXc2+nVozLVAG669WOpT/aHNtdlQuH2oHSOA21pqdb1Pp5y2jNSDaW4YeSbL+
      fhF40jQoaszhmWulmLVFxhJQqeUGAz6dRIPOMRt8ALQ4BGipSqkpVmyQ80rMu61d2blWO8
      cbS8O/XnjWwUgfxZAvXiDOvJ3lofz9GTojmksB5BKQc0Z1wnbKPlltlnvE7oSOUgwcZS/N
      VkYNYSf8E+AryTfZYm8gM4mumbW0qJ2hj7OgYIsPJetZ0E8hMlP6sHlR1MOlZSjWeInX/i
      Jf4VA4xgnBxKmSsPnrf1/AlLjJtmuugyWfMIyreS2qhM/5Mus1CjkqD7QySk9KBgAfBc7B
      jh5KEoSRMcsH3jotUplQDexZCHTXrap2818PXCwTNdQmFz6jg3Me+y7Iw8AKHwjd/2ULUQ
      1K/HBubxjxEcQdkKoeni4EdSM+1loTOz9EQoisCOcYYi2DsVvXpQ44v6u2dTWMWhGzp5Ck
      eiWgsYMhga4i2fQxWhAAABAHHA3Uojvz23DL/Tukq2jfTaQvU/1tw3oPFoMI7PyUUYsbH+
      JQeOiUP6FDKEFktcv4pJaZQpeQKAuJYpH+VTo91m67solgxHnS0hdmDUVPBRlxlZO8b98B
      uLC5g0LiEUohF2GMmXSCkqZ8gtbxD+Gis0ODqEtimC3WVlDL/cRXku19LFU2NJqrvt6CY1
      ELmS991Fnhu7GlHw0cclpFFyVANh3eIs0FzvnmfF58Q2gktmFwbObwO3OoH3ne8S5xom6i
      PVK/tZ4DPx1JkT4hZG8bdMNin8EchydHkkSdcnoXa/AwpqPTyeUMXXu4jEFjl/ka4Z25/b
      ZwWxf+1fDcXAZpQAAAEBAPUKr34Xy59Rox+EozpI/EBk4Xjf5dKV3ZE6K8ygJbwc2XYy1r
      b1PQtyGyIX6fceFqPmJU1YN5NPsyB1CRtKg+l08U6DjPymcPoF2047qEW+NTd2tRfuACYm
      fuhzibhC86homq241LmBNuNKdVHxB84Ujw4E4CFjkkZyTBA3bZHLdZ9qccNfVMBo3lwtT/
      BpzRVUDkOcymk66a203oIxKfSD5819bLiHqwzZgF1nji/MWaRs0rkX42r1jBLGZMaOhGDE
      +5yTIro0b9o+TvpnbiSfl63bJ2HrKTG7oycNsR6CEtQIwbSDWgIQPR+5rgWLRixz3Y8lZC
      C4KILG/Cuw2vsAAAEBAPFvtdiCoxgR2IIdiuTIHzhh7RgdC8tbcdrtcI/4U8qqLFeb0xQt
      WDHYTQIf67we+2/vtxUcDZEJJO0EuRoYKXQTOBQo+jJqqrAmCJf+nZqRVXL/YA5JFX7Oiq
      N8cySPohyYSf4XP0lfYsbF2LVz0r/yGDOMfMeNOad/5kzGBPg2fClGVGYbAV1TW5zzIMi8
      sPNvjaJl7CJHtnZDrLtmH/b8yzM+sfZ0UDgvUKjfO9pd1Xz/4312QLtr4bCZSBWeodVapZ
      D4Mys/n5WucdEqVdUyUNZkWSz5i320KLvnmbEQ4fqYHR6QEDC/CPa9VrmyHjAJJ7+43+Mn
      ks4t5UWeIokAAAAfdWNlZGFAdWNlZGEtVGhpbmtQYWQtTDE1LUdlbi0yYQECAwQ=
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-redis-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:56
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.56/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo redis-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name redis-1 \n    --ram 2048 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/redis-1.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:56 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-redis-1.yaml\,network-config=/tmp/network-config-redis-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ redis-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:17:58 ------------------------------------------------
# VM: maxscale-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/maxscale-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/maxscale-1.qcow2 30G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-maxscale-1.yaml <<'EOF'
#cloud-config
hostname: maxscale-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$1UP4LCRnhMD4j64Z$COgTuQfoy0kbg.7EDv7cIJVmplUlJCynO57UOTXeUpBDg5REJuCjQIZjYaRJbEkJsKaX7XGiLZ0woQFGqvtz6.
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 maxscale-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-maxscale-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:60
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.60/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo maxscale-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name maxscale-1 \n    --ram 2048 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/maxscale-1.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:60 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-maxscale-1.yaml\,network-config=/tmp/network-config-maxscale-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ maxscale-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:17:58 ------------------------------------------------
# VM: mariadb-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/mariadb-1.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-1-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/mariadb-1-data.qcow2 40G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-mariadb-1.yaml <<'EOF'
#cloud-config
hostname: mariadb-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$d5owbjMSx6ClDNT7$/xbISseIDG7Hpve9IaO.XF9fBmGnxDd2tihP/XrTmvbCj1EppJzCYZ76VpK4ikCFo6gsh9M54i0mCZRDhu4X5.
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 mariadb-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAACFwAAAAdzc2gtcn
      NhAAAAAwEAAQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5FDS4gPZbQAnf3Zeg7TJok
      FKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87xvjyCXSKF3FRGkoDZLJOd
      gUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz11tsMBacc8E/jyzXqjxl9
      QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDPIf59O9mf2m+muZKfq8KZ
      j0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T8fQBaRS3Cmu/d3m9LRYZ
      XU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5ELOGb4pFl0y3e4uXRnbBr
      Wa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5mqrE0DXd/9zXQjYbAfGa
      tPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrDnfFIv38LOphPD3tAq0Op
      cMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jwyc8tbD/GZwxqezZ8J7+p
      L3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e0KLaPwEX35W3+edKykhl
      MAAAdYd5mCNXeZgjUAAAAHc3NoLXJzYQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5F
      DS4gPZbQAnf3Zeg7TJokFKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87x
      vjyCXSKF3FRGkoDZLJOdgUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz1
      1tsMBacc8E/jyzXqjxl9QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDP
      If59O9mf2m+muZKfq8KZj0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T
      8fQBaRS3Cmu/d3m9LRYZXU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5E
      LOGb4pFl0y3e4uXRnbBrWa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5
      mqrE0DXd/9zXQjYbAfGatPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrD
      nfFIv38LOphPD3tAq0OpcMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jw
      yc8tbD/GZwxqezZ8J7+pL3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e
      0KLaPwEX35W3+edKykhlMAAAADAQABAAACAFfMFbrepyBIShmIMXaW8pwp7ueWvE8VSOKC
      /ZiobQojDYhXu/+UJ9T3SqKk1TqUC+0Pul9IXQ11o/o8ikkHaNsGpxzgemxDQO44tS4aCG
      WHiNnxFfqxgJf3hh9FqksLIZUrD954+9aXPknvrcTVtq0BfAlT44cnV4kMXVXTyWwH+NXR
      jjWvkVzy3PXc2+nVozLVAG669WOpT/aHNtdlQuH2oHSOA21pqdb1Pp5y2jNSDaW4YeSbL+
      fhF40jQoaszhmWulmLVFxhJQqeUGAz6dRIPOMRt8ALQ4BGipSqkpVmyQ80rMu61d2blWO8
      cbS8O/XnjWwUgfxZAvXiDOvJ3lofz9GTojmksB5BKQc0Z1wnbKPlltlnvE7oSOUgwcZS/N
      VkYNYSf8E+AryTfZYm8gM4mumbW0qJ2hj7OgYIsPJetZ0E8hMlP6sHlR1MOlZSjWeInX/i
      Jf4VA4xgnBxKmSsPnrf1/AlLjJtmuugyWfMIyreS2qhM/5Mus1CjkqD7QySk9KBgAfBc7B
      jh5KEoSRMcsH3jotUplQDexZCHTXrap2818PXCwTNdQmFz6jg3Me+y7Iw8AKHwjd/2ULUQ
      1K/HBubxjxEcQdkKoeni4EdSM+1loTOz9EQoisCOcYYi2DsVvXpQ44v6u2dTWMWhGzp5Ck
      eiWgsYMhga4i2fQxWhAAABAHHA3Uojvz23DL/Tukq2jfTaQvU/1tw3oPFoMI7PyUUYsbH+
      JQeOiUP6FDKEFktcv4pJaZQpeQKAuJYpH+VTo91m67solgxHnS0hdmDUVPBRlxlZO8b98B
      uLC5g0LiEUohF2GMmXSCkqZ8gtbxD+Gis0ODqEtimC3WVlDL/cRXku19LFU2NJqrvt6CY1
      ELmS991Fnhu7GlHw0cclpFFyVANh3eIs0FzvnmfF58Q2gktmFwbObwO3OoH3ne8S5xom6i
      PVK/tZ4DPx1JkT4hZG8bdMNin8EchydHkkSdcnoXa/AwpqPTyeUMXXu4jEFjl/ka4Z25/b
      ZwWxf+1fDcXAZpQAAAEBAPUKr34Xy59Rox+EozpI/EBk4Xjf5dKV3ZE6K8ygJbwc2XYy1r
      b1PQtyGyIX6fceFqPmJU1YN5NPsyB1CRtKg+l08U6DjPymcPoF2047qEW+NTd2tRfuACYm
      fuhzibhC86homq241LmBNuNKdVHxB84Ujw4E4CFjkkZyTBA3bZHLdZ9qccNfVMBo3lwtT/
      BpzRVUDkOcymk66a203oIxKfSD5819bLiHqwzZgF1nji/MWaRs0rkX42r1jBLGZMaOhGDE
      +5yTIro0b9o+TvpnbiSfl63bJ2HrKTG7oycNsR6CEtQIwbSDWgIQPR+5rgWLRixz3Y8lZC
      C4KILG/Cuw2vsAAAEBAPFvtdiCoxgR2IIdiuTIHzhh7RgdC8tbcdrtcI/4U8qqLFeb0xQt
      WDHYTQIf67we+2/vtxUcDZEJJO0EuRoYKXQTOBQo+jJqqrAmCJf+nZqRVXL/YA5JFX7Oiq
      N8cySPohyYSf4XP0lfYsbF2LVz0r/yGDOMfMeNOad/5kzGBPg2fClGVGYbAV1TW5zzIMi8
      sPNvjaJl7CJHtnZDrLtmH/b8yzM+sfZ0UDgvUKjfO9pd1Xz/4312QLtr4bCZSBWeodVapZ
      D4Mys/n5WucdEqVdUyUNZkWSz5i320KLvnmbEQ4fqYHR6QEDC/CPa9VrmyHjAJJ7+43+Mn
      ks4t5UWeIokAAAAfdWNlZGFAdWNlZGEtVGhpbmtQYWQtTDE1LUdlbi0yYQECAwQ=
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-mariadb-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:61
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.61/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo mariadb-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name mariadb-1 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/mariadb-1.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/mariadb-1-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:61 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-mariadb-1.yaml\,network-config=/tmp/network-config-mariadb-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ mariadb-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:17:58 ------------------------------------------------
# VM: mariadb-2
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-2.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/mariadb-2.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-2-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/mariadb-2-data.qcow2 40G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-mariadb-2.yaml <<'EOF'
#cloud-config
hostname: mariadb-2
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$4AThg225.7NFjCTz$JXsndQHBrVUHpYmIB1ekr16uvI6U3atnM1xhbgi6AYsm9hjzJGN89tgCa/asF148vDjpfUS1GlMQdWdjj9zaT0
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 mariadb-2
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-mariadb-2.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:62
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.62/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo mariadb-2 >/dev/null 2>&1; then
  sudo virt-install \
    --name mariadb-2 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/mariadb-2.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/mariadb-2-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:62 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-mariadb-2.yaml\,network-config=/tmp/network-config-mariadb-2.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ mariadb-2\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:17:58 ------------------------------------------------
# VM: mariadb-3
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-3.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/mariadb-3.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-3-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/mariadb-3-data.qcow2 40G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-mariadb-3.yaml <<'EOF'
#cloud-config
hostname: mariadb-3
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$qWTOXvmkwGKkL9dj$zcNkd/9Jf0zuNNRJop8krYkEiJV8PHcg9yABsDQNl9EkbQq5Ywjy0WOSsv2PBLOeD8iam8V2.vRgKxnXqTGgF.
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 mariadb-3
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAACFwAAAAdzc2gtcn
      NhAAAAAwEAAQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5FDS4gPZbQAnf3Zeg7TJok
      FKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87xvjyCXSKF3FRGkoDZLJOd
      gUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz11tsMBacc8E/jyzXqjxl9
      QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDPIf59O9mf2m+muZKfq8KZ
      j0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T8fQBaRS3Cmu/d3m9LRYZ
      XU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5ELOGb4pFl0y3e4uXRnbBr
      Wa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5mqrE0DXd/9zXQjYbAfGa
      tPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrDnfFIv38LOphPD3tAq0Op
      cMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jwyc8tbD/GZwxqezZ8J7+p
      L3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e0KLaPwEX35W3+edKykhl
      MAAAdYd5mCNXeZgjUAAAAHc3NoLXJzYQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5F
      DS4gPZbQAnf3Zeg7TJokFKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87x
      vjyCXSKF3FRGkoDZLJOdgUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz1
      1tsMBacc8E/jyzXqjxl9QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDP
      If59O9mf2m+muZKfq8KZj0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T
      8fQBaRS3Cmu/d3m9LRYZXU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5E
      LOGb4pFl0y3e4uXRnbBrWa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5
      mqrE0DXd/9zXQjYbAfGatPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrD
      nfFIv38LOphPD3tAq0OpcMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jw
      yc8tbD/GZwxqezZ8J7+pL3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e
      0KLaPwEX35W3+edKykhlMAAAADAQABAAACAFfMFbrepyBIShmIMXaW8pwp7ueWvE8VSOKC
      /ZiobQojDYhXu/+UJ9T3SqKk1TqUC+0Pul9IXQ11o/o8ikkHaNsGpxzgemxDQO44tS4aCG
      WHiNnxFfqxgJf3hh9FqksLIZUrD954+9aXPknvrcTVtq0BfAlT44cnV4kMXVXTyWwH+NXR
      jjWvkVzy3PXc2+nVozLVAG669WOpT/aHNtdlQuH2oHSOA21pqdb1Pp5y2jNSDaW4YeSbL+
      fhF40jQoaszhmWulmLVFxhJQqeUGAz6dRIPOMRt8ALQ4BGipSqkpVmyQ80rMu61d2blWO8
      cbS8O/XnjWwUgfxZAvXiDOvJ3lofz9GTojmksB5BKQc0Z1wnbKPlltlnvE7oSOUgwcZS/N
      VkYNYSf8E+AryTfZYm8gM4mumbW0qJ2hj7OgYIsPJetZ0E8hMlP6sHlR1MOlZSjWeInX/i
      Jf4VA4xgnBxKmSsPnrf1/AlLjJtmuugyWfMIyreS2qhM/5Mus1CjkqD7QySk9KBgAfBc7B
      jh5KEoSRMcsH3jotUplQDexZCHTXrap2818PXCwTNdQmFz6jg3Me+y7Iw8AKHwjd/2ULUQ
      1K/HBubxjxEcQdkKoeni4EdSM+1loTOz9EQoisCOcYYi2DsVvXpQ44v6u2dTWMWhGzp5Ck
      eiWgsYMhga4i2fQxWhAAABAHHA3Uojvz23DL/Tukq2jfTaQvU/1tw3oPFoMI7PyUUYsbH+
      JQeOiUP6FDKEFktcv4pJaZQpeQKAuJYpH+VTo91m67solgxHnS0hdmDUVPBRlxlZO8b98B
      uLC5g0LiEUohF2GMmXSCkqZ8gtbxD+Gis0ODqEtimC3WVlDL/cRXku19LFU2NJqrvt6CY1
      ELmS991Fnhu7GlHw0cclpFFyVANh3eIs0FzvnmfF58Q2gktmFwbObwO3OoH3ne8S5xom6i
      PVK/tZ4DPx1JkT4hZG8bdMNin8EchydHkkSdcnoXa/AwpqPTyeUMXXu4jEFjl/ka4Z25/b
      ZwWxf+1fDcXAZpQAAAEBAPUKr34Xy59Rox+EozpI/EBk4Xjf5dKV3ZE6K8ygJbwc2XYy1r
      b1PQtyGyIX6fceFqPmJU1YN5NPsyB1CRtKg+l08U6DjPymcPoF2047qEW+NTd2tRfuACYm
      fuhzibhC86homq241LmBNuNKdVHxB84Ujw4E4CFjkkZyTBA3bZHLdZ9qccNfVMBo3lwtT/
      BpzRVUDkOcymk66a203oIxKfSD5819bLiHqwzZgF1nji/MWaRs0rkX42r1jBLGZMaOhGDE
      +5yTIro0b9o+TvpnbiSfl63bJ2HrKTG7oycNsR6CEtQIwbSDWgIQPR+5rgWLRixz3Y8lZC
      C4KILG/Cuw2vsAAAEBAPFvtdiCoxgR2IIdiuTIHzhh7RgdC8tbcdrtcI/4U8qqLFeb0xQt
      WDHYTQIf67we+2/vtxUcDZEJJO0EuRoYKXQTOBQo+jJqqrAmCJf+nZqRVXL/YA5JFX7Oiq
      N8cySPohyYSf4XP0lfYsbF2LVz0r/yGDOMfMeNOad/5kzGBPg2fClGVGYbAV1TW5zzIMi8
      sPNvjaJl7CJHtnZDrLtmH/b8yzM+sfZ0UDgvUKjfO9pd1Xz/4312QLtr4bCZSBWeodVapZ
      D4Mys/n5WucdEqVdUyUNZkWSz5i320KLvnmbEQ4fqYHR6QEDC/CPa9VrmyHjAJJ7+43+Mn
      ks4t5UWeIokAAAAfdWNlZGFAdWNlZGEtVGhpbmtQYWQtTDE1LUdlbi0yYQECAwQ=
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-mariadb-3.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:63
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.63/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo mariadb-3 >/dev/null 2>&1; then
  sudo virt-install \
    --name mariadb-3 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/mariadb-3.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/mariadb-3-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:63 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-mariadb-3.yaml\,network-config=/tmp/network-config-mariadb-3.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ mariadb-3\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:17:58 ------------------------------------------------
# VM: cephfs-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/cephfs-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/cephfs-1.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/cephfs-1-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/cephfs-1-data.qcow2 80G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-cephfs-1.yaml <<'EOF'
#cloud-config
hostname: cephfs-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$aJ90jzHQD5wXtWSy$mTk.eTKvNpzU6ekTMSD7nQzcvKEt/CKNMJkzlptej4lOg97W8x9tceMkiBQcjHpgZp8RolfQsPHrP9bmnj0pL/
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 cephfs-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-cephfs-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:64
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.64/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo cephfs-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name cephfs-1 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/cephfs-1.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/cephfs-1-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:64 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-cephfs-1.yaml\,network-config=/tmp/network-config-cephfs-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ cephfs-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:21:08 ------------------------------------------------
# VM: redis-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/redis-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/redis-1.qcow2 30G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-redis-1.yaml <<'EOF'
#cloud-config
hostname: redis-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$emA4XjN/5RebpsOm$2ub8rd9lsLOujGojnt2HYyy2l3gMls.vadJYivkOev.QpQd207my121ussegh0bx0jTd0kGjTIVUftLoLBcbC0
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 redis-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAACFwAAAAdzc2gtcn
      NhAAAAAwEAAQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5FDS4gPZbQAnf3Zeg7TJok
      FKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87xvjyCXSKF3FRGkoDZLJOd
      gUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz11tsMBacc8E/jyzXqjxl9
      QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDPIf59O9mf2m+muZKfq8KZ
      j0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T8fQBaRS3Cmu/d3m9LRYZ
      XU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5ELOGb4pFl0y3e4uXRnbBr
      Wa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5mqrE0DXd/9zXQjYbAfGa
      tPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrDnfFIv38LOphPD3tAq0Op
      cMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jwyc8tbD/GZwxqezZ8J7+p
      L3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e0KLaPwEX35W3+edKykhl
      MAAAdYd5mCNXeZgjUAAAAHc3NoLXJzYQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5F
      DS4gPZbQAnf3Zeg7TJokFKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87x
      vjyCXSKF3FRGkoDZLJOdgUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz1
      1tsMBacc8E/jyzXqjxl9QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDP
      If59O9mf2m+muZKfq8KZj0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T
      8fQBaRS3Cmu/d3m9LRYZXU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5E
      LOGb4pFl0y3e4uXRnbBrWa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5
      mqrE0DXd/9zXQjYbAfGatPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrD
      nfFIv38LOphPD3tAq0OpcMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jw
      yc8tbD/GZwxqezZ8J7+pL3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e
      0KLaPwEX35W3+edKykhlMAAAADAQABAAACAFfMFbrepyBIShmIMXaW8pwp7ueWvE8VSOKC
      /ZiobQojDYhXu/+UJ9T3SqKk1TqUC+0Pul9IXQ11o/o8ikkHaNsGpxzgemxDQO44tS4aCG
      WHiNnxFfqxgJf3hh9FqksLIZUrD954+9aXPknvrcTVtq0BfAlT44cnV4kMXVXTyWwH+NXR
      jjWvkVzy3PXc2+nVozLVAG669WOpT/aHNtdlQuH2oHSOA21pqdb1Pp5y2jNSDaW4YeSbL+
      fhF40jQoaszhmWulmLVFxhJQqeUGAz6dRIPOMRt8ALQ4BGipSqkpVmyQ80rMu61d2blWO8
      cbS8O/XnjWwUgfxZAvXiDOvJ3lofz9GTojmksB5BKQc0Z1wnbKPlltlnvE7oSOUgwcZS/N
      VkYNYSf8E+AryTfZYm8gM4mumbW0qJ2hj7OgYIsPJetZ0E8hMlP6sHlR1MOlZSjWeInX/i
      Jf4VA4xgnBxKmSsPnrf1/AlLjJtmuugyWfMIyreS2qhM/5Mus1CjkqD7QySk9KBgAfBc7B
      jh5KEoSRMcsH3jotUplQDexZCHTXrap2818PXCwTNdQmFz6jg3Me+y7Iw8AKHwjd/2ULUQ
      1K/HBubxjxEcQdkKoeni4EdSM+1loTOz9EQoisCOcYYi2DsVvXpQ44v6u2dTWMWhGzp5Ck
      eiWgsYMhga4i2fQxWhAAABAHHA3Uojvz23DL/Tukq2jfTaQvU/1tw3oPFoMI7PyUUYsbH+
      JQeOiUP6FDKEFktcv4pJaZQpeQKAuJYpH+VTo91m67solgxHnS0hdmDUVPBRlxlZO8b98B
      uLC5g0LiEUohF2GMmXSCkqZ8gtbxD+Gis0ODqEtimC3WVlDL/cRXku19LFU2NJqrvt6CY1
      ELmS991Fnhu7GlHw0cclpFFyVANh3eIs0FzvnmfF58Q2gktmFwbObwO3OoH3ne8S5xom6i
      PVK/tZ4DPx1JkT4hZG8bdMNin8EchydHkkSdcnoXa/AwpqPTyeUMXXu4jEFjl/ka4Z25/b
      ZwWxf+1fDcXAZpQAAAEBAPUKr34Xy59Rox+EozpI/EBk4Xjf5dKV3ZE6K8ygJbwc2XYy1r
      b1PQtyGyIX6fceFqPmJU1YN5NPsyB1CRtKg+l08U6DjPymcPoF2047qEW+NTd2tRfuACYm
      fuhzibhC86homq241LmBNuNKdVHxB84Ujw4E4CFjkkZyTBA3bZHLdZ9qccNfVMBo3lwtT/
      BpzRVUDkOcymk66a203oIxKfSD5819bLiHqwzZgF1nji/MWaRs0rkX42r1jBLGZMaOhGDE
      +5yTIro0b9o+TvpnbiSfl63bJ2HrKTG7oycNsR6CEtQIwbSDWgIQPR+5rgWLRixz3Y8lZC
      C4KILG/Cuw2vsAAAEBAPFvtdiCoxgR2IIdiuTIHzhh7RgdC8tbcdrtcI/4U8qqLFeb0xQt
      WDHYTQIf67we+2/vtxUcDZEJJO0EuRoYKXQTOBQo+jJqqrAmCJf+nZqRVXL/YA5JFX7Oiq
      N8cySPohyYSf4XP0lfYsbF2LVz0r/yGDOMfMeNOad/5kzGBPg2fClGVGYbAV1TW5zzIMi8
      sPNvjaJl7CJHtnZDrLtmH/b8yzM+sfZ0UDgvUKjfO9pd1Xz/4312QLtr4bCZSBWeodVapZ
      D4Mys/n5WucdEqVdUyUNZkWSz5i320KLvnmbEQ4fqYHR6QEDC/CPa9VrmyHjAJJ7+43+Mn
      ks4t5UWeIokAAAAfdWNlZGFAdWNlZGEtVGhpbmtQYWQtTDE1LUdlbi0yYQECAwQ=
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-redis-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:56
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.56/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo redis-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name redis-1 \n    --ram 2048 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/redis-1.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:56 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-redis-1.yaml\,network-config=/tmp/network-config-redis-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ redis-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:21:08 ------------------------------------------------
# VM: maxscale-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/maxscale-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/maxscale-1.qcow2 30G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-maxscale-1.yaml <<'EOF'
#cloud-config
hostname: maxscale-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$K2QxBrDZNRSTbvgg$KmCcyhKyGyvVh4wdMXPK/pmfK/Vz/4ZxCpUWzAfXS/YKCYqnC9xOy3KUEcUAHRPa0SOvtK7tiJeXtz1gKEina.
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 maxscale-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-maxscale-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:60
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.60/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo maxscale-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name maxscale-1 \n    --ram 2048 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/maxscale-1.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:60 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-maxscale-1.yaml\,network-config=/tmp/network-config-maxscale-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ maxscale-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:21:08 ------------------------------------------------
# VM: mariadb-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/mariadb-1.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-1-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/mariadb-1-data.qcow2 40G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-mariadb-1.yaml <<'EOF'
#cloud-config
hostname: mariadb-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$OhXLUbHFtYY2i5dV$OmUu/r5hnTAUZwzqq2ZC4OQqIhRpsl8Ewc8qZutlRbxuGhScCHGPg.zLqUwrStkNkp8jHkf70KziKivhYqPWd.
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 mariadb-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-mariadb-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:61
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.61/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo mariadb-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name mariadb-1 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/mariadb-1.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/mariadb-1-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:61 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-mariadb-1.yaml\,network-config=/tmp/network-config-mariadb-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ mariadb-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:21:08 ------------------------------------------------
# VM: mariadb-2
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-2.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/mariadb-2.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-2-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/mariadb-2-data.qcow2 40G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-mariadb-2.yaml <<'EOF'
#cloud-config
hostname: mariadb-2
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$0cx5fPidcyFF.9Rn$y2cQpLYQGwn0l9tYOX8RoASfVMH68bxcpaL5j9EE4BGUKRg9mcLzI8rUwdM4eTnHFVHu.zk4E97WXed.K10Aa/
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 mariadb-2
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-mariadb-2.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:62
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.62/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo mariadb-2 >/dev/null 2>&1; then
  sudo virt-install \
    --name mariadb-2 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/mariadb-2.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/mariadb-2-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:62 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-mariadb-2.yaml\,network-config=/tmp/network-config-mariadb-2.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ mariadb-2\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:21:08 ------------------------------------------------
# VM: mariadb-3
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-3.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/mariadb-3.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-3-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/mariadb-3-data.qcow2 40G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-mariadb-3.yaml <<'EOF'
#cloud-config
hostname: mariadb-3
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$MsiQZEpRqZTAswlu$DhKjVnw8pavHizOPoEuiTs8UINfSlu/wISHV/zUapa2UaYkR2lNH0o/68KQEOr0OLFyfMw5yhFEDfoG8jQb0S/
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 mariadb-3
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-mariadb-3.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:63
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.63/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo mariadb-3 >/dev/null 2>&1; then
  sudo virt-install \
    --name mariadb-3 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/mariadb-3.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/mariadb-3-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:63 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-mariadb-3.yaml\,network-config=/tmp/network-config-mariadb-3.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ mariadb-3\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:21:09 ------------------------------------------------
# VM: cephfs-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/cephfs-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/cephfs-1.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/cephfs-1-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/cephfs-1-data.qcow2 80G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-cephfs-1.yaml <<'EOF'
#cloud-config
hostname: cephfs-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$W3MBFU5AJ67JR/45$tSZsPyAgFNnNlumLk10YlSUr9SYo3n1Jy6/NM.LpfmFp3g61kqTpa.7OhCCm4fcd4wRDDKJTShYewG3vE04bd0
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 cephfs-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-cephfs-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:64
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.64/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo cephfs-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name cephfs-1 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/cephfs-1.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/cephfs-1-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:64 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-cephfs-1.yaml\,network-config=/tmp/network-config-cephfs-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ cephfs-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:50:50 ------------------------------------------------
# VM: redis-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/redis-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/redis-1.qcow2 30G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-redis-1.yaml <<'EOF'
#cloud-config
hostname: redis-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$5axgIeYTHn.9.xqN$ThmeYXRfH/9FWG4oF2PQ6uL9niBq5YsCD6mjlbu0QyiTYj8.WRAeCMjaFSkclkoN8JChcGr5uT4yqLvXcpxfg1
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 redis-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-redis-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:56
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.56/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo redis-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name redis-1 \n    --ram 2048 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/redis-1.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:56 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-redis-1.yaml\,network-config=/tmp/network-config-redis-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ redis-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:50:50 ------------------------------------------------
# VM: maxscale-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/maxscale-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/maxscale-1.qcow2 30G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-maxscale-1.yaml <<'EOF'
#cloud-config
hostname: maxscale-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$5RMuNded2QaYhf9O$eIMtWJczrhrevCmur964GkpOpSqRIBM5Nxoy4VFlaEjx75RpWEeWpZrfTcJE6sANnJPH6yXNnxFYt9.OhA/RD0
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 maxscale-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-maxscale-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:60
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.60/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo maxscale-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name maxscale-1 \n    --ram 2048 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/maxscale-1.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:60 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-maxscale-1.yaml\,network-config=/tmp/network-config-maxscale-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ maxscale-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:50:50 ------------------------------------------------
# VM: mariadb-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/mariadb-1.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-1-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/mariadb-1-data.qcow2 40G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-mariadb-1.yaml <<'EOF'
#cloud-config
hostname: mariadb-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$//x5P3ia5xzwZFOg$4G.NJLoT0ApL8AhuLUQxI9MvjrAu7UnMvESi1y17H7tswG2/pQVMZ1TDKsnKkC.J6jG9.36oXkNZqAp2vrhO1/
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 mariadb-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-mariadb-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:61
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.61/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo mariadb-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name mariadb-1 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/mariadb-1.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/mariadb-1-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:61 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-mariadb-1.yaml\,network-config=/tmp/network-config-mariadb-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ mariadb-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:50:50 ------------------------------------------------
# VM: mariadb-2
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-2.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/mariadb-2.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-2-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/mariadb-2-data.qcow2 40G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-mariadb-2.yaml <<'EOF'
#cloud-config
hostname: mariadb-2
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$7MvZOsr8HI.dGkCV$pckFEjhJm.6hToeTymfAx4/cpFzTze9cOiYXxuo3t8SskLAfeYeFFaYhkuS4xILZbnQEQBXMEbV73jnMotvlo/
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 mariadb-2
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-mariadb-2.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:62
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.62/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo mariadb-2 >/dev/null 2>&1; then
  sudo virt-install \
    --name mariadb-2 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/mariadb-2.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/mariadb-2-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:62 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-mariadb-2.yaml\,network-config=/tmp/network-config-mariadb-2.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ mariadb-2\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:50:50 ------------------------------------------------
# VM: mariadb-3
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-3.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/mariadb-3.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/mariadb-3-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/mariadb-3-data.qcow2 40G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-mariadb-3.yaml <<'EOF'
#cloud-config
hostname: mariadb-3
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$qDT9CyNiDKiSGZPz$YOZX2ZGQCGXrLcvaFN/wTOlB3Oezr6yJRWJJo69zzB1qT8ScpCgPtO4e/tbCi.0pJ2m2MDkOzO9yL7yLyqyez/
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 mariadb-3
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAACFwAAAAdzc2gtcn
      NhAAAAAwEAAQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5FDS4gPZbQAnf3Zeg7TJok
      FKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87xvjyCXSKF3FRGkoDZLJOd
      gUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz11tsMBacc8E/jyzXqjxl9
      QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDPIf59O9mf2m+muZKfq8KZ
      j0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T8fQBaRS3Cmu/d3m9LRYZ
      XU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5ELOGb4pFl0y3e4uXRnbBr
      Wa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5mqrE0DXd/9zXQjYbAfGa
      tPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrDnfFIv38LOphPD3tAq0Op
      cMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jwyc8tbD/GZwxqezZ8J7+p
      L3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e0KLaPwEX35W3+edKykhl
      MAAAdYd5mCNXeZgjUAAAAHc3NoLXJzYQAAAgEA5xn855g2xXLVLyKuVAdANkDOzmVrjB5F
      DS4gPZbQAnf3Zeg7TJokFKMb18WD1EDNUkXJvgScGUe4mdLDyNLsONVknUS86Fki3vh87x
      vjyCXSKF3FRGkoDZLJOdgUvFa+tnMWFLIwfDzWSbij5kowhIPy3jZ2RhH1mUMASjTCXjz1
      1tsMBacc8E/jyzXqjxl9QnGrcECH3z+5Qi/N+Wus6fNQ/idw/iPQi37/kKQbSkJET5ppDP
      If59O9mf2m+muZKfq8KZj0DKRHb8IXohuzLN8ByCzbuQtd/iuVbgIW/XwWWlWgyxXVrx3T
      8fQBaRS3Cmu/d3m9LRYZXU8OT5HhvL7fF0rrwVn8I3IqJwVeJTolqUQLrYPtJHM0xAFc5E
      LOGb4pFl0y3e4uXRnbBrWa58is+2XQuWwKEn0BBTaMEAxIoxFa3qfeF4YQDkZW7JOK+ON5
      mqrE0DXd/9zXQjYbAfGatPhaA262o5xEu1GB/Iiyh7otbyrI8hQOXMuy06QFr6bF7WzOrD
      nfFIv38LOphPD3tAq0OpcMXgEzqG3/nGx2QFpK2c/lfF/jZcQpA5eQUEnV02Yg4nXg82jw
      yc8tbD/GZwxqezZ8J7+pL3ptClm45gDUkCMOVAsULMvDTq4+ZZRLXcTtLMbnj3JoOPpj8e
      0KLaPwEX35W3+edKykhlMAAAADAQABAAACAFfMFbrepyBIShmIMXaW8pwp7ueWvE8VSOKC
      /ZiobQojDYhXu/+UJ9T3SqKk1TqUC+0Pul9IXQ11o/o8ikkHaNsGpxzgemxDQO44tS4aCG
      WHiNnxFfqxgJf3hh9FqksLIZUrD954+9aXPknvrcTVtq0BfAlT44cnV4kMXVXTyWwH+NXR
      jjWvkVzy3PXc2+nVozLVAG669WOpT/aHNtdlQuH2oHSOA21pqdb1Pp5y2jNSDaW4YeSbL+
      fhF40jQoaszhmWulmLVFxhJQqeUGAz6dRIPOMRt8ALQ4BGipSqkpVmyQ80rMu61d2blWO8
      cbS8O/XnjWwUgfxZAvXiDOvJ3lofz9GTojmksB5BKQc0Z1wnbKPlltlnvE7oSOUgwcZS/N
      VkYNYSf8E+AryTfZYm8gM4mumbW0qJ2hj7OgYIsPJetZ0E8hMlP6sHlR1MOlZSjWeInX/i
      Jf4VA4xgnBxKmSsPnrf1/AlLjJtmuugyWfMIyreS2qhM/5Mus1CjkqD7QySk9KBgAfBc7B
      jh5KEoSRMcsH3jotUplQDexZCHTXrap2818PXCwTNdQmFz6jg3Me+y7Iw8AKHwjd/2ULUQ
      1K/HBubxjxEcQdkKoeni4EdSM+1loTOz9EQoisCOcYYi2DsVvXpQ44v6u2dTWMWhGzp5Ck
      eiWgsYMhga4i2fQxWhAAABAHHA3Uojvz23DL/Tukq2jfTaQvU/1tw3oPFoMI7PyUUYsbH+
      JQeOiUP6FDKEFktcv4pJaZQpeQKAuJYpH+VTo91m67solgxHnS0hdmDUVPBRlxlZO8b98B
      uLC5g0LiEUohF2GMmXSCkqZ8gtbxD+Gis0ODqEtimC3WVlDL/cRXku19LFU2NJqrvt6CY1
      ELmS991Fnhu7GlHw0cclpFFyVANh3eIs0FzvnmfF58Q2gktmFwbObwO3OoH3ne8S5xom6i
      PVK/tZ4DPx1JkT4hZG8bdMNin8EchydHkkSdcnoXa/AwpqPTyeUMXXu4jEFjl/ka4Z25/b
      ZwWxf+1fDcXAZpQAAAEBAPUKr34Xy59Rox+EozpI/EBk4Xjf5dKV3ZE6K8ygJbwc2XYy1r
      b1PQtyGyIX6fceFqPmJU1YN5NPsyB1CRtKg+l08U6DjPymcPoF2047qEW+NTd2tRfuACYm
      fuhzibhC86homq241LmBNuNKdVHxB84Ujw4E4CFjkkZyTBA3bZHLdZ9qccNfVMBo3lwtT/
      BpzRVUDkOcymk66a203oIxKfSD5819bLiHqwzZgF1nji/MWaRs0rkX42r1jBLGZMaOhGDE
      +5yTIro0b9o+TvpnbiSfl63bJ2HrKTG7oycNsR6CEtQIwbSDWgIQPR+5rgWLRixz3Y8lZC
      C4KILG/Cuw2vsAAAEBAPFvtdiCoxgR2IIdiuTIHzhh7RgdC8tbcdrtcI/4U8qqLFeb0xQt
      WDHYTQIf67we+2/vtxUcDZEJJO0EuRoYKXQTOBQo+jJqqrAmCJf+nZqRVXL/YA5JFX7Oiq
      N8cySPohyYSf4XP0lfYsbF2LVz0r/yGDOMfMeNOad/5kzGBPg2fClGVGYbAV1TW5zzIMi8
      sPNvjaJl7CJHtnZDrLtmH/b8yzM+sfZ0UDgvUKjfO9pd1Xz/4312QLtr4bCZSBWeodVapZ
      D4Mys/n5WucdEqVdUyUNZkWSz5i320KLvnmbEQ4fqYHR6QEDC/CPa9VrmyHjAJJ7+43+Mn
      ks4t5UWeIokAAAAfdWNlZGFAdWNlZGEtVGhpbmtQYWQtTDE1LUdlbi0yYQECAwQ=
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-mariadb-3.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:63
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.63/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo mariadb-3 >/dev/null 2>&1; then
  sudo virt-install \
    --name mariadb-3 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/mariadb-3.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/mariadb-3-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:63 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-mariadb-3.yaml\,network-config=/tmp/network-config-mariadb-3.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ mariadb-3\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

# 2026-04-30 23:50:50 ------------------------------------------------
# VM: cephfs-1
# Paso 1: validar imagen base
test -f /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 || { echo '[ERROR] Falta imagen base: /var/lib/libvirt/images/ubuntu-22.04-base.qcow2'; exit 1; }

# Paso 2: generar disco del sistema (si no existe)
if [[ ! -f /var/lib/libvirt/images/cephfs-1.qcow2 ]]; then
  sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-22.04-base.qcow2 -F qcow2 /var/lib/libvirt/images/cephfs-1.qcow2 30G
fi

# Paso 3: generar disco de datos (si no existe)
if [[ ! -f /var/lib/libvirt/images/cephfs-1-data.qcow2 ]]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/cephfs-1-data.qcow2 80G
fi

# Paso 4: crear cloud-init user-data
cat > /tmp/user-data-cephfs-1.yaml <<'EOF'
#cloud-config
hostname: cephfs-1
manage_etc_hosts: false
timezone: America/El_Salvador
users:
  - name: admin
    primary_group: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$X7PLrOUkVHP85dzo$O7peGgiUbVZvaDDScBb24DDCIEQ8mVKYgsNMdNWamANdu4HF4fgkcGP83wyYFcprAXabQfW1FvpvmrRy.R2Wo0
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
chpasswd:
  expire: false
ssh_pwauth: true
write_files:
  - path: /etc/hosts
    owner: root:root
    permissions: '0644'
    content: |
      127.0.0.1 localhost
      127.0.1.1 cephfs-1
      192.168.3.56 redis-1
      192.168.3.60 maxscale-1
      192.168.3.61 mariadb-1
      192.168.3.62 mariadb-2
      192.168.3.63 mariadb-3
      192.168.3.64 cephfs-1
  - path: /home/admin/.ssh/id_rsa
    owner: admin:admin
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /home/admin/.ssh/id_rsa.pub
    owner: admin:admin
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /home/admin/.ssh/authorized_keys
    owner: admin:admin
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/id_rsa
    owner: root:root
    permissions: '0600'
    content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      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
      -----END OPENSSH PRIVATE KEY-----
  - path: /root/.ssh/id_rsa.pub
    owner: root:root
    permissions: '0644'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
  - path: /root/.ssh/authorized_keys
    owner: root:root
    permissions: '0600'
    content: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDnGfznmDbFctUvIq5UB0A2QM7OZWuMHkUNLiA9ltACd/dl6DtMmiQUoxvXxYPUQM1SRcm+BJwZR7iZ0sPI0uw41WSdRLzoWSLe+HzvG+PIJdIoXcVEaSgNksk52BS8Vr62cxYUsjB8PNZJuKPmSjCEg/LeNnZGEfWZQwBKNMJePPXW2wwFpxzwT+PLNeqPGX1CcatwQIffP7lCL835a6zp81D+J3D+I9CLfv+QpBtKQkRPmmkM8h/n072Z/ab6a5kp+rwpmPQMpEdvwheiG7Ms3wHILNu5C13+K5VuAhb9fBZaVaDLFdWvHdPx9AFpFLcKa793eb0tFhldTw5PkeG8vt8XSuvBWfwjcionBV4lOiWpRAutg+0kczTEAVzkQs4ZvikWXTLd7i5dGdsGtZrnyKz7ZdC5bAoSfQEFNowQDEijEVrep94XhhAORlbsk4r443maqsTQNd3/3NdCNhsB8Zq0+FoDbrajnES7UYH8iLKHui1vKsjyFA5cy7LTpAWvpsXtbM6sOd8Ui/fws6mE8Pe0CrQ6lwxeATOobf+cbHZAWkrZz+V8X+NlxCkDl5BQSdXTZiDideDzaPDJzy1sP8ZnDGp7Nnwnv6kvem0KWbjmANSQIw5UCxQsy8NOrj5llEtdxO0sxuePcmg4+mPx7Qoto/ARfflbf550rKSGUw== uceda@uceda-ThinkPad-L15-Gen-2a
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdTy1c/HriciPjqVmUrnQ96EWkg/eo203WTfdqa5gSvNbrMgLN9dIFoiGHkxas+OfTorFsLSy5pMHQpZzqq1JYKVgxDBU/IjBtHf34jgDfZYNWLR4zikRCYJpmedo91RcQTa63HHUfxw/px7DLsubPEgUhgLTTHo685tepWFA4GxVTMJMVSd9+DSpbOkGzFwmm9+pBgBq/0Z3DUnTQftttTyPPCMxru59BToTNAgpbDI2Alld143hHLL0btwnFEL/UhNmeoXmvcX5C4d1sqVe+9Ja38QRYd58jbi8F+SvyYGPVCjVbKv5h5BSVsAEpf36JlJjXSwxdHUB0Rc0aPXbB0K0zDuv3cAhF7QxVAqKV7Q2LO8oKUzFXR62IywXQCtW5SjZZHmrUR8+8/EX/C9FtjXgHrSoEMMc256oJ09hDLqhoktezgYDVAYl/yhnIrmPPU31u1XPDVom2J0T8dA1j0ts+ZhjwD3+F55PPnG5HDwT7f2RcXdYurnJ1Yr0vH2pkoE/A/KZ3R6MBJIvcGkBT2PEXdMAtI14J+ZirmmhMHBMdOUtX48MeKNDFyjvvLKT4UA8NgQqoBLbZDjjJruGCWMKC+/0uIrFmkWdd8lyJDS96V97BTeYKxHOJNyagdE7TaR4AV+SpkH6xFnRPPWxvcHjflW7WvQ6q63EbEEmCAQ== uceda@uceda-ThinkPad-L15-Gen-2a

package_update: true
packages:
  - chrony
  - openssh-server
  - curl
  - qemu-guest-agent
runcmd:
  - timedatectl set-timezone America/El_Salvador || true
  - sed -i '/^pool /d;/^server /d' /etc/chrony/chrony.conf
  - printf 'server ntp.ues.edu.sv iburst\n' >> /etc/chrony/chrony.conf
  - systemctl enable --now chrony
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod 700 /home/admin/.ssh
  - chmod 600 /home/admin/.ssh/id_rsa /home/admin/.ssh/authorized_keys
  - chmod 644 /home/admin/.ssh/id_rsa.pub
  - chown -R admin:admin /home/admin/.ssh
  - chmod 700 /root/.ssh
  - chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
  - chmod 644 /root/.ssh/id_rsa.pub

EOF

# Paso 5: crear cloud-init network-config
cat > /tmp/network-config-cephfs-1.yaml <<'EOF'
version: 2
ethernets:
  enp1s0:
    match:
      macaddress: 52:54:00:cc:dd:64
    set-name: enp1s0
    dhcp4: false
    addresses: [192.168.3.64/24]
    routes:
      - to: default
        via: 192.168.3.1
    nameservers:
      addresses: [192.168.3.55,8.8.8.8]
EOF

# Paso 6: crear VM con virt-install
if ! sudo virsh dominfo cephfs-1 >/dev/null 2>&1; then
  sudo virt-install \
    --name cephfs-1 \n    --ram 4096 \n    --vcpus 2 \n    --disk path=/var/lib/libvirt/images/cephfs-1.qcow2\,format=qcow2 \n    --disk path=/var/lib/libvirt/images/cephfs-1-data.qcow2\,format=qcow2 \n    --network network=net-192-168-3\,model=virtio\,mac=52:54:00:cc:dd:64 \n    --os-variant ubuntu22.04 \n    --cloud-init user-data=/tmp/user-data-cephfs-1.yaml\,network-config=/tmp/network-config-cephfs-1.yaml \n    --noautoconsole \n    --import
else
  echo \[WARN\]\ La\ VM\ cephfs-1\ ya\ existe\ en\ libvirt.\ Se\ omite\ creacion.
fi

