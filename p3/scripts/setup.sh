#!/bin/bash
set -e

CLUSTER_NAME="iot-alassiqu"

echo "==> [1/5] Deleting any existing cluster '${CLUSTER_NAME}'..."
k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true

echo "==> [2/5] Creating K3d cluster..."
k3d cluster create "$CLUSTER_NAME" \
    --port "8888:8888@loadbalancer" \
    --port "8080:80@loadbalancer" \
    --port "8443:443@loadbalancer" \
    --agents 1 \
    --wait

echo "==> [3/5] Creating 'argocd' namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "==> [4/5] Installing Argo CD (stable)..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> Waiting for Argo CD pods to be Ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo "==> [5/5] Exposing Argo CD UI on NodePort 30443..."
kubectl patch svc argocd-server -n argocd -p \
'{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"targetPort":8080,"nodePort":30443}]}}'

echo ""
echo "============================================================"
echo " Argo CD is up."
echo "  URL      : https://localhost:30443"
echo "  Username : admin"
echo -n "  Password : "
kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "============================================================"
echo " Next step: create GitHub repo 'iot-alassiqu' with deployment.yaml,"
echo " then run: kubectl apply -f confs/application.yaml"
echo "============================================================"