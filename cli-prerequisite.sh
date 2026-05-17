#!/usr/bin/env bash

#set -euo pipefail

echo "========================================"
echo " DevOps / Cloud CLI Installation Script "
echo " Ubuntu / Debian Linux"
echo "========================================"

# -----------------------------------------------------------------------------
# Update System Packages
# -----------------------------------------------------------------------------

echo ""
echo "[1/9] Updating packages..."

sudo apt update
sudo apt install -y \
    curl \
    wget \
    unzip \
    gnupg \
    software-properties-common \
    git \
    jq \
    python3 \
    python3-pip \
    ca-certificates

# -----------------------------------------------------------------------------
# Create ~/bin and Ensure PATH
# -----------------------------------------------------------------------------

echo ""
echo "[2/9] Configuring ~/bin..."

mkdir -p "$HOME/bin"

if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
fi

export PATH="$HOME/bin:$PATH"

# -----------------------------------------------------------------------------
# Install AWS CLI
# -----------------------------------------------------------------------------

echo ""
echo "[3/9] Installing AWS CLI..."

cd /tmp

curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

rm -rf aws
unzip -oq awscliv2.zip

sudo ./aws/install --update

echo "AWS CLI Installed:"
aws --version

# -----------------------------------------------------------------------------
# Install kubectl
# -----------------------------------------------------------------------------

echo ""
echo "[4/9] Installing kubectl..."

KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

chmod +x kubectl
mv kubectl "$HOME/bin/kubectl"

echo "kubectl Installed:"
kubectl version --client

# -----------------------------------------------------------------------------
# Install Helm
# -----------------------------------------------------------------------------

echo ""
echo "[5/9] Installing Helm..."

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "Helm Installed:"
helm version

# -----------------------------------------------------------------------------
# Install Terraform via tfenv
# -----------------------------------------------------------------------------

echo ""
echo "[6/9] Installing Terraform via tfenv..."

if [ ! -d "$HOME/.tfenv" ]; then
    git clone https://github.com/tfutils/tfenv.git ~/.tfenv
fi

ln -sf ~/.tfenv/bin/* "$HOME/bin/"

TF_VERSION="1.5.7"

tfenv install "${TF_VERSION}" || true
tfenv use "${TF_VERSION}"

echo "Terraform Installed:"
terraform --version

# -----------------------------------------------------------------------------
# Install ArgoCD CLI
# -----------------------------------------------------------------------------

echo ""
echo "[7/9] Installing ArgoCD CLI..."

curl -sSL -o argocd-linux-amd64 \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

chmod +x argocd-linux-amd64
mv argocd-linux-amd64 "$HOME/bin/argocd"

echo "ArgoCD Installed:"
argocd version --client

# -----------------------------------------------------------------------------
# Install Ansible
# -----------------------------------------------------------------------------

echo ""
echo "[8/9] Installing Ansible..."

python3 -m pip install --user ansible

echo "Ansible Installed:"
~/.local/bin/ansible --version

# -----------------------------------------------------------------------------
# Install Docker
# -----------------------------------------------------------------------------

echo ""
echo "[9/9] Installing Docker..."

curl -fsSL https://get.docker.com | sh

sudo usermod -aG docker "$USER"

echo "Docker Installed:"
docker version

# -----------------------------------------------------------------------------
# Install Trivy
# -----------------------------------------------------------------------------

echo ""
echo "Installing Trivy..."

curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
sh -s -- -b /usr/local/bin

echo "Trivy Installed:"
trivy --version

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------

echo ""
echo "========================================"
echo " Installation Complete"
echo "========================================"

echo ""
echo "IMPORTANT:"
echo "- Restart your shell or run: source ~/.bashrc"
echo "- Logout/login may be required for Docker group changes"
echo "- Verify tools manually if needed"
echo ""

echo "Installed Versions:"
echo "-------------------"

aws --version || true
kubectl version --client || true
helm version || true
terraform --version || true
argocd version --client || true
docker version || true
trivy --version || true
~/.local/bin/ansible --version || true