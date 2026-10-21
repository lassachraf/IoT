#!/bin/bash

# Stop the script immediately if a command fails.
set -e

# Refresh package lists and install curl
apt-get update
apt-get install -y curl

# Install K3s as the Kubernetes server (control-plane).
# --node-ip: use the VM's fixed IP address.
# --flannel-iface: use eth1 for communication between nodes.
# --write-kubeconfig-mode 644: allow users to read the kubeconfig file.
curl -sfL https://get.k3s.io | sh -s - server \
    --node-ip 192.168.56.110 \
    --flannel-iface eth1 \
    --write-kubeconfig-mode 644

# Read the token that worker nodes need to authenticate with the server.
sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token

# Ensure the shared token file can be read by the worker VM.
chmod 644 /vagrant/node-token
