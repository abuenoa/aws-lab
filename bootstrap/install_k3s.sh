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

if sudo systemctl is-active --quiet k3s; then
  log "k3s service is already running. Skipping installation."
else
  if [[ "$is_amazon_linux_2" == "true" ]]; then
    log "Amazon Linux 2 detected. Skipping SELinux RPM to avoid container-selinux conflicts."
    log "This is a lab-friendly workaround and is sufficient for this demo."
  fi
  log "Installing k3s (single-node Kubernetes)..."
  curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -
fi

log "Ensuring k3s service is enabled and running..."
sudo systemctl enable --now k3s
if ! sudo systemctl is-active --quiet k3s; then
  log "k3s service is not active. Showing recent logs:"
  sudo journalctl -u k3s --no-pager -n 50
  exit 1
fi

log "Ensuring kubectl is available..."
sudo ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl

log "Configuring kubeconfig for current user..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
if ! grep -q "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" "$HOME/.bashrc" 2>/dev/null; then
  echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> "$HOME/.bashrc"
fi

log "Validating Kubernetes node readiness..."
if ! kubectl get nodes; then
  log "kubectl validation failed. Ensure KUBECONFIG is set and k3s is running."
  exit 1
fi

log "k3s installation complete."
