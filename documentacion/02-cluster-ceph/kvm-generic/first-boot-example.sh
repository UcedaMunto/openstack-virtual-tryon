#!/usr/bin/env bash
set -euo pipefail

# Script opcional de primer arranque para personalizaciones extra.
# Se ejecuta una sola vez via cloud-init durante la creacion inicial.

echo "[first-boot] Inicio $(date -Iseconds)" | sudo tee -a /var/log/first-boot-custom.log

sudo apt update
sudo apt install -y htop jq

sudo mkdir -p /opt/lab
echo "Bootstrap completado en $(date -Iseconds)" | sudo tee /opt/lab/bootstrap.txt >/dev/null

echo "[first-boot] Fin $(date -Iseconds)" | sudo tee -a /var/log/first-boot-custom.log
