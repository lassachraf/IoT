#!/bin/bash
set -e

echo "==> [1/4] Installing Docker..."
if ! command -v docker &>/dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER" || true
    echo "    -> Docker installed. (You may need to log out/in for the docker group.)"
else
    echo "    -> Docker already installed."
fi

# Ensure docker group exists and add user
if getent group docker >/dev/null; then
    echo "    -> docker group exists."
else
    sudo groupadd docker
fi

if id -nG "$USER" | grep -qw docker; then
    echo "    -> User already in docker group."
else
    sudo usermod -aG docker "$USER"
    echo "    -> Added $USER to docker group."
fi

# Check if the current shell can use docker without sudo
if docker ps >/dev/null 2>&1; then
    echo "    -> Docker is usable without sudo in this shell."
else
    echo ""
    echo "    [WARNING] Docker is NOT usable without sudo in this shell."
    echo "    You MUST log out and log back in (or reboot) before running setup.sh."
    echo "    Do NOT continue until 'docker ps' works without sudo."
    echo ""
    exit 1
fi

echo "==> [2/4] Installing k3d..."
if ! command -v k3d &>/dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
    echo "    -> k3d already installed."
fi

echo "==> [3/4] Installing kubectl..."
if ! command -v kubectl &>/dev/null; then
    KVER=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
else
    echo "    -> kubectl already installed."
fi

echo "==> [4/4] Installing argocd CLI..."
if ! command -v argocd &>/dev/null; then
    curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd /usr/local/bin/argocd
    rm -f argocd
else
    echo "    -> argocd CLI already installed."
fi

echo ""
echo "[OK] All dependencies installed."
echo "     Versions:"
docker --version 2>/dev/null || echo "  docker : (re-login required)"
k3d version       | head -n1
kubectl version --client=true --output=yaml 2>/dev/null | grep gitVersion || kubectl version --client
argocd version --client 2>/dev/null | head -n1