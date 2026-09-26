#!/usr/bin/env bash
# =============================================================================
# _copiar-conocimientos.sh
# -----------------------------------------------------------------------------
# Copia, desde los proyectos de referencia, ÚNICAMENTE los archivos de texto
# útiles (guías .md, scripts, XML, YAML, PlantUML, configs, ejemplos) hacia la
# carpeta de documentación genérica del proyecto openstack-virtual-tryon.
#
# Excluye deliberadamente: binarios (ISO/qcow2/img/pdf/docx/pptx/png/jpg/jar),
# claves privadas SSH, entornos virtuales (.venv*), .git, node_modules y
# cachés, para dejar un árbol de documentación ligero y versionable.
#
# Re-ejecutable: cada `sync_dir` sobrescribe el destino sin duplicar.
# =============================================================================
set -euo pipefail

DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# NOTA: los '*.md' originales ya NO se copian a las carpetas temáticas;
# viven en trash/ (movidos ahí tras consolidar el README.md único).
INCLUDE=(
  '*/'
  '*.sh' '*.bash' '*.xml' '*.yml' '*.yaml' '*.puml' '*.txt'
  '*.cfg' '*.conf' '*.ini' '*.env' '*.j2' '*.jinja2' '*.json' '*.toml'
  '*.tmpl' '*.py' '*.cnf' '*.list' '*.html'
)
EXCLUDE=(
  '.git/' '.venv/' '.venv-*/' '.vscode/' 'node_modules/' '__pycache__/'
  '*.pyc' '.tools/' '.mypy_cache/' '.pytest_cache/'
  '*.iso' '*.qcow2' '*.img' '*.pdf' '*.docx' '*.pptx' '*.odt'
  '*.png' '*.jpg' '*.jpeg' '*.webp' '*.avif' '*.gif' '*.svg' '*.jar'
  '*.gz' '*.tgz' '*.zip' '*.pid' '*.log' '*.db' '*.sqlite3'
  'id_rsa' 'id_rsa.pub' 'id_ed25519' 'id_ed25519.pub' '*.pub'
  'seed.iso' 'plantuml.jar'
  'backups 2/' 'backups 3/' '.venv-django-local/' 'ssh-keys/' 'disks/'
  'vms/' 'vms-bridge01/' 'camisas/' 'imagenes-modelo/' 'staticfiles/'
)

sync_dir() {
  local src="$1" dst="$2"
  local args=()
  for e in "${EXCLUDE[@]}"; do args+=(--exclude="$e"); done
  for i in "${INCLUDE[@]}"; do args+=(--include="$i"); done
  args+=(--exclude='*')
  mkdir -p "$dst"
  rsync -a --prune-empty-dirs "${args[@]}" "$src/" "$dst/"
  echo "OK -> $dst"
}

# 1) InstalacionOpenstack (manual OSA + lab Kolla-Ansible/K8s). Se excluye
#    documentacion_ansible porque tiene carpeta propia (fuente 7).
sync_dir /home/uceda/Documents/InstalacionOpenstack \
  "$DEST/01-InstalacionOpenstack"
rm -rf "$DEST/01-InstalacionOpenstack/documentacion_ansible"

# 2) cluster-ceph
sync_dir /home/uceda/Documents/cluster-ceph \
  "$DEST/02-cluster-ceph"

# 3) PRACTICA (LAB 1 KVM)
sync_dir "/home/uceda/Documents/ESPECIALIZACION/LAB 1/PRACTICA" \
  "$DEST/03-PRACTICA-KVM"

# 4) LXC (Ceph docker + Ceph KVM)
sync_dir /home/uceda/Documents/ESPECIALIZACION/LXC \
  "$DEST/04-LXC-ceph"

# 5) redes-xml-kvm
sync_dir /home/uceda/Documents/redes-xml-kvm \
  "$DEST/05-redes-xml-kvm"

# 6) guias123
sync_dir /home/uceda/Documents/ESPECIALIZACION/guias123 \
  "$DEST/06-guias123"

# 7) documentacion_ansible
sync_dir /home/uceda/Documents/InstalacionOpenstack/documentacion_ansible \
  "$DEST/07-documentacion-ansible"

echo "=== Copia completada ==="
find "$DEST" -type f | wc -l
