#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[k3s] $1"
}

if [[ $(id -u) -eq 0 ]]; then
  log "Please run this script as a non-root user with sudo privileges."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  log "curl not found. Installing curl..."
  sudo yum install -y curl
fi

log "Installing k3s (single-node Kubernetes)..."
curl -sfL https://get.k3s.io | sh -

log "Configuring kubectl for current user..."
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

export KUBECONFIG="$HOME/.kube/config"

log "Waiting for node to be Ready..."
for i in {1..30}; do
  if kubectl get nodes 2>/dev/null | grep -q " Ready "; then
    log "Node is Ready."
    kubectl get nodes
    exit 0
  fi
  sleep 5
  log "Still waiting..."
done

log "Timed out waiting for node readiness. Check 'kubectl get nodes'."
exit 1
