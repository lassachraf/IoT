#!/bin/bash
set -e
CLUSTER_NAME="iot-alassiqu"
echo "==> Deleting cluster '${CLUSTER_NAME}'..."
k3d cluster delete "$CLUSTER_NAME" || true
echo "[OK] Cluster removed."