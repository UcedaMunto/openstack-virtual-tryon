#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${ROOT_DIR}/scripts/00-check-prereqs.sh"
bash "${ROOT_DIR}/scripts/10-create-networks.sh"
bash "${ROOT_DIR}/scripts/20-create-vms.sh"
bash "${ROOT_DIR}/scripts/30-bootstrap-ceph.sh"
