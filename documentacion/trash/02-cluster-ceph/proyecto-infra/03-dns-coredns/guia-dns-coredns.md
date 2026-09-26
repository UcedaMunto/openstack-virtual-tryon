# Guia - DNS con CoreDNS

Objetivo: desplegar VM para DNS interno y configurar CoreDNS.

Referencia central de estructura y conexiones:
- `../00-estructura-conexiones.md`

## Secuencia de comandos VM

```bash
cd /home/uceda/Documents/cluster-ceph/proyecto-infraestructura/03-dns-coredns
bash 03-dns-coredns.sh plan
bash 03-dns-coredns.sh apply
```

Nota operativa:
- `plan` deja un archivo de comandos trazable.
- `apply` crea la VM directamente para evitar errores de sintaxis en ejecucion de algunos archivos generados por `--comandos`.

## Secuencia de comandos CoreDNS (dentro de dns-1)

```bash
sudo apt update
sudo apt install -y curl tar

cd /tmp
curl -LO https://github.com/coredns/coredns/releases/download/v1.11.1/coredns_1.11.1_linux_amd64.tgz
tar -xzf coredns_1.11.1_linux_amd64.tgz
sudo mv coredns /usr/local/bin/coredns
sudo chmod +x /usr/local/bin/coredns

sudo mkdir -p /etc/coredns
cat <<'EOF' | sudo tee /etc/coredns/Corefile
mimas.net:53 {
  bind 192.168.3.55
  hosts {
    192.168.3.50 lb1.mimas.net
    192.168.3.51 lb2.mimas.net
    192.168.3.52 app1.mimas.net
    192.168.3.53 app2.mimas.net
    192.168.3.54 app3.mimas.net
    fallthrough
  }
  forward . 8.8.8.8 1.1.1.1
  log
  errors
}
EOF

cat <<'EOF' | sudo tee /etc/systemd/system/coredns.service
[Unit]
Description=CoreDNS
After=network.target

[Service]
ExecStart=/usr/local/bin/coredns -conf /etc/coredns/Corefile
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now coredns
sudo systemctl status coredns --no-pager
```

Nota importante:
- Si CoreDNS falla con `bind: address already in use`, normalmente `systemd-resolved` ya usa `127.0.0.53:53`.
- Mantener `bind 192.168.3.55` en el Corefile evita el conflicto y permite servir DNS interno en la IP de la VM.

## Validar DNS

```bash
dig @192.168.3.55 app1.mimas.net +short
dig @192.168.3.55 lb1.mimas.net +short
```
