#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[k3s] $1"
}

is_amazon_linux_2=false
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${NAME:-}" == "Amazon Linux" && "${VERSION_ID:-}" == "2" ]]; then
    is_amazon_linux_2=true
  fi
fi

if [[ $(id -u) -eq 0 ]]; then
  log "Please run this script as a non-root user with sudo privileges."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  log "curl not found. Installing curl..."
  sudo yum install -y curl
fi

if command -v k3s >/dev/null 2>&1; then
  log "k3s is already installed. Skipping installation."
else
  if [[ "$is_amazon_linux_2" == "true" ]]; then
    log "Amazon Linux 2 detected. Skipping SELinux RPM to avoid container-selinux conflicts."
    log "This is a lab-friendly workaround and is sufficient for this demo."
    curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -
  else
    log "Installing k3s (single-node Kubernetes)..."
    curl -sfL https://get.k3s.io | sh -
  fi
fi

log "Configuring kubectl for current user..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

log "Validating Kubernetes node readiness..."
for i in {1..30}; do
  if kubectl get nodes >/dev/null 2>&1 && kubectl get nodes | grep -q " Ready "; then
    log "Node is Ready and kubectl is working."
    kubectl get nodes
    exit 0
  fi
  sleep 5
  log "Still waiting..."
done

log "Timed out waiting for node readiness. Check 'kubectl get nodes'."
exit 1
