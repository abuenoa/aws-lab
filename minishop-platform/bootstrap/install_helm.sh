#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[helm] $1"
}

if [[ $(id -u) -eq 0 ]]; then
  log "Please run this script as a non-root user with sudo privileges."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  log "curl not found. Installing curl..."
  sudo yum install -y curl
fi

log "Downloading and installing Helm 3..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

log "Verifying Helm installation..."
helm version
